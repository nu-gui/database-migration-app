# multi_threading.py

import logging
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from tqdm import tqdm

from database_connections import connect_mysql, connect_postgresql
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

    # Define task function for each table
    def migrate_single_table(table_name):
        try:
            with connect_mysql(mysql_config) as mysql_conn, connect_postgresql(postgres_config) as pg_conn:
                merge_and_update_data(mysql_conn, pg_conn, table_name, table_name, unique_cols=table_options.get(table_name, {}).get('unique_cols'))
            logging.info(f"Successfully migrated table '{table_name}'")
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
                    if future.result():  # Only update progress if successful
                        pbar.update(1)
                except Exception as e:
                    logging.error(f"Unhandled exception during migration of table '{table}': {e}")

    # Retry failed migrations sequentially after initial pass
    retry_failed_tables(failed_tables, mysql_config, postgres_config, table_options, email_notify, recipient_email, schema_name, retries)

    # Final report with email notification
    send_migration_summary(failed_tables, email_notify, recipient_email)

# Retry failed migrations
def retry_failed_tables(failed_tables, mysql_config, postgres_config, table_options, email_notify, recipient_email, schema_name, retries):
    """
    Retries migration for tables that failed initially.

    :param failed_tables: List of tables that failed in the first migration attempt.
    :param mysql_config: MySQL connection configuration.
    :param postgres_config: PostgreSQL connection configuration.
    :param table_options: Table-specific options.
    :param email_notify: Boolean, whether to send email notifications.
    :param recipient_email: Email address for notifications.
    :param schema_name: PostgreSQL schema name.
    :param retries: Number of retries for failed migrations.
    """
    for table_name in failed_tables[:]:  # Iterate over a copy of the list
        try:
            retry_migration_operation(table_name, mysql_config, postgres_config, schema_name, retries)
            failed_tables.remove(table_name)  # Remove table from failed list if retry succeeds
            logging.info(f"Retry succeeded for table '{table_name}'")
        except Exception as e:
            logging.error(f"Retry failed for table '{table_name}': {e}")

# Send final migration summary email
def send_migration_summary(failed_tables, email_notify, recipient_email):
    """
    Sends a summary email after migration, including details of any failed tables.

    :param failed_tables: List of tables that failed migration.
    :param email_notify: Boolean, whether to send email notifications.
    :param recipient_email: Recipient email address for the summary.
    """
    subject = "Database Migration Summary"
    if failed_tables:
        body = f"Migration completed with errors. The following tables failed to migrate:\n" + "\n".join(failed_tables)
        logging.error("Some tables failed to migrate. See the summary email for details.")
    else:
        body = "Migration completed successfully for all tables."
        logging.info("All tables migrated successfully.")

    if email_notify and recipient_email:
        send_email_notification(subject, body, recipient_email, email_notify=email_notify)
