#!/bin/bash

# Ensure -c is provided
while getopts ":c:" opt; do
  case $opt in
    c)
      length="$OPTARG"
      ;;
    *)
      echo "Usage: $0 -c <length>"
      exit 1
      ;;
  esac
done

# Check if length is set and is a positive number
if ! [[ "$length" =~ ^[0-9]+$ ]] || [ "$length" -le 0 ]; then
  echo "Error: Please provide a valid positive number with -c"
  exit 1
fi

# Generate password
tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
echo
