#!/usr/bin/env python3
import sys, email, sqlite3, os

DB_FILE = "/var/mail/maildb.sqlite"

# Read full email
raw_msg = sys.stdin.read()
msg = email.message_from_string(raw_msg)

# Envelope
sender = sys.argv[sys.argv.index("-f")+1] if "-f" in sys.argv else ""
recipient = sys.argv[-1]

# Headers
subject = msg.get("Subject", "")
mail_from = msg.get("From", sender)
mail_to = msg.get("To", recipient)
date = msg.get("Date", "")

# Extract plain text body
body = ""
if msg.is_multipart():
    for part in msg.walk():
        if part.get_content_type() == "text/plain":
            body += part.get_payload(decode=True).decode(errors="ignore")
else:
    try:
        body = msg.get_payload(decode=True).decode(errors="ignore")
    except Exception:
        body = msg.get_payload()

# Save into SQLite
conn = sqlite3.connect(DB_FILE)
cur = conn.cursor()
cur.execute("""
    CREATE TABLE IF NOT EXISTS mails (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mail_from TEXT,
        mail_to TEXT,
        subject TEXT,
        date TEXT,
        body TEXT,
        raw_message TEXT
    )
""")
cur.execute("INSERT INTO mails (mail_from, mail_to, subject, date, body, raw_message) VALUES (?,?,?,?,?,?)",
            (mail_from, mail_to, subject, date, body, raw_msg))
conn.commit()
conn.close()