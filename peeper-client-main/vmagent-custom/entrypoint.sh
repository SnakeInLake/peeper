#!/bin/sh

# Проверяем, установлена ли переменная STUD_HOST. Если нет - завершить скрипт с ошибкой.
: "${STUD_HOST?Переменная STUD_HOST не установлена}"
# Проверяем, установлена ли переменная STUD_PORT. Если нет - присвоить ей значение по умолчанию "443".
: "${STUD_PORT:=443}"

# Собираем полный URL для отправки метрик из переменных, добавляя HTTPS и путь.
REMOTE_WRITE_URL="https://""${STUD_HOST}":"${STUD_PORT}""/metrics/api/v1/write"

# 'exec' заменяет текущий процесс (скрипт) на новый (vmagent), делая vmagent главным процессом контейнера.
# Запускаем основной исполняемый файл vmagent.
exec /vmagent-prod \
    # Указываем путь к файлу с правилами сбора метрик (scrape configs).
    -promscrape.config=/etc/vmagent/configs/agent.yaml \
    # Передаем полный URL, куда нужно отправлять собранные метрики.
    -remoteWrite.url="${REMOTE_WRITE_URL}" \
    # Передаем имя пользователя для Basic-аутентификации на сервере.
    -remoteWrite.basicAuth.username="${PEEPER_USER}" \
    # Передаем пароль для Basic-аутентификации на сервере.
    -remoteWrite.basicAuth.password="${PEEPER_PASSWORD}" \
    # Отключаем проверку цепочки доверия SSL-сертификата (доверять самоподписанным сертификатам).
    -remoteWrite.tlsInsecureSkipVerify=true \
    # Включаем нативный, высокопроизводительный протокол VictoriaMetrics для отправки данных.
    -remoteWrite.forceVMProto=true \
    # Указываем путь внутри контейнера для хранения временной очереди данных (буфера).
    -remoteWrite.tmpDataPath=/data \
    # Ограничиваем максимальный размер буфера на диске 1 гигабайтом.
    -remoteWrite.maxDiskUsagePerURL=1073741824 \
    # Указываем vmagent запустить свой HTTP-сервер на порту 8429 для приема PUSH-метрик и доступа к UI.
    -httpListenAddr=:8429 \
    # "Обманываем" TLS-проверку, говоря, что мы ожидаем от сервера сертификат, выданный для имени "192.68.122.77".
    -remoteWrite.tlsServerName="192.68.122.77"
