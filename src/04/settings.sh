#!/usr/bin/env bash

LOG_DAYS_COUNT=5
MIN_LOG_RECORDS=100
MAX_LOG_RECORDS=1000
MIN_RESPONSE_BYTE=100
MAX_RESPONSE_BYTE=5000

# HTTP methods:
# GET    — запрос данных с сервера.
# POST   — отправка новых данных на сервер.
# PUT    — полное обновление существующего ресурса.
# PATCH  — частичное обновление ресурса.
# DELETE — удаление ресурса.

METHODS=('GET' 'POST' 'PUT' 'PATCH' 'DELETE')

# HTTP status codes:
# 200 — OK, запрос выполнен успешно.
# 201 — Created, ресурс успешно создан.
# 400 — Bad Request, некорректный запрос.
# 401 — Unauthorized, требуется авторизация.
# 403 — Forbidden, доступ запрещён.
# 404 — Not Found, ресурс не найден.
# 500 — Internal Server Error, внутренняя ошибка сервера.
# 501 — Not Implemented, метод не поддерживается сервером.
# 502 — Bad Gateway, ошибка шлюза или прокси.
# 503 — Service Unavailable, сервис временно недоступен.

STATUSES=('200' '201' '400' '401' '403' '404' '500' '501' '502' '503')
URLS=(
    '/'
    '/index.html'
    '/about'
    '/contact'
    '/login'
    '/logout'
    '/register'
    '/profile'
    '/dashboard'
    '/admin'
    '/api/users'
    '/api/products'
    '/api/orders'
    '/api/auth/login'
    '/api/auth/logout'
    '/api/v1/data'
    '/css/style.css'
    '/css/main.css'
    '/js/app.js'
    '/js/main.js'
    '/images/logo.png'
    '/images/banner.jpg'
    '/favicon.ico'
    '/docs/manual.pdf'
    '/download/archive.zip'
    '/search?q=test'
    '/news'
    '/blog'
    '/blog/article-1'
    '/health'
    '/metrics'
)
REFERERS=(
    '-'
    'https://google.com'
    'https://yandex.ru'
    'https://github.com'
    'https://example.com'
    'https://school21.ru'
)
USER_AGENTS=(
    'Mozilla'
    'Google Chrome'
    'Opera'
    'Safari'
    'Internet Explorer'
    'Microsoft Edge'
    'Crawler and bot'
    'Library and net tool'
)
USERS=(
    '-'
    'admin'
    'user'
    'guest'
    'alex'
)

LOG_DIR="$SCRIPT_DIR/logs"

# ANSI-коды цветов для оформления сообщений
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'

# Жирный текст
BOLD='\033[1m'

# Сброс ANSI-оформления
NC='\033[0m'
