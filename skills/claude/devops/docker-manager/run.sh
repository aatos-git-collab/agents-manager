#!/bin/bash
# Skill entry point

case "${1:-help}" in
    help|--help|-h)
        echo "Skill Help"
        ;;
    *)
        echo "Executing..."
        ;;
esac
