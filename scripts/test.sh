# Check your permissions
az role assignment list \
  --assignee $(az account show --query user.name -o tsv) \
  --subscription "51e4dde5-a3cf-4369-b57f-137b90f633f0" \
  --output table

az account get-access-token \
  --subscription "51e4dde5-a3cf-4369-b57f-137b90f633f0" \
  --query accessToken -o tsv  


your-dynatrace-token-here