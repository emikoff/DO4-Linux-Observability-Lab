#!/usr/bin/env bash

# Генерирует имя из заданных символов.
# Каждый символ из chars используется минимум один раз.
# Итоговая длина находится в диапазоне min_len..max_len.
generate_name() {
    # echo "start generate_name"
    local chars="$1"
    local min_len="$2"
    local max_len="$3"

    local len_chars=${#chars}
    local result=""



    # Если символов больше минимальной длины,
    # минимальная длина поднимается до длины chars
    if (( len_chars > min_len )); then
        min_len=$len_chars
    fi

    # Защита: max_len не может быть меньше min_len
    if (( max_len < min_len )); then
        max_len=$min_len
    fi

    # Случайная добавка считается ПОСЛЕ корректировки min_len
    local random_extra=$(( RANDOM % (max_len - min_len + 1) ))

    local total_add=$(( min_len + random_extra - len_chars ))
    local i
    local add
    local repeat

    for (( i=0; i<len_chars; i++ )); do
        if (( i < len_chars - 1 )); then
            if (( total_add > 0 )); then
                add=$(( RANDOM % (total_add + 1) ))
                total_add=$(( total_add - add ))
            else
                add=0
            fi
        else
            add=$total_add
        fi

        repeat=$(( add + 1 ))
        local j
        for (( j=0; j<repeat; j++ )); do
            result="${result}${chars:$i:1}"
        done
    done

    echo "$result"
}

# Генерирует имя файла с датой и расширением.
# Основа имени создаётся через generate_name.
# Расширение добавляется только если ext_chars не пустой.
generate_file_name() {
    # echo "start generate_file_name"
    local chars_name="$1"
    local ext_chars="$2"
    local min_f="$MIN_LEN_FILE"
    local max_f="$MAX_LEN_FILE"

    # 1. Генерируем основу имени (например, "aaaz")
    local name_base
    name_base=$(generate_name "$chars_name" "$min_f" "$max_f")

    # 2. Собираем: имя_дата
    local result="${name_base}_${TDATE}"

    # 3. Если есть символы расширения, генерируем расширение (от 1 до 3 символов)
    if [[ -n "$ext_chars" ]]; then
        local ext_base
        ext_base=$(generate_name "$ext_chars" 1 3)
        result="${result}.${ext_base}"
    fi

    echo "$result"
}

# Генерирует полный путь для новой директории.
# Базовый путь выбирается случайно из DIRS_FOR_WRITE.
generate_path_dir_name() {
    # echo "start generate_path_dir_name"
    local target_path
    target_path=$(random_path)
    local d_chars="$1"
    local min_d="$MIN_LEN_DIR"
    local max_d="$MAX_LEN_DIR"
    local dir_name=""
    local full_dir_path=""
    local attempts=0

    while true; do
        ((attempts++))
        if (( attempts > MAX_ATTEMPTS )); then
            # echo "Ошибка: не удалось создать уникальное имя папки после $MAX_ATTEMPTS попыток." >&2
            (( SKIPPED_DIR_ATTEMPTS++ ))
            return 1
        fi

        dir_name=$(generate_name "$d_chars" "$min_d" "$max_d")
        full_dir_path="${target_path}/${dir_name}_${TDATE}"

        if ! check_entity_exists "$full_dir_path"; then
            echo "$full_dir_path"
            break
        fi
    done
}

# Создаёт папки в случайных доступных директориях.
# Для каждой папки генерирует уникальное имя с датой,
# после создания заполняет её случайным количеством файлов.
create_path_and_file() {
    # echo "start create_path_and_file"
    # Параметры для самой функции (папки)
    # local f_count="$2"
    local d_chars="$1"

    # Параметры, которые мы просто "пробрасываем" дальше в create_file
    local files_in_dir=0
    local f_chars="$2"
    local e_chars="$3"
    local f_size="$4"

    local full_path=""
    local error_path=0
       
    while (( CREATED_DIRS < MAX_DIRS )); do

        if (( error_path >= 10 )); then
            init_dirs_for_write
            error_path=0
        fi

        if ! df_available "$(( f_size * 1024 ))"; then
            STOP_REASON="Достигнут лимит свободного места"
            break
        fi

        # Создаем путь
        if ! full_path=$(generate_path_dir_name "$d_chars"); then
            (( error_path++ ))
            continue
        fi

        if [[ -z "$full_path" ]]; then
            (( error_path++ ))
            continue
        fi

        # echo "$full_path"
        if mkdir -p "$full_path"; then
            if ! cd "$full_path"; then
                (( error_path++ ))
                echo "Ошибка: не удалось перейти в папку: $full_path" >&2
                continue
            fi

            error_path=0
            (( CREATED_DIRS++ ))
            write_to_log "$(pwd)" "dir"

            files_in_dir=$(( (RANDOM % FILES_PER_DIR) + 1 ))
            if ! create_file "$files_in_dir" "$f_chars" "$e_chars" "$f_size"; then
                break
            fi
        else
            (( error_path++ ))
            echo "Ошибка: не удалось создать путь: $full_path" >&2
            continue
        fi
    done
}

# Создаёт заданное количество файлов в текущей папке.
# Для каждого файла генерирует уникальное имя,
# создаёт файл нужного размера и записывает данные в лог.
create_file() {
    # echo "start create_file"
    local total_files=$1
    local chars_name=$2
    local ext_chars=$3
    local f_size_mb=$4
    
    local f_size_kb=$(( $f_size_mb*1024 ))
    local i
    for (( i=0; i<total_files; i++ )); do
        if ! df_available "$f_size_kb"; then
            STOP_REASON="Достигнут лимит свободного места"
            return 1
        fi

        local file_name=""
        local attempts=0

        # Добавляем цикл перегенерации для файлов
        while true; do
            ((attempts++))
            if (( attempts > MAX_ATTEMPTS )); then
                # echo "Ошибка: не удалось создать уникальное имя файла после $MAX_ATTEMPTS попыток." >&2
                # exit 1
                (( SKIPPED_FILE_ATTEMPTS++ ))
                return 1
            fi

            file_name="$(generate_file_name "$chars_name" "$ext_chars")"

            if ! check_entity_exists "$file_name"; then
                break
            fi
        done

        # Создание файла
        if dd if=/dev/zero of="$file_name" bs="${f_size_mb}M" count=1 2>/dev/null; then
            local full_file_path
            full_file_path=$(readlink -f "$file_name")

            # echo "$file_name"
            # echo "$full_file_path"

            local actual_size
            local human_size
            actual_size=$(stat -c%s "$full_file_path")
            human_size=$(define_unit $actual_size)
            (( CREATED_FILES++ ))

            # echo "a_size=$actual_size"
            # echo "h_size=$human_size"
            write_to_log "$full_file_path" "file" "$actual_size" "$human_size"
        else
            echo "Ошибка: не удалось создать файл: $file_name" >&2
            exit 1
        fi
    done
}

# Записывает информацию о созданной папке или файле в лог.
# Формат записи: дата, тип объекта, путь, размер в байтах, размер в человекочитаемом виде.
write_to_log() {
    # echo "start write_to_log"
    local entry_path=$1
    local type=$2
    local entry_size=${3:-"-"}
    local entry_size_human=${4:-"-"}
    local current_date
    current_date=$(date +"%Y-%m-%dT%H:%M:%S")

    # Проверяем, существует ли папка перед записью
    validate_path_exists "$entry_path"
    printf "%s\t%s\t%s\t%s\t%s\n" \
        "$current_date" "$type" "$entry_path" "$entry_size" "$entry_size_human" >> "$LOG_FILE"
}

# Проверяет, останется ли на корневом разделе не менее 1 GB.
# Если после создания файла свободного места будет меньше лимита,
# завершает выполнение скрипта с ошибкой.
df_available() {
    local file_size_kb="${1:-0}"
    local limit_kb=1048576  # 1 GiB = 1024 * 1024 KiB

    local available_kb
    available_kb=$(df -k / | awk 'NR==2 {print $4}')

    local after_create_kb=$(( available_kb - file_size_kb ))

    if (( after_create_kb < limit_kb )); then
        echo "Внимание: недостаточно места." >&2
        echo "Свободно сейчас: $(( available_kb / 1024 )) MiB." >&2
        echo "Размер будущего файла: $(( file_size_kb / 1024 )) MiB." >&2
        echo "Останется после создания: $(( after_create_kb / 1024 )) MiB." >&2
        echo "Минимально допустимо: $(( limit_kb / 1024 )) MiB." >&2
        return 1
    fi
}

# Проверяет существование файла или папки.
# Возвращает 0, если объект существует.
# Возвращает 1, если объекта нет.
check_entity_exists() {
    # echo "start check_entiry_wxists"
    if [[ -e "$1" ]]; then
        return 0 # Объект существует
    else
        return 1 # Объекта нет
    fi
}

# Выводит стартовую информацию о параметрах запуска скрипта.
# Используется для контроля перед созданием папок и файлов.
print_start_info() {
    local latters_dirs=$1
    local latters_files=$2
    local file_size=$3
    local start_time=$4
    local tdate=$5
    local max_dirs=$6
    local files_per_dir=$7
    local first_dir=$8
    local free_before_mb=$9

    echo
    echo -e "${CYAN}${BOLD}========================================================${NC}"
    echo -e "${GREEN}${BOLD}Старт скрипта:${NC} ${WHITE}$start_time${NC}"
    echo -e "${CYAN}${BOLD}========================================================${NC}"

    echo -e "${BLUE}${BOLD}Параметры запуска:${NC}"
    echo -e "  ${GRAY}•${NC} Буквы папок:                    ${YELLOW}$latters_dirs${NC}"
    echo -e "  ${GRAY}•${NC} Буквы имени файла и расширения: ${YELLOW}$latters_files${NC}"
    echo -e "  ${GRAY}•${NC} Размер файла:                   ${YELLOW}$file_size${NC}"
    echo -e "  ${GRAY}•${NC} Дата в именах:                  ${YELLOW}$tdate${NC}"
    echo -e "  ${GRAY}•${NC} Максимум папок:                 ${YELLOW}$max_dirs${NC}"
    echo -e "  ${GRAY}•${NC} Максимум файлов в папке:        ${YELLOW}$files_per_dir${NC}"
    echo -e "  ${GRAY}•${NC} Начальная директория:           ${YELLOW}$first_dir${NC}"
    echo -e "  ${GRAY}•${NC} Свободное место до запуска:     ${GREEN}${free_before_mb} Mb${NC}"
    echo
}

# Выводит итоговый отчёт после завершения работы скрипта.
# Показывает количество созданных папок и файлов.
print_finish_report() {
    local end_time="$1"
    local process_sec="$2"
    local free_after_mb="$3"
    local used_mb="$4"
    local created_dirs="$5"
    local created_files="$6"
    local stop_reason="$7"
    local retry_dirs="$8"
    local retry_files="$9"

    echo
    echo -e "${MAGENTA}${BOLD}========================================================${NC}"
    echo -e "${WHITE}${BOLD}Итоговый отчёт${NC}"
    echo -e "${MAGENTA}${BOLD}========================================================${NC}"

    echo -e "  ${GRAY}•${NC} Статус:                          ${YELLOW}$stop_reason${NC}"
    echo -e "  ${GRAY}•${NC} Завершение скрипта:              ${WHITE}$end_time${NC}"
    echo -e "  ${GRAY}•${NC} Создано папок:                   ${GREEN}$created_dirs${NC}"
    echo -e "  ${GRAY}•${NC} Повторных генераций имени папки: ${YELLOW}$retry_dirs${NC}"
    echo -e "  ${GRAY}•${NC} Повторных попыток имени файла:   ${YELLOW}$retry_files${NC}"
    echo -e "  ${GRAY}•${NC} Создано файлов:                  ${GREEN}$created_files${NC}"
    echo -e "  ${GRAY}•${NC} Свободное место после запуска:   ${GREEN}${free_after_mb} Mb${NC}"
    echo -e "  ${GRAY}•${NC} Израсходовано места:             ${RED}${used_mb} Mb${NC}"
    echo -e "  ${GRAY}•${NC} Время выполнения:                ${CYAN}$(time_ui "$process_sec")${NC}"

    echo -e "${MAGENTA}${BOLD}========================================================${NC}"
    echo
}


# Преобразует размер в байтах в человекочитаемый формат.
# Использует единицы b, kb, mb, gb.
define_unit() {
    # echo "start devine_unit"
    local check_size="$1"
    local units=(b kb mb gb)
    local unit_index=0

    while (( check_size >= 1024 && unit_index < 3 )); do
        check_size=$(( check_size / 1024 ))
        (( unit_index++ ))
    done

    echo "${check_size}${units[$unit_index]}"
}

# Возвращает случайную директорию из списка доступных для записи.
random_path() {
    # echo "start random_path"
    local index_path
    index_path=$(( RANDOM % ${#DIRS_FOR_WRITE[@]} ))
    echo "${DIRS_FOR_WRITE[$index_path]}"
}

# Собирает список директорий, куда можно писать.
# Исключает системные пути из EXCLUDE и сохраняет результат в DIRS_FOR_WRITE.
init_dirs_for_write() {
    local prune_args=()
    
    local p=""
    for p in "${EXCLUDE[@]}"; do
        prune_args+=( -path "$p" -o )
    done

    unset 'prune_args[${#prune_args[@]}-1]'

    mapfile -t DIRS_FOR_WRITE < <(
        find "$FIRST_DIR" \( "${prune_args[@]}" \) -prune -o -type d -writable -print 2>/dev/null
    )

    if (( ${#DIRS_FOR_WRITE[@]}==0 )); then
        echo "Ошибка: список путй пуст" >&2
        exit 1
    fi
}

# Возвращает текущее время в формате для пользовательского отчёта.
time_human() {
    echo "$(date +"%H:%M:%S %d.%m.%Y")"
}

# Возвращает текущее Unix-время в секундах.
time_sec() {
    echo "$(date +"%s")"
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

# Возвращает свободное место в байтах для указанной директории.
df_free() {
    local dir=$1
    local free_bytes
    free_bytes=$(df -B1 "$dir" | awk 'NR==2 {print $4}')

    echo "$free_bytes"
}

write_summary() {
    {
        local start_time="$1"
        local end_time="$2"
        local process_sec="$3"
        local created_dirs="$4"
        local created_files="$5"
        local free_before_mb="$6"
        local free_after_mb="$7"
        local used_mb="$8"
        local stop_reason="$9"

        echo "# SUMMARY"
        echo -e "START_TIME	$start_time"
        echo -e "END_TIME	$end_time"
        echo -e "DURATION_SEC	$process_sec"
        echo -e "CREATED_DIRS	$created_dirs"
        echo -e "CREATED_FILES	$created_files"
        echo -e "FREE_BEFORE_MB	${free_before_mb}"
        echo -e "FREE_AFTER_MB	${free_after_mb}"
        echo -e "USED_MB	${used_mb}"
        echo -e "STOP_REASON	$stop_reason"
    } >> "$LOG_FILE"
}

collect_start_metrics() {
    START_TIME=$(time_human)
    START_TIME_SEC=$(date +%s)
    FREE_BEFORE_MB=$(df -m "$FIRST_DIR" | awk 'NR==2 {print $4}')
}
collect_finish_metrics() {
    END_TIME_SEC=$(date +%s)
    END_TIME=$(time_human)
    FREE_AFTER_MB=$(df -m "$FIRST_DIR" | awk 'NR==2 {print $4}')
    PROCESS_SEC=$(( END_TIME_SEC - START_TIME_SEC ))
    USED_MB=$(( FREE_BEFORE_MB - FREE_AFTER_MB ))
}
