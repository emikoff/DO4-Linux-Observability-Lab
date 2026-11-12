#!/usr/bin/env bash

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Пути к частям проекта
PART2_DIR="$SCRIPT_DIR/../02"
PART3_DIR="$SCRIPT_DIR/../03"
PART_NGINX_DIR="/var/www/html"

METRICS_FILE="$PART_NGINX_DIR/metrics"
TMP_FILE="$PART_NGINX_DIR/.metrics.tmp"

# Параметры тестов
PART2_ARGS=(az az.az 1Mb)
STRESS_ARGS=(-c 2 -i 1 -m 1 --vm-bytes 32M -t 10s)

PID_FILE="$PART_NGINX_DIR/metrics_generator.pid"
