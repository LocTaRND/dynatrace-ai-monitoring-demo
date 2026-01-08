# Get your subscription ID (it's already visible: 51e4dde5-a3cf-4369-b57f-137b90f633f0)
SUBSCRIPTION_ID="51e4dde5-a3cf-4369-b57f-137b90f633f0"

# Create Service Principal
az ad sp create-for-rbac \
  --name "Dynatrace-Monitoring-Zenfolio" \
  --role "Monitoring Reader" \
  --scopes "/subscriptions/$SUBSCRIPTION_ID" \
  --json-auth