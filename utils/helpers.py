# Helper functions for formatting, data parsing, etc.
# helpers.py

import logging
import random
import time
from datetime import datetime
from .constants import MYSQL_TO_POSTGRES_TYPES, RETRY_BACKOFF_BASE, RETRY_MAX_DELAY, RETRY_JITTER_ENABLED

# Data Type Conversion
def map_mysql_to_postgres_type(mysql_type):
    """
    Maps a MySQL data type to the equivalent PostgreSQL data type.

    :param mysql_type: MySQL column data type.
    :return: Corresponding PostgreSQL data type.
    """
    base_type = mysql_type.split('(')[0].lower()
    pg_type = MYSQL_TO_POSTGRES_TYPES.get(base_type, 'TEXT')  # Default to TEXT if no match
    logging.debug(f"Mapping MySQL type '{mysql_type}' to PostgreSQL type '{pg_type}'")
    return pg_type


# Exponential Backoff with Optional Jitter
def exponential_backoff(attempt, base=RETRY_BACKOFF_BASE, max_delay=RETRY_MAX_DELAY, jitter=RETRY_JITTER_ENABLED):
    """
    Calculates exponential backoff delay time.

    :param attempt: Current retry attempt number.
    :param base: Base multiplier for exponential backoff.
    :param max_delay: Maximum allowed delay time.
    :param jitter: If True, adds random jitter to the delay.
    :return: Calculated delay time in seconds.
    """
    delay = min(max_delay, base ** attempt)
    if jitter:
        delay *= random.uniform(0.8, 1.2)  # Adds a slight random variation
    logging.info(f"Backoff delay: {delay:.2f} seconds on attempt {attempt + 1}")
    time.sleep(delay)
    return delay


# Timestamp Formatter
def format_timestamp(dt=None):
    """
    Formats a datetime object as a string for logs or records.

    :param dt: Datetime object (defaults to current time).
    :return: Formatted string in ISO format.
    """
    dt = dt or datetime.now()
    formatted_timestamp = dt.strftime('%Y-%m-%d %H:%M:%S')
    logging.debug(f"Formatted timestamp: {formatted_timestamp}")
    return formatted_timestamp


# Validate Email Format
def validate_email(email):
    """
    Checks if the provided string is a valid email format.

    :param email: Email address to validate.
    :return: True if email format is valid, False otherwise.
    """
    import re
    email_regex = r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$'
    is_valid = re.match(email_regex, email) is not None
    logging.debug(f"Validating email '{email}': {'Valid' if is_valid else 'Invalid'}")
    return is_valid


# Format Error Messages for User Display
def format_error_message(error, details=None):
    """
    Formats an error message with optional details for user display.

    :param error: Main error message.
    :param details: Additional details to include in the message.
    :return: Formatted string combining error and details.
    """
    message = f"Error: {error}"
    if details:
        message += f"\nDetails: {details}"
    logging.debug(f"Formatted error message: {message}")
    return message


# Retry Operation Wrapper with Backoff
def retry_operation(operation, max_attempts=3, *args, **kwargs):
    """
    Attempts an operation with retry and backoff.

    :param operation: Callable function to execute.
    :param max_attempts: Maximum retry attempts.
    :param args: Positional arguments for the operation.
    :param kwargs: Keyword arguments for the operation.
    :return: Result of the operation if successful.
    :raises: Last exception if all attempts fail.
    """
    for attempt in range(max_attempts):
        try:
            logging.info(f"Attempt {attempt + 1} for operation '{operation.__name__}'")
            return operation(*args, **kwargs)
        except Exception as e:
            logging.warning(f"Attempt {attempt + 1} failed with error: {e}")
            if attempt < max_attempts - 1:
                exponential_backoff(attempt)
            else:
                logging.error(f"Operation '{operation.__name__}' failed after {max_attempts} attempts.")
                raise
