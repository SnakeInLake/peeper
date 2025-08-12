FROM victoriametrics/victoria-metrics:v1.93.0

USER root

RUN apk add --no-cache wget curl

# Возвращаемся к стандартному пользователю 'nobody',
# от которого работает VictoriaMetrics для большей безопасности.
USER nobody
