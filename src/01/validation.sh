#!/usr/bin/env bash

# validation.sh — модуль проверки входных параметров.
# Содержит функции валидации количества аргументов, пути,
# числовых параметров, буквенных наборов, шаблона имени файла
# и размера создаваемых файлов.
#
# Файл не запускается самостоятельно.
# Подключается из main.sh после settings.sh,
# так как использует константы и ANSI-коды цветов.

show_help() {
    echo "Ожидается $LEN_ARGS аргументов:"
    echo "1) путь"
    echo "2) количество папок > 0"
    echo "3) буквы папок"
    echo "4) количество файлов > 0"
    echo "5) имя.расширение"
    echo "6) размер 1–100kb"
    echo
    echo "Пример:"
    echo "./main.sh $HOME/test_env 4 az 5 az.az 3kb"
}

# Проверка количества аргументов
# valid_len_param() {
validate_args_count() {
    if [ $# -ne "$LEN_ARGS" ]; then
        echo -e "${RED}Ошибка: ожидается $LEN_ARGS аргументов, получено $#${NC}"
        show_help
        exit 1
    fi
}

# проверяет, что путь начинается с '/'
validate_path_format() {
    local path="$1"

    if [[ "$path" != /* ]]; then
        echo -e "${RED}Ошибка: параметр должен начинаться знаком '/'.${NC}"
        show_help
        exit 1
    fi
}

# проверяет, что путь существует
validate_path_exists() {
    local path="$1"

    if [ ! -e "$path" ]; then
        echo -e "${RED}Ошибка: такой путь $path не существует.${NC}"
        exit 1
    fi
}

# проверяет, что путь является директорией
validate_path_is_directory() {
    local path="$1"

    if [ ! -d "$path" ]; then
        echo -e "${RED}Ошибка: указанный путь не является директорией: $path${NC}"
        exit 1
    fi
}

# проверяет, что есть права на запись
validate_path_writable() {
    local path="$1"

    if [ ! -w "$path" ]; then
        echo -e "${RED}Ошибка: нет прав на запись в директорию: $path${NC}"
        exit 1
    fi
}

# Общая функция проверки пути
validate_path() {
    local input_path="$1"

    validate_path_format "$input_path"
    validate_path_exists "$input_path"
    validate_path_is_directory "$input_path"
    validate_path_writable "$input_path"
}


# Проверка, что аргумент — целое число
validate_positive_integer() {
    local el="$1"

    if ! [[ "$el" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Ошибка: '$el' не является целым числом${NC}"
        show_help
        exit 1
    fi
    if (( 10#$el <= 0 )); then
        echo -e "${RED}Значение '$el' должно быть больше 0${NC}"
        show_help
        exit 1
    fi
}


# Проверяет, что строка содержит только английские буквы.
# Длину проверяет отдельная функция validate_length_range.
validate_letters() {
    local el="$1"

    if ! [[ "$el" =~ ^[a-zA-Z]+$ ]]; then
        echo -e "${RED}Ошибка: параметр должен содержать только английские буквы${NC}"
        show_help
        exit 1
    fi
}

# Проверка длины строки

validate_length_range() {
    local el="$1"
    local min_len="${2:-1}"
    local max_len="${3:-7}"


    if [ "${#el}" -lt "$min_len" ] || [ "${#el}" -gt "$max_len" ]; then
        echo -e "${RED}Ошибка: длина '$el' равна ${#el}, ожидается от $min_len до $max_len символов${NC}"
        show_help
        exit 1
    fi
}

# Проверяет базовый формат file.ext:
# - до точки есть хотя бы один символ;
# - после точки есть хотя бы один символ.
# Количество точек проверяется отдельно в validate_one_dot.
validate_file_pattern() {
    local str="$1"

    # Проверяем: минимум один символ, потом точка, потом минимум один символ
    if [[ ! "$str" =~ ^.+\..+$ ]]; then
        echo -e "${RED}Ошибка: неверный формат (нужно 'имя.расширение')${NC}"
        show_help
        exit 1
    fi
}

# Проверяет, что в строке ровно одна точка
validate_one_dot() {
    local str="$1"
    # Удаляем из строки всё, кроме точек
    local dots_only="${str//[^.]/}"

    # Проверяем длину получившейся строки
    if [[ ${#dots_only} -ne 1 ]]; then
        echo -e "${RED}Ошибка: должна быть ровно одна точка (сейчас: ${#dots_only})${NC}"
        show_help
        exit 1
    fi
}


# Проверяет формат размера
validate_size_format() {
    # размер файла
    local size_arg="${1,,}"

    if ! [[ "$size_arg" =~ ^[0-9]+(kb)$ ]]; then
        echo -e "${RED}Ошибка: некорректный формат размера '$1'${NC}"
        show_help
        exit 1
    fi
}

# Проверяет значение размера
validate_size_value() {
    local size_val="10#$1"

    # Сравниваем как целые числа
    if (( size_val <= 0 )) || (( size_val > 100 )); then
        echo -e "${RED}Ошибка: некорректный размер '$1'.${NC}"
        show_help
        exit 1
    fi
}

# Запускает все проверки параметров Part 1 в нужном порядке.
# После успешного выполнения main.sh может безопасно разбирать аргументы.
run_all_validations() {
    # 1. Проверка количества
    validate_args_count "$@"

    # 2. Проверка пути (Параметр 1)
    validate_path "$1"

    # 3. Числовые параметры (Параметры 2 и 4)
    validate_positive_integer "$2"
    validate_positive_integer "$4"

    # 4. Буквы папок (Параметр 3)
    validate_letters "$3"
    validate_length_range "$3" 1 "$MAX_LEN_DIR"

    # 5. Параметр file.ext (Параметр 5)
    validate_file_pattern "$5"
    validate_one_dot "$5"

    local file_name="${5%.*}" # всё до последней точки
    local extension="${5#*.}" # всё после первой точки
    validate_letters "$file_name"
    validate_length_range "$file_name" 1 "$MAX_LEN_FILE"
    validate_letters "$extension"
    validate_length_range "$extension" "$MIN_LEN_EXT" "$MAX_LEN_EXT"

    # 6. Размер (Параметр 6)
    local size_lower="${6,,}"
    validate_size_format "$6"
    local size_num="${size_lower%kb}"
    validate_size_value "$size_num"
}
