#!/usr/bin/env bash

set -euo pipefail

policies=$(aws iam list-attached-role-policies --role-name $1 | jq -r '.AttachedPolicies[].PolicyArn')

ecoded_doc=$(/bin/echo -n $policies | base64)

jq -n --arg ecoded_doc "$ecoded_doc" '{"ecoded_doc":$ecoded_doc}'
