#!/usr/bin/env bash
# functions.sh — основной модуль очистки и вывода отчётов.
#
# Файл содержит функции для трёх режимов очистки:
# • по лог-файлу из предыдущей части проекта;
# • по дате и времени создания;
# • по маске имени.
#
# Также здесь находятся общие функции поиска, удаления, форматирования
# времени и печати служебных отчётов. Файл подключается из main.sh
# и использует глобальные настройки из settings.sh.

# Очищает файлы и пустые директории по записям из лог-файла.
# Аргументы:
#   $1 — путь к TSV-лог-файлу.
# Возвращает:
#   0 — обработка завершена;
#   1 — лог-файл не найден.
# Побочные эффекты:
#   обновляет счётчики DELETE_FILES, DELETE_DIRS и SKIPPED_DIR.
cleanup_by_log() {
    local log_file="$1"
    local dirs=()
    

    if [[ ! -f "$log_file" ]]; then
        echo -e "${RED}${BOLD}Ошибка:${NC} лог-файл не найден: ${WHITE}$log_file${NC}"
        return 1
    fi

    start
    print_start_info "$START_TIME" "$FREE_BEFORE_MB" "по лог-файлу"
    print_params_clear_by_log "$log_file"

    local _date type path _size _human

    # Сначала удаляются файлы, а директории только запоминаются:
    # иначе rmdir может не удалить каталог, пока внутри ещё есть файлы.
    while IFS=$'\t' read -r _date type path _size _human; do
        if [[ ! -e "$path" ]]; then
            continue;
        fi

        if [[ "$type" == 'file' ]]; then
            delete_file "$path"
        elif [[ "$type" == 'dir' ]]; then
            dirs+=("$path")
        fi
    done < "$log_file"

    # Обратная сортировка помогает удалить вложенные директории раньше родительских.
    if [[ ${#dirs[@]} -gt 0 ]]; then
        echo -e "${BLUE}${BOLD}Удаляю пустые директории...${NC}"
        
        while IFS= read -r dir; do
            delete_dir "$dir"
        done < <(printf '%s\n' "${dirs[@]}" | sort -r)
    fi
}

# Запускает интерактивную очистку по дате и диапазону времени.
# Пользователь вводит дату, время начала и время окончания.
# Функция строит временные метки для find и удаляет найденные файлы
# и пустые директории с датой в имени.
# Побочные эффекты:
#   создаёт временные файлы /tmp/daystart и /tmp/dayend;
#   обновляет глобальные счётчики очистки.
cleanup_by_datetime() {
    local start_date
    local end_date
    

    local clean_day start_time end_time default_day
    default_day=$(tdate)

    while true; do
        prompt_input "Введите дату очистки ${GRAY}(DD.MM.YYYY, например: ${WHITE}$default_day${GRAY})${NC}:" clean_day
        clean_day="${clean_day}"
        if validate_date_human "$clean_day"; then
            break
        fi
    done

    while true; do
        prompt_input "Введите время начала ${GRAY}(HH:MM, например: ${WHITE}11:58${GRAY})${NC}:" start_time
        start_time="${start_time}"
        if validate_time_human "$start_time"; then
            break
        fi
    done

    while true; do
        prompt_input "Введите время окончания ${GRAY}(HH:MM, по умолчанию: ${WHITE}11:59${GRAY})${NC}:" end_time
        end_time="${end_time}"
        if validate_time_human "$end_time"; then
            break
        fi
    done

    local path_start_date path_end_date mask_date file_mask dir_mask

    path_start_date='/tmp/daystart'
    path_end_date='/tmp/dayend'
    mask_date=$(convert_date_for_mask "${clean_day}")
    file_mask="*_${mask_date}*"
    dir_mask="*_${mask_date}"


    start_date=$(convert_datetime_for_touch "$clean_day" "${start_time}")
    end_date=$(convert_datetime_for_touch "$clean_day" "${end_time}")

    # find сравнивает даты через существующие файлы-метки.
    touch -t "$start_date" "$path_start_date"
    touch -t "$end_date" "$path_end_date"

    start
    print_start_info "$START_TIME" "$FREE_BEFORE_MB" "по дате и времени"
    print_params_clear_by_datetime "$clean_day" "$start_time" "$end_time" "$file_mask" "$dir_mask"

    while IFS= read -r file; do
        delete_file "$file"
    done < <(find_targets \
                        "date" \
                        f \
                        "${file_mask}" \
                        "${path_start_date}" \
                        "${path_end_date}")

    while IFS= read -r dir; do
        delete_dir "$dir"
    done < <(find_targets \
                        "date" \
                        d \
                        "${dir_mask}" \
                        "${path_start_date}" \
                        "${path_end_date}")

    rm -f -- "$path_start_date" "$path_end_date"
}

# Запускает интерактивную очистку по маске имени.
# Пользователь вводит буквы для директорий, шаблон file.ext,
# размер файла и дату из имени. После валидации функция строит
# POSIX-регулярные выражения для find и удаляет найденные объекты.
# Побочные эффекты:
#   обновляет глобальные счётчики очистки.
cleanup_by_mask() {
    local dir_chars=""
    local file_pattern=""
    local size_raw=""
    local date=""

    local file_chars=""
    local ext_chars=""
    local size_digits=""    


    print_info_clean_by_mask

    while true; do
        prompt_input "Введите буквы для имени директорий ${GRAY}(1-7 английских букв, пример: ${WHITE}az${GRAY})${NC}:" dir_chars
        if ! validate_length_range "$dir_chars" 1 7; then
            continue
        fi
        if validate_letters "$dir_chars"; then
            break
        fi
    done

    while true; do
        prompt_input "Введите шаблон имени файла и расширения ${GRAY}(формат ${WHITE}name.ext${GRAY}, пример: ${WHITE}az.az${GRAY})${NC}:" file_pattern
        if ! validate_file_pattern "$file_pattern"; then
            continue
        fi
        if ! validate_one_dot "$file_pattern"; then
            continue
        fi

        file_chars=$(echo "$file_pattern" | cut -d. -f1)
        ext_chars=$(echo "$file_pattern" | cut -d. -f2)
        if ! validate_length_range "$file_chars" 1 7; then
            continue
        fi
        
        if ! validate_letters "$file_chars"; then
            continue
        fi
        if ! validate_length_range "$ext_chars" 1 3; then
            continue
        fi
        if validate_letters "$ext_chars"; then
            break
        fi
    
    done
    
    while true; do
        prompt_input "Введите размер файлов ${GRAY}(формат ${WHITE}NMb${GRAY}, пример: ${WHITE}3Mb${GRAY})${NC}:" size_raw
        if ! validate_size_format "$size_raw"; then
            continue
        fi

        # Отделяем число от суффикса Mb и принудительно считаем его десятичным.
        size_digits="${size_raw//[^0-9]/}"
        size_digits=$(( 10#$size_digits ))
        if validate_size_value "$size_digits"; then
            break
        fi
    done

    while true; do
        prompt_input "Введите дату из имени файлов ${GRAY}(формат ${WHITE}DDMMYY${GRAY}, пример: ${WHITE}080526${GRAY})${NC}:" date
        if validate_date_mask "$date"; then
            break
        fi
    done
    

    local mask_file mask_dir
    local min_len_file max_len_file min_len_ext max_len_ext
    min_len_file="${MIN_LEN_FILE:-5}"
    max_len_file="${MAX_LEN_FILE:-7}"
    min_len_ext="${MIN_LEN_EXT:-1}"
    max_len_ext="${MAX_LEN_EXT:-3}"
    
    local min_len_dir max_len_dir
    min_len_dir="${MIN_LEN_DIR:-5}"
    max_len_dir="${MAX_LEN_DIR:-7}"

    # Квадратные скобки позволяют искать имена, собранные из введённых букв
    # в разрешённом диапазоне длины, а дата фиксирует хвост имени.
    mask_file=".*/[${file_chars}]{$min_len_file,$max_len_file}_${date}\.[${ext_chars}]{$min_len_ext,$max_len_ext}"
    mask_dir=".*/[${dir_chars}]{$min_len_dir,$max_len_dir}_${date}"

    start
    print_start_info "$START_TIME" "$FREE_BEFORE_MB" "по маске имени"
    print_params_clear_by_mask "$dir_chars" "$file_pattern" "$size_raw" \
                                "$min_len_dir" "$max_len_dir" \
                                "$min_len_file" "$max_len_file" \
                                "$min_len_ext" "$max_len_ext" \
                                "$mask_file" "$mask_dir"


    while IFS= read -r file; do
        delete_file "$file"
    done < <(find_targets \
                        "mask" \
                        f \
                        "$mask_file" \
                        "${size_digits}")

    while IFS= read -r dir; do
        delete_dir "$dir"
    done < <(find_targets \
                        "mask" \
                        d \
                        "$mask_dir")
}

# Удаляет файл и увеличивает счётчик удалённых файлов.
# Аргументы:
#   $1 — путь к файлу.
delete_file() {
    local file_del="$1"

    if rm -f -- "$file_del"; then
            # echo "Удалён файл: $file_del"
            (( DELETE_FILES++ ))
    else
        echo -e "${RED}${BOLD}Не удалось удалить файл:${NC} ${WHITE}$file_del${NC}"
        STOP_REASON="Не удалось очитсить все данные"
        (( SKIPPED_FILES++ ))
    fi
}

# Удаляет пустую директорию через rmdir.
# Аргументы:
#   $1 — путь к директории.
# Побочные эффекты:
#   увеличивает DELETE_DIRS при успехе или SKIPPED_DIR при ошибке.
delete_dir() {
    local dir_del="$1"

    if rmdir -- "$dir_del" 2>/dev/null; then
        # echo "Удалена папка: $dir_del"
        (( DELETE_DIRS++ ))
    else
        echo -e "${YELLOW}${BOLD}Пропущена папка:${NC} ${WHITE}$dir_del${NC}"
        STOP_REASON="Не удалось очитсить все данные"
        (( SKIPPED_DIR++ ))
    fi
}

# Ищет файлы или директории для очистки.
# Аргументы:
#   $1 — метод поиска: "mask" или "date";
#   $2 — тип объекта для find: "f" или "d";
#   $3 — регулярное выражение при method=mask
#        или name-маска при method=date;
#   $4 — размер в Mb при method=mask
#        или файл начала диапазона при method=date;
#   $5 — файл конца диапазона при method=date.
# Вывод:
#   печатает найденные пути по одному на строку.
find_targets() {
    local method="$1"
    local type="$2"

    if [[ "$method" == "mask" ]]; then
        local regex="$3"
        local size="$4"
    fi

    if [[ "$method" == "date" ]]; then
        local create_date="${3:-'*_080526'}"
        local day_start="${4:-'/tmp/daystart'}"
        local day_end="${5:-'/tmp/dayend'}"
    fi
    
    local depth=()
    local prune_args=()
    local add_regex=()
    local size_filter=()
    local add_name=()
    local add_newer=()
    
    if [[ "$method" == "mask" ]]; then
        add_regex=(-regex "$regex")

        # Директории ищем с -depth, чтобы вложенные пути шли раньше родительских.
        if [[ "$type" == "d" ]]; then
            depth=(-depth)
        elif [[ "$type" == "f" && -n "$size" ]]; then
            size_filter=(-size "${size}M")
        fi
    fi

    if [[ "$method" == "date" ]]; then
        add_name=(-name "$create_date")

        if [[ "$type" == "f" ]]; then
            add_newer=(-newer "$day_start" ! -newer "$day_end")
        fi
        
        if [[ "$type" == "d" ]]; then
            add_newer=(-newer "$day_start")
            depth=(-depth)
        fi
    fi
    
    for p in "${EXCLUDE[@]}"; do
        prune_args+=( -path "$p" -o )
    done

    # Последний -o нужен только между шаблонами исключений.
    unset 'prune_args[${#prune_args[@]}-1]'
    
    find / \
        "${depth[@]}" \
        -regextype posix-extended \
        \( "${prune_args[@]}" \) -prune -o \
        -type "$type" \
        "${add_regex[@]}" \
        "${size_filter[@]}" \
        "${add_name[@]}" \
        "${add_newer[@]}" \
        -print \
        2>/dev/null
}

# Возвращает текущее время в человекочитаемом формате.
# Формат вывода: HH:MM:SS DD.MM.YYYY.
time_human() {
    date +"%H:%M:%S %d.%m.%Y"
}

# Преобразует дату и время в формат для touch -t.
# Аргументы:
#   $1 — дата в формате DD.MM.YYYY;
#   $2 — время в формате HH:MM.
# Вывод:
#   строка YYYYMMDDHHMM.
convert_datetime_for_touch() {
    local day="${1:-"08.05.2026"}"
    local time="${2:-"22:00"}"

    local dd="${day:0:2}"
    local mm="${day:3:2}"
    local yyyy="${day:6:4}"
    local hhmm="${time:0:2}${time:3:2}"

    echo "${yyyy}${mm}${dd}${hhmm}"

}

# Преобразует дату из формата DD.MM.YYYY в DDMMYY.
# Используется для поиска даты в имени файла или директории.
convert_date_for_mask() {
    local day="${1:-"08.05.2026"}"

    local dd="${day:0:2}"
    local mm="${day:3:2}"
    local yyyy="${day:6:4}"

    echo "${dd}${mm}${yyyy:2:2}"
}

# Печатает общий заголовок старта очистки.
# Аргументы:
#   $1 — время запуска;
#   $2 — свободное место до запуска в Mb;
#   $3 — текстовое название режима очистки.
print_start_info() {
    local start_time=$1
    local free_before_mb=$2
    local method=$3

    echo
    echo -e "${CYAN}${BOLD}======================================================${NC}"
    echo -e "${GREEN}${BOLD}Старт скрипта очистки${NC}"
    echo -e "${CYAN}${BOLD}======================================================${NC}"
    echo -e "  ${GRAY}•${NC} Время запуска:                 ${WHITE}$start_time${NC}"
    echo -e "  ${GRAY}•${NC} Свободное место до запуска:    ${GREEN}${free_before_mb} Mb${NC}"
    echo -e "  ${GRAY}•${NC} Режим очистки:                 ${YELLOW}${method}${NC}"
}

# Печатает параметры режима очистки по лог-файлу.
# Аргументы:
#   $1 — путь к лог-файлу.
print_params_clear_by_log() {
    local log_file="$1"

    echo -e "${GREEN}${BOLD}Параметры очистки:${NC}"
    echo -e "  ${GRAY}•${NC} Лог-файл:                 ${WHITE}$log_file${NC}"
    echo -e "${CYAN}${BOLD}======================================================${NC}"
}

# Печатает параметры режима очистки по дате и времени.
# Аргументы:
#   $1 — дата очистки;
#   $2 — время начала;
#   $3 — время окончания;
#   $4 — маска файлов;
#   $5 — маска директорий.
print_params_clear_by_datetime() {
    local date="$1"
    local start_time="$2"
    local end_time="$3"
    local mask_file="$4"
    local mask_dir="$5"

    local time="$start_time - $end_time"

    echo
    echo -e "${GREEN}${BOLD}Параметры очистки:${NC}"
    echo -e "  ${GRAY}•${NC} Дата очистки:                 ${WHITE}$date${NC}"
    echo -e "  ${GRAY}•${NC} Временной диапазон:           ${WHITE}$time${NC}"
    echo -e "  ${GRAY}•${NC} Маска файлов:                 ${WHITE}$mask_file${NC}"
    echo -e "  ${GRAY}•${NC} Маска директорий:             ${WHITE}$mask_dir${NC}"
    echo -e "${CYAN}${BOLD}======================================================${NC}"
    echo
}

# Печатает параметры режима очистки по маске имени.
# Аргументы:
#   $1  — буквы директорий;
#   $2  — шаблон имени файла file.ext;
#   $3  — исходный размер файла;
#   $4-$9 — ограничения длины имени и расширения;
#   $10 — итоговая маска файлов;
#   $11 — итоговая маска директорий.
print_params_clear_by_mask() {
    local dir_chars="$1"
    local file_pattern="$2"
    local size_raw="$3"
    local min_len_dir="$4"
    local max_len_dir="$5"
    local min_len_file="$6"
    local max_len_file="$7"
    local min_len_ext="$8"
    local max_len_ext="$9"
    local mask_file="${10}"
    local mask_dir="${11}"

    echo
    echo -e "${GREEN}${BOLD}Параметры очистки:${NC}"
    echo -e "  ${GRAY}•${NC} Режим очистки:                  ${WHITE}по маске имени${NC}"
    echo -e "  ${GRAY}•${NC} Буквы директорий:              ${WHITE}$dir_chars${NC}"
    echo -e "  ${GRAY}•${NC} Шаблон файла:                  ${WHITE}$file_pattern${NC}"
    echo -e "  ${GRAY}•${NC} Размер файлов:                 ${WHITE}$size_raw${NC}"
    echo -e "  ${GRAY}•${NC} Длина имени директории:        ${WHITE}${min_len_dir}-${max_len_dir}${NC}"
    echo -e "  ${GRAY}•${NC} Длина имени файла:             ${WHITE}${min_len_file}-${max_len_file}${NC}"
    echo -e "  ${GRAY}•${NC} Длина расширения файла:        ${WHITE}${min_len_ext}-${max_len_ext}${NC}"
    echo -e "  ${GRAY}•${NC} Маска файлов:                  ${WHITE}$mask_file${NC}"
    echo -e "  ${GRAY}•${NC} Маска директорий:              ${WHITE}$mask_dir${NC}"
    echo -e "${CYAN}${BOLD}======================================================${NC}"
}

# Выводит итоговый отчёт после завершения работы скрипта.
# Аргументы:
#   $1 — unix-время старта;
#   $2 — unix-время завершения;
#   $3 — свободное место до очистки в Mb;
#   $4 — свободное место после очистки в Mb;
#   $5 — количество удалённых директорий;
#   $6 — количество удалённых файлов;
#   $7 — причина или статус остановки;
#   $8 — количество пропущенных директорий;
#   $9 — количество пропущенных файлов.
print_finish_report() {
    local start_time_sec="$1"
    local end_time_sec="$2"
    local free_before_mb="$3"
    local free_after_mb="$4"
    local deleted_dirs="$5"
    local deleted_files="$6"
    local stop_reason="$7"
    local skipped_dirs="$8"
    local skipped_files="$9"

    local end_time changed_mb process_sec

    end_time=$(time_human)
    changed_mb=$(( free_after_mb - free_before_mb ))
    process_sec=$(( end_time_sec - start_time_sec ))

    echo
    echo -e "${MAGENTA}${BOLD}======================================================${NC}"
    echo -e "${WHITE}${BOLD}Итоговый отчёт${NC}"
    echo -e "${MAGENTA}${BOLD}======================================================${NC}"
    echo -e "  ${GRAY}•${NC} Статус завершения:             ${YELLOW}$stop_reason${NC}"
    echo -e "  ${GRAY}•${NC} Завершение скрипта:            ${WHITE}$end_time${NC}"
    echo
    echo -e "${BLUE}${BOLD}Результат очистки:${NC}"
    echo -e "  ${GRAY}•${NC} Удалено файлов:                ${GREEN}$deleted_files${NC}"
    echo -e "  ${GRAY}•${NC} Удалено директорий:            ${GREEN}$deleted_dirs${NC}"
    echo -e "  ${GRAY}•${NC} Пропущено файлов:              ${YELLOW}$skipped_files${NC}"
    echo -e "  ${GRAY}•${NC} Пропущено директорий:          ${YELLOW}$skipped_dirs${NC}"
    echo
    echo -e "${BLUE}${BOLD}Использование диска:${NC}"
    echo -e "  ${GRAY}•${NC} Свободное место после запуска: ${GREEN}${free_after_mb} Mb${NC}"
    echo -e "  ${GRAY}•${NC} Освобождено места:             ${CYAN}${changed_mb} Mb${NC}"
    echo
    echo -e "  ${GRAY}•${NC} Время выполнения:              ${MAGENTA}$(time_ui "$process_sec")${NC}"
    echo    "Для поиска оставшихся файлов и папок выполните:"
    echo    'sudo find / -name "*_DDMMYY*" 2>/dev/null'
    echo -e "${MAGENTA}${BOLD}======================================================${NC}"
    echo
}

# Печатает короткую справку перед интерактивной очисткой по маске.
print_info_clean_by_mask() {
    echo
    echo -e "${CYAN}${BOLD}========================================${NC}"
    echo -e "${GREEN}${BOLD}Очистка файлов и директорий по маске${NC}"
    echo -e "${CYAN}${BOLD}========================================${NC}"
    echo -e "${BLUE}${BOLD}Примеры имён:${NC}"
    echo -e "  ${GRAY}•${NC} Директория: ${WHITE}aaaaz_080526${NC}"
    echo -e "  ${GRAY}•${NC} Файл:       ${WHITE}aaaaz_080526.az${NC}"
    echo
}

# Печатает цветной интерактивный запрос и читает ответ пользователя.
# Аргументы:
#   $1 — текст вопроса;
#   $2 — имя переменной, куда нужно записать ввод.
prompt_input() {
    local message="$1"
    local var_name="$2"

    echo -ne "${message} "
    read -r "$var_name"
}

# Форматирует длительность в секундах для вывода пользователю.
# Аргументы:
#   $1 — количество секунд.
# Вывод:
#   строка вида "N ч N мин N сек".
time_ui() {
    local sec=$1
    local hours minutes seconds

    hours=$(( sec / 3600 ))
    minutes=$(( (sec % 3600) / 60 ))
    seconds=$(( sec % 60 ))
    
    echo "$hours ч $minutes мин $seconds сек"
}

# Возвращает текущую дату в формате DD.MM.YYYY.
tdate() {
    date +"%d.%m.%Y"
}

# Инициализирует время запуска и свободное место до очистки.
# Заполняет глобальные переменные START_TIME_SEC, START_TIME и FREE_BEFORE_MB.
start() {
    START_TIME_SEC=$(date +%s)
    START_TIME=$(time_human)
    FREE_BEFORE_MB=$(df -m "$FIRST_DIR" | awk 'NR==2 {print $4}')
}

search_logs() {
    local logs num selected_log array_index i

    logs=( $LOG_PATTERN )
    # for log in "${logs[@]}"; do
    #     echo "$log"
    #     done

    for (( i=0; i<"${#logs[@]}"; i++ )); do
        num=$(( i + 1 ))
        echo "$num) $(basename "${logs[i]}")" >&2
    done

    read -r -p "Выберите лог: " array_index

    validate_positive_integer "$array_index" "${#logs[@]}"

    selected_log="${logs[$(( array_index - 1 ))]}"
    echo "$selected_log"
}   