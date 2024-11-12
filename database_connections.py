# database_connections.py

import mysql.connector
import psycopg2
from psycopg2 import sql
import logging
from contextlib import contextmanager
from utils.helpers import exponential_backoff  # For consistent backoff behavior
from config import get_database_config  # Import configuration functions

# MySQL Connection with Retry Logic
@contextmanager
def connect_mysql(config=None, retries=3):
    """
    Establishes a connection to MySQL with retry logic, using a context manager.

    :param config: Dictionary containing MySQL database configuration. If None, loads from environment.
    :param retries: Number of retry attempts if the connection fails.
    :yield: MySQL connection object.
    """
    if not config:
        config = get_database_config('MySQL')  # Load MySQL config from environment

    attempt = 0
    connection = None
    while attempt < retries:
        try:
            logging.info(f"Connecting to MySQL (Attempt {attempt + 1})...")
            connection = mysql.connector.connect(**config)
            if connection.is_connected():
                logging.info("MySQL connection established.")
                yield connection
                return
        except mysql.connector.Error as e:
            logging.error(f"MySQL connection attempt {attempt + 1} failed: {e}")
            attempt += 1
            if attempt < retries:
                exponential_backoff(attempt)
        finally:
            if connection and connection.is_connected():
                connection.close()
                logging.info("MySQL connection closed.")

# PostgreSQL Connection with Retry Logic
@contextmanager
def connect_postgresql(config=None, retries=3):
    """
    Establishes a connection to PostgreSQL with retry logic, using a context manager.

    :param config: Dictionary containing PostgreSQL database configuration. If None, loads from environment.
    :param retries: Number of retry attempts if the connection fails.
    :yield: PostgreSQL connection object.
    """
    if not config:
        config = get_database_config('PostgreSQL')  # Load PostgreSQL config from environment

    attempt = 0
    connection = None
    while attempt < retries:
        try:
            logging.info(f"Connecting to PostgreSQL (Attempt {attempt + 1})...")
            connection = psycopg2.connect(**config)
            logging.info("PostgreSQL connection established.")
            yield connection
            return
        except psycopg2.Error as e:
            logging.error(f"PostgreSQL connection attempt {attempt + 1} failed: {e}")
            attempt += 1
            if attempt < retries:
                exponential_backoff(attempt)
        finally:
            if connection:
                connection.close()
                logging.info("PostgreSQL connection closed.")

# Check if a table exists in PostgreSQL
def check_table_exists(pg_conn, table_name, schema_name='public'):
    """
    Checks if a table exists in the specified PostgreSQL schema.

    :param pg_conn: Active PostgreSQL connection object.
    :param table_name: Name of the table to check.
    :param schema_name: Name of the schema where the table should be located.
    :return: True if the table exists, False otherwise.
    """
    query = """
        SELECT EXISTS(
            SELECT FROM information_schema.tables 
            WHERE table_name = %s AND table_schema = %s
        );
    """
    with pg_conn.cursor() as cur:
        cur.execute(query, (table_name.lower(), schema_name.lower()))
        exists = cur.fetchone()[0]
        logging.info(f"Table '{table_name}' existence check: {'Found' if exists else 'Not found'}.")
        return exists

# Create PostgreSQL Table Based on MySQL Schema
def create_postgresql_table(pg_conn, table_name, columns, schema_name='public'):
    """
    Creates a PostgreSQL table in the specified schema based on a list of MySQL columns.

    :param pg_conn: Active PostgreSQL connection object.
    :param table_name: Name of the table to create.
    :param columns: List of columns from MySQL schema (column name, type, nullable, default).
    :param schema_name: Schema name for the table.
    """
    create_table_sql = f'CREATE TABLE IF NOT EXISTS "{schema_name}"."{table_name}" ('
    column_definitions = []
    
    for col_name, col_type, nullable, default in columns:
        col_type = map_mysql_type_to_postgresql(col_type)
        nullable_str = "NULL" if nullable else "NOT NULL"
        default_str = f"DEFAULT {default}" if default else ""
        column_definitions.append(f'"{col_name}" {col_type} {nullable_str} {default_str}'.strip())
    
    create_table_sql += ", ".join(column_definitions) + ');'
    
    with pg_conn.cursor() as cur:
        cur.execute(create_table_sql)
        pg_conn.commit()
        logging.info(f"Table '{table_name}' created in schema '{schema_name}'.")

# Map MySQL Data Types to PostgreSQL
def map_mysql_type_to_postgresql(mysql_type):
    """
    Maps MySQL data types to PostgreSQL-compatible types.

    :param mysql_type: The MySQL data type as a string.
    :return: The corresponding PostgreSQL data type.
    """
    type_mappings = {
        'int': 'INTEGER',
        'tinyint': 'SMALLINT',
        'bigint': 'BIGINT',
        'varchar': 'VARCHAR',
        'text': 'TEXT',
        'double': 'DOUBLE PRECISION',
        'decimal': 'NUMERIC',
        'datetime': 'TIMESTAMP',
        'timestamp': 'TIMESTAMP',
        'date': 'DATE',
        'blob': 'BYTEA',
    }
    mapped_type = type_mappings.get(mysql_type.lower(), 'TEXT')
    logging.debug(f"Mapping MySQL type '{mysql_type}' to PostgreSQL type '{mapped_type}'")
    return mapped_type
