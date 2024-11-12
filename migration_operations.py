import logging
from datetime import datetime
import psycopg2
from psycopg2 import sql
import psycopg2.extras
from database_connections import check_table_exists, create_postgresql_table, map_mysql_type_to_postgresql

# Merge and Update Data from MySQL to PostgreSQL
def merge_and_update_data(mysql_conn, pg_conn, mysql_table, pg_table, unique_cols=None, batch_size=500):
    """
    Merges data from MySQL into PostgreSQL by upserting rows. Handles both inserts and updates.

    :param mysql_conn: MySQL connection object.
    :param pg_conn: PostgreSQL connection object.
    :param mysql_table: Name of the MySQL table to read from.
    :param pg_table: Name of the PostgreSQL table to write to.
    :param unique_cols: List of columns to identify unique records for upsert.
    :param batch_size: Number of rows to process in each batch.
    """
    try:
        # Query all data from MySQL table
        with mysql_conn.cursor(dictionary=True) as mysql_cur:
            mysql_cur.execute(f"SELECT * FROM {mysql_table}")
            rows = mysql_cur.fetchall()

            if not rows:
                logging.info(f"No data found in MySQL table '{mysql_table}' to migrate.")
                return

            # Process data in batches
            for i in range(0, len(rows), batch_size):
                batch = rows[i:i + batch_size]
                
                # Extract column names from the first row in the batch
                columns = list(batch[0].keys())
                columns.append("insert_date")  # Add an additional column for the insertion timestamp

                # Prepare upsert conflict action if unique columns are provided
                if unique_cols:
                    conflict_action = sql.SQL("ON CONFLICT ({conflict_cols}) DO UPDATE SET {update_cols}").format(
                        conflict_cols=sql.SQL(', ').join(map(sql.Identifier, unique_cols)),
                        update_cols=sql.SQL(', ').join(sql.Identifier(col) + sql.SQL(" = EXCLUDED.") + sql.Identifier(col) for col in columns)
                    )
                else:
                    conflict_action = sql.SQL("")  # No conflict action if there are no unique columns

                # Prepare the PostgreSQL upsert query
                insert_query = sql.SQL("""
                    INSERT INTO {table} ({fields}) VALUES %s
                    {conflict_action}
                """).format(
                    table=sql.Identifier(pg_table),
                    fields=sql.SQL(', ').join(map(sql.Identifier, columns)),
                    conflict_action=conflict_action
                )

                # Add insert date for each row in the batch
                values = [tuple(row.values()) + (datetime.now(),) for row in batch]

                # Execute batch upsert
                with pg_conn.cursor() as pg_cur:
                    psycopg2.extras.execute_values(pg_cur, insert_query, values)
                    pg_conn.commit()
                    logging.info(f"Upserted {len(batch)} rows into '{pg_table}' from MySQL table '{mysql_table}'.")

    except Exception as e:
        logging.error(f"Failed to migrate data for table '{mysql_table}' to PostgreSQL: {e}")
        pg_conn.rollback()
        raise

# Ensure PostgreSQL Table and Columns are Ready
def ensure_pg_table_created(pg_conn, pg_table, mysql_columns, unique_cols, schema='public'):
    """
    Ensures the PostgreSQL table and necessary columns exist for migration.

    :param pg_conn: PostgreSQL connection object.
    :param pg_table: Target PostgreSQL table name.
    :param mysql_columns: List of MySQL columns with (name, type, nullable, default).
    :param unique_cols: List of columns for unique constraints.
    :param schema: Schema where the PostgreSQL table resides.
    """
    table_exists = check_table_exists(pg_conn, pg_table, schema)

    if not table_exists:
        # Create table in PostgreSQL if it doesn't exist
        logging.info(f"Creating PostgreSQL table '{pg_table}' in schema '{schema}'.")
        create_postgresql_table(pg_conn, pg_table, mysql_columns, schema)

    # Add unique constraints if they do not exist
    if unique_cols:
        add_unique_constraint(pg_conn, pg_table, unique_cols, schema)

# Add Unique Constraint in PostgreSQL
def add_unique_constraint(pg_conn, table_name, unique_cols, schema='public'):
    """
    Adds a unique constraint to the specified columns in a PostgreSQL table.

    :param pg_conn: PostgreSQL connection object.
    :param table_name: PostgreSQL table name.
    :param unique_cols: List of columns for the unique constraint.
    :param schema: Schema where the table resides.
    """
    unique_constraint_name = f"{table_name}_unique_constraint"
    unique_columns = ', '.join(f'"{col}"' for col in unique_cols)
    add_constraint_sql = f"""
        ALTER TABLE "{schema}"."{table_name}"
        ADD CONSTRAINT {unique_constraint_name} UNIQUE ({unique_columns});
    """
    try:
        with pg_conn.cursor() as cur:
            cur.execute(add_constraint_sql)
            pg_conn.commit()
            logging.info(f"Unique constraint added to '{table_name}' on columns {unique_cols}.")
    except psycopg2.Error as e:
        logging.error(f"Error adding unique constraint to table '{table_name}': {e}")
        pg_conn.rollback()
        raise

# Helper function to map MySQL columns to PostgreSQL
def map_mysql_columns_to_pg(mysql_columns):
    """
    Maps MySQL column definitions to PostgreSQL-compatible format.

    :param mysql_columns: List of MySQL column definitions (name, type, nullable, default).
    :return: List of mapped PostgreSQL column definitions.
    """
    pg_columns = []
    for col_name, col_type, is_nullable, default in mysql_columns:
        pg_type = map_mysql_type_to_postgresql(col_type)
        nullable_str = "NULL" if is_nullable else "NOT NULL"
        default_str = f"DEFAULT {default}" if default else ""
        pg_columns.append(f'"{col_name}" {pg_type} {nullable_str} {default_str}'.strip())
    return pg_columns
