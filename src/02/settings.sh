#!/usr/bin/env bash

# settings.sh — файл настроек.
# Содержит глобальные константы: путь к лог-файлу,
# ограничения длины имён, текущую дату для маски имён
# и ANSI-коды цветов для вывода сообщений.

# Количесвто аргументов main.sh
LEN_ARGS=3

# Лог создаётся в текущей рабочей директории, из которой запущен скрипт.
TDATE=$(date +"%d%m%y")

PROJECT_DIR="$SCRIPT_DIR"
LOG_DIR="$PROJECT_DIR/logs"

mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/log_${TDATE}_$(date +%H%M%S).tsv"

# Ограничения длины имени директории
MIN_LEN_DIR=5
MAX_LEN_DIR=7

# Ограничения длины имени файла без расширения
MIN_LEN_FILE=5
MAX_LEN_FILE=7

# Ограничения длины расширения файла
MIN_LEN_EXT=1
MAX_LEN_EXT=3

# ANSI-коды цветов для вывода информационных сообщений и ошибок
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'

BOLD='\033[1m'
NC='\033[0m' # Сброс цвета

EXCLUDE=( "*/bin*" "*/sbin*" "/proc*" "/sys*" "/dev*" "/run*" )

DIRS_FOR_WRITE=()

MAX_DIRS=100

FIRST_DIR="/"

MAX_ATTEMPTS=500
FILES_PER_DIR=30
