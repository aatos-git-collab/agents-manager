#!/bin/bash
# Excel to Dashboard DB - Main Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    cat << EOF
📊 Excel to Dashboard DB (Self-Learning)

USAGE:
    ./run.sh <command> [options]

DATA COMMANDS:
    import <file> [--db <file>] [--table <name>]  Import Excel/CSV to database
    export [--db <file>] [--summary]              Export dashboard data
    stats <db-file>                               Show database statistics

LEARNING COMMANDS:
    learn                                        Learn from last session
    recall <query>                                Recall relevant patterns
    feedback <issue> <fix>                        Learn from feedback

EXAMPLES:
    ./run.sh import data.xlsx --db data/dashboard.db --table sales
    ./run.sh export --db data/dashboard.db --summary
    ./run.sh stats data/dashboard.db
    ./run.sh learn
    ./run.sh recall "sales data"
    ./run.sh feedback "too slow" "use chunking"

LEARNING WORKFLOW:
    1. Complete your task
    2. ./run.sh learn              (extract patterns)
    3. ./run.sh recall "query"    (recall before similar task)
    4. ./run.sh feedback "x" "y" (learn from corrections)

EOF
}

case "${1:-help}" in
    import)
        shift
        python3 "${SCRIPT_DIR}/scripts/excel-to-db.py" "$@"
        ;;
    export)
        shift
        python3 "${SCRIPT_DIR}/scripts/db-to-dashboard.py" "$@"
        ;;
    stats)
        shift
        python3 "${SCRIPT_DIR}/scripts/db-to-dashboard.py" --db "$1" --summary
        ;;
    learn)
        "${SCRIPT_DIR}/scripts/learning/learn-from-session.sh"
        ;;
    recall)
        shift
        "${SCRIPT_DIR}/scripts/learning/recall-patterns.sh" "$@"
        ;;
    feedback)
        shift
        "${SCRIPT_DIR}/scripts/learning/learn-from-feedback.sh" "$@"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Unknown command: ${1}"
        show_help
        exit 1
        ;;
esac
