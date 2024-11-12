# error_handling.py

import logging
import random
import re
import time
from psycopg2 import sql
from user_interaction import prompt_user_for_fix
from database_connections import add_column_to_postgresql, create_postgresql_table
from migration_operations import merge_and_update_data

# Custom error handling function for dynamic error resolution
def resolve_error_based_on_choice(mysql_conn, pg_conn, table_name, schema_name, error_message, error_type, table_options):
    """
    Resolves migration errors based on user selection or automatically applied fixes.

    :param mysql_conn: MySQL connection object.
    :param pg_conn: PostgreSQL connection object.
    :param table_name: The table where the error occurred.
    :param schema_name: PostgreSQL schema name.
    :param error_message: Error message detailing the issue.
    :param error_type: General type of error encountered.
    :param table_options: Dictionary containing options for handling the table.
    """
    suggestions = [
        "Create the missing table",
        "Add the missing column",
        "Handle duplicate key",
        "Skip the table and continue",
        "Retry the migration"
    ]

    user_choice = prompt_user_for_fix(error_message, suggestions)

    if user_choice is None:
        logging.info("Error resolution was skipped by user.")
        return

    try:
        if user_choice == 0:  # Create missing table
            handle_missing_table(mysql_conn, pg_conn, table_name, table_options, schema_name)
        elif user_choice == 1:  # Add missing column
            handle_missing_column(mysql_conn, pg_conn, table_name, table_options, error_message, schema_name)
        elif user_choice == 2:  # Handle duplicate key
            handle_duplicate_key(mysql_conn, pg_conn, table_name, table_options, schema_name)
        elif user_choice == 3:  # Skip the table
            logging.info(f"Skipping table '{table_name}' migration as per user request.")
        elif user_choice == 4:  # Retry migration
            retry_migration_operation(mysql_conn, pg_conn, table_name, schema_name, retries=3)
    except Exception as e:
        logging.error(f"Failed to apply error resolution for '{table_name}' in '{schema_name}': {e}")
        raise

# Handle missing table errors by creating the table in PostgreSQL
def handle_missing_table(mysql_conn, pg_conn, table_name, table_options, schema_name):
    """
    Attempts to create a missing table in PostgreSQL based on MySQL schema.

    :param mysql_conn: MySQL connection object.
    :param pg_conn: PostgreSQL connection object.
    :param table_name: Name of the missing table.
    :param table_options: Options specific to the table.
    :param schema_name: PostgreSQL schema where the table will be created.
    """
    logging.info(f"Attempting to create missing table '{table_name}' in schema '{schema_name}'.")

    # Fetch MySQL columns to create the table in PostgreSQL
    with mysql_conn.cursor() as cur:
        cur.execute(f"SHOW COLUMNS FROM `{table_name}`")
        columns = [(row[0], row[1], row[2] == "YES", row[4]) for row in cur.fetchall()]
        
    # Create table in PostgreSQL
    create_postgresql_table(pg_conn, table_name, columns, schema_name)

# Handle missing column errors by adding the column to PostgreSQL
def handle_missing_column(mysql_conn, pg_conn, table_name, table_options, error_message, schema_name):
    """
    Adds a missing column to the specified PostgreSQL table.

    :param mysql_conn: MySQL connection object.
    :param pg_conn: PostgreSQL connection object.
    :param table_name: Name of the table with the missing column.
    :param table_options: Dictionary containing table-specific options.
    :param error_message: Error message indicating the missing column.
    :param schema_name: PostgreSQL schema name.
    """
    missing_column = extract_missing_column_from_error(error_message)
    
    if missing_column:
        logging.info(f"Adding missing column '{missing_column}' to table '{table_name}' in schema '{schema_name}'.")
        
        # Retrieve MySQL column information
        with mysql_conn.cursor() as cur:
            cur.execute(f"SHOW COLUMNS FROM `{table_name}` LIKE '{missing_column}'")
            column_info = cur.fetchone()
        
        if column_info:
            col_name, col_type, is_nullable, default_value = column_info[0], column_info[1], column_info[2] == "YES", column_info[4]
            add_column_to_postgresql(pg_conn, table_name, col_name, col_type, is_nullable, default_value, schema_name)
    else:
        logging.warning("Could not identify the missing column from the error message.")

# Extract missing column from error message
def extract_missing_column_from_error(error_message):
    """
    Parses the missing column name from a PostgreSQL error message.

    :param error_message: Error message indicating a missing column.
    :return: The column name, if found, otherwise None.
    """
    match = re.search(r"column [\"'](.*?)[\"'] does not exist", error_message, re.IGNORECASE)
    return match.group(1) if match else None

# Handle duplicate key errors
def handle_duplicate_key(mysql_conn, pg_conn, table_name, table_options, schema_name):
    """
    Handles duplicate key errors by adjusting the upsert query.

    :param mysql_conn: MySQL connection object.
    :param pg_conn: PostgreSQL connection object.
    :param table_name: Name of the table with the duplicate key.
    :param table_options: Dictionary with unique column options.
    :param schema_name: PostgreSQL schema name.
    """
    logging.info(f"Handling duplicate key error for table '{table_name}' in schema '{schema_name}'.")
    
    # Redefine the upsert logic by modifying unique constraint handling in PostgreSQL
    merge_and_update_data(mysql_conn, pg_conn, table_name, table_name, unique_cols=table_options.get('unique_cols'))

# Retry Migration Operation with Backoff
def retry_migration_operation(mysql_conn, pg_conn, table_name, schema_name, retries=3):
    """
    Retries the migration operation with exponential backoff.

    :param mysql_conn: MySQL connection object.
    :param pg_conn: PostgreSQL connection object.
    :param table_name: Name of the table to migrate.
    :param schema_name: Schema name where the table resides in PostgreSQL.
    :param retries: Number of retry attempts.
    """
    for attempt in range(retries):
        try:
            logging.info(f"Retrying migration for table '{table_name}' (Attempt {attempt + 1}).")
            merge_and_update_data(mysql_conn, pg_conn, table_name, table_name, unique_cols=None)
            
            logging.info(f"Migration retry successful for table '{table_name}'.")
            break  # Exit loop if successful

        except Exception as e:
            logging.error(f"Retry {attempt + 1} failed for table '{table_name}': {e}")
            
            if attempt < retries - 1:
                backoff_time = exponential_backoff(attempt)
                logging.info(f"Waiting {backoff_time} seconds before next retry.")
                time.sleep(backoff_time)
            else:
                logging.error(f"Failed to migrate table '{table_name}' after {retries} attempts.")
                raise

# Exponential Backoff Function
def exponential_backoff(attempt, base=2, max_delay=60, jitter=True):
    """
    Calculates delay time for exponential backoff with optional jitter.

    :param attempt: Current retry attempt number.
    :param base: Base multiplier for backoff.
    :param max_delay: Maximum backoff time in seconds.
    :param jitter: Whether to add random jitter to prevent collisions.
    :return: Calculated delay time in seconds.
    """
    delay = min(max_delay, base ** attempt)
    if jitter:
        delay *= random.uniform(0.8, 1.2)
    return delay
