# Берем чистый образ хапрокси от alpine (потому что он легче)
FROM haproxy:3.0-alpine
# Переключаемся на рут пользователя
USER root
# Добавляем бессмысленную команду, чтобы точно сломать кеш
RUN echo "build_id=999" && mkdir -p /var/run/haproxy && chown haproxy:haproxy /var/run/haproxy
# вешаем метки для сбора  метриков
LABEL metrics.scrape="true" \
      metrics.job="proxy" \
      metrics.port="8404" \
      metrics.path="/metrics"
