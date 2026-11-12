#!/usr/bin/env bash

# Устанавливает GoAccess.
# Сначала пробует официальный репозиторий, затем стандартный репозиторий Ubuntu.
install_GoAccess() {
  echo "Устанавливаю GoAccess"
  if add_key_gpg && add_repo_GoAccess && install_goaccess_package && check_install_GoAccess; then
    echo -e "${GREEN}GoAccess установлен${NC}"
    return 0
  else
    echo -e "${YELLOW}Официальный репозиторий недоступен${NC}"
    echo -e "${YELLOW}Пробую установить из стандартного репозитория Ubuntu${NC}"
    sudo rm -f "$GOACCESS_REPO_FILE"

    if install_goaccess_package && check_install_GoAccess; then
      echo -e "${GREEN}GoAccess установлен${NC}"
      return 0
    else
      echo -e "${RED}GoAccess не установлен${NC}"
      return 1
    fi
  fi
}

# Добавляет GPG-ключ официального репозитория GoAccess.
add_key_gpg() {
  echo "Добавляю ключ GPG для репозитория GoAccess"
  if key_gpg; then
    echo "Ключ добавлен"
    return 0
  else
    echo "Ключ не добавлен"
    return 1
  fi
}

# Скачивает GPG-ключ и сохраняет его в keyring для apt.
key_gpg() {
  wget -O - "$GOACCESS_KEY_URL" |
    gpg --dearmor |
    sudo tee "$GOACCESS_KEYRING" >/dev/null
}

# Добавляет apt-репозиторий GoAccess.
add_repo_GoAccess() {
  echo "Добавляю репозиторий GoAccess"
  if repo_GoAccess; then
    echo "Репозиторий добавлен"
    return 0
  else
    echo "Репозиторий не добавлен"
    return 1
  fi
}

# Формирует строку репозитория GoAccess для текущего дистрибутива.
repo_GoAccess() {
  echo "deb [signed-by=${GOACCESS_KEYRING} arch=$(dpkg --print-architecture)] ${GOACCESS_REPO_URL} $(lsb_release -cs) main" |
    sudo tee "$GOACCESS_REPO_FILE" >/dev/null
}

# Устанавливает пакет goaccess через apt.
install_goaccess_package() {
  if sudo apt update && sudo apt install goaccess -y; then
    return 0
  else
    return 1
  fi
}

# Проверяет наличие GoAccess и выводит его версию.
check_install_GoAccess() {
  command -v goaccess >/dev/null 2>&1 && goaccess --version
}

# Открывает интерактивный отчёт GoAccess в терминале.
report_terminal() {
  if check_install_GoAccess; then
    goaccess "$LOG_DIR"/*.log --log-format=COMBINED
  elif install_GoAccess; then
    goaccess "$LOG_DIR"/*.log --log-format=COMBINED
  else
    echo -e "${RED}GoAccess не установлен${NC}"
    exit 1
  fi
}

# Создаёт HTML-отчёт GoAccess по access-логам.
report_html() {
  if check_install_GoAccess; then
    goaccess "$LOG_DIR"/*.log \
      --log-format=COMBINED \
      -o access-log.html
  elif install_GoAccess; then
    goaccess "$LOG_DIR"/*.log \
      --log-format=COMBINED \
      -o access-log.html
  else
    echo -e "${RED}GoAccess не установлен${NC}"
    exit 1
  fi
}

# Удаляет пакет GoAccess.
rm_GoAccess() {
  sudo apt remove goaccess -y
}

# Запускает простой HTTP-сервер для просмотра HTML-отчёта.
# Если отчёта ещё нет, сначала создаёт его.
run_http_server() {
  if [[ ! -f access-log.html ]]; then
    report_html || return 1
  fi

  echo
  echo "HTTP-сервер будет запущен в текущем терминале."
  echo -e "${CYAN}Для остановки нажмите Ctrl+C.${NC}"
  echo -e "${CYAN}Откройте в браузере: http://127.0.0.1:8080/access-log.html${NC}"
  echo "Если VM работает через NAT, пробросьте порт 8080 -> 8080"

  python3 -m http.server 8080
}

# Показывает интерактивное меню Part 6 и запускает выбранное действие.
interactive_menu() {
  echo
  echo "1 - Открыть терминальный отчёт"
  echo "2 - Создать HTML-отчёт"
  echo "3 - Запустить HTTP-сервер для HTML-отчёта"
  echo "4 - Установить GoAccess"
  echo "5 - Удалить GoAccess"
  echo "0 - Выход"
  echo

  local menu

  read -rp "Выберите пункт: " menu

  case "$menu" in
  1)
    report_terminal
    exit 0
    ;;
  2)
    report_html
    exit 0
    ;;
  3)
    run_http_server
    exit 0
    ;;
  4)
    install_GoAccess
    exit 0
    ;;
  5)
    rm_GoAccess
    exit 0
    ;;
  0) exit 0
    ;;
  
  *)
  echo -e "${RED}Ошибка: выберите пункт от 0 до 5${NC}"
  interactive_menu
  ;;
  esac
}

# Выводит справку по доступным командам.
print_help() {
  echo "Использование:"
  echo "  ./main.sh                - интерактивный режим"
  echo "  ./main.sh COMMAND"
  echo

  echo "Команды:"
  echo "  install           - установить GoAccess"
  echo "  report_terminal   - открыть терминальный отчёт"
  echo "  report_html       - создать HTML-отчёт"
  echo "  serve             - запустить HTTP-сервер"
  echo "  rm                - удалить GoAccess"
  echo "  help              - показать справку"
  echo

  echo "Примеры:"
  echo "  ./main.sh install"
  echo "  ./main.sh report_html"
  echo "  ./main.sh serve"
}

# Проверяет количество аргументов и выводит ошибку при необходимости.
validate_args() {
    if (( "$#" > 1 )); then
        echo -e "${RED}Ошибка: слишком много аргументов${NC}"
        print_help
        exit 1
    fi
}