#!/bin/sh

# Устанавливаем значения по умолчанию, если переменные не заданы
: "${PEEPER_HOST?Переменная PEEPER_HOST не установлена}"
: "${PEEPER_PORT:=443}"
: "${PEEPER_USER?Переменная PEEPER_USER не установлена}"
: "${PEEPER_PASSWORD?Переменная PEEPER_PASSWORD не установлена}"

# Формируем URL для отправки метрик
REMOTE_WRITE_URL="https://""${PEEPER_HOST}":"${PEEPER_PORT}""/metrics/api/v1/write"

# Запускаем vmagent, передавая ему все параметры в виде флагов,
# собранных из переменных окружения.
# exec - чтобы vmagent стал главным процессом в контейнере.
exec /vmagent-prod \
    -promscrape.config=/etc/vmagent/configs/agent.yaml \
    -remoteWrite.url="${REMOTE_WRITE_URL}" \
    -remoteWrite.basicAuth.username="${PEEPER_USER}" \
    -remoteWrite.basicAuth.password="${PEEPER_PASSWORD}" \
    -remoteWrite.tlsInsecureSkipVerify=true \
    -remoteWrite.forceVMProto=true \
    -remoteWrite.tmpDataPath=/data \
    -remoteWrite.maxDiskUsagePerURL=1073741824 \
    -httpListenAddr=:8429
