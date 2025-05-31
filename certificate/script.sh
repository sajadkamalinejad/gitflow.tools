#!/bin/bash

# Default values
MODE=""
NAMESPACE=""
DOMAINS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -m)
      MODE="$2"
      shift 2
      ;;
    -n)
      NAMESPACE="$2"
      shift 2
      ;;
    -d)
      DOMAINS+=("$2")
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Read from stdin if -d wasn't used
if [[ ${#DOMAINS[@]} -eq 0 ]] && ! [ -t 0 ]; then
  while read -r line; do
    [[ -n "$line" ]] && DOMAINS+=("$line")
  done
fi

# Check required inputs
if [[ "$MODE" != "create" || -z "$NAMESPACE" || ${#DOMAINS[@]} -eq 0 ]]; then
  echo "Usage: $0 -m create -n namespace-name -d domain1 [-d domain2 ...]"
  echo "   or: echo domain1 domain2 | $0 -m create -n namespace-name"
  exit 1
fi

# Output file
CERT_FILE="cert.yml"

# Generate YAML
{
  echo "apiVersion: cert-manager.io/v1"
  echo "kind: Certificate"
  echo "metadata:"
  echo "  name: gitflow-tls"
  echo "  namespace: $NAMESPACE"
  echo "spec:"
  echo "  secretName: gitflow-tls"
  echo "  issuerRef:"
  echo "    name: letsencrypt-dns"
  echo "    kind: ClusterIssuer"
  echo "  dnsNames:"
  for domain in "${DOMAINS[@]}"; do
    echo "  - $domain"
  done
} > "$CERT_FILE"

echo "Certificate manifest saved to $CERT_FILE"
echo "Applying to Kubernetes..."
kubectl create -f "$CERT_FILE"
