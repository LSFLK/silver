# data_generator.py - Test data generation utilities
import os
import random
from faker import Faker
from config import EmailServerConfig


class TestDataGenerator:
    """Generate realistic test data for emails"""
    
    def __init__(self):
        self.fake = Faker()
        self.config = EmailServerConfig()
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
        """Get list of test attachment files (all under configured size limit)"""
        attachment_dir = "test_data/attachments/"
        os.makedirs(attachment_dir, exist_ok=True)

        # Get max size from config (default 8MB to account for base64 encoding overhead)
        max_size = self.config.MAX_ATTACHMENT_SIZE_BYTES
        
        # Define files and sizes (all under the configured limit)
        # Note: Base64 encoding adds ~33% overhead, so 8MB file becomes ~10.6MB encoded
        # To stay safely under 10MB after encoding, we limit raw files to 8MB max
        files = {
            "sample.pdf": 1024 * 1024,                    # 1MB
            "image.jpg": 512 * 1024,                      # 512KB
            "document.docx": 2 * 1024 * 1024,             # 2MB
            "spreadsheet.xlsx": 3 * 1024 * 1024,          # 3MB
            "presentation.pptx": 5 * 1024 * 1024,         # 5MB
            "large_file.zip": min(max_size, 8 * 1024 * 1024)  # 8MB or max_size, whichever is smaller
        }

        # Validate all files are under limit
        for filename, size in list(files.items()):
            if size > max_size:
                print(f"Warning: {filename} ({size} bytes) exceeds max size ({max_size} bytes), adjusting...")
                files[filename] = max_size

        # Create files if missing
        for filename, size in files.items():
            filepath = os.path.join(attachment_dir, filename)
            if not os.path.exists(filepath):
                with open(filepath, 'wb') as f:
                    # Write random bytes instead of zeros for more realistic files
                    f.write(os.urandom(size))

        # Return attachment info
        return [
            {
                "path": os.path.join(attachment_dir, fname), 
                "size": f"{size//1024}KB" if size < 1024*1024 else f"{size//(1024*1024)}MB",
                "bytes": size
            } 
            for fname, size in files.items()
        ]
    
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