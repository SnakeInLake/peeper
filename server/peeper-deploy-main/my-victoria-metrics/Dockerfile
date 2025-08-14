# берем чистый образ виктории
FROM victoriametrics/victoria-metrics:v1.93.0
# заходим под привилегированным пользователем
USER root
# запускаем установку утилит для healthcheck
RUN apk add --no-cache wget curl

# Возвращаемся к стандартному пользователю 'nobody',
# от которого работает VictoriaMetrics для большей безопасности.
USER nobody
