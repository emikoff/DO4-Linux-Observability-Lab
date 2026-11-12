#!/usr/bin/env bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

source "$SCRIPT_DIR/settings.sh"
source "$SCRIPT_DIR/functions.sh"

validate_args "$@"

if (( $# == 0 )); then
    interactive_menu
    exit 0
fi

case "$1" in
    report_terminal)
        report_terminal
        ;;
    report_html)
        report_html
        ;;
    serve)
        run_http_server
        ;;
    install)
        install_GoAccess
        ;;
    rm)
        rm_GoAccess
        ;;
    help|-h|--help)
        print_help
        ;;
    *)
        echo -e "${RED}Ошибка: неизвестная команда: $1${NC}"
        print_help
        exit 1
        ;;
esac
