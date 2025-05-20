#!/bin/bash

# === Error Handler ===
error_exit() {
  echo "ERROR: $1"
  exit 1
}

# === Environment Check ===
: "${API_TOKEN:?$(error_exit 'Environment variable API_TOKEN is not set')}"
: "${ZONE_ID:?$(error_exit 'Environment variable ZONE_ID is not set')}"

API_BASE="https://api.cloudflare.com/client/v4"
AUTH_HEADER="Authorization: Bearer $API_TOKEN"
CONTENT_HEADER="Content-Type: application/json"

# === Input Parsing ===
IP=""
while getopts ":m:f:i:" opt; do
  case $opt in
    m) MODE=$OPTARG ;;
    f) FQDN=$OPTARG ;;
    i) IP=$OPTARG ;;
    \?) error_exit "Invalid option: -$OPTARG" ;;
  esac
done

# === Input Validation ===
[[ -z "$MODE" || -z "$FQDN" ]] && error_exit "Usage: $0 -m <create|delete> -f <fqdn> [-i <ip>]"
[[ "$MODE" == "create" && -z "$IP" ]] && error_exit "IP address (-i) required for create mode"

# === Zone Name Retrieval ===
get_zone_name() {
  RESPONSE=$(curl -s -X GET "$API_BASE/zones/$ZONE_ID" \
    -H "$AUTH_HEADER" -H "$CONTENT_HEADER")
  [[ $(echo "$RESPONSE" | jq -r '.success') != "true" ]] && error_exit "Failed to get zone details: $(echo "$RESPONSE" | jq -r '.errors[]?.message')"
  echo "$RESPONSE" | jq -r '.result.name'
}

ZONE_NAME=$(get_zone_name)

# === Subdomain Extraction ===
if [[ "$FQDN" == "$ZONE_NAME" ]]; then
  SUBDOMAIN="@"
elif [[ "$FQDN" =~ \.$ZONE_NAME$ ]]; then
  SUBDOMAIN="${FQDN%.$ZONE_NAME}"
else
  error_exit "FQDN '$FQDN' does not belong to zone '$ZONE_NAME'"
fi

# === DNS Functions ===
create_record() {
  echo "Creating A record for $FQDN -> $IP"
  RESPONSE=$(curl -s -X POST "$API_BASE/zones/$ZONE_ID/dns_records" \
    -H "$AUTH_HEADER" -H "$CONTENT_HEADER" \
    --data "{\"type\":\"A\",\"name\":\"$SUBDOMAIN\",\"content\":\"$IP\",\"ttl\":1,\"proxied\":false}")
    
  [[ $(echo "$RESPONSE" | jq -r '.success') != "true" ]] && error_exit "Failed to create DNS record: $(echo "$RESPONSE" | jq -r '.errors[]?.message')"
  echo "Record created."
}

delete_record() {
  echo "Deleting A record for $FQDN"
  
  # Get all 'A' records for the zone
  RECORDS=$(curl -s -X GET "$API_BASE/zones/$ZONE_ID/dns_records?type=A" \
    -H "$AUTH_HEADER" -H "$CONTENT_HEADER")
  
  # Find the matching record by exact domain name
  if [[ -n "$IP" ]]; then
    # If IP is provided, match both domain and IP
    RECORD_ID=$(echo "$RECORDS" | jq -r --arg ip "$IP" --arg fqdn "$FQDN" \
      '.result[] | select(.content == $ip and .name == $fqdn) | .id')
  else
    # Match only by domain name
    RECORD_ID=$(echo "$RECORDS" | jq -r --arg fqdn "$FQDN" \
      '.result[] | select(.name == $fqdn) | .id')
  fi
  
  # If no exact match by FQDN, try with subdomain format
  if [[ -z "$RECORD_ID" || "$RECORD_ID" == "null" ]]; then
    if [[ -n "$IP" ]]; then
      RECORD_ID=$(echo "$RECORDS" | jq -r --arg ip "$IP" --arg subdomain "$SUBDOMAIN" \
        '.result[] | select(.content == $ip and .name == $subdomain) | .id')
    else
      RECORD_ID=$(echo "$RECORDS" | jq -r --arg subdomain "$SUBDOMAIN" \
        '.result[] | select(.name == $subdomain) | .id')
    fi
  fi
  
  if [[ -z "$RECORD_ID" || "$RECORD_ID" == "null" ]]; then
    error_exit "No DNS record found for $FQDN"
  fi

  echo "Found record ID: $RECORD_ID"
  
  RESPONSE=$(curl -s -X DELETE "$API_BASE/zones/$ZONE_ID/dns_records/$RECORD_ID" \
    -H "$AUTH_HEADER" -H "$CONTENT_HEADER")
    
  [[ $(echo "$RESPONSE" | jq -r '.success') != "true" ]] && error_exit "Failed to delete DNS record: $(echo "$RESPONSE" | jq -r '.errors[]?.message')"
  echo "Record deleted successfully."
}

# === Main Logic ===
case "$MODE" in
  create) create_record ;;
  delete) delete_record ;;
  *) error_exit "Invalid mode: $MODE. Use -m create or -m delete" ;;
esac
