#!/usr/bin/env bash

set -u
set -o pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
passed=0
failed=0
skipped=0

pass() {
    printf 'PASS: %s\n' "$1"
    ((passed++))
}

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    ((failed++))
}

skip() {
    printf 'SKIP: %s\n' "$1"
    ((skipped++))
}

expect_success() {
    local name="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        pass "$name"
    else
        fail "$name"
    fi
}

expect_failure() {
    local name="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        fail "$name"
    else
        pass "$name"
    fi
}

shell_files=()
while IFS= read -r file; do
    shell_files+=("$file")
done < <(find "$PROJECT_ROOT/src" -type f -name '*.sh' -print | sort)

expect_success "Синтаксис всех Bash-сценариев" bash -n "${shell_files[@]}"

expect_failure "Part 1 проверяет количество аргументов" \
    bash "$PROJECT_ROOT/src/01/main.sh"
expect_failure "Part 2 проверяет количество аргументов" \
    bash "$PROJECT_ROOT/src/02/main.sh"
expect_failure "Part 3 требует режим очистки" \
    bash "$PROJECT_ROOT/src/03/main.sh"

expect_success "Part 4: общая справка" \
    bash "$PROJECT_ROOT/src/04/main.sh" --help
expect_success "Part 4: справка по HTTP-кодам" \
    bash "$PROJECT_ROOT/src/04/main.sh" code
expect_success "Part 4: справка по HTTP-методам" \
    bash "$PROJECT_ROOT/src/04/main.sh" method
expect_success "Part 4: справка по Combined Log Format" \
    bash "$PROJECT_ROOT/src/04/main.sh" combined
expect_failure "Part 5 требует режим анализа" \
    bash "$PROJECT_ROOT/src/05/main.sh"
expect_success "Part 6: справка" \
    bash "$PROJECT_ROOT/src/06/main.sh" help

expect_failure "Part 7 не принимает аргументы" \
    bash "$PROJECT_ROOT/src/07/main.sh" unexpected
expect_failure "Part 8 не принимает аргументы" \
    bash "$PROJECT_ROOT/src/08/main.sh" unexpected
expect_failure "Part 9 не принимает аргументы" \
    bash "$PROJECT_ROOT/src/09/main.sh" unexpected

if command -v jq >/dev/null 2>&1; then
    json_files=()
    while IFS= read -r file; do
        json_files+=("$file")
    done < <(find "$PROJECT_ROOT/src" -type f -name '*.json' -print | sort)
    expect_success "Синтаксис Grafana dashboards" jq empty "${json_files[@]}"
else
    skip "Синтаксис Grafana dashboards — jq не установлен"
fi

if grep -q '^# HELP ' "$PROJECT_ROOT/src/09/configs/metrics-example.prom" && \
   grep -q '^# TYPE ' "$PROJECT_ROOT/src/09/configs/metrics-example.prom"; then
    pass "Пример содержит Prometheus HELP и TYPE"
else
    fail "Пример содержит Prometheus HELP и TYPE"
fi

for config in "$PROJECT_ROOT"/src/{07,08,09}/configs/prometheus.yml; do
    if grep -q '^scrape_configs:' "$config"; then
        pass "Prometheus scrape_configs: ${config#"$PROJECT_ROOT/"}"
    else
        fail "Prometheus scrape_configs: ${config#"$PROJECT_ROOT/"}"
    fi
done

printf '\nРезультат: %d успешно, %d ошибок, %d пропущено\n' \
    "$passed" "$failed" "$skipped"
[[ "$failed" -eq 0 ]]
