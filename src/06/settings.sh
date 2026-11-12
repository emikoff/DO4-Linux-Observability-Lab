#!/usr/bin/env bash

GOACCESS_KEY_URL="https://deb.goaccess.io/gnugpg.key"
GOACCESS_KEYRING="/usr/share/keyrings/goaccess.gpg"
GOACCESS_REPO_FILE="/etc/apt/sources.list.d/goaccess.list"
GOACCESS_REPO_URL="https://deb.goaccess.io/"
LOG_DIR="$SCRIPT_DIR/../04/logs"

# ANSI-коды цветов для оформления сообщений
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'

# Жирный текст
BOLD='\033[1m'

# Сброс ANSI-оформления
NC='\033[0m'
