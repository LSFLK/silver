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
        {"port": 993, "ssl": True, "starttls": False, "name": "IMAP SSL (Port 993)"},
        {"port": 143, "ssl": False, "starttls": True, "name": "IMAP with STARTTLS (Port 143)"},
        {"port": 143, "ssl": False, "starttls": False, "name": "IMAP Plain (Port 143)"},
    ]

    TIMEOUT = 30
    USE_TLS = True

    # Attachment size limit (10MB - industry standard for email attachments)
    # Setting to 6MB to ensure encoded size stays under 10MB (base64 adds ~33% overhead)
    MAX_ATTACHMENT_SIZE_MB = 6
    MAX_ATTACHMENT_SIZE_BYTES = MAX_ATTACHMENT_SIZE_MB * 1024 * 1024