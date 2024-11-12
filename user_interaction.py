# user_interaction.py

import logging
import threading
from contextlib import contextmanager
from tabulate import tabulate

# Timeout Exception for User Input
class TimeoutExpired(Exception):
    """Custom exception raised when user input times out."""
    pass

# Timeout handler for user input
def timeout_handler():
    raise TimeoutExpired

# Prompt user with timeout option
@contextmanager
def prompt_user_with_timeout(prompt, timeout=30):
    """
    Prompts the user with a timeout. If no input is given within the timeout, a default action is taken.

    :param prompt: The message to prompt the user with.
    :param timeout: Number of seconds to wait before timing out (default: 30).
    :yield: User input or None if timeout expired.
    """
    timer = threading.Timer(timeout, timeout_handler)
    timer.start()
    try:
        response = input(prompt)
        timer.cancel()  # Cancel the timer if the user provides input
        yield response
    except TimeoutExpired:
        logging.warning(f"No input detected within {timeout} seconds. Proceeding with default action.")
        yield None
    finally:
        if timer.is_alive():
            timer.cancel()

# Prompt user for default or custom configuration
def ask_default_db():
    """
    Asks the user whether to use default database connections from environment variables.

    :return: True if user chooses default, False otherwise.
    """
    while True:
        with prompt_user_with_timeout("Use default DB connections from .env? (yes/no, default 'yes'): ") as response:
            response = response.strip().lower() if response else 'yes'  # Default to 'yes' if no input

            if response in ['yes', 'y', '']:
                return True
            elif response in ['no', 'n']:
                return False
            else:
                print("Invalid input. Please enter 'yes' or 'no'.")

# Ask user if email notifications should be enabled
def ask_email_notification():
    """
    Asks the user whether to enable email notifications and prompts for a recipient email.

    :return: (bool, str) indicating if notifications are enabled and the recipient email.
    """
    while True:
        with prompt_user_with_timeout("Enable email notifications? (yes/no, default 'no'): ", timeout=20) as response:
            response = response.strip().lower() if response else 'no'

            if response in ['yes', 'y']:
                email = input("Enter your email address for notifications: ").strip()
                return True, email
            elif response in ['no', 'n', '']:
                return False, None
            else:
                print("Invalid input. Please enter 'yes' or 'no'.")

# Display a formatted table and prompt user for table selection
def list_and_select_tables(mysql_conn):
    """
    Lists tables in MySQL database and prompts the user to select tables for migration.

    :param mysql_conn: MySQL connection object.
    :return: List of selected table names.
    """
    with mysql_conn.cursor() as cursor:
        cursor.execute("SHOW TABLES")
        tables = [table[0] for table in cursor.fetchall()]

    if not tables:
        logging.info("No tables found in MySQL database.")
        return []

    # Display table list
    table_data = [[i + 1, table] for i, table in enumerate(tables)]
    print("\nAvailable Tables in MySQL Database:")
    print(tabulate(table_data, headers=["#", "Table Name"], tablefmt="pretty"))

    # Prompt for table selection
    while True:
        selected_indexes = input("Enter table numbers to migrate (comma-separated), 'all' for all, 'cancel' to exit: ").strip().lower()
        
        if selected_indexes == 'all':
            return tables
        elif selected_indexes == 'cancel':
            logging.info("Table selection canceled by user.")
            return []

        try:
            indexes = [int(i.strip()) - 1 for i in selected_indexes.split(",")]
            selected_tables = [tables[i] for i in indexes if 0 <= i < len(tables)]
            if selected_tables:
                return selected_tables
        except ValueError:
            print("Invalid input. Please enter valid table numbers or 'all'.")

# List columns for user selection
def list_columns_for_table(mysql_conn, table_name):
    """
    Lists columns in the specified MySQL table and prompts user for column selection.

    :param mysql_conn: MySQL connection object.
    :param table_name: Name of the MySQL table.
    :return: List of selected columns.
    """
    with mysql_conn.cursor() as cursor:
        cursor.execute(f"SHOW COLUMNS FROM {table_name}")
        columns = [col[0] for col in cursor.fetchall()]

    if not columns:
        logging.info(f"No columns found in table '{table_name}'.")
        return []

    # Display columns for selection
    column_data = [[i + 1, column] for i, column in enumerate(columns)]
    print(f"\nColumns in table '{table_name}':")
    print(tabulate(column_data, headers=["#", "Column Name"], tablefmt="pretty"))

    while True:
        selection = input("Enter column numbers to select (comma-separated), 'all' for all, 'cancel' to exit: ").strip().lower()

        if selection == 'all':
            return columns
        elif selection == 'cancel':
            logging.info(f"Column selection canceled for table '{table_name}'.")
            return []

        try:
            indexes = [int(i.strip()) - 1 for i in selection.split(",")]
            selected_columns = [columns[i] for i in indexes if 0 <= i < len(columns)]
            if selected_columns:
                return selected_columns
        except ValueError:
            print("Invalid input. Please enter valid column numbers or 'all'.")

# Prompt user to resolve errors with dynamic suggestions
def prompt_user_for_fix(error_message, suggestions):
    """
    Prompts the user with error message and suggestions for resolution.

    :param error_message: Description of the encountered error.
    :param suggestions: List of suggestion options for user to choose from.
    :return: Selected suggestion index.
    """
    print(f"\nError encountered: {error_message}")
    print("Choose an option to resolve the issue:")
    for idx, suggestion in enumerate(suggestions, 1):
        print(f"{idx}. {suggestion}")

    # Prompt user to select an option
    while True:
        choice = input("Enter the number of your choice or 'cancel' to skip: ").strip().lower()
        if choice.isdigit() and 1 <= int(choice) <= len(suggestions):
            return int(choice) - 1
        elif choice == 'cancel':
            logging.info("Error resolution canceled by user.")
            return None
        else:
            print("Invalid input. Please enter a valid option number or 'cancel'.")
