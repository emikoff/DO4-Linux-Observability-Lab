#!/usr/bin/env bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# shellcheck source=settings.sh
source "$SCRIPT_DIR/settings.sh"

# shellcheck source=functions.sh
source "$SCRIPT_DIR/functions.sh"

# shellcheck source=http_info.sh
source "$SCRIPT_DIR/http_info.sh"

validate_args "$@"

if (( "$#" == 0)); then
    CREATED_FILES=0
    CREATED_LOGS=0

    START_TIME_SEC=$(date +%s)
    START_TIME=$(date +"%H:%M:%S %d.%m.%Y")

    rm -rf "$LOG_DIR"
    mkdir -p "$LOG_DIR"

    print_start_info "$START_TIME" "$LOG_DIR" "$LOG_DAYS_COUNT" "$MIN_LOG_RECORDS" "$MAX_LOG_RECORDS"
    generate_log "$LOG_DAYS_COUNT" "$MIN_LOG_RECORDS" "$MAX_LOG_RECORDS" "$LOG_DIR"

    END_TIME_SEC=$(date +%s)
    END_TIME=$(date +"%H:%M:%S %d.%m.%Y")

    print_finish_report "$END_TIME" "$CREATED_FILES" "$CREATED_LOGS" "$START_TIME_SEC" "$END_TIME_SEC" "$LOG_DIR"
    exit 0
fi



case "$1" in
    -h|--help)
        print_help
        exit 0
        ;;
    code) print_http_code_info
        exit 0
        ;;
    method) print_http_metods_info
        exit 0
        ;;
    combined) print_combined_format_info
        exit 0
        ;;
    *) echo -e "${RED}Ошибка: неизвестная команда: $1${NC}"
        print_help
        exit 1  
esac
