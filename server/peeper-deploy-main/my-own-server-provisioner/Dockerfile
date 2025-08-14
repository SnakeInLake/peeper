FROM alpine:latest

# Устанавливаем ВСЕ нужные утилиты, ВКЛЮЧАЯ BASH для 100% работы скрипта
RUN apk add --no-cache curl jq netcat-openbsd dos2unix bash

# Создаем папку для дашбордов
RUN mkdir -p /dashboards/system

# Копируем наш скрипт
COPY entrypoint.sh /entrypoint.sh

# Исправляем окончания и даем права
# dos2unix для очищения скрипта (с ним возникли трудности)
RUN dos2unix /entrypoint.sh && chmod +x /entrypoint.sh

# Указываем точку входа
ENTRYPOINT ["/entrypoint.sh"]
