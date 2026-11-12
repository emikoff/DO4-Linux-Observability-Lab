#!/usr/bin/env bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

source "$SCRIPT_DIR/settings.sh"
source "$SCRIPT_DIR/functions.sh"

validate "$@"

case "$1" in
	1) print_sorted_by_code "$LOG_DIR"
	exit 0
	;;
	2) print_unique_ips "$LOG_DIR"
	exit 0
	;;
	3) print_error_requests "$LOG_DIR"
	exit 0
	;;
	4) print_unique_error_ips "$LOG_DIR"
	exit 0
	;;
	*) error
	exit 1
esac
