#/bin/bash

# Update the token in your app
az webapp config appsettings set \
  --name dynatrace-demo-api-7536 \
  --resource-group dynatrace-demo-rg \
  --settings DT_API_TOKEN="$DT_TOKEN"

# Restart twice
az webapp restart --name dynatrace-demo-api-7536 --resource-group dynatrace-demo-rg
sleep 30
az webapp restart --name dynatrace-demo-api-7536 --resource-group dynatrace-demo-rg