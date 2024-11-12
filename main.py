# Main script entry and menu handling
# main.py

import logging
from config import load_env_variables, setup_logging, get_database_config, get_email_config
from database_connections import connect_mysql, connect_postgresql
from user_interaction import ask_default_db, ask_email_notification, list_and_select_tables, list_columns_for_table
from multi_threading import multi_threaded_migration
from error_handling import retry_migration_operation
from notifications import send_email_notification

# Main entry function for the migration process
def main():
    # Step 1: Load environment variables and set up logging
    load_env_variables()
    setup_logging()
    logging.info("Starting migration process.")

    # Step 2: Retrieve database and email configurations
    try:
        # Load MySQL and PostgreSQL configurations
        mysql_config = get_database_config('MySQL')
        postgres_config = get_database_config('PostgreSQL')
        logging.info("Database configurations loaded successfully.")

        # Load email configuration
        email_config = get_email_config()
        logging.info("Email configuration loaded successfully.")
    except ValueError as e:
        logging.error(f"Configuration error: {e}")
        return  # Exit if configuration fails

    # Step 3: Ask user if they want to use default database configuration
    use_default_db = ask_default_db()
    if use_default_db is None:
        logging.info("Migration process was canceled by the user.")
        return  # Exit if user cancels

    # Step 4: Ask user for email notification preference
    email_notify, recipient_email = ask_email_notification()

    # Step 5: Connect to MySQL to list available tables
    try:
        with connect_mysql(mysql_config) as mysql_conn:
            selected_tables = list_and_select_tables(mysql_conn)

            if not selected_tables:
                logging.info("No tables selected for migration.")
                return  # Exit if no tables are selected

            # Step 6: Allow user to select columns and unique constraints
            table_options = {}
            for table in selected_tables:
                columns = list_columns_for_table(mysql_conn, table)
                unique_cols = input(f"Enter unique columns for '{table}' (comma-separated) or press Enter to skip: ").strip().split(',')
                table_options[table] = {
                    'unique_cols': [col.strip() for col in unique_cols if col.strip()],
                    'columns': columns
                }

    except Exception as e:
        logging.error(f"Error during table selection: {e}")
        return

    # Step 7: Connect to PostgreSQL and select schema
    schema_name = 'public'  # Default schema for PostgreSQL
    try:
        with connect_postgresql(postgres_config) as pg_conn:
            logging.info(f"Using schema '{schema_name}' for PostgreSQL migrations.")

    except Exception as e:
        logging.error(f"Error connecting to PostgreSQL: {e}")
        return

    # Step 8: Begin multi-threaded migration
    try:
        logging.info("Starting multi-threaded migration.")
        multi_threaded_migration(
            tables=selected_tables,
            mysql_config=mysql_config,
            postgres_config=postgres_config,
            table_options=table_options,
            email_notify=email_notify,
            recipient_email=recipient_email,
            schema_name=schema_name
        )
    except Exception as e:
        logging.error(f"Migration process encountered an error: {e}")
        if email_notify and recipient_email:
            send_email_notification(
                subject="Migration Process Error",
                body=f"The migration process encountered an error: {e}",
                recipient_email=recipient_email,
                email_notify=True
            )

    # Step 9: Final migration summary and notification
    logging.info("Migration process completed.")
    if email_notify and recipient_email:
        send_email_notification(
            subject="Migration Process Completed",
            body="The migration process has completed. Please review the logs for details.",
            recipient_email=recipient_email,
            email_notify=True
        )


# Execute the main function if this script is run directly
if __name__ == "__main__":
    main()
