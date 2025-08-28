# Thunder Mail Server

This directory contains a script to create an application and user in Thunder. Set the .env variables inside the scripts folder before running the script.

## Quick Start

### Make the scripts executable and run them from the thunder directory.
To run the complete test sequence, ensure the scripts are executable and run them from the thunder directory.

```bash
cd services/thunder
chmod +x ./scripts/*.sh
./scripts/init.sh
```

### Adding environment variables
Create a `.env` file in the `scripts` directory with the following content:

```bash
# Thunder Server Configuration
THUNDER_HOST="localhost"
THUNDER_PORT="8090"

# Application Configuration
APP_NAME="MyThunderApp"
APP_DESCRIPTION="Thunder application for API testing and development"
APP_CLIENT_ID="************"
APP_CLIENT_SECRET="************"

# User Configuration
USER_USERNAME="#######"
USER_PASSWORD="#######"
USER_EMAIL="#######"
USER_FIRST_NAME="#######"
USER_LAST_NAME="#######"
USER_AGE="#######"
USER_PHONE="#######"

# User Address (JSON format)
USER_ADDRESS='{"street":"###","city":"###","state":"###","zipCode":"###","country":"###"}'
```

### Run the script to create an application and user in Thunder
```bash
./scripts/create_app_and_user.sh
```