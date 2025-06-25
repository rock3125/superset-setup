import pandas as pd
import psycopg2
from psycopg2 import sql
import math

def get_postgres_type(pandas_type):
    """Maps pandas dtype to PostgreSQL data type."""
    if "int64" in str(pandas_type):
        return "BIGINT"
    elif "int32" in str(pandas_type):
        return "INTEGER"
    elif "float64" in str(pandas_type):
        return "DOUBLE PRECISION"
    elif "float32" in str(pandas_type):
        return "REAL"
    elif "object" in str(pandas_type):
        return "TEXT"
    elif "bool" in str(pandas_type):
        return "BOOLEAN"
    elif "datetime64" in str(pandas_type):
        return "TIMESTAMP"
    else:
        return "TEXT" # Default for other types

def parquet_to_postgres_batched(parquet_file_path, db_params, table_name, chunk_size=1000):
    """
    Reads a Parquet file, creates a schema and table in PostgreSQL,
    and inserts the data in batches.

    Args:
        parquet_file_path (str): The path to the Parquet file.
        db_params (dict): A dictionary with database connection parameters.
        table_name (str): The name of the table to create.
        chunk_size (int): The number of records to insert per batch.
    """
    conn = None
    cursor = None
    try:
        # Step 1: Read Parquet file into a pandas DataFrame
        print(f"Reading Parquet file from: {parquet_file_path}")
        df = pd.read_parquet(parquet_file_path)
        print("Parquet file read successfully.")
        print(f"Total records to insert: {len(df)}")
        print("\nDataFrame Info:")
        df.info()

        # Step 2: Connect to the PostgreSQL database
        print("\nConnecting to the PostgreSQL database...")
        conn = psycopg2.connect(**db_params)
        cursor = conn.cursor()
        print("Database connection successful.")

        # Step 4: Dynamically generate the CREATE TABLE statement
        print(f"Generating CREATE TABLE statement for '{table_name}'...")
        columns_with_types = []
        for column_name, dtype in df.dtypes.items():
            pg_type = get_postgres_type(dtype)
            columns_with_types.append(sql.SQL("{} {}").format(
                sql.Identifier(column_name),
                sql.SQL(pg_type)
            ))

        # Drop table if it exists to start fresh
        drop_table_query = sql.SQL("DROP TABLE IF EXISTS {}").format(
            sql.Identifier(table_name)
        )
        cursor.execute(drop_table_query)
        print(f"Dropped table '{table_name}' if it existed.")

        create_table_query = sql.SQL("CREATE TABLE {} ({})").format(
            sql.Identifier(table_name),
            sql.SQL(", ").join(columns_with_types)
        )
        cursor.execute(create_table_query)
        print(f"Table '{table_name}' created successfully.")

        # Step 5: Insert data in batches
        print(f"\nStarting data insertion in batches of {chunk_size}...")
        
        # Prepare the INSERT statement
        insert_query = sql.SQL("INSERT INTO {} ({}) VALUES ({})").format(
            sql.Identifier(table_name),
            sql.SQL(", ").join(map(sql.Identifier, df.columns)),
            sql.SQL(", ").join(sql.Placeholder() * len(df.columns))
        )

        # Iterate over the DataFrame in chunks
        total_chunks = math.ceil(len(df) / chunk_size)
        for i in range(0, len(df), chunk_size):
            chunk_df = df.iloc[i:i + chunk_size]
            
            # Convert chunk to list of tuples for insertion
            data_to_insert = [tuple(x) for x in chunk_df.to_numpy()]
            
            # Execute the insert statement for the chunk
            cursor.executemany(insert_query, data_to_insert)
            
            current_chunk_num = (i // chunk_size) + 1
            print(f"Inserted chunk {current_chunk_num} of {total_chunks} ({len(data_to_insert)} records)")

        # Commit the entire transaction
        conn.commit()
        print("\nAll batches inserted successfully. Transaction committed.")

    except (Exception, psycopg2.Error) as error:
        print(f"\nError while connecting to PostgreSQL or processing file: {error}")
        if conn:
            conn.rollback()
            print("Transaction rolled back.")
    finally:
        # Closing database connection.
        if conn:
            cursor.close()
            conn.close()
            print("PostgreSQL connection is closed.")


if __name__ == "__main__":
    # --- Configuration ---
    
    # Path to your Parquet file
    PARQUET_PATH = "demo_knowledge_base-summary-2025-6-24.parquet"
    
    # PostgreSQL connection details
    DB_CONNECTION_PARAMS = {
        "host": "localhost",
        "database": "parquet_store",
        "user": "simsage",
        "password": "<password>"
    }

    # Desired table name in PostgreSQL
    TABLE = "data"
    
    # Records per batch
    BATCH_SIZE = 1000

    # --- Run the main function ---
    parquet_to_postgres_batched(PARQUET_PATH, DB_CONNECTION_PARAMS, TABLE, chunk_size=BATCH_SIZE)
