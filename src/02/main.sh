#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# main.sh — точка входа.
# Скрипт принимает 6 параметров, проверяет их, нормализует значения
# и запускает создание дерева директорий и файлов.
#

source "$SCRIPT_DIR/settings.sh"
source "$SCRIPT_DIR/functions.sh"
source "$SCRIPT_DIR/validation.sh"


# Глобальные счётчики созданных объектов.
# Увеличиваются внутри функций создания и используются в итоговом отчёте.

START_TIME=""
END_TIME=""

START_TIME_SEC=""
END_TIME_SEC=""

FREE_AFTER_MB=0
FREE_BEFORE_MB=0

PROCESS_SEC=0
USED_MB=0

CREATED_DIRS=0
CREATED_FILES=0

SKIPPED_DIR_ATTEMPTS=0
SKIPPED_FILE_ATTEMPTS=0

STOP_REASON="Успешно"

# 1. Валидация (проверяем сырые $1..$3)
run_all_validations "$@"

collect_start_metrics

print_start_info "$@" "$START_TIME" "$TDATE" "$MAX_DIRS" "$FILES_PER_DIR" "$FIRST_DIR" "$FREE_BEFORE_MB"

# 2. Очистка и нормализация (превращаем в чистые переменные)
# target_path="$1"
dir_chars="$1"
# files_count=$(( (RANDOM % 59) + 1 ))
file_pattern="$2"
size_raw="$3"

# 3. Дополнительная декомпозиция сложных параметров
# На этом этапе validation.sh уже гарантирует,
# что file_pattern имеет формат name.ext.
file_chars=$(echo "$file_pattern" | cut -d. -f1)
ext_chars=$(echo "$file_pattern" | cut -d. -f2)
size_digits=$(echo "$size_raw" | sed 's/[^0-9]//g') # Размер файла в Mb без суффикса
size_digits=$(( 10#$size_digits )) # Преобразует в десятичное число

# Заполняет массив с директориями достумные для записи
init_dirs_for_write


# 4. Запуск главной функции (передаем 4 параметров)
create_path_and_file "$dir_chars" "$file_chars" "$ext_chars" "$size_digits"

collect_finish_metrics

print_finish_report \
  "$END_TIME" \
  "$PROCESS_SEC" \
  "$FREE_AFTER_MB" \
  "$USED_MB" \
  "$CREATED_DIRS" \
  "$CREATED_FILES" \
  "$STOP_REASON" \
  "$SKIPPED_DIR_ATTEMPTS" \
  "$SKIPPED_FILE_ATTEMPTS"

  write_summary \
  "$START_TIME" \
  "$END_TIME" \
  "$PROCESS_SEC" \
  "$CREATED_DIRS" \
  "$CREATED_FILES" \
  "$FREE_BEFORE_MB" \
  "$FREE_AFTER_MB" \
  "$USED_MB" \
  "$STOP_REASON"
