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
        echo -e "${GREEN}$1 запущена${NC}"
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

# Удаляет компоненты мониторинга и stress.
remove_all() {
    remove prometheus
    remove grafana grafana-server
    remove prometheus-node-exporter
    sudo rm -f /etc/apt/sources.list.d/grafana.list
    sudo rm -f /etc/apt/keyrings/grafana.asc
    sudo apt remove stress -y
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
    echo "0. Выход"
}

# Обрабатывает выбранный пункт интерактивного меню.
menu() {
    local action
    read -p "Введите номер действия (0-4): " action

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
