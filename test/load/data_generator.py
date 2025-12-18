# data_generator.py - Test data generation utilities
import os
import random
from faker import Faker


class TestDataGenerator:
    """Generate realistic test data for emails"""
    
    def __init__(self):
        self.fake = Faker()
        self.email_templates = self._load_templates()
        self.attachments = self._get_attachments()
    
    def _load_templates(self):
        """Load email templates"""
        return {
            'marketing': """
            <html><body>
            <h2>Special Offer Just for You!</h2>
            <p>Dear {name},</p>
            <p>We have an exclusive offer that expires soon...</p>
            <img src="cid:image1" alt="Promotion">
            </body></html>
            """,
            'transactional': """
            <html><body>
            <h2>Order Confirmation</h2>
            <p>Dear {name},</p>
            <p>Your order #{order_id} has been confirmed.</p>
            <p>Total: ${amount}</p>
            </body></html>
            """,
            'newsletter': """
            <html><body>
            <h1>Weekly Newsletter</h1>
            <p>Hello {name},</p>
            <p>Here are this week's highlights...</p>
            <ul>
                <li>Feature update</li>
                <li>New blog post</li>
                <li>Community spotlight</li>
            </ul>
            </body></html>
            """,
            'plain_text': """
            Hi {name},
            
            This is a simple text message for testing purposes.
            
            Regards,
            Test System
            """
        }
    
    def _get_attachments(self):
        """Get list of test attachment files"""
        attachment_dir = "test_data/attachments/"
        os.makedirs(attachment_dir, exist_ok=True)

        # Define files and sizes
        files = {
            "sample.pdf": 1024 * 1024,      # 1MB
            "image.jpg": 512 * 1024,        # 500KB
            "document.docx": 2 * 1024 * 1024, # 2MB
            "spreadsheet.xlsx": 3 * 1024 * 1024, # 3MB
            "large_file.zip": 10 * 1024 * 1024  # 10MB
        }

        # Create files if missing
        for filename, size in files.items():
            filepath = os.path.join(attachment_dir, filename)
            if not os.path.exists(filepath):
                with open(filepath, 'wb') as f:
                    f.write(b'0' * size)

        # Return attachment info
        return [{"path": os.path.join(attachment_dir, fname), "size": f"{size//1024}KB"} for fname, size in files.items()]
    
    def generate_email_content(self, email_type="random"):
        """Generate email content based on type"""
        if email_type == "random":
            email_type = random.choice(list(self.email_templates.keys()))
        
        template = self.email_templates[email_type]
        
        return {
            'subject': self.fake.sentence(nb_words=6),
            'body': template.format(
                name=self.fake.name(),
                order_id=random.randint(10000, 99999),
                amount=random.uniform(10.99, 299.99)
            ),
            'type': email_type
        }
    
    def get_random_attachment(self):
        """Get a random attachment for testing"""
        return random.choice(self.attachments)
