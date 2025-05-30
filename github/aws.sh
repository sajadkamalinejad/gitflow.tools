#!/bin/bash

set -e

usage() {
  echo "Usage: $0 -m set -e <endpoint> -a <access_key> -s <secret_key> -p <profile_name> -r <region>"
  exit 1
}

while getopts "m:e:a:s:p:r:" opt; do
  case "$opt" in
    m) MODE=$OPTARG ;;
    e) ENDPOINT=$OPTARG ;;
    a) ACCESS_KEY=$OPTARG ;;
    s) SECRET_KEY=$OPTARG ;;
    p) PROFILE=$OPTARG ;;
    r) REGION=$OPTARG ;;
    *) usage ;;
  esac
done

if [[ "$MODE" != "set" ]] || [ -z "$ENDPOINT" ] || [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ] || [ -z "$PROFILE" ] || [ -z "$REGION" ]; then
  usage
fi

# Setup AWS CLI profile for DigitalOcean Spaces (or any S3-compatible service)
aws configure set aws_access_key_id "$ACCESS_KEY" --profile "$PROFILE"
aws configure set aws_secret_access_key "$SECRET_KEY" --profile "$PROFILE"
aws configure set region "$REGION" --profile "$PROFILE"
aws configure set output json --profile "$PROFILE"
aws configure set s3.endpoint_url "$ENDPOINT" --profile "$PROFILE"

echo "aws s3 has been set with this profile name: $PROFILE"
