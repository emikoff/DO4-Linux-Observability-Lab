#!/usr/bin/env bash

# Генерирует имя из заданных символов.
# Каждый символ из chars используется минимум один раз.
# Итоговая длина находится в диапазоне min_len..max_len.
generate_name() {
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

# Создаёт цепочку вложенных папок в target_path.
# Для каждой созданной папки генерирует уникальное имя с датой,
# переходит внутрь неё и создаёт заданное количество файлов.
create_tree_and_file() {
    # Параметры для самой функции (папки)
    local target_path="$1"
    local f_count="$2"
    local d_chars="$3"
    local min_d="$4"
    local max_d="$5"

    # Параметры, которые мы просто "пробрасываем" дальше в create_file
    local files_in_dir="$6"
    local f_chars="$7"
    local f_ext="$8"
    local f_size="$9"
    local min_f="${10}"
    local max_f="${11}"

    # Переходим в начальную точку
    cd "$target_path" || exit 1

    local i
    for (( i=0; i<f_count; i++ )); do
        df_available "$f_size" # Проверка места

        local folder_name=""
        local dir_with_date=""
        local attempts=0

        while true; do
            ((attempts++))
            if (( attempts > 10000 )); then
                echo "Ошибка: не удалось создать уникальное имя папки после 10000 попыток."
                exit 1
            fi

            folder_name=$(generate_name "$d_chars" "$min_d" "$max_d")
            dir_with_date="${folder_name}_${TDATE}"

            if ! check_entity_exists "$dir_with_date"; then
                break
            fi
        done

        if mkdir "$dir_with_date"; then
            cd "$dir_with_date" || {
                echo "Ошибка: не удалось перейти в папку: $dir_with_date"
                exit 1
            }

            (( CREATED_DIRS++ ))
            write_to_log "$(pwd)" "dir"

            create_file "$files_in_dir" "$f_chars" "$f_ext" "$f_size" "$min_f" "$max_f"
        else
            echo "Ошибка: не удалось создать папку: $dir_with_date"
            exit 1
        fi
    done
}

# Генерирует имя файла с датой и расширением.
# Основа имени создаётся через generate_name.
# Расширение добавляется только если ext_chars не пустой.
generate_file_name() {
    local chars_name="$1"
    local ext_chars="$2"
    local min_f="$3"
    local max_f="$4"

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

# Создаёт заданное количество файлов в текущей папке.
# Для каждого файла генерирует уникальное имя,
# создаёт файл нужного размера и записывает данные в лог.
create_file() {
    local total_files=$1
    local chars_name=$2
    local ext_chars=$3
    local f_size=$4
    local min_len=$5   # Теперь передаем извне
    local max_len=$6   # Теперь передаем извне

    local i
    for (( i=0; i<total_files; i++ )); do
        df_available "$f_size" # Проверка места

        local file_name=""
        local attempts=0

        # Добавляем цикл перегенерации для файлов
        while true; do
            ((attempts++))
            if (( attempts > 10000 )); then
                echo "Ошибка: не удалось создать уникальное имя файла после 10000 попыток."
                exit 1
            fi

            file_name="$(generate_file_name "$chars_name" "$ext_chars" "$min_len" "$max_len")"

            if ! check_entity_exists "$file_name"; then
                break
            fi
        done

        # Создание файла
        if dd if=/dev/zero of="$file_name" bs="${f_size}k" count=1 2>/dev/null; then
            local full_file_path
            full_file_path=$(readlink -f "$file_name")

            local actual_size
            local human_size
            actual_size=$(stat -c%s "$full_file_path")
            human_size=$(define_unit $actual_size)
            (( CREATED_FILES++ ))

            write_to_log "$full_file_path" "file" "$actual_size" "$human_size"
        else
            echo "Ошибка: не удалось создать файл: $file_name"
            exit 1
        fi
    done
}

# Записывает информацию о созданной папке или файле в лог.
# Формат записи: дата, тип объекта, путь, размер в байтах, размер в человекочитаемом виде.
write_to_log() {
    local entry_path=$1
    local type=$2
    local entry_size=${3:-"-"}
    local entry_size_kb=${4:-"-"}
    local current_date
    current_date=$(date +"%Y-%m-%dT%H:%M:%S")

    # Проверяем, существует ли папка перед записью
    validate_path_exists "$entry_path"
    echo -e "$current_date\t$type\t$entry_path\t$entry_size\t$entry_size_kb" >> "$LOG_FILE"
}

# Проверяет, останется ли на корневом разделе не менее 1 GB.
# Если после создания файла свободного места будет меньше лимита,
# завершает выполнение скрипта с ошибкой.
df_available() {
    local file_size_kb=${1:-0}
    local limit_kb=1048576  # 1 GB в килобайтах

    # Получаем свободное место в КБ
    local available
    available=$(df -k / | awk 'NR==2 {print $4}')

    # Проверяем: (остаток - размер будущего файла) < 1 ГБ
    if (( (available - file_size_kb) <= limit_kb )); then
        local current_gb
        current_gb=$(echo "scale=2; $available / 1024 / 1024" | bc)
        echo "Ошибка: недостаточно места."
        echo "Осталось: $current_gb GB. Создание файла весом ${file_size_kb}KB приведет к остатку менее 1GB."
        exit 1
    fi
}

# Проверяет существование файла или папки.
# Возвращает 0, если объект существует.
# Возвращает 1, если объекта нет.
check_entity_exists() {
    if [[ -e "$1" ]]; then
        return 0 # Объект существует
    else
        return 1 # Объекта нет
    fi
}

# Выводит стартовую информацию о параметрах запуска скрипта.
# Используется для контроля перед созданием папок и файлов.
print_start_info() {
    echo
    echo -e "${CYAN}${BOLD}==============================================================${NC}"
    echo -e "${GREEN}${BOLD}Запуск генератора файлов${NC}"
    echo -e "${CYAN}${BOLD}==============================================================${NC}"
    echo -e "${BLUE}${BOLD}Параметры запуска:${NC}"
    echo -e "  ${GRAY}•${NC} Начальный путь:                    ${YELLOW}$1${NC}"
    echo -e "  ${GRAY}•${NC} Количество вложенных папок:        ${YELLOW}$2${NC}"
    echo -e "  ${GRAY}•${NC} Символы в названии папок:          ${YELLOW}$3${NC}"
    echo -e "  ${GRAY}•${NC} Файлов в каждой папке:             ${YELLOW}$4${NC}"
    echo -e "  ${GRAY}•${NC} Символы имени файла и расширения:  ${YELLOW}$5${NC}"
    echo -e "  ${GRAY}•${NC} Размер файлов:                     ${YELLOW}$6${NC}"
    echo -e "  ${GRAY}•${NC} Суффикс даты:                      ${MAGENTA}${TDATE}${NC}"
    echo -e "${CYAN}${BOLD}==============================================================${NC}"
    echo
}

# Выводит итоговый отчёт после завершения работы скрипта.
# Показывает количество созданных папок и файлов.
print_finish_report() {
    echo
    echo -e "${MAGENTA}${BOLD}==============================================================${NC}"
    echo -e "${WHITE}${BOLD}Сценарий успешно завершён${NC}"
    echo -e "${MAGENTA}${BOLD}==============================================================${NC}"
    echo -e "${BLUE}${BOLD}Результаты выполнения:${NC}"
    echo -e "  ${GRAY}•${NC} Создано папок:                     ${GREEN}${CREATED_DIRS}${NC}"
    echo -e "  ${GRAY}•${NC} Создано файлов:                    ${GREEN}${CREATED_FILES}${NC}"
    echo -e "${MAGENTA}${BOLD}==============================================================${NC}"
    echo
}

# Преобразует размер в байтах в человекочитаемый формат.
# Использует единицы b, kb, mb, gb.
define_unit() {
    local check_size="$1"
    local units=(b kb mb gb)
    local unit_index=0

    while (( check_size >= 1024 && unit_index < 3 )); do
        check_size=$(( check_size / 1024 ))
        (( unit_index++ ))
    done

    echo "${check_size}${units[$unit_index]}"
}
