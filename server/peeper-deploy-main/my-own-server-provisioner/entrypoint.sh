#!/bin/bash
echo "--- Custom Server Provisioner Started ---"

# Переменная для адреса графаны (имя сервиса + стандартный порт доступа)
GRAFANA_URL="http://stud-grafana:3000"

echo "Waiting for Grafana to be available at ${GRAFANA_URL}..."
# Цикл ожидания: чтоб не обогнать графану мы уходим в цикл
# nc пытается соединиться с графкой на порту, пока не(!) завершится успешно
# -w - раз в секунду, -z - только проверка, устанвока соединения и все(zero length)  
while ! nc -z -w 1 stud-grafana 3000; do sleep 1; done
echo "Grafana is up and listening!"

# Если строка пуста, то выведется сообщение и выход
if [ -z "$GRAFANA_TOKEN" ]; then
  echo "CRITICAL ERROR: GRAFANA_TOKEN environment variable is not set. Exiting."
  exit 1

fi
# Иначе
echo "Token found. Starting to provision dashboards..."
EXIT_CODE=0

# Команда find ищет в папке /dashboards (которую мы "пробросили" в контейнер)
# все обычные файлы (-type f), чьи имена заканчиваются на .json.
#|: "Пайп" (труба). Он передает список найденных файлов на вход следующей команде.
# Читает полученный список по одной строке за раз и присваивает имя файла переменной dashboard_file.
find /dashboards -type f -name "*.json" | while read -r dashboard_file; do
  
  echo "--------------------------------------------------"
  echo "Processing file: $dashboard_file"
  
  # 1. sed ... : Читает файл и на лету заменяет все упоминания старого источника на новый.
  # 2. | jq ... : Берет исправленный JSON, извлекает .spec и упаковывает для API.
  # 3. | curl ... : Отправляет полностью готовый и исправленный дашборд в Grafana.
  CURL_RESPONSE=$(sed 's/"peeper-metrics"/"MyVictoriaMetrics"/g' "$dashboard_file" | \
                  jq -c '{ "dashboard": .spec, "overwrite": true }' | \
                  curl -s -w '\n%{http_code}' -X POST \
                       -H "Authorization: Bearer $GRAFANA_TOKEN" \
                       -H "Content-Type: application/json" \
                       --data-binary @- \
                       "${GRAFANA_URL}/api/dashboards/db")
# Берет последнюю строку из вывода curl
  HTTP_STATUS=$(echo "$CURL_RESPONSE" | tail -n1)
 # Берет все строки, кроме последней  
  BODY=$(echo "$CURL_RESPONSE" | head -n-1)

# Если HTTP-статус равен 200 ("OK"), скрипт выводит сообщение об успехе.
  if [ -z "$HTTP_STATUS" ]; then
      echo "ERROR: Did not receive a valid HTTP response from Grafana for '$dashboard_file'."
      EXIT_CODE=1
      continue
  fi

  if [ "$HTTP_STATUS" -eq 200 ]; then
    SUCCESS_INFO=$(echo "$BODY" | jq -r '"Dashboard UID: \(.uid), Version: \(.version), Status: \(.status)"')
    echo "SUCCESS: Provisioned. Info: $SUCCESS_INFO"
  else
    echo "ERROR: Failed to provision (HTTP Status: $HTTP_STATUS)"
    echo "ERROR RESPONSE FROM GRAFANA: $BODY"
    EXIT_CODE=1
  fi
done

echo "--------------------------------------------------"
echo "--- Custom Server Provisioner Finished ---"
exit $EXIT_CODE
