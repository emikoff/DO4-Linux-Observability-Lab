#!/usr/bin/env bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# Подключаем функции и настройки
source "$SCRIPT_DIR/settings.sh"
source "$SCRIPT_DIR/functions.sh"

if (( $# == 0 )); then
    menu_info
    menu
    exit 0
else
    echo "Не принимает аргументы"
    exit 1
fi
