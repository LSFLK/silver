# config.py - Email server configuration
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()
MAIL_DOMAIN = os.getenv("MAIL_DOMAIN", "localhost")


class EmailServerConfig:
    """Email server configuration with multiple fallback options"""
    SMTP_SERVER = MAIL_DOMAIN
    SMTP_PORT = 587
    IMAP_SERVER = MAIL_DOMAIN

    # Try these configurations in order
    IMAP_CONFIGS = [
        {"port": 993, "ssl": True, "name": "IMAP4_SSL"},      # Standard SSL
        {"port": 143, "ssl": False, "starttls": True, "name": "STARTTLS"},  # STARTTLS
        {"port": 143, "ssl": False, "starttls": False, "name": "Plain"},    # Plain (fallback)
    ]
    
    TIMEOUT = 30
    USE_TLS = True
