### Load Testing Silver Mail Service

This directory contains files and scripts for load testing the Silver Mail Service. It includes test data, configuration files, and scripts to simulate user interactions with the service.

#### Contents
1. ./test_data - Directory containing sample data files used for testing and user simulation and attachment files.
2. ./locustfile.py - Locust configuration file defining user behavior and load test scenarios.
3. ./test_results - Directory where load test results and logs will be stored.
4. ./README.md - This file, providing an overview and instructions for running the load tests.
5. .env - Environment configuration file for setting up necessary environment variables.


#### Usage
1. Ensure you have [Locust](https://locust.io/) installed. You can install it via pip:
    ```bash
    pip install locust
    ```
2. Navigate to the `test` directory:
    ```bash
    cd test
    ```
3. Run the Locust load test:
    ```bash
    python3 -m locust -f locustfile.py --host=http://localhost
    ```
4. Open your web browser and go to `http://localhost:8089` to access the Locust web interface.
5. Configure the number of users and spawn rate, then start the test.

