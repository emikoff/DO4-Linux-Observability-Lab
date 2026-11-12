#!/usr/bin/env bash

# Выводит все записи логов, отсортированные по HTTP-коду ответа.
print_sorted_by_code() {
	local path="$1"
  	sort -k9 -n "$path"/*.log
}

# Выводит список уникальных IP-адресов из access-логов.
print_unique_ips() {
	local path="$1"
	awk '{print $1}' "$path"/*.log | sort | uniq
}

# Выводит только запросы с кодами ответа из диапазона ошибок.
print_error_requests() {
	local path="$1"
	local error_min="${2:-400}"
	local error_max="${3:-599}"

	awk -v error_min="$error_min" -v error_max="$error_max" '$9>=error_min && $9<=error_max {print $0}' "$path"/*.log
}

# Выводит уникальные IP-адреса, встречающиеся среди ошибочных запросов.
print_unique_error_ips() {
	local path="$1"
	local error_min="${2:-400}"
	local error_max="${3:-599}"

	awk -v error_min="$error_min" -v error_max="$error_max" '$9>=error_min && $9<=error_max {print $1}' "$path"/*.log | sort | uniq
}

# Печатает сообщение об ошибке для неверного режима анализа.
error() {
	echo "Ошибка: скрипт принимает ровно один параметр."

	echo "Использование:"
	echo "./main.sh <режим>"

	echo "Доступные режимы:"
	echo "1  — все записи, отсортированные по коду ответа"
	echo "2  — уникальные IP-адреса"
	echo "3  — запросы с ошибками 4xx/5xx"
	echo "4  — уникальные IP-адреса среди ошибочных запросов"
}

# Проверяет, что скрипт запущен ровно с одним параметром.
validate() {
	if [ "$#" -ne 1 ]; then
		error
		exit 1
	fi
}
