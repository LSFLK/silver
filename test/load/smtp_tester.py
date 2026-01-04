# smtp_tester.py - SMTP load testing tasks
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
        """Send email with attachment"""
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
            
            # Add attachment
            if os.path.exists(attachment['path']):
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
