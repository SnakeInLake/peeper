#!/bin/sh
set -e

# Создаем директорию для сокета HAProxy, если она не существует
mkdir -p /var/run/haproxy

# Выдаем права на эту директорию пользователю и группе haproxy
# (Этот пользователь и группа существуют в официальном образе)
chown -R haproxy:haproxy /var/run/haproxy

# Запускаем оригинальную команду, переданную в контейнер
# (например, "haproxy -f /usr/local/etc/haproxy/haproxy.cfg")
exec "$@"
