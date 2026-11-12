#!/usr/bin/env bash

# Выводит справку по запуску генератора и информационным командам.
print_help() {
    echo -e "${CYAN}${BOLD}==============================================================${NC}"
    echo -e "${CYAN}${BOLD}                  NGINX LOG GENERATOR HELP                   ${NC}"
    echo -e "${CYAN}${BOLD}==============================================================${NC}"
    echo

    echo -e "${YELLOW}${BOLD}Запуск генератора:${NC}"
    echo
    echo -e "  ${GREEN}./main.sh${NC}"
    echo
    echo "      • Запускает генерацию nginx access логов"
    echo "        в формате combined."
    echo

    echo -e "${YELLOW}${BOLD}Информационные команды:${NC}"
    echo

    echo -e "  ${GREEN}./main.sh code${NC}"
    echo
    echo "      • Выводит информацию"
    echo "        об HTTP status codes и HTTP methods."
    echo

    echo -e "  ${GREEN}./main.sh method${NC}"
    echo
    echo "      • Выводит описание"
    echo "        HTTP-методов."
    echo

    echo -e "  ${GREEN}./main.sh combined${NC}"
    echo
    echo "      • Показывает описание"
    echo "        nginx combined log format."
    echo
    echo -e "${CYAN}${BOLD}==============================================================${NC}"
}

# Печатает краткую справку по HTTP status codes,
# которые используются при генерации access-логов.
print_http_code_info() {
    echo -e "${CYAN}${BOLD}==============================================================${NC}"
    echo -e "${CYAN}${BOLD}                 HTTP STATUS CODES                            ${NC}"
    echo -e "${CYAN}${BOLD}==============================================================${NC}"
    echo

    echo -e "${YELLOW}${BOLD}1. Информационные ответы (100 – 199)${NC}"

    echo -e "${YELLOW}${BOLD}2. Успешные ответы (200 – 299)${NC}"

    echo -e "   ${GREEN}• 200 - OK${NC}"
    echo "         • GET: Ресурс был получен и передан в теле сообщения."
    echo "         • HEAD: Ответ содержит заголовки, но тела сообщения нет."
    echo "         • PUT или POST: Ресурс, описывающий результат действия,"
    echo "           передан в теле сообщения."
    echo "         • TRACE: Тело сообщения содержит сообщение запроса,"
    echo "           полученное сервером."
    echo

    echo -e "   ${GREEN}• 201 - Created${NC}"
    echo "         • Запрос выполнен успешно, и в результате был создан"
    echo "           новый ресурс."
    echo "         • Обычно это ответ, отправляемый на запросы POST или PUT."
    echo

    echo -e "${YELLOW}${BOLD}3. Сообщения о перенаправлении (300 – 399)${NC}"

    echo -e "${YELLOW}${BOLD}4. Ошибки клиента (400 – 499)${NC}"

    echo -e "   ${RED}• 400 - Bad Request${NC}"
    echo "         • Сервер не может или не будет обрабатывать запрос"
    echo "           из-за ошибки клиента."
    echo "         • Например:"
    echo "             - неправильный синтаксис"
    echo "             - неверный формат"
    echo "             - ошибка маршрутизации"
    echo

    echo -e "   ${RED}• 401 - Unauthorized${NC}"
    echo "         • Хотя стандарт HTTP определяет этот ответ"
    echo "           как «неавторизованный», семантически"
    echo "           он означает «неаутентифицированный»."
    echo "         • Клиент должен аутентифицировать себя,"
    echo "           чтобы получить запрошенный ответ."
    echo

    echo -e "   ${RED}• 403 - Forbidden${NC}"
    echo "         • Клиент не имеет прав доступа к контенту."
    echo "         • Сервер понимает кто клиент,"
    echo "           но отказывается предоставить ресурс."
    echo "         • В отличие от 401 Unauthorized,"
    echo "           личность клиента серверу известна."
    echo

    echo -e "   ${RED}• 404 - Not Found${NC}"
    echo "         • Сервер не может найти запрошенный ресурс."
    echo "         • В браузере это означает,"
    echo "           что URL-адрес не распознан."
    echo "         • В API это также может означать,"
    echo "           что адрес правильный, но ресурс не существует."
    echo "         • Сервер также может отправить этот код"
    echo "           вместо 403 Forbidden,"
    echo "           чтобы скрыть существование ресурса"
    echo "           от неавторизованного клиента."
    echo "         • Это самый известный код ответа"
    echo "           из-за его частого появления в сети."
    echo

    echo -e "${YELLOW}${BOLD}5. Ошибки сервера (500 – 599)${NC}"

    echo -e "   ${MAGENTA}• 500 - Internal Server Error${NC}"
    echo "         • На сервере произошла ошибка,"
    echo "           в результате которой он не может"
    echo "           успешно обработать запрос."
    echo

    echo -e "   ${MAGENTA}• 501 - Not Implemented${NC}"
    echo "         • Метод запроса не поддерживается сервером"
    echo "           и поэтому не может быть обработан."
    echo "         • Методы GET и HEAD должны"
    echo "           всегда поддерживаться сервером,"
    echo "           и для них не должен"
    echo "           возвращаться этот код."
    echo

    echo -e "   ${MAGENTA}• 502 - Bad Gateway${NC}"
    echo "         • Такой ответ может прислать сервер,"
    echo "           который выступает в качестве шлюза,"
    echo "           если при обработке запроса"
    echo "           он получил недопустимый ответ"
    echo "           от целевого сервера."
    echo

    echo -e "   ${MAGENTA}• 503 - Service Unavailable${NC}"
    echo "         • Сервер не готов обработать запрос"
    echo "           в данный момент."
    echo "         • Возможные причины:"
    echo "             - техническое обслуживание"
    echo "             - перегрузка сервера"
    echo "         • Вместе с таким ответом"
    echo "           рекомендуется отправлять:"
    echo "             - страницу с описанием проблемы"
    echo "             - HTTP-заголовок Retry-After"
    echo "         • Обычно такие ответы"
    echo "           не должны кешироваться."
    echo
}

# Печатает описание HTTP-методов, используемых генератором логов.
print_http_metods_info() {
    echo -e "${CYAN}${BOLD}==============================================================${NC}"
    echo -e "${CYAN}${BOLD}                           METHODS                            ${NC}"
    echo -e "${CYAN}${BOLD}==============================================================${NC}"
    echo

    echo -e "   ${GREEN}• GET${NC}"
    echo "         • Метод GET запрашивает представление ресурса."
    echo "         • Запросы с использованием этого метода"
    echo "           могут только извлекать данные."
    echo

    echo -e "   ${GREEN}• POST${NC}"
    echo "         • Используется для отправки сущностей"
    echo "           к определённому ресурсу."
    echo "         • Часто вызывает изменение состояния"
    echo "           или побочные эффекты на сервере."
    echo

    echo -e "   ${GREEN}• PUT${NC}"
    echo "         • Заменяет все текущие представления ресурса"
    echo "           данными запроса."
    echo

    echo -e "   ${GREEN}• PATCH${NC}"
    echo "         • Используется для частичного изменения ресурса."
    echo

    echo -e "   ${GREEN}• DELETE${NC}"
    echo "         • Удаляет указанный ресурс."
    echo

    echo -e "${CYAN}${BOLD}==============================================================${NC}"
}

# Печатает структуру nginx combined log format и поясняет поля строки.
print_combined_format_info() {
    echo -e "${CYAN}${BOLD}==============================================================${NC}"
    echo -e "${CYAN}${BOLD}                  NGINX COMBINED LOG FORMAT                  ${NC}"
    echo -e "${CYAN}${BOLD}==============================================================${NC}"
    echo

    echo -e "${YELLOW}${BOLD}Формат строки:${NC}"
    echo
    echo -e "${WHITE}IP ident user [date] \"METHOD URL HTTP/version\" status bytes \"referer\" \"user-agent\"${NC}"
    echo

    echo -e "${YELLOW}${BOLD}Пример:${NC}"
    echo
    echo -e "${GREEN}93.184.216.34 - - [10/May/2026:14:03:17 +0000] \"GET /index.html HTTP/1.1\" 200 1024 \"-\" \"Mozilla\"${NC}"
    echo

    echo -e "${CYAN}${BOLD}==============================================================${NC}"
    echo -e "${CYAN}${BOLD}                     ОПИСАНИЕ ПОЛЕЙ                          ${NC}"
    echo -e "${CYAN}${BOLD}==============================================================${NC}"
    echo

    echo -e " ${GREEN}1. IP${NC}"
    echo "      • IP-адрес клиента,"
    echo "        отправившего HTTP-запрос."
    echo

    echo -e " ${GREEN}2. ident${NC}"
    echo "      • Идентификатор клиента через ident-протокол."
    echo "      • Обычно содержит символ \"-\"."
    echo

    echo -e " ${GREEN}3. user${NC}"
    echo "      • Имя авторизованного пользователя."
    echo "      • Если авторизация отсутствует — \"-\"."
    echo

    echo -e " ${GREEN}4. [date]${NC}"
    echo "      • Дата и время запроса"
    echo "        в формате nginx access log."
    echo "      • Пример:"
    echo "          [10/May/2026:14:03:17 +0000]"
    echo

    echo -e " ${GREEN}5. \"request\"${NC}"
    echo "      • HTTP-запрос клиента."
    echo "      • Содержит:"
    echo "          - HTTP-метод"
    echo "          - URL"
    echo "          - версию протокола"
    echo "      • Пример:"
    echo "          \"GET /index.html HTTP/1.1\""
    echo

    echo -e " ${GREEN}6. status${NC}"
    echo "      • HTTP-код ответа сервера."
    echo "      • Например:"
    echo "          200, 404, 500"
    echo

    echo -e " ${GREEN}7. bytes${NC}"
    echo "      • Размер ответа сервера"
    echo "        в байтах."
    echo

    echo -e " ${GREEN}8. \"referer\"${NC}"
    echo "      • Страница-источник перехода."
    echo "      • Показывает,"
    echo "        откуда пользователь пришёл."
    echo "      • Если источник неизвестен — \"-\"."
    echo

    echo -e " ${GREEN}9. \"user-agent\"${NC}"
    echo "      • Клиентское приложение,"
    echo "        выполнившее запрос."
    echo "      • Может содержать:"
    echo "          - браузер"
    echo "          - бота"
    echo "          - библиотеку"
    echo "          - curl/wget"
    echo

    echo -e "${CYAN}${BOLD}==============================================================${NC}"
}
