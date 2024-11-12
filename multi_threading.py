import logging
from concurrent.futures import ThreadPoolExecutor, as_completed
from tqdm import tqdm

from database_connections import connect_mysql, connect_postgresql, ensure_table_exists
from migration_operations import merge_and_update_data
from error_handling import retry_migration_operation
from notifications import send_email_notification

# Multi-threaded Migration for Multiple Tables
def multi_threaded_migration(tables, mysql_config, postgres_config, table_options, email_notify, recipient_email, schema_name='public', max_workers=10, retries=3):
    """
    Executes multi-threaded migration of multiple tables with a progress bar.

    :param tables: List of table names to migrate.
    :param mysql_config: MySQL connection configuration.
    :param postgres_config: PostgreSQL connection configuration.
    :param table_options: Dictionary with options for each table.
    :param email_notify: Boolean, whether to send email notifications.
    :param recipient_email: Email address for notifications.
    :param schema_name: Schema name in PostgreSQL for tables.
    :param max_workers: Number of worker threads (default: 10).
    :param retries: Number of retries for failed migrations.
    """
    failed_tables = []  # Track tables that fail migration

    # Function to ensure all tables are created in PostgreSQL before migration
    def create_pg_tables():
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            table_creation_tasks = {executor.submit(ensure_table_exists, pg_conn, table, mysql_conn, table): table for table in tables}
            for future in as_completed(table_creation_tasks):
                table = table_creation_tasks[future]
                try:
                    future.result()
                    logging.info(f"Table '{table}' prepared in PostgreSQL.")
                except Exception as e:
                    logging.error(f"Failed to prepare table '{table}': {e}")
                    failed_tables.append(table)

    # Create PostgreSQL tables in parallel before migration
    with connect_mysql(mysql_config) as mysql_conn, connect_postgresql(postgres_config) as pg_conn:
        create_pg_tables()

    # Task function for each table's migration
    def migrate_single_table(table_name):
        """
        Task function to migrate a single table. Ensures table exists in PostgreSQL before migration and logs only essential messages.
        """
        try:
            with connect_mysql(mysql_config) as mysql_conn, connect_postgresql(postgres_config) as pg_conn:
                merge_and_update_data(
                    mysql_conn, 
                    pg_conn, 
                    table_name, 
                    table_name, 
                    unique_cols=table_options.get(table_name, {}).get('unique_cols')
                )
            logging.info(f"Table '{table_name}' migrated successfully.")
            return True
        except Exception as e:
            logging.error(f"Migration failed for table '{table_name}': {e}")
            failed_tables.append(table_name)
            return False

    # Use ThreadPoolExecutor with progress bar
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {executor.submit(migrate_single_table, table): table for table in tables}

        with tqdm(total=len(tables), desc="Migrating Tables", unit="table") as pbar:
            for future in as_completed(futures):
                table = futures[future]
                try:
                    if future.result():
                        pbar.update(1)
                except Exception as e:
                    logging.error(f"Unhandled exception during migration of table '{table}': {e}")

    # Retry failed migrations after the initial pass
    if failed_tables:
        retry_failed_tables(failed_tables, mysql_config, postgres_config, table_options, schema_name, retries)
        logging.info("Retry process completed for failed tables.")

    # Send summary report via email if required
    send_migration_summary(failed_tables, email_notify, recipient_email)

# Retry failed migrations
def retry_failed_tables(failed_tables, mysql_config, postgres_config, table_options, schema_name, retries):
    """
    Retries migration for tables that failed initially, logging only high-level retry information.
    """
    for table_name in failed_tables[:]:
        try:
            retry_migration_operation(table_name, mysql_config, postgres_config, schema_name, retries)
            failed_tables.remove(table_name)
            logging.info(f"Retry succeeded for table '{table_name}'")
        except Exception as e:
            logging.warning(f"Retry failed for table '{table_name}': {e}")

# Send final migration summary email
def send_migration_summary(failed_tables, email_notify, recipient_email):
    """
    Sends a summary email after migration, including details of any failed tables.
    """
    subject = "Database Migration Summary"
    if failed_tables:
        body = "Migration completed with errors. Failed tables:\n" + "\n".join(failed_tables)
        logging.error("Migration completed with errors. Check email for details.")
    else:
        body = "Migration completed successfully for all tables."
        logging.info("All tables migrated successfully.")

    if email_notify and recipient_email:
        send_email_notification(subject, body, recipient_email)
