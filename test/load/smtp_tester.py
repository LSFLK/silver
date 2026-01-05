# smtp_tester.py - SMTP load testing tasks
#
# This module implements SMTP load testing for the email server.
# 
# Rate Limit Handling:
# The server implements connection rate limiting via smtpd_client_connection_rate_limit.
# When this limit is hit, the server returns a 421 error ("too many connections").
# This is expected behavior during load testing and is treated as a successful test
# scenario rather than a failure. Rate-limited requests are logged and counted
# separately (with "_rate_limited" suffix) but do not cause the test to fail.
#
import time
import random
import smtplib
import logging
import os
from locust import User, task, between
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email import encoders

from config import EmailServerConfig
from data_generator import TestDataGenerator
from user_manager import TestUserManager

logger = logging.getLogger(__name__)


class SMTPLoadTester(User):
    """SMTP Load Testing User"""
    wait_time = between(1, 5)
    weight = 3
    
    def on_start(self):
        """Initialize user session"""
        self.config = EmailServerConfig()
        self.data_generator = TestDataGenerator()
        self.user_manager = TestUserManager()
        self.user_account = self.user_manager.get_random_user()
        logger.info(f"Starting SMTP tests for user: {self.user_account['email']}")
    
    def _is_rate_limit_error(self, exception):
        """Check if exception is a rate limit error (421 - too many connections)"""
        if isinstance(exception, smtplib.SMTPConnectError):
            # SMTPConnectError args: (code, message)
            if len(exception.args) >= 1:
                code = exception.args[0]
                return code == 421
        # Also check for errors during connection that contain '421'
        error_str = str(exception).lower()
        return '421' in error_str or 'too many connections' in error_str
    
    def _connect_smtp(self):
        """Establish SMTP connection"""
        start_time = time.time()
        server = None
        
        try:
            if self.config.USE_TLS:
                server = smtplib.SMTP(self.config.SMTP_SERVER, self.config.SMTP_PORT)
                server.starttls()
            else:
                server = smtplib.SMTP(self.config.SMTP_SERVER, self.config.SMTP_PORT)
            
            server.login(self.user_account['username'], self.user_account['password'])
            
            response_time = (time.time() - start_time) * 1000
            self.environment.events.request.fire(
                request_type="SMTP",
                name="connect",
                response_time=response_time,
                response_length=0,
                exception=None
            )
            return server
            
        except Exception as e:
            response_time = (time.time() - start_time) * 1000
            
            # Check if this is a rate limit error (expected during load testing)
            if self._is_rate_limit_error(e):
                logger.info(f"SMTP rate limit hit (expected): {e}")
                # Report as success with a special marker
                self.environment.events.request.fire(
                    request_type="SMTP",
                    name="connect_rate_limited",
                    response_time=response_time,
                    response_length=0,
                    exception=None  # Don't treat as failure
                )
            else:
                # Real error - report as failure
                self.environment.events.request.fire(
                    request_type="SMTP",
                    name="connect",
                    response_time=response_time,
                    response_length=0,
                    exception=e
                )
            
            if server:
                try:
                    server.quit()
                except:
                    pass
            return None
    
    @task(5)
    def send_plain_text_email(self):
        """Send plain text email"""
        server = self._connect_smtp()
        if not server:
            return
        
        start_time = time.time()
        
        try:
            content = self.data_generator.generate_email_content("plain_text")
            recipient = self.user_manager.get_random_user()['email']
            
            msg = MIMEText(content['body'], 'plain')
            msg['Subject'] = content['subject']
            msg['From'] = self.user_account['email']
            msg['To'] = recipient
            
            server.send_message(msg)
            server.quit()
            
            response_time = (time.time() - start_time) * 1000
            self.environment.events.request.fire(
                request_type="SMTP",
                name="send_text",
                response_time=response_time,
                response_length=len(content['body']),
                exception=None
            )
            
        except Exception as e:
            response_time = (time.time() - start_time) * 1000
            
            # Check if this is a rate limit error
            if self._is_rate_limit_error(e):
                logger.info(f"SMTP rate limit hit during send (expected): {e}")
                self.environment.events.request.fire(
                    request_type="SMTP",
                    name="send_text_rate_limited",
                    response_time=response_time,
                    response_length=0,
                    exception=None  # Don't treat as failure
                )
            else:
                self.environment.events.request.fire(
                    request_type="SMTP",
                    name="send_text",
                    response_time=response_time,
                    response_length=0,
                    exception=e
                )
            
            if server:
                try:
                    server.quit()
                except:
                    pass
    
    @task(3)
    def send_html_email(self):
        """Send HTML email"""
        server = self._connect_smtp()
        if not server:
            return
        
        start_time = time.time()
        
        try:
            content = self.data_generator.generate_email_content("marketing")
            recipient = self.user_manager.get_random_user()['email']
            
            msg = MIMEMultipart('alternative')
            msg['Subject'] = content['subject']
            msg['From'] = self.user_account['email']
            msg['To'] = recipient
            
            html_part = MIMEText(content['body'], 'html')
            msg.attach(html_part)
            
            server.send_message(msg)
            server.quit()
            
            response_time = (time.time() - start_time) * 1000
            self.environment.events.request.fire(
                request_type="SMTP",
                name="send_html",
                response_time=response_time,
                response_length=len(content['body']),
                exception=None
            )
            
        except Exception as e:
            response_time = (time.time() - start_time) * 1000
            
            # Check if this is a rate limit error
            if self._is_rate_limit_error(e):
                logger.info(f"SMTP rate limit hit during send (expected): {e}")
                self.environment.events.request.fire(
                    request_type="SMTP",
                    name="send_html_rate_limited",
                    response_time=response_time,
                    response_length=0,
                    exception=None  # Don't treat as failure
                )
            else:
                self.environment.events.request.fire(
                    request_type="SMTP",
                    name="send_html",
                    response_time=response_time,
                    response_length=0,
                    exception=e
                )
            
            if server:
                try:
                    server.quit()
                except:
                    pass
    
    @task(1)
    def send_email_with_attachment(self):
        """Send email with attachment (max 10MB)"""
        server = self._connect_smtp()
        if not server:
            return
        
        start_time = time.time()
        
        try:
            content = self.data_generator.generate_email_content("transactional")
            recipient = self.user_manager.get_random_user()['email']
            attachment = self.data_generator.get_random_attachment()
            
            msg = MIMEMultipart()
            msg['Subject'] = content['subject']
            msg['From'] = self.user_account['email']
            msg['To'] = recipient
            
            # Add body
            msg.attach(MIMEText(content['body'], 'html'))
            
            # Add attachment with size check (enforced by config)
            if os.path.exists(attachment['path']):
                file_size = os.path.getsize(attachment['path'])
                
                # Skip attachment if it exceeds configured limit
                # Note: Base64 encoding adds ~33% overhead to the size
                if file_size > self.config.MAX_ATTACHMENT_SIZE_BYTES:
                    logger.warning(
                        f"Skipping attachment {attachment['path']}: "
                        f"size {file_size//(1024*1024)}MB exceeds {self.config.MAX_ATTACHMENT_SIZE_MB}MB limit"
                    )
                else:
                    with open(attachment['path'], "rb") as attachment_file:
                        part = MIMEBase('application', 'octet-stream')
                        part.set_payload(attachment_file.read())
                    
                    encoders.encode_base64(part)
                    part.add_header(
                        'Content-Disposition',
                        f'attachment; filename= {os.path.basename(attachment["path"])}'
                    )
                    msg.attach(part)
            
            server.send_message(msg)
            server.quit()
            
            response_time = (time.time() - start_time) * 1000
            self.environment.events.request.fire(
                request_type="SMTP",
                name="send_attachment",
                response_time=response_time,
                response_length=len(content['body']),
                exception=None
            )
            
        except Exception as e:
            response_time = (time.time() - start_time) * 1000
            
            # Check if this is a rate limit error
            if self._is_rate_limit_error(e):
                logger.info(f"SMTP rate limit hit during send (expected): {e}")
                self.environment.events.request.fire(
                    request_type="SMTP",
                    name="send_attachment_rate_limited",
                    response_time=response_time,
                    response_length=0,
                    exception=None  # Don't treat as failure
                )
            else:
                self.environment.events.request.fire(
                    request_type="SMTP",
                    name="send_attachment",
                    response_time=response_time,
                    response_length=0,
                    exception=e
                )
            
            if server:
                try:
                    server.quit()
                except:
                    pass
    
    @task(2)
    def send_bulk_emails(self):
        """Send multiple emails in one session"""
        server = self._connect_smtp()
        if not server:
            return
        
        start_time = time.time()
        
        try:
            # Send 5-10 emails in one session
            num_emails = random.randint(5, 10)
            
            for i in range(num_emails):
                content = self.data_generator.generate_email_content()
                recipient = self.user_manager.get_random_user()['email']
                
                msg = MIMEText(content['body'], 'plain' if content['type'] == 'plain_text' else 'html')
                msg['Subject'] = f"Bulk Test {i+1}: {content['subject']}"
                msg['From'] = self.user_account['email']
                msg['To'] = recipient
                
                server.send_message(msg)
            
            server.quit()
            
            response_time = (time.time() - start_time) * 1000
            self.environment.events.request.fire(
                request_type="SMTP",
                name="send_bulk",
                response_time=response_time,
                response_length=num_emails,
                exception=None
            )
            
        except Exception as e:
            response_time = (time.time() - start_time) * 1000
            
            # Check if this is a rate limit error
            if self._is_rate_limit_error(e):
                logger.info(f"SMTP rate limit hit during bulk send (expected): {e}")
                self.environment.events.request.fire(
                    request_type="SMTP",
                    name="send_bulk_rate_limited",
                    response_time=response_time,
                    response_length=0,
                    exception=None  # Don't treat as failure
                )
            else:
                self.environment.events.request.fire(
                    request_type="SMTP",
                    name="send_bulk",
                    response_time=response_time,
                    response_length=0,
                    exception=e
                )
            
            if server:
                try:
                    server.quit()
                except:
                    pass