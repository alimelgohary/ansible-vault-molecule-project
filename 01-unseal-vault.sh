#!/bin/bash
set -euo pipefail


if [[ ! -f unseal-keys.txt ]] ; then
	echo "No unseal keys available"
	exit 1
fi

jq -r '.unseal_keys_b64[:3][]' unseal-keys.txt | xargs -I {} \
  docker exec -i -e VAULT_ADDR=http://127.0.0.1:8200 vault vault operator unseal {} > /dev/null

echo "Vault created, initialized, unsealed successfully"
echo "Login using root token: `jq -r '.root_token' unseal-keys.txt`"
