#!/usr/bin/env bash

# Возвращает случайный индекс в диапазоне 0..num-1.
# Использует два значения RANDOM, чтобы расширить диапазон случайности.
random_index() {
    local num="$1"
    local big_random
    big_random=$(( RANDOM * 32768 + RANDOM ))

    echo "$(( big_random % num ))"
}

# Возвращает случайный элемент из переданного списка.
random_data() {
    local data=("$@")
    local num
    num=${#data[@]}
    
    echo "${data[$(random_index "$num")]}"
}


# Возвращает случайное число в диапазоне min_number..max_number.
random_number() {
    local min_number="${1:-100}"
    local max_number="${2:-5000}"
    local random result

    random=$(random_index $(( max_number - min_number + 1)))
    result=$(( random + min_number ))

    echo "$result"
}

# Проверяет, что IP не попадает в приватные и служебные диапазоны.
# На вход получает первые два октета адреса.
is_public_ip() {
    local octet1="$1"
    local octet2="$2"
    
    if (( octet1 == 10 || octet1 == 127 )); then
        return 1
    fi

    if (( octet1 == 192 || octet1 == 172 || octet1 == 169 )); then
        if (( octet1 == 192 && octet2 == 168)); then
            return 1
        fi

        if (( octet1 == 172 && (octet2 >= 16 && octet2 <= 31) )); then
            return 1
        fi

        if (( octet1 == 169 && octet2 == 254)); then
            return 1
        fi
    fi
    return 0
}

# Генерирует публичный IPv4-адрес.
# Октеты подбираются до тех пор, пока адрес не пройдёт is_public_ip.
ip_random() {
    local octet1 octet2 octet3 octet4
    local result

    while true; do
        octet1=$(random_number 1 223)
        octet2=$(random_number 0 255)
        
        if is_public_ip "$octet1" "$octet2"; then
            break
        fi
    done

    octet3=$(random_number 0 255)
    octet4=$(random_number 0 255)

    result="$octet1.$octet2.$octet3.$octet4"
    echo "$result"
}

# Формирует дату nginx-лога из timestamp начала дня и смещения в секундах.
format_log_date() {
    local day_start_ts sec result
    day_start_ts="$1"
    sec=${2}    

    result=$(( sec + day_start_ts ))

    date -d "@$result" +"%d/%b/%Y:%H:%M:%S %z"
}

# Генерирует отсортированный список секунд внутри одного дня.
# Это нужно, чтобы записи в логе шли по возрастанию времени.
generate_day_seconds() {
    local records_count="${1:-10}"
    local list_sec=()
    local i

    for (( i = 0; i < records_count; i++ )); do
        list_sec+=("$(random_index 86400)")
    done

    local sorted_list_sec=()
    local sec

    while IFS= read -r sec; do
        sorted_list_sec+=("$sec")
    done < <(printf '%s\n' "${list_sec[@]}" | sort -n)

    printf '%s\n' "${sorted_list_sec[@]}"
}

# Создаёт набор access-логов за указанное количество дней.
# Для каждого дня выбирает случайное количество записей в заданных границах.
generate_log() {
    local log_days_count="${1:-5}"
    local min_logs_count="${2:-100}"
    local max_logs_count="${3:-1000}"
    local log_dir="$4"
    
    local log_seconds=()
    
    local format_date days_ago records_count
    local day_start_ts log_file_date log_file
    
    for (( days_ago = "$log_days_count"; days_ago > 0; days_ago-- )); do
        records_count=$(random_number "$min_logs_count" "$max_logs_count")
        day_start_ts=$(date -d "$days_ago days ago 00:00:00" +%s)
        log_file_date=$(date -d "$days_ago days ago 00:00:00" +"%Y-%m-%d")
        log_file="${log_dir}/nginx_access_${log_file_date}.log"
        
        print_create_log_file "$log_file"
        (( CREATED_FILES++ ))

        mapfile -t log_seconds < <(generate_day_seconds "$records_count")
        for sec in "${log_seconds[@]}"; do
            format_date=$(format_log_date "$day_start_ts" "$sec")
            generate_log_line "$format_date" "$log_file"
            (( CREATED_LOGS++ ))
        done
        
        local actual_size
        actual_size=$(stat -c%s "$log_file")
        actual_size="$(( actual_size / 1024 ))"
        print_write_log_lines "${#log_seconds[@]}" "$actual_size"
    done
        
}

# Записывает одну строку nginx access log в combined-формате.
# Поля строки выбираются случайно из настроек settings.sh.
generate_log_line() {
    local ip ident user log_date method url status bytes referer user_agent
    
    local log_file="$2"

    ip=$(ip_random)
    ident='-'
    user=$(random_data "${USERS[@]}")
    
    log_date="$1"
    
    method=$(random_data "${METHODS[@]}")
    url=$(random_data "${URLS[@]}")
    status=$(random_data "${STATUSES[@]}")
    bytes=$(random_number "$MIN_RESPONSE_BYTE" "$MAX_RESPONSE_BYTE")
    referer=$(random_data "${REFERERS[@]}")
    user_agent=$(random_data "${USER_AGENTS[@]}")

    local client time_field request response referer_field agent_field log_line
    # Формирование строки лога
    client="$ip $ident $user"
    time_field="[$log_date]"
    request="\"$method $url HTTP/1.1\""
    response="$status $bytes"
    referer_field="\"$referer\""
    agent_field="\"$user_agent\""

    log_line="$client $time_field $request $response $referer_field $agent_field"

    printf '%s\n' "$log_line" >> "$log_file"
}

# Выводит стартовую информацию о генерации логов.
print_start_info() {
    local start_time="$1"
    local log_dir="$2"
    local log_days_count="${3:-5}"
    local min_logs_count="${4:-100}"
    local max_logs_count="${5:-1000}"

    echo
    echo -e "${CYAN}${BOLD}==============================================================${NC}"
    echo -e "${GREEN}${BOLD}Старт скрипта генерации nginx логов в combined формате${NC}"
    echo -e "${CYAN}${BOLD}==============================================================${NC}"
    echo -e "  ${GRAY}•${NC} Формат логов:                  ${WHITE}nginx combined${NC}"
    echo -e "  ${GRAY}•${NC} Каталог вывода:                ${WHITE}$log_dir${NC}"
    echo -e "  ${GRAY}•${NC} Файлов к созданию:             ${WHITE}$log_days_count${NC}"
    echo -e "  ${GRAY}•${NC} Записей на файл:               ${WHITE}$min_logs_count – $max_logs_count${NC}"
    echo -e "  ${GRAY}•${NC} Время запуска:                 ${WHITE}$start_time${NC}"
    echo -e "  ${GRAY}•${NC} Исключённые IP-диапазоны:"
    echo "      • 0.x.x.x"
    echo "      • 10.x.x.x"
    echo "      • 127.x.x.x"
    echo "      • 169.254.x.x"
    echo "      • 172.16–31.x.x"
    echo "      • 192.168.x.x"
    echo "      • 224–239.x.x.x"
    echo "      • 240–255.x.x.x"
    echo
    echo -e "Создание файлов:"
}

# Печатает путь создаваемого лог-файла в общем отчёте.
print_create_log_file() {
    printf '%b\t' "${WHITE}$1${NC}"
}

# Печатает количество строк и размер созданного лог-файла.
print_write_log_lines() {
    printf '%b\t' "${GREEN}$1 строк${NC}"
    printf '%b\n' "${CYAN}$2 kb${NC}"
}

# Выводит итоговый отчёт после генерации логов.
print_finish_report() {
    local end_time="$1" #
    local created_files="$2" #
    local created_logs="$3" #

    local start_time_sec="$4" #
    local end_time_sec="$5" #

    local log_dir="$6"

    local process_sec actual_size
    
    process_sec=$(( end_time_sec - start_time_sec ))
    
    actual_size=$(du -sk "$log_dir" | awk '{print $1}')

    echo
    echo -e "${MAGENTA}${BOLD}==============================================================${NC}"
    echo -e "${WHITE}${BOLD}Итоговый отчёт${NC}"
    echo -e "${MAGENTA}${BOLD}==============================================================${NC}"
    echo -e "  ${GRAY}•${NC} Завершение скрипта:            ${WHITE}$end_time${NC}"
    echo
    echo -e "${BLUE}${BOLD}Результат генерации:${NC}"
    echo -e "  ${GRAY}•${NC} Создано файлов:                ${GREEN}$created_files${NC}"
    echo -e "  ${GRAY}•${NC} Всего записей:                 ${GREEN}$created_logs${NC}"
    echo -e "  ${GRAY}•${NC} Общий размер:                  ${CYAN}$actual_size kb${NC}"
    echo -e "  ${GRAY}•${NC} Время выполнения:              ${MAGENTA}$(time_ui "$process_sec")${NC}"
    echo -e "${MAGENTA}${BOLD}==============================================================${NC}"
    echo
}

# Преобразует длительность в секундах в строку "ч мин сек".
time_ui() {
    local sec=$1
    local hours minutes seconds

    hours=$(( sec / 3600 ))
    minutes=$(( (sec % 3600) / 60 ))
    seconds=$(( sec % 60 ))
    
    echo "$hours ч $minutes мин $seconds сек"
}

validate_args() {
    if (( "$#" > 1 )); then
        echo -e "${RED}Ошибка: слишком много аргументов${NC}"
        print_help
        exit 1
    fi
}