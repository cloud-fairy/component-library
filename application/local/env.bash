#!/usr/bin/env bash

# env.sh

# Change the contents of this output to get the environment variables
# of interest. The output must be valid JSON, with strings for both
# keys and values.
set -eo pipefail

if [ -z ${CI_COMMIT_SHA} ]; then
     ci_commit_sha=""
else ci_commit_sha="$CI_COMMIT_SHA"
fi

cat <<EOF
{
  "CI_COMMIT_SHA": "$ci_commit_sha"
}
EOF