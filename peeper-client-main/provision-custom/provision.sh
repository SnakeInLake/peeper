#!/bin/sh

echo "--- Custom Peeper Provisioner Started ---"

# ИЗМЕНЕНИЕ 1: GRAFANA_URL теперь берется из переменной окружения, а не захардкожен
: "${GRAFANA_URL?Переменная GRAFANA_URL не установлена}"

echo "Waiting for Grafana to be available..."
# Простая проверка доступности через curl вместо nc, так как curl у нас точно будет
until curl -k -s -o /dev/null "$GRAFANA_URL"; do
  echo "Grafana is unavailable - sleeping"
  sleep 1
done
echo "Grafana is up!"

if [ -z "$GRAFANA_TOKEN" ]; then
  echo "CRITICAL ERROR: GRAFANA_TOKEN environment variable is not set. Exiting."
  exit 1
fi

echo "Token found. Starting to provision dashboards from /provisioning/dashboards ..."
EXIT_CODE=0

find /provisioning/dashboards -type f -name "*.json" | while read -r dashboard_file; do
  
  echo "--------------------------------------------------"
  echo "Processing file: $dashboard_file"
  
  CURL_RESPONSE=$(sed 's/"peeper-metrics"/"MyVictoriaMetrics"/g' "$dashboard_file" | \
                  jq -c '{ "dashboard": .spec, "overwrite": true }' | \
                  curl -s -k -w '\n%{http_code}' -X POST \
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
echo "--- Custom Peeper Provisioner Finished ---"
exit $EXIT_CODE
