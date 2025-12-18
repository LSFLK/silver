# imap_tester.py - IMAP load testing tasks
import time
import ssl
import imaplib
import logging
from locust import User, task, between

from config import EmailServerConfig
from user_manager import TestUserManager

logger = logging.getLogger(__name__)


class IMAPLoadTester(User):
    """IMAP Load Testing User with robust connection handling"""
    wait_time = between(2, 8)
    weight = 2
    
    def on_start(self):
        self.config = EmailServerConfig()
        self.user_manager = TestUserManager()
        self.user_account = self.user_manager.get_random_user()
        self.working_config = None  # Cache working config
        logger.info(f"Starting IMAP tests for user: {self.user_account['email']}")
    
    def _create_ssl_context(self):
        """Create a more permissive SSL context"""
        try:
            context = ssl.create_default_context()
            # Allow older TLS versions if needed
            context.minimum_version = ssl.TLSVersion.TLSv1_2
            # For testing environments, you might need to disable cert verification
            # context.check_hostname = False
            # context.verify_mode = ssl.CERT_NONE
            return context
        except Exception:
            return None
    
    def _try_imap_connection(self, config):
        """Try a specific IMAP configuration"""
        mail = None
        try:
            if config.get("ssl", False):
                # Direct SSL connection
                context = self._create_ssl_context()
                mail = imaplib.IMAP4_SSL(
                    self.config.IMAP_SERVER, 
                    config["port"],
                    ssl_context=context
                )
            else:
                # Plain connection, possibly with STARTTLS
                mail = imaplib.IMAP4(self.config.IMAP_SERVER, config["port"])
                if config.get("starttls", False):
                    context = self._create_ssl_context()
                    mail.starttls(ssl_context=context)
            
            # Test login
            mail.login(self.user_account['username'], self.user_account['password'])
            logger.info(f"IMAP connection successful using {config['name']} on port {config['port']}")
            return mail, config
            
        except Exception as e:
            logger.debug(f"IMAP connection failed for {config['name']}: {e}")
            if mail:
                try: 
                    mail.logout()
                except: 
                    pass
            return None, None
    
    def _connect_imap(self):
        """Connect to IMAP with fallback configurations"""
        start_time = time.time()
        
        # If we have a working config, try it first
        if self.working_config:
            mail, config = self._try_imap_connection(self.working_config)
            if mail:
                self.environment.events.request.fire(
                    request_type="IMAP",
                    name="connect",
                    response_time=(time.time() - start_time) * 1000,
                    response_length=0,
                    exception=None
                )
                return mail
        
        # Try all configurations until one works
        for config in self.config.IMAP_CONFIGS:
            mail, working_config = self._try_imap_connection(config)
            if mail:
                self.working_config = working_config  # Cache for future use
                self.environment.events.request.fire(
                    request_type="IMAP",
                    name="connect",
                    response_time=(time.time() - start_time) * 1000,
                    response_length=0,
                    exception=None
                )
                return mail
        
        # All configurations failed
        error_msg = f"All IMAP connection methods failed for {self.config.IMAP_SERVER}"
        logger.error(error_msg)
        self.environment.events.request.fire(
            request_type="IMAP",
            name="connect",
            response_time=(time.time() - start_time) * 1000,
            response_length=0,
            exception=Exception(error_msg)
        )
        return None

    @task(5)
    def check_inbox(self):
        """Check inbox for new messages"""
        mail = self._connect_imap()
        if not mail: 
            return
            
        start_time = time.time()
        try:
            mail.select('INBOX')
            status, messages = mail.search(None, 'ALL')
            message_count = len(messages[0].split()) if messages[0] else 0
            mail.logout()
            
            self.environment.events.request.fire(
                request_type="IMAP",
                name="check_inbox",
                response_time=(time.time() - start_time) * 1000,
                response_length=message_count,
                exception=None
            )
            logger.info(f"Inbox check successful: {message_count} messages")
            
        except Exception as e:
            self.environment.events.request.fire(
                request_type="IMAP",
                name="check_inbox",
                response_time=(time.time() - start_time) * 1000,
                response_length=0,
                exception=e
            )
            if mail:
                try: 
                    mail.logout()
                except: 
                    pass
            logger.error(f"Inbox check failed: {e}")

    @task(3)
    def list_folders(self):
        """List available folders"""
        mail = self._connect_imap()
        if not mail: 
            return
            
        start_time = time.time()
        try:
            status, folders = mail.list()
            folder_count = len(folders) if folders else 0
            mail.logout()
            
            self.environment.events.request.fire(
                request_type="IMAP",
                name="list_folders",
                response_time=(time.time() - start_time) * 1000,
                response_length=folder_count,
                exception=None
            )
            logger.info(f"Folder listing successful: {folder_count} folders")
            
        except Exception as e:
            self.environment.events.request.fire(
                request_type="IMAP",
                name="list_folders",
                response_time=(time.time() - start_time) * 1000,
                response_length=0,
                exception=e
            )
            if mail:
                try: 
                    mail.logout()
                except: 
                    pass
            logger.error(f"Folder listing failed: {e}")

    @task(2)
    def fetch_recent_messages(self):
        """Fetch recent messages"""
        mail = self._connect_imap()
        if not mail: 
            return
            
        start_time = time.time()
        try:
            mail.select('INBOX')
            # Get recent messages (last 5)
            status, messages = mail.search(None, 'ALL')
            if messages[0]:
                message_ids = messages[0].split()
                recent_ids = message_ids[-5:] if len(message_ids) >= 5 else message_ids
                
                fetched_count = 0
                for msg_id in recent_ids:
                    status, msg_data = mail.fetch(msg_id, '(RFC822)')
                    if status == 'OK':
                        fetched_count += 1
                
                mail.logout()
                
                self.environment.events.request.fire(
                    request_type="IMAP",
                    name="fetch_messages",
                    response_time=(time.time() - start_time) * 1000,
                    response_length=fetched_count,
                    exception=None
                )
                logger.info(f"Message fetch successful: {fetched_count} messages")
            else:
                mail.logout()
                self.environment.events.request.fire(
                    request_type="IMAP",
                    name="fetch_messages",
                    response_time=(time.time() - start_time) * 1000,
                    response_length=0,
                    exception=None
                )
                
        except Exception as e:
            self.environment.events.request.fire(
                request_type="IMAP",
                name="fetch_messages",
                response_time=(time.time() - start_time) * 1000,
                response_length=0,
                exception=e
            )
            if mail:
                try: 
                    mail.logout()
                except: 
                    pass
            logger.error(f"Message fetch failed: {e}")
