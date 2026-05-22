#!/bin/bash
# Git Project Manager - Main Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    cat << EOF
Git Project Manager

USAGE:
    ./run.sh <command> [options]

PROJECT COMMANDS:
    analyze                     Analyze current project structure
    profile                     Generate project profile

BRAIN BACKUP COMMANDS:
    backup [--push]             Backup agents to brains repo

LEARNING COMMANDS:
    learn                       Learn from session
    recall <query>             Recall relevant patterns
    feedback <issue> <fix>      Learn from feedback

EOF
}

case "${1:-help}" in
    analyze)
        python3 "${SCRIPT_DIR}/scripts/git-manager.py" --path . --profile
        ;;
    profile)
        python3 "${SCRIPT_DIR}/scripts/git-manager.py" --path . --profile --output project.json
        ;;
    backup)
        shift
        python3 "${SCRIPT_DIR}/scripts/agent-brain-backup.py" --source /root/hermes-workspace "$@"
        ;;
    learn)
        "${SCRIPT_DIR}/scripts/learning/learn-project-patterns.sh"
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
