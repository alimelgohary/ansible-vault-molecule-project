#!/bin/bash
set -euo pipefail
 
# ─── Args ─────────────────────────────────────────────────────────────────────
read -rsp "Vault token: " VAULT_TOKEN
echo ""
 
if [[ -z "$VAULT_TOKEN" ]]; then
  echo "Error: VAULT_TOKEN is required." >&2
  exit 1
fi
 
# ─── Config ───────────────────────────────────────────────────────────────────
VAULT_CONTAINER="vault"
POLICY_NAME="ansible-postgres"
ROLE_NAME="ansible-provisioner"
SECRET_PATH="secret/data/postgres"
DB_PASSWORD="changeme123"
REPLICATION_PASSWORD="replication456"
APPUSER_PASSWORD="APPUSER123456"
REPORTUSER_PASSWORD="REPORTUSER123"
 
# ─── Helper ───────────────────────────────────────────────────────────────────
vault_exec() {
  docker exec \
    -e VAULT_ADDR="http://127.0.0.1:8200" \
    -e VAULT_TOKEN="$VAULT_TOKEN" \
    "$VAULT_CONTAINER" vault "$@"
}
 
echo "==> [1/5] Enabling KV secrets engine at secret/"
vault_exec secrets enable -path=secret kv-v2 2>/dev/null || echo "    Already enabled, skipping."
 
echo "==> [2/5] Writing secret to $SECRET_PATH"
vault_exec kv put secret/postgres \
  db_password="$DB_PASSWORD" \
  replication_password="$REPLICATION_PASSWORD" \
  appuser_password="$APPUSER_PASSWORD" \
  reportuser_password="$REPORTUSER_PASSWORD"
 
echo "==> [3/5] Writing policy: $POLICY_NAME"
docker exec \
  -e VAULT_ADDR="http://127.0.0.1:8200" \
  -e VAULT_TOKEN="$VAULT_TOKEN" \
  "$VAULT_CONTAINER" /bin/sh -c 'vault policy write ansible-postgres - <<EOF
path "secret/data/postgres" {
  capabilities = ["read"]
}
EOF
'
 
echo "==> [4/5] Enabling AppRole auth method"
vault_exec auth enable approle 2>/dev/null || echo "    Already enabled, skipping."
 
echo "==> [5/5] Creating AppRole: $ROLE_NAME"
vault_exec write auth/approle/role/$ROLE_NAME \
  token_policies="$POLICY_NAME" \
  token_ttl=1h \
  token_max_ttl=4h \
  secret_id_ttl=0 \
  secret_id_num_uses=10 \
  bind_secret_id=true
 
# ─── Output credentials ───────────────────────────────────────────────────────
echo ""
echo "==> Done. Fetching RoleID and SecretID..."
echo ""
 
export ROLE_ID=$(vault_exec read -field=role_id auth/approle/role/$ROLE_NAME/role-id)
export SECRET_ID=$(vault_exec write -f -field=secret_id auth/approle/role/$ROLE_NAME/secret-id)
 
echo "  ROLE_ID:    $ROLE_ID"
echo "  SECRET_ID:  $SECRET_ID"
echo ""
echo "Login test:"
vault_exec write auth/approle/login \
  role_id="$ROLE_ID" \
  secret_id="$SECRET_ID"
 

