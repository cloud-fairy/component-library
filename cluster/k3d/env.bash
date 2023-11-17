#!/usr/bin/env bash

# env.sh

# Change the contents of this output to get the environment variables
# of interest. The output must be valid JSON, with strings for both
# keys and values.
set -eo pipefail

cat <<EOF
{
  "PWD": "$PWD"
}
EOF