# config.py

import os
import logging
from logging.handlers import RotatingFileHandler
from dotenv import load_dotenv

# Load environment variables from a .env file, if available
def load_env_variables(env_file=".env"):
    """
    Loads environment variables from a .env file into the application environment.

    :param env_file: Path to the .env file (default is ".env").
    """
    if os.path.exists(env_file):
        load_dotenv(dotenv_path=env_file)
        logging.info(f"Loaded environment variables from '{env_file}'")
    else:
        logging.warning(f"'{env_file}' file not found. Using system environment variables.")

# Retrieve database configurations for MySQL and PostgreSQL
def get_database_config(db_type):
    """
    Retrieves database configurations from environment variables.

    :param db_type: 'MySQL' or 'PostgreSQL'
    :return: Dictionary with the database configuration.
    :raises ValueError: If required environment variables are missing.
    """
    if db_type.lower() == 'mysql':
        config = {
            'host': os.getenv('MSDB_HOST'),
            'user': os.getenv('MSDB_USERNAME'),
            'password': os.getenv('MSDB_PASSWORD'),
            'database': os.getenv('MSDB_NAME'),
            'port': int(os.getenv('MSDB_PORT', 3306)),
        }
    elif db_type.lower() == 'postgresql':
        config = {
            'host': os.getenv('PGDB_HOST'),
            'user': os.getenv('PGDB_USERNAME'),
            'password': os.getenv('PGDB_PASSWORD'),
            'database': os.getenv('PGDB_NAME'),
            'port': int(os.getenv('PGDB_PORT', 5432)),
        }
    else:
        raise ValueError(f"Unsupported database type: {db_type}")

    # Check for missing fields
    missing = [key for key, value in config.items() if value is None]
    if missing:
        raise ValueError(f"Missing environment variables for {db_type} database: {', '.join(missing)}")
    
    return config

# Configure logging with file rotation and optional console output
def setup_logging(log_file="migration_log.txt", log_level=logging.INFO, console_output=True):
    """
    Configures logging with rotation to a specified file.

    :param log_file: Path to the log file.
    :param log_level: Logging level (default: logging.INFO).
    :param console_output: If True, logs will also be printed to console.
    """
    logger = logging.getLogger()
    logger.setLevel(log_level)
    
    log_format = logging.Formatter('%(asctime)s:%(levelname)s:%(message)s')

    # Rotating file handler
    file_handler = RotatingFileHandler(log_file, maxBytes=5 * 1024 * 1024, backupCount=5)
    file_handler.setFormatter(log_format)
    logger.addHandler(file_handler)

    # Console handler for real-time logging output (optional)
    if console_output:
        console_handler = logging.StreamHandler()
        console_handler.setFormatter(log_format)
        logger.addHandler(console_handler)

    logging.info("Logging has been configured successfully.")

# Retrieve email configuration for notifications
def get_email_config():
    """
    Retrieves email server configuration from environment variables.

    :return: Dictionary with the email server configuration.
    :raises ValueError: If required environment variables are missing.
    """
    config = {
        'mail_server': os.getenv('MAIL_SERVER'),
        'mail_port': int(os.getenv('MAIL_PORT', 587)),
        'mail_username': os.getenv('MAIL_USERNAME'),
        'mail_password': os.getenv('MAIL_PASSWORD'),
        'mail_default_sender': os.getenv('MAIL_DEFAULT_SENDER', 'no-reply@yourdomain.com')
    }
    
    missing = [key for key, value in config.items() if value is None and key != 'mail_default_sender']
    if missing:
        raise ValueError(f"Missing environment variables for email configuration: {', '.join(missing)}")
    
    return config

# Example usage for testing configuration setup
if __name__ == "__main__":
    # Load environment variables
    load_env_variables()
    
    # Set up logging
    setup_logging()

    # Test database and email configurations
    try:
        mysql_config = get_database_config('MySQL')
        postgres_config = get_database_config('PostgreSQL')
        email_config = get_email_config()
        logging.info("Database and email configurations loaded successfully.")
    except ValueError as e:
        logging.error(f"Configuration error: {e}")
