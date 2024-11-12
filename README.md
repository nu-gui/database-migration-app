---

# Database Migration Application

This application is designed to migrate data between MySQL and PostgreSQL databases. It includes multi-threaded migration, error handling with retry and backoff logic, and optional email notifications (using SMTP and Mailgun fallback).

## Table of Contents
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Running the Application](#running-the-application)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Features
- Multi-threaded data migration for enhanced performance.
- Support for MySQL to PostgreSQL data type mapping.
- Customizable retry logic with exponential backoff.
- Optional email notifications with SMTP and Mailgun API fallback.
- Detailed logging with file rotation.

## Requirements
- Python 3.8+
- MySQL and PostgreSQL drivers:
  - `mysql-connector-python`
  - `psycopg2`
- Required Python libraries:
  - `requests` (for Mailgun API)
  - `python-dotenv` (for environment variable management)
  - `tqdm` (for progress bar)

## Installation

### Step 1: Clone the Repository
```bash
git clone https://github.com/your-repo/database-migration-app.git
cd database-migration-app
```

### Step 2: Set Up Python Environment
It is recommended to use a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### Step 3: Install Dependencies
Install the required packages with:
```bash
pip install -r requirements.txt
```

### Step 4: Set Up Databases
1. Ensure MySQL and PostgreSQL databases are running and accessible.
2. Create databases and tables as needed for migration.

## Configuration

### Step 5: Environment Variables
Create a `.env` file in the project root directory to store sensitive configurations:
```plaintext
# MySQL Configuration
MSDB_HOST=your_mysql_host
MSDB_USERNAME=your_mysql_username
MSDB_PASSWORD=your_mysql_password
MSDB_NAME=your_mysql_database
MSDB_PORT=3306

# PostgreSQL Configuration
PGDB_HOST=your_postgres_host
PGDB_USERNAME=your_postgres_username
PGDB_PASSWORD=your_postgres_password
PGDB_NAME=your_postgres_database
PGDB_PORT=5432

# Email SMTP Configuration
MAIL_SERVER=your_smtp_server
MAIL_PORT=587
MAIL_USERNAME=your_smtp_username
MAIL_PASSWORD=your_smtp_password
MAIL_DEFAULT_SENDER=your_email@example.com

# Mailgun Fallback Configuration
MAILGUN_API_KEY=your_mailgun_api_key
MAILGUN_DOMAIN=your_mailgun_domain
MAILGUN_DEFAULT_SENDER=no-reply@yourdomain.com
```

### Step 6: Logging Configuration (Optional)
The default logging settings are stored in the `config.py` file. By default, logs are written to `migration_log.txt`.

## Running the Application

1. **Start the Application**
   Run the main script:
   ```bash
   python main.py
   ```

2. **Follow the Prompts**
   - You will be asked to confirm the database configurations (either to use the defaults from `.env` or specify manually).
   - Select the tables you wish to migrate from MySQL to PostgreSQL.
   - Specify any unique columns for upsert logic if required.
   - Choose to enable or disable email notifications.

3. **Monitor Progress**
   - A progress bar will display the migration progress.
   - Logs are saved in `migration_log.txt` for review.

## Troubleshooting

### Common Issues
1. **Database Connection Errors**
   - Verify the database credentials in `.env`.
   - Ensure the databases are accessible from your network.

2. **Email Notification Failures**
   - Ensure your SMTP or Mailgun settings are correctly configured in `.env`.
   - Check the logs for specific error messages if emails are not sent.

3. **Performance Adjustments**
   - You can modify the `max_workers` parameter in `multi_threaded_migration` within `multi_threading.py` to control the number of concurrent threads.

4. **Migration Errors**
   - If a table fails migration, the app will retry with exponential backoff. Failed tables are logged for review.

## License
This project is licensed under the MIT License.

---
