# SeaweedFS Configuration Files

This directory contains configuration files for SeaweedFS S3 gateway.

## Quick Start

### Option 1: Automatic Setup (Recommended)

Run the credential generator script:

```bash
../../scripts/utils/generate-seaweedfs-credentials.sh
```

This will:
- Generate secure random credentials
- Create both `.env` and `s3-config.json` files
- Display credentials for you to store securely

### Option 2: Manual Setup

```bash
# Copy example files
cp .env.example .env
cp s3-config.json.example s3-config.json

# Edit .env with your credentials
nano .env

# Edit s3-config.json with the SAME credentials
nano s3-config.json
```

## Configuration Details

### .env File

Used by `gen-raven-conf.sh` to configure Raven's S3 integration:

```bash
# S3 Access Credentials
S3_ACCESS_KEY=your-access-key
S3_SECRET_KEY=your-secret-key

# S3 Endpoint Configuration
S3_ENDPOINT=http://seaweedfs-s3:8333
S3_REGION=us-east-1
S3_BUCKET=email-attachments
S3_TIMEOUT=30
```

### s3-config.json File

Used by SeaweedFS S3 gateway for authentication:

```json
{
  "identities": [
    {
      "name": "raven",
      "credentials": [
        {
          "accessKey": "your-access-key",
          "secretKey": "your-secret-key"
        }
      ],
      "actions": ["Admin", "Read", "Write"]
    }
  ]
}
```

## Important: Keep Credentials Synchronized

⚠️ **The credentials in `.env` and `s3-config.json` MUST match!**

- `.env` is used by Raven (mail server) to connect to S3
- `s3-config.json` is used by SeaweedFS S3 gateway for authentication
- If they don't match, Raven won't be able to store/retrieve attachments