# Constants for data types, schemas, etc.
# constants.py

import os

# Database Configuration Constants
MYSQL_DEFAULT_PORT = 3306
POSTGRES_DEFAULT_PORT = 5432
DEFAULT_SCHEMA = 'public'

# Supported Data Types Mapping (MySQL to PostgreSQL)
MYSQL_TO_POSTGRES_TYPES = {
    'int': 'INTEGER',
    'smallint': 'SMALLINT',
    'bigint': 'BIGINT',
    'tinyint': 'SMALLINT',  # MySQL's TINYINT often maps to SMALLINT
    'mediumint': 'INTEGER',
    'float': 'REAL',
    'double': 'DOUBLE PRECISION',
    'decimal': 'NUMERIC',
    'varchar': 'VARCHAR',
    'char': 'CHAR',
    'text': 'TEXT',
    'tinytext': 'TEXT',
    'mediumtext': 'TEXT',
    'longtext': 'TEXT',
    'blob': 'BYTEA',
    'tinyblob': 'BYTEA',
    'mediumblob': 'BYTEA',
    'longblob': 'BYTEA',
    'datetime': 'TIMESTAMP',
    'timestamp': 'TIMESTAMP',
    'date': 'DATE',
    'time': 'TIME',
    'enum': 'TEXT',  # ENUMs in MySQL can be mapped to TEXT in PostgreSQL
    'set': 'TEXT',  # MySQL SET type can also map to TEXT
    'json': 'JSON',
}

# Email Notification Constants
DEFAULT_SENDER_EMAIL = 'no-reply@yourdomain.com'
EMAIL_SUBJECT_MIGRATION_SUCCESS = "Database Migration Completed Successfully"
EMAIL_SUBJECT_MIGRATION_FAILURE = "Database Migration Encountered Errors"
EMAIL_BODY_SUCCESS_TEMPLATE = "The migration process has completed successfully for all tables."
EMAIL_BODY_FAILURE_TEMPLATE = "The following tables encountered errors during migration:\n{failed_tables}"

# Logging Configuration Constants
LOG_FILE_PATH = 'migration_log.txt'
LOG_MAX_BYTES = 5 * 1024 * 1024  # 5 MB per log file
LOG_BACKUP_COUNT = 5  # Number of backup log files to keep

# Retry Configuration
MAX_RETRY_ATTEMPTS = 3
RETRY_BACKOFF_BASE = 2  # Exponential backoff base
RETRY_MAX_DELAY = 60  # Maximum backoff delay in seconds
RETRY_JITTER_ENABLED = True  # Random jitter for backoff

# Notification Email API Fallback (if SMTP fails)
MAILGUN_API_BASE_URL = "https://api.mailgun.net/v3"
MAILGUN_DEFAULT_DOMAIN = os.getenv('MAILGUN_DOMAIN', 'yourdomain.com')

# Progress Bar Format
PROGRESS_BAR_FORMAT = "{l_bar}{bar} [ time left: {remaining} ]"
