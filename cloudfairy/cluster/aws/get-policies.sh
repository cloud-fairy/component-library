#!/usr/bin/env sh    

set -euo pipefail

policies=$(aws iam list-attached-role-policies --role-name $1 | jq -r '.AttachedPolicies[].PolicyArn')

ecoded_doc=$(echo "$policies\c" | base64)

jq -n --arg ecoded_doc "$ecoded_doc" '{"ecoded_doc":$ecoded_doc}'
