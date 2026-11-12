#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# main.sh — точка входа.
# Скрипт принимает 6 параметров, проверяет их, нормализует значения
# и запускает создание дерева директорий и файлов.

source "$SCRIPT_DIR/functions.sh" # Логика создания вынесена
source "$SCRIPT_DIR/validation.sh" # Проверка входных данных
source "$SCRIPT_DIR/settings.sh" # Настройки ограничений

# Глобальные счётчики созданных объектов.
# Увеличиваются внутри функций создания и используются в итоговом отчёте.
CREATED_DIRS=0
CREATED_FILES=0

# 1. Валидация (проверяем сырые $1..$6)
run_all_validations "$@"
print_start_info "$@"

# 2. Очистка и нормализация (превращаем в чистые переменные)
target_path="$1"
folders_count=$(( 10#$2 ))
dir_chars="$3"
files_count=$(( 10#$4 ))
file_pattern="$5"
size_raw="$6"

# 3. Дополнительная декомпозиция сложных параметров
# На этом этапе validation.sh уже гарантирует,
# что file_pattern имеет формат name.ext.
file_chars=$(echo "$file_pattern" | cut -d. -f1)
ext_chars=$(echo "$file_pattern" | cut -d. -f2)
size_digits=$(echo "$size_raw" | sed 's/[^0-9]//g') # Размер файла в KB без суффикса
size_digits=$(( 10#$size_digits )) # Преобразует в десятичное число

# 4. Запуск главной функции (передаем 11 параметров)
create_tree_and_file "$target_path" "$folders_count" "$dir_chars" \
                     "$MIN_LEN_DIR" "$MAX_LEN_DIR" \
                     "$files_count" "$file_chars" "$ext_chars" \
                     "$size_digits" "$MIN_LEN_FILE" "$MAX_LEN_FILE"

print_finish_report
