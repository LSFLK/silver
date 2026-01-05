# 📊 Load Testing Suite

This directory contains the load testing suite for the Silver Mail Server using [Locust](https://locust.io/). The tests simulate real-world email traffic patterns including SMTP sending and IMAP operations.

## 📁 Files Overview

- **`locustfile.py`** - Main Locust configuration file that orchestrates all load tests
- **`smtp_tester.py`** - SMTP load testing scenarios (sending emails)
- **`imap_tester.py`** - IMAP load testing scenarios (reading, managing emails)
- **`config.py`** - Email server configuration and settings
- **`user_manager.py`** - User management utilities for test users
- **`data_generator.py`** - Generates realistic test data (emails, attachments)
- **`requirements.txt`** - Python dependencies
- **`test_data/`** - Directory containing test users and attachments

## 🚀 Quick Start

### Prerequisites

1. Python 3.8 or higher
2. Silver Mail Server running and accessible

### Step 1: Create Test Users

> [!NOTE]
> The code snippet in this section(Step 1) should be run in the server environment where your Silver Mail Server and Thunder IDP are running.

Before running any load tests, you must create test users first:

```bash
cd ../../scripts/user
./create_test_users.sh
```

This script will:
- Create test users in Thunder IDP
- Create users in the shared database
- Generate a credentials file at `scripts/user/test_users/test_users_credentials.csv`

> [!IMPORTANT]
> After creating test users, copy the credentials file to the load test directory in local development environment.

Without this file, the load tests will not have any users to authenticate with and will fail.

### Step 2: Installation

1. Create and activate a virtual environment (recommended):

```bash
python3 -m venv .venv
source .venv/bin/activate  # On macOS/Linux
# or
.venv\Scripts\activate  # On Windows
```

2. Install dependencies:

```bash
pip install -r requirements.txt
```

### Configuration

Set the mail domain as an environment variable or create a `.env` file:

```bash
export MAIL_DOMAIN=your-domain.com
```

Or create a `.env` file in the `test/load` directory:

```
MAIL_DOMAIN=your-domain.com
```

## 📋 Running Load Tests

### Interactive Mode (Web UI)

Run Locust with the web interface to manually control the load test:

```bash
locust -f locustfile.py --host https://your-domain.com
```

Then open your browser to `http://localhost:8089` and configure:
- Number of users
- Spawn rate (users per second)
- Host URL

### Headless Mode (Automated)

Run Locust in headless mode with predefined parameters (same as GitHub workflow):

```bash
locust \
  -f locustfile.py \
  --headless \
  -u 10 \
  -r 2 \
  --run-time 60s \
  --host https://your-domain.com \
  --html report.html \
  --csv results \
  --logfile locust.log \
  --loglevel INFO
```

#### Parameters Explained:

- `-f locustfile.py` - Locust file to use
- `--headless` - Run without web UI
- `-u 10` - Number of concurrent users to simulate
- `-r 2` - Spawn rate (users spawned per second)
- `--run-time 60s` - Test duration (60 seconds)
- `--host https://your-domain.com` - Target mail server
- `--html report.html` - Generate HTML report
- `--csv results` - Generate CSV results (creates results_stats.csv, results_failures.csv, results_stats_history.csv)
- `--logfile locust.log` - Log file location
- `--loglevel INFO` - Logging level

### Custom Test Scenarios

#### Light Load Test (5 users, 30 seconds)

```bash
locust \
  -f locustfile.py \
  --headless \
  -u 5 \
  -r 1 \
  --run-time 30s \
  --host https://your-domain.com \
  --html report-light.html
```

#### Heavy Load Test (50 users, 5 minutes)

```bash
locust \
  -f locustfile.py \
  --headless \
  -u 50 \
  -r 5 \
  --run-time 5m \
  --host https://your-domain.com \
  --html report-heavy.html \
  --csv results-heavy
```

#### SMTP Only Test

```bash
locust \
  -f locustfile.py \
  --headless \
  -u 10 \
  -r 2 \
  --run-time 60s \
  --host https://your-domain.com \
  --tags smtp
```

#### IMAP Only Test

```bash
locust \
  -f locustfile.py \
  --headless \
  -u 10 \
  -r 2 \
  --run-time 60s \
  --host https://your-domain.com \
  --tags imap
```

## 📊 Understanding Results

### HTML Report

The HTML report (`report.html`) includes:
- Request statistics (RPS, response times, failures)
- Charts showing performance over time
- Percentile response times (50th, 66th, 75th, 80th, 90th, 95th, 98th, 99th, 100th)
- Total request count and failure rate

### CSV Results

Three CSV files are generated:
- `results_stats.csv` - Aggregated statistics per request type
- `results_failures.csv` - Details of all failures
- `results_stats_history.csv` - Time-series data of statistics

### Log File

The `locust.log` file contains detailed logs of the test execution, useful for debugging failures.

## 📚 Resources

- [Locust Documentation](https://docs.locust.io/)
- [Writing Locust Tests](https://docs.locust.io/en/stable/writing-a-locustfile.html)
- [Locust Configuration](https://docs.locust.io/en/stable/configuration.html)

## 🆘 Support

For issues or questions:
1. Check the log files (`locust.log`)
2. Review the test/load test results
3. Consult the Silver Mail documentation
4. Open an issue in the repository
