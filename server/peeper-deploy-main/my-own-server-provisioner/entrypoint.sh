#!/bin/bash
# Убираем set -e, чтобы скрипт не падал, а сообщал об ошибках
# и продолжал работу с другими файлами.

echo "--- Custom Server Provisioner Started ---"

GRAFANA_URL="http://peeper-grafana:3000"

echo "Waiting for Grafana to be available at ${GRAFANA_URL}..."
while ! nc -z -w 1 peeper-grafana 3000; do sleep 1; done
echo "Grafana is up and listening!"

if [ -z "$GRAFANA_TOKEN" ]; then
  echo "CRITICAL ERROR: GRAFANA_TOKEN environment variable is not set. Exiting."
  exit 1
fi

echo "Token found. Starting to provision dashboards..."
EXIT_CODE=0

find /dashboards -type f -name "*.json" | while read -r dashboard_file; do
  
  echo "--------------------------------------------------"
  echo "Processing file: $dashboard_file"
  
  # --- ВОТ ОНА, ФИНАЛЬНАЯ МАГИЯ ---
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

  HTTP_STATUS=$(echo "$CURL_RESPONSE" | tail -n1)
  BODY=$(echo "$CURL_RESPONSE" | head -n-1)

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
