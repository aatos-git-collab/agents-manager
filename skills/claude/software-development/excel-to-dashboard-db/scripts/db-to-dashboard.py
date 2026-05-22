#!/usr/bin/env python3
"""
Database to Dashboard Converter
Generates dashboard-ready data from SQLite database.
"""

import sqlite3
import json
import sys
import os
from datetime import datetime

def get_table_data(db_file, table_name=None):
    """Get all data from table as JSON."""
    if not os.path.exists(db_file):
        print(f"Error: Database not found: {db_file}")
        sys.exit(1)
    
    conn = sqlite3.connect(db_file)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    
    if table_name:
        tables = [table_name]
    else:
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = [r[0] for r in cursor.fetchall()]
    
    result = {}
    for table in tables:
        cursor.execute(f"SELECT * FROM {table}")
        rows = cursor.fetchall()
        result[table] = {
            "columns": list(rows[0].keys()) if rows else [],
            "data": [dict(row) for row in rows],
            "count": len(rows),
            "updated_at": datetime.now().isoformat()
        }
    
    conn.close()
    return result

def generate_summary(db_file):
    """Generate summary statistics for dashboard."""
    conn = sqlite3.connect(db_file)
    cursor = conn.cursor()
    
    summary = {
        "generated_at": datetime.now().isoformat(),
        "tables": {}
    }
    
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
    for (table,) in cursor.fetchall():
        cursor.execute(f"SELECT COUNT(*) FROM {table}")
        count = cursor.fetchone()[0]
        
        # Get numeric columns for stats
        cursor.execute(f"PRAGMA table_info({table})")
        cols = cursor.fetchall()
        numeric_cols = [c[1] for c in cols if c[2] in ('INTEGER', 'REAL')]
        
        stats = {"count": count, "numeric_fields": numeric_cols}
        
        if numeric_cols and count > 0:
            for col in numeric_cols[:3]:  # Limit to 3 columns
                cursor.execute(f"SELECT AVG({col}), SUM({col}), MIN({col}), MAX({col}) FROM {table}")
                avg, sum_, min_, max_ = cursor.fetchone()
                stats[col] = {
                    "avg": round(avg, 2) if avg else 0,
                    "sum": round(sum_, 2) if sum_ else 0,
                    "min": min_,
                    "max": max_
                }
        
        summary["tables"][table] = stats
    
    conn.close()
    return summary

def export_json(db_file, output_file=None):
    """Export database to JSON."""
    data = get_table_data(db_file)
    
    if output_file is None:
        output_file = "data/dashboard-data.json"
    
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    with open(output_file, 'w') as f:
        json.dump(data, f, indent=2, default=str)
    
    print(f"✅ Exported to: {output_file}")
    return output_file

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Database to Dashboard Converter")
    parser.add_argument("--db", "-d", help="Database file", default="data/dashboard.db")
    parser.add_argument("--table", "-t", help="Specific table", default=None)
    parser.add_argument("--summary", "-s", action="store_true", help="Show summary")
    parser.add_argument("--export", "-e", help="Export to JSON file", default=None)
    
    args = parser.parse_args()
    
    if args.summary:
        summary = generate_summary(args.db)
        print(json.dumps(summary, indent=2, default=str))
    elif args.export:
        export_json(args.db, args.export)
    else:
        data = get_table_data(args.db, args.table)
        print(json.dumps(data, indent=2, default=str))
