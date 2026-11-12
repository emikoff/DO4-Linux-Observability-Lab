#!/usr/bin/env bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# Подключает файлы проекта:
# settings.sh   — глобальные настройки и константы;
# functions.sh  — основные функции очистки и вывода отчётов;
# validation.sh — функции проверки входных параметров.
#source ./settings.sh
#source ./functions.sh
#source ./validation.sh

# shellcheck source=settings.sh
source "$SCRIPT_DIR/settings.sh"

# shellcheck source=functions.sh
source "$SCRIPT_DIR/functions.sh"

# shellcheck source=validation.sh
source "$SCRIPT_DIR/validation.sh"

# Инициализирует глобальные переменные статистики.
# Они заполняются во время работы выбранного режима очистки.
START_TIME_SEC=""
START_TIME=""
STOP_REASON="Успешно"

DELETE_DIRS=0
DELETE_FILES=0
SKIPPED_DIR=0
SKIPPED_FILES=0

FREE_BEFORE_MB=0

# Проверяет, что скрипт запущен с одним параметром:
# 1 — очистка по лог-файлу;
# 2 — очистка по дате и времени;
# 3 — очистка по маске имени.
validate_cleanup_mode "$@"

mode=$1

# Выбирает способ очистки в зависимости от переданного параметра.
case "$mode" in
    1)  
        LOG_FILE=$(search_logs)
        cleanup_by_log "${LOG_FILE}"
        ;;
    2) cleanup_by_datetime
        ;;
    3) cleanup_by_mask
        ;;
    *) show_help
        exit 1
        ;;
esac

# Фиксирует время завершения и свободное место после очистки.
END_TIME_SEC=$(date +%s)
FREE_AFTER_MB=$(df -m "$FIRST_DIR" | awk 'NR==2 {print $4}')

# Выводит итоговый отчёт:
# время выполнения, количество удалённых и пропущенных объектов,
# изменение свободного места.
print_finish_report "$START_TIME_SEC" "$END_TIME_SEC" "$FREE_BEFORE_MB" "$FREE_AFTER_MB" "$DELETE_DIRS" "$DELETE_FILES" "$STOP_REASON" "$SKIPPED_DIR" "$SKIPPED_FILES"
