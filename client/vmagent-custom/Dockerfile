# Используем официальный образ vmagent как основу
FROM victoriametrics/vmagent

# Устанавливаем рабочую директорию
WORKDIR /vmagent/

# Копируем нашу папку с конфигурациями внутрь образа
COPY configs/ /etc/vmagent/configs/

# Копируем наш стартовый скрипт
COPY entrypoint.sh /entrypoint.sh

# Указываем, что при запуске контейнера нужно выполнить наш скрипт
ENTRYPOINT ["/entrypoint.sh"]
