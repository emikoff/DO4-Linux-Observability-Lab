#!/usr/bin/env bash

# Запрашивает подтверждение и запускает установку Prometheus и Grafana.
install_prometheus_and_grafana() {
    local var

    read -rp "Подтвердите установку Prometheus и Grafana (y/n): " var
    case $var in
        y|Y|Д|д)
            if install_prometheus && install_grafana; then
                echo
                echo -e "${GREEN}Prometheus и Grafana установлены.${NC}"
                echo
                echo -e "${BLUE}Дальнейшая настройка Grafana:${NC}"
                echo -e "1. Откройте Grafana:"
                echo -e "${CYAN}http://localhost:3000${NC} или ${CYAN}http://<IP_СЕРВЕРА>:3000${NC}"
                echo
                echo -e "2. Выполните вход:"
                echo -e "   Логин: admin"
                echo -e "   Пароль: admin"
                echo
                echo -e "3. Добавьте источник данных Prometheus:"
                echo -e "   Connections -> Add new connection -> Prometheus"
                echo
                echo -e "4. Укажите URL:"
                echo -e "${CYAN}http://localhost:9090${NC}"
                echo
                echo -e "5. Нажмите ${CYAN}Save & test${NC}"
                echo
                echo -e "${BLUE}Импорт дашбордов:${NC}"
                echo -e "1. Перейдите:"
                echo -e "   Dashboards -> New -> Import"
                echo
                echo -e "2. Выберите JSON-файлы из директории:"
                echo -e "${CYAN}./configs${NC}"
                echo
            fi
        ;;
        *) exit 0
    esac
}

# Устанавливает Prometheus и node_exporter, запускает сервисы
# и применяет локальный prometheus.yml, если он есть.
install_prometheus() {
    echo -e "${BLUE}Установка Prometheus и Node Exporter...${NC}"
    if ! check_installation prometheus || ! check_installation prometheus-node-exporter; then
        sudo apt update -y
        sudo apt install prometheus prometheus-node-exporter -y
        if ! check_installation prometheus || ! check_installation prometheus-node-exporter; then
            echo -e "${RED}Ошибка${NC}: Не удалось установить Prometheus"
            exit 1
        fi
    fi
    
    if ! check_run prometheus || ! check_run prometheus-node-exporter; then
        sudo systemctl enable --now prometheus
        sudo systemctl enable --now prometheus-node-exporter
        if ! check_run prometheus || ! check_run prometheus-node-exporter; then
            echo -e "${RED}Ошибка${NC}: Не удалось запустить Prometheus"
            exit 1
        fi
    fi

    if [[ -f "$SCRIPT_DIR/configs/prometheus.yml" ]]; then
        sudo cp "$SCRIPT_DIR/configs/prometheus.yml" /etc/prometheus/prometheus.yml

        sudo systemctl restart prometheus

        echo -e "${GREEN}Конфигурация Prometheus обновлена${NC}"
    else
        echo -e "${RED}Ошибка${NC}: configs/prometheus.yml не найден"
        exit 1
    fi
    
    echo -e "${GREEN}Prometheus установлен и запущен${NC}"
}

# Устанавливает Grafana из официального репозитория и запускает сервис.
install_grafana() {
    echo -e "${BLUE}Установка Grafana...${NC}"
    if ! check_installation grafana; then
        # Install the prerequisite packages:
        sudo apt-get install -y apt-transport-https wget gnupg
        
        # Import the GPG key:
        sudo mkdir -p /etc/apt/keyrings
        sudo wget -O /etc/apt/keyrings/grafana.asc https://apt.grafana.com/gpg-full.key
        sudo chmod 644 /etc/apt/keyrings/grafana.asc
        
        # To add a repository for stable releases, runё the following command:
        echo "deb [signed-by=/etc/apt/keyrings/grafana.asc] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
        
        # Run the following command to update the list of available packages:
        # Updates the list of available packages
        sudo apt-get update

        # Installs the latest OSS release:
        sudo apt-get install -y grafana

        if ! check_installation grafana; then
            echo -e "${RED}Ошибка${NC}: Не удалось установить Grafana"
            exit 1
        fi
    fi

    if ! check_run grafana-server; then
        sudo systemctl enable grafana-server
        sudo systemctl start grafana-server
        if ! check_run grafana-server; then
            echo -e "${RED}Ошибка${NC}:Не удалось запустить Grafana"
            exit 1
        fi
    fi
}

# Проверяет, установлен ли apt-пакет.
check_installation() {
    echo -e "${YELLOW}Проверка установки $1${NC}"
    
    if dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"; then
        echo -e "${GREEN}$1 установлен${NC}"
        return 0
    else
        echo -e "${YELLOW}$1 не установлен${NC}"
        return 1
    fi
}

# Проверяет, активен ли systemd-сервис.
check_run() {
    if systemctl is-active --quiet "$1"; then
        echo -e "${GREEN}Сервис $1 запущена${NC}"
        return 0
    else
        echo -e "${YELLOW}$1 не запущен${NC}"
        return 1
    fi
}

# Останавливает, отключает и удаляет указанный пакет/сервис.
remove() {
    local packages="$1"
    local services="${2:-"$1"}"
    if check_installation "$packages"; then
        sudo systemctl stop "$services"
        sudo systemctl disable "$services"
        sudo apt purge "$packages" -y
    else
        echo -e "${YELLOW}Пакет уже отсутствует${NC}"
    fi
}

# Удаляет компоненты мониторинга, stress, iperf3 и nginx.
remove_all() {
    remove prometheus
    remove grafana grafana-server
    remove prometheus-node-exporter
    sudo rm -f /etc/apt/sources.list.d/grafana.list
    sudo rm -f /etc/apt/keyrings/grafana.asc
    sudo apt remove iperf3 stress nginx -y
    sudo apt autoremove -y
    echo -e "${GREEN}Все установленные компоненты Prometheus, Grafana и stress-test удалены"${NC}
}

# Устанавливает stress, если утилита отсутствует.
ensure_stress() {
    if ! command -v stress &> /dev/null; then
        echo -e "${YELLOW}Утилита stress не найдена. Установка...${NC}"
        sudo apt update -y && sudo apt install stress -y
    fi
}

# Запускает stress с параметрами из settings.sh.
stress_test() {
    stress "${STRESS_ARGS[@]}"
}

# Запускает скрипт Part 2 для создания нагрузки на диск.
run_part2_script() {
        if [[ -f "$PART2_DIR/main.sh" ]]; then
            (cd "$PART2_DIR" && ./main.sh "${PART2_ARGS[@]}")
        else
            echo -e "${RED}Ошибка${NC}: Скрипт из Части 2 не найден"
            exit 1
        fi
}

# Запускает очистку данных через скрипт Part 3.
clear_logs() {
        if [[ -f "$PART3_DIR/main.sh" ]]; then
            (cd "$PART3_DIR" && ./main.sh 1)
        else
            echo -e "${RED}Ошибка${NC}: Скрипт очистки не найден"
            exit 1
        fi
}

# Печатает пункты интерактивного меню.
menu_info() {
    echo "1. Установить и запустить мониторинг (Prometheus + Grafana)"
    echo "2. Запустить скрипт из Части 2"
    echo "3. Очистить данные через скрипт из Части 3"
    echo "4. Запустить стресс-тест"
    echo "5. Установить и запустить nginx"
    echo "6. Запустить кастомный генератор метрик для prometheus"
    echo "7. Остановить кастомный генератор метрик для prometheus"
    echo "8. Удалить мониторинг(Grafana, Prometheus, stress_test, nginx и iperf)"
    echo "0. Выход"
}

# Обрабатывает выбранный пункт интерактивного меню.
menu() {
    local action
    read -rp "Введите номер действия (0-8): " action

    case $action in
        1)
            install_prometheus_and_grafana
            exit 0
            ;;
            
        2)
            echo -e "${BLUE} Запуск bash-скрипта из Части 2...${NC}"
            run_part2_script
            exit 0
            ;;

        3)  
            echo -e "${BLUE}Очистка по логу из Части 3...${NC}"
            clear_logs
            exit 0
            ;;
        
        4)
            echo -e "${BLUE} Подготовка к стресс-тесту...${NC}"
            ensure_stress
            echo -e "${YELLOW} Запуск стресс-теста на 10 секунд...${NC}"
            stress_test
            echo -e "${GREEN} Стресс-тест завершен.${NC}"
            exit 0
            ;;

        5) 
            ensure_nginx
            exit 0
            ;;
        
        6) 
            start_metrics_generator
            exit 0
            ;;

        7)
            stop_metrics_generator
            exit 0
            ;;

        8)
            read -rp "Вы уверены, что хотите УДАЛИТЬ все компоненты? (y/n): " confirm
            case $confirm in
                y|Y|Д|д)
                    remove_all
                    ;;
                *)
                    echo -e "${YELLOW}Удаление отменено.${NC}"
                    ;;
            esac
            exit 0
            ;;
            
        0)
            echo -e "${BLUE}Выход из программы.${NC}"
            exit 0
            ;;
            
        *)
            echo -e "${RED}Ошибка${NC}: Неверный параметр меню"
            exit 1
            ;;
    esac
}

# Устанавливает iperf3 при необходимости и запускает сервер.
ensure_iperf3() {
    if ! command -v iperf3 &> /dev/null; then
        echo -e "${YELLOW}Утилита stress не найдена. Установка...${NC}"
        sudo apt update -y && sudo apt install iperf3 -y
    fi
    iperf3 -s
}

# Устанавливает nginx и выдаёт пользователю права на каталог с метриками.
ensure_nginx() {
    if ! command -v nginx &> /dev/null; then
        echo -e "${YELLOW}Утилита stress не найдена. Установка...${NC}"
        sudo apt update -y && sudo apt install nginx -y
        sudo chown -R "$USER":"$USER" "$PART_NGINX_DIR"
    fi
}

# Печатает CPU-метрики в формате Prometheus.
# Значения берутся из /proc/stat и переводятся из тиков в секунды.
node_cpu_seconds_total() {
    local i j cpu field value hz
    local cpu_el=(user nice system idle iowait irq softirq steal guest guest_nice)

    echo '# HELP node_cpu_seconds_total Seconds the CPUs spent in each mode.'
    echo '# TYPE node_cpu_seconds_total counter'

    hz=$(getconf CLK_TCK)

    for (( i=0; i<$(nproc); i++ )); do
        cpu="cpu${i}"

        for (( j=0; j<${#cpu_el[@]}; j++ )); do
            field=$(( j + 2 ))

            value=$(awk -v cpu="$cpu" -v f="$field" -v hz="$hz" '
                $1 == cpu { printf "%.2f", $f / hz }
            ' /proc/stat)

            printf 'node_cpu_seconds_total{cpu="%s",mode="%s"} %s\n' \
                "$i" "${cpu_el[j]}" "$value"
        done
    done
}

# Печатает счётчики завершённых операций чтения и записи по дискам.
node_disk_stats_total() {
    local dev reads_completed writes_completed
    local devs
    echo '# HELP node_disk_reads_completed_total The total number of reads completed successfully.'
    echo '# TYPE node_disk_reads_completed_total counter'
    echo '# HELP node_disk_writes_completed_total The total number of writes completed successfully.'
    echo '# TYPE node_disk_writes_completed_total counter'

    mapfile -t devs < <(
        awk '$3 !~ /^(loop|ram|sr|fd)/ {print $3}' /proc/diskstats | sort -u
    )

    for dev in "${devs[@]}"; do
        read -r reads_completed writes_completed < <(
            awk -v d="$dev" '$3 == d {print $4, $8}' /proc/diskstats
        )

        printf 'node_disk_reads_completed_total{device="%s"} %s\n' \
            "$dev" "$reads_completed"

        printf 'node_disk_writes_completed_total{device="%s"} %s\n' \
            "$dev" "$writes_completed"
    done
    echo
}

# Печатает размер и доступное место по файловым системам.
# Временные и служебные файловые системы исключаются.
node_filesystem() {
    local line device size_bytes avail_bytes mountpoint fstype
    local lines

    echo '# HELP node_filesystem_size_bytes Filesystem size in bytes.'
    echo '# TYPE node_filesystem_size_bytes gauge'
    echo '# HELP node_filesystem_avail_bytes Filesystem space available to non-root users in bytes.'
    echo '# TYPE node_filesystem_avail_bytes gauge'



    mapfile -t lines < <(
        df -B1 --output=source,fstype,size,avail,target |
        tail -n +2 |
        awk '$1 !~ /^(tmpfs|devtmpfs|proc|sysfs|cgroup|overlay|squashfs|snap|udev)$/ &&
             $5 !~ /^(\/run|\/sys|\/proc|\/dev)$/ {
                 print $1, $2, $3, $4, $5
             }'
    )

    for line in "${lines[@]}"; do
        read -r device fstype size_bytes avail_bytes mountpoint <<< "$line"

        printf 'node_filesystem_size_bytes{device="%s",fstype="%s",mountpoint="%s"} %s\n' \
            "$device" "$fstype" "$mountpoint" "$size_bytes"

        printf 'node_filesystem_avail_bytes{device="%s",fstype="%s",mountpoint="%s"} %s\n' \
            "$device" "$fstype" "$mountpoint" "$avail_bytes"
    done
    echo
}

# Печатает общее и свободное количество inode по файловым системам.
node_filesystem_inode() {
    echo '# HELP node_filesystem_files Filesystem total file nodes.'
    echo '# TYPE node_filesystem_files gauge'
    echo '# HELP node_filesystem_files_free Filesystem total free file nodes.'
    echo '# TYPE node_filesystem_files_free gauge'
    
    df -iT | awk '
    NR > 1 &&
    $1 !~ /^(tmpfs|devtmpfs|proc|sysfs|cgroup|overlay|squashfs|snap|udev)$/ &&
    $7 !~ /^(\/run|\/sys|\/proc|\/dev)$/ {
        printf "node_filesystem_files{device=\"%s\",fstype=\"%s\",mountpoint=\"%s\"} %s\n", $1, $2, $7, $3
        printf "node_filesystem_files_free{device=\"%s\",fstype=\"%s\",mountpoint=\"%s\"} %s\n", $1, $2, $7, $5
    }'
    echo
}

# Печатает базовые метрики оперативной памяти.
node_memory() {
    local total available cached free_mem

    read -r total free_mem cached available < <(
        free -b | awk 'NR==2 {print $2, $4, $6, $7}'
    )

    echo '# HELP node_memory_MemTotal_bytes Memory information field MemTotal_bytes.'
    echo '# TYPE node_memory_MemTotal_bytes gauge'
    echo "node_memory_MemTotal_bytes $total"

    echo '# HELP node_memory_MemAvailable_bytes Memory information field MemAvailable_bytes.'
    echo '# TYPE node_memory_MemAvailable_bytes gauge'
    echo "node_memory_MemAvailable_bytes $available"

    echo '# HELP node_memory_Cached_bytes Memory information field Cached_bytes.'
    echo '# TYPE node_memory_Cached_bytes gauge'
    echo "node_memory_Cached_bytes $cached"

    echo '# HELP node_memory_MemFree_bytes Memory information field MemFree_bytes.'
    echo '# TYPE node_memory_MemFree_bytes gauge'
    echo "node_memory_MemFree_bytes $free_mem"

    echo
}

# В цикле собирает метрики и атомарно обновляет файл для nginx.
generate_metrics() {
    while true; do    
        {
        # информация о CPU
        node_cpu_seconds_total
        
        # информация о диске
        node_disk_stats_total

        # информация о файловой системе
        node_filesystem
        node_filesystem_inode
        node_memory
        } > "$TMP_FILE"

        mv "$TMP_FILE" "$METRICS_FILE"
        sleep 3
    done
}

# Запускает генератор метрик в фоне и сохраняет его PID.
start_metrics_generator() {
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo -e "${YELLOW}Генератор уже запущен. PID: $(cat "$PID_FILE")${NC}"
        return 0
    fi

    generate_metrics &
    echo "$!" > "$PID_FILE"

    echo -e "${GREEN}Генератор метрик запущен в фоне. PID: $!${NC}"
}

# Останавливает фоновый генератор метрик по PID-файлу.
stop_metrics_generator() {
    if [[ ! -f "$PID_FILE" ]]; then
        echo -e "${YELLOW}PID-файл не найден. Генератор, вероятно, не запущен.${NC}"
        return 0
    fi

    local pid
    pid="$(cat "$PID_FILE")"

    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid"
        rm -f "$PID_FILE"
        echo -e "${GREEN}Генератор метрик остановлен. PID: $pid${NC}"
    else
        rm -f "$PID_FILE"
        echo -e "${YELLOW}Процесс уже не работает. PID-файл удалён.${NC}"
    fi
}
