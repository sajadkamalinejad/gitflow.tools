#!/bin/bash

set -e

# Parse arguments
while getopts ":m:d:u:p:P:h:b:e:f:" opt; do
  case $opt in
    m) MODE="$OPTARG" ;;
    d) DB_NAME="$OPTARG" ;;
    u) DB_USER="$OPTARG" ;;
    p) DB_PASS="$OPTARG" ;;
    P) DB_PORT="$OPTARG" ;;
    h) DB_HOST="$OPTARG" ;;
    b) BUCKET="$OPTARG" ;;
    e) ENDPOINT="$OPTARG" ;;
    f) PROFILE="$OPTARG" ;;
    \?) echo "Invalid option -$OPTARG" >&2; exit 1 ;;
    :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
  esac
done

# Check required variables
if [[ -z "$MODE" || -z "$DB_NAME" || -z "$DB_USER" || -z "$DB_PASS" || -z "$DB_PORT" || -z "$DB_HOST" || -z "$BUCKET" || -z "$ENDPOINT" || -z "$PROFILE" ]]; then
  echo "[ERROR] Missing required arguments."
  exit 1
fi

# Export for AWS and PostgreSQL
export AWS_ENDPOINT_URL="$ENDPOINT"
export PGPASSWORD="$DB_PASS"

# Friendly timestamp
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
FILENAME="${TIMESTAMP}-${DB_NAME}.sql"
TMP_FILE="/tmp/${FILENAME}"

if [[ "$MODE" == "backup" ]]; then
  echo "[INFO] Creating backup of $DB_NAME from $DB_HOST..."
  pg_dump -h "$DB_HOST" -U "$DB_USER" -p "$DB_PORT" "$DB_NAME" > "$TMP_FILE"

  echo "[INFO] Uploading to s3://$BUCKET/$FILENAME"
  aws --profile "$PROFILE" s3 cp "$TMP_FILE" "s3://$BUCKET/$FILENAME" --endpoint-url "$AWS_ENDPOINT_URL"

  echo "[INFO] Backup complete."
  rm -f "$TMP_FILE"

elif [[ "$MODE" == "restore" ]]; then
  echo "[INFO] Looking for latest backup of $DB_NAME in $BUCKET..."

  LATEST_FILE=$(aws --profile "$PROFILE" s3 ls "s3://$BUCKET/" --endpoint-url "$AWS_ENDPOINT_URL" | \
    grep -- "-${DB_NAME}.sql" | sort | tail -n 1 | awk '{print $4}')

  if [[ -z "$LATEST_FILE" ]]; then
    echo "[ERROR] No backup found for database $DB_NAME"
    exit 1
  fi

  echo "[INFO] Downloading $LATEST_FILE..."
  aws --profile "$PROFILE" s3 cp "s3://$BUCKET/$LATEST_FILE" "$TMP_FILE" --endpoint-url "$AWS_ENDPOINT_URL"

  echo "[INFO] Restoring $LATEST_FILE to database $DB_NAME on $DB_HOST..."
  psql -h "$DB_HOST" -U "$DB_USER" -p "$DB_PORT" "$DB_NAME" < "$TMP_FILE"

  echo "[INFO] Restore complete."
  rm -f "$TMP_FILE"

else
  echo "[ERROR] Invalid mode. Use -m backup or -m restore"
  exit 1
fi