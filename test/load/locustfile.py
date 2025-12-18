# locustfile.py - Main Locust Load Testing File
"""
Modular Locust load testing suite for email server testing.

This is the main entry point that imports and registers all test classes.
The actual implementations are in separate modules for better organization:
- config.py: Server configuration
- data_generator.py: Email content and attachment generation
- user_manager.py: Test user account management
- smtp_tester.py: SMTP protocol testing
- imap_tester.py: IMAP protocol testing
"""

import os
import sys
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Import all test classes - these will be automatically discovered by Locust
from smtp_tester import SMTPLoadTester
from imap_tester import IMAPLoadTester

# Expose classes for Locust to discover
__all__ = ['SMTPLoadTester', 'IMAPLoadTester']


if __name__ == "__main__":
    # This allows running the test directly with python
    logger.info("Starting Locust load tests...")
    logger.info("Available test classes: SMTPLoadTester, IMAPLoadTester")
    os.system(f"locust -f {sys.argv[0]} --host=http://localhost")
