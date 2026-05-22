#!/usr/bin/env python3
"""
Excel to Database Converter
Reads Excel files and stores data in SQLite database for dashboard use.
"""

import pandas as pd
import sqlite3
import os
import sys
from datetime import datetime

def excel_to_db(excel_file, db_file=None, table_name=None):
    """
    Convert Excel file to SQLite database.
    
    Args:
        excel_file: Path to Excel file (.xlsx, .xls, .csv)
        db_file: Output database file (default: data/dashboard.db)
        table_name: Table name (default: sheet name or 'excel_data')
    """
    if not os.path.exists(excel_file):
        print(f"Error: File not found: {excel_file}")
        sys.exit(1)
    
    # Determine output
    if db_file is None:
        db_file = "data/dashboard.db"
    
    os.makedirs(os.path.dirname(db_file), exist_ok=True)
    
    # Determine table name
    if table_name is None:
        table_name = "excel_data"
    
    print(f"📊 Converting: {excel_file}")
    print(f"   → Database: {db_file}")
    print(f"   → Table: {table_name}")
    
    # Read Excel
    if excel_file.endswith('.csv'):
        df = pd.read_csv(excel_file)
    else:
        df = pd.read_excel(excel_file)
    
    # Clean column names
    df.columns = [col.strip().replace(' ', '_').lower() for col in df.columns]
    
    # Add timestamp
    df['_imported_at'] = datetime.now().isoformat()
    
    # Store in SQLite
    conn = sqlite3.connect(db_file)
    df.to_sql(table_name, conn, if_exists='replace', index=False)
    conn.close()
    
    print(f"✅ Imported {len(df)} rows into '{table_name}'")
    print(f"   Columns: {list(df.columns)}")
    
    return db_file, table_name

def db_stats(db_file):
    """Show database statistics."""
    if not os.path.exists(db_file):
        print(f"Database not found: {db_file}")
        return
    
    conn = sqlite3.connect(db_file)
    cursor = conn.cursor()
    
    # List tables
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = cursor.fetchall()
    
    print(f"\n📊 Database: {db_file}")
    print("Tables:")
    for (table,) in tables:
        cursor.execute(f"SELECT COUNT(*) FROM {table}")
        count = cursor.fetchone()[0]
        print(f"   - {table}: {count} rows")
    
    conn.close()

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Excel to Database Converter")
    parser.add_argument("file", help="Excel or CSV file to import")
    parser.add_argument("--db", "-d", help="Output database file", default="data/dashboard.db")
    parser.add_argument("--table", "-t", help="Table name", default=None)
    parser.add_argument("--stats", "-s", action="store_true", help="Show database stats")
    
    args = parser.parse_args()
    
    if args.stats:
        db_stats(args.db)
    else:
        excel_to_db(args.file, args.db, args.table)
