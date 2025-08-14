# Используем легкий базовый образ Alpine Linux
FROM alpine:latest

# Устанавливаем необходимые инструменты
RUN apk add --no-cache curl jq bash

# Копируем наш главный скрипт
COPY provision.sh /provision.sh

# Запускаем скрипт при старте контейнера
CMD ["/provision.sh"]
