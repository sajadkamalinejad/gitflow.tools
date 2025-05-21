#!/bin/bash

while getopts "d:p:" opt; do
  case $opt in
    d) directory="$OPTARG" ;;
    p) placeholder_value="$OPTARG" ;;
    *) echo "Usage: $0 -d directory -p placeholder_value" >&2; exit 1 ;;
  esac
done

if [[ -z "$directory" || -z "$placeholder_value" ]]; then
  echo "Both -d and -p options are required."
  echo "Usage: $0 -d directory -p placeholder_value"
  exit 1
fi

# Debug: Show matching files before replacement
echo "Searching for files containing 'placeholder'..."
grep -rl 'placeholder' "$directory"

# Replace using | as delimiter to avoid slash issues
find "$directory" -type f \( -name '*.yml' -o -name '*.yaml' \) -exec sed -i "s|placeholder|${placeholder_value//|/\\|}|g" {} +

echo "Done replacing 'placeholder' with '$placeholder_value' in $directory"
