#!/bin/bash
set -euo pipefail
# Create config directories
mkdir -p ./vault/config ./vault/data ./vault/logs
chown 100 -R vault/   # Set owner to the vault user inside the container
cat > ./vault/config/vault.hcl <<EOF
disable_mlock = true
ui = true

storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

api_addr = "http://0.0.0.0:8200"

log_file  = "/vault/logs/vault.log"
log_level = "info"
EOF

docker run -d \
  --name vault \
  --cap-add=IPC_LOCK \
  -p 8200:8200 \
  -v $(pwd)/vault/config:/vault/config \
  -v $(pwd)/vault/data:/vault/data \
  -v $(pwd)/vault/logs:/vault/logs \
  hashicorp/vault@sha256:47f14a6acb98f48d798a07df7c83f23a6e636e1cf724c5f8ff165cb32667a1e2 \
  server > /dev/null

docker exec -i \
  -e VAULT_ADDR=http://127.0.0.1:8200 \
  -e VAULT_FORMAT=json \
  vault vault operator init > unseal-keys.txt

./99-unseal-vault.sh
