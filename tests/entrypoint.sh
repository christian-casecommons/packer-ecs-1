#!/bin/bash
set -e -o pipefail

# Configure SSH agent
eval $(ssh-agent -s)
echo "$SSH_PRIVATE_KEY" | ssh-add -

# Execute input command args
exec "$@"