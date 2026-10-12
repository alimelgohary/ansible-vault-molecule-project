# ansible-vault-molecule-project

Ansible role that provisions and configures PostgreSQL 16 on Ubuntu 22.04.
Credentials are passed into the role at runtime from HashiCorp Vault using
AppRole authentication. Nothing is hardcoded in the codebase.

---

## What this project covers

- Ansible role with tasks, handlers, templates, defaults, and loops
- HashiCorp Vault KV v2 with AppRole authentication
- Molecule for unit testing with mocked credentials, no Vault needed
- GitHub Actions CI pipeline: lint and Molecule on every push, integration smoke test on push to master

---

## Architecture

Ansible authenticates to Vault using AppRole, fetches the database passwords, then provisions PostgreSQL on the target container — credentials never touch the codebase.

```
┌─────────────────────┐     fetch secrets     ┌─────────────────────┐
│  Ansible control    │ ───────────────────►  │  HashiCorp Vault    │
│  node               │ ◄───────────────────  │  KV v2, AppRole     │
│  (playbook.yml)     │      passwords        └─────────────────────┘
└─────────────────────┘
          │
          │  provision
          ▼
┌─────────────────────┐
│  PostgreSQL         │
│  container          │
│  Ubuntu 22.04 :5432 │
└─────────────────────┘
```

### AppRole authentication flow

```
Ansible                  Vault                    Target host
   │                       │                           │
   │  POST /approle/login  │                           │
   │  (ROLE_ID+SECRET_ID)  │                           │
   │ ─────────────────────►│                           │
   │                       │                           │
   │  short-lived token    │                           │
   │  (TTL: 1 hour)        │                           │
   │ ◄─────────────────────│                           │
   │                       │                           │
   │  GET secret/data/postgres                         │
   │ ─────────────────────►│                           │
   │                       │                           │
   │  appuser_password     │                           │
   │  reportuser_password  │                           │
   │ ◄─────────────────────│                           │
   │                       │                           │
   │  provision PostgreSQL (passwords injected)        │
   │ ──────────────────────────────────────────────── ►│
```

---

## Running on KillerCoda

Use [KillerCoda's Ubuntu playground](https://killercoda.com/playgrounds/scenario/ubuntu) for a
temporary environment with no local setup required.

Paste and run the script below. It handles everything end to end.

```bash
#!/bin/bash
set -euo pipefail

# Install dependencies
sudo apt update && \
sudo apt install -y python3-venv docker.io && \
sudo systemctl start docker

# Clone the repo
git clone https://github.com/alimelgohary/ansible-vault-molecule-project
cd ansible-vault-molecule-project

nohup bash -c 'while true; do git pull origin master > /dev/null 2>&1; sleep 5; done' > /dev/null 2>&1 &

# ========= Molecule Setup & Test =========

python3 -m venv molecule-env
source molecule-env/bin/activate

# ansible          - core engine that runs playbooks and roles
# ansible-lint     - static analysis; catches style and correctness issues before runtime
# molecule         - framework for testing Ansible roles in isolated containers
# molecule-plugins[docker] - Docker driver so Molecule can spin up containers as test hosts
# hvac             - Python client for HashiCorp Vault; used by the hashi_vault collection
pip install ansible ansible-lint molecule molecule-plugins[docker] hvac

# Install Ansible collections:
#   community.postgresql  - modules to manage databases, users, and privileges
#   community.hashi_vault - vault_kv2_get and AppRole auth used in the playbook
#   community.general     - general-purpose utility modules used across the role
ansible-galaxy collection install -r requirements.yml

ansible-lint roles/postgresql

cd roles/postgresql/
molecule test || exit 1
cd ../..

# ========= Vault Setup =========

# Start a Vault container, initialize it, and unseal it.
# Unseal keys and root token are written to unseal-keys.txt.
# Back this file up somewhere safe. If it is lost the Vault
# cannot be unsealed and all secrets inside it are unrecoverable.
./00-initialize-vault.sh

# Enable KV v2, write the secrets, create the policy, enable AppRole,
# and export ROLE_ID and SECRET_ID into this shell session.
# Must be run with `source` so the exports persist. Running it as a
# subshell (./01-setup-vault.sh) would discard the exports and the
# playbook would fail to authenticate to Vault.
source 01-setup-vault.sh

# ========= Test on Inventory =========

# Spin up a target host. inventory.ini already points at this container.
# The image is pinned by SHA rather than a floating tag so the test
# environment is reproducible: a tag like `latest` can silently change
# between runs, causing failures unrelated to your role changes.
sudo docker run -d \
  --name pg_test \
  --privileged \
  --cgroupns=host \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  geerlingguy/docker-ubuntu2204-ansible@sha256:7c37bfb098b8f52d18ee730a65f946a2535acab19b6f491418c2ed788d51974a

# Authenticate to Vault using ROLE_ID and SECRET_ID, fetch the passwords,
# and provision PostgreSQL on the container defined in inventory.ini.
ansible-playbook -i inventory.ini playbook.yml
```

---

## What a successful run produces

After the playbook completes, the `pg_test` container will have:

- PostgreSQL 16 installed and running on **port 5432**
- Two databases created: `appdb` and `reportdb`
- Two users created with passwords sourced from Vault:
  - `appuser`: full privileges on `appdb`
  - `reportuser`: full privileges on `reportdb`
- PostgreSQL configured to accept connections on all interfaces (`listen_addresses = '*'`),
  with `scram-sha-256` authentication required for TCP connections and `peer` authentication
  for local Unix socket connections

---

## AppRole authentication flow

Vault AppRole is a machine identity system. Instead of a username and password
for humans, it uses two values:

- **Role ID**: identifies which AppRole to use, like a username
- **Secret ID**: proves you are allowed to use that role, like a password

The playbook sends both to Vault, receives a short-lived token valid for 1 hour,
and uses that token to read the secrets.

---

## Vault secrets layout

```
secret/
└── postgres/
    ├── appuser_password
    └── reportuser_password
```

Policy `ansible-postgres` grants read-only access to `secret/data/postgres`
and nothing else.

---

## Project structure

```
.
├── .github/workflows/
│   ├── ci.yml               # lint + molecule on every push
│   └── integration.yml      # full Vault smoke test on push to master
├── roles/postgresql/
│   ├── defaults/main.yml
│   ├── handlers/main.yml
│   ├── meta/main.yml
│   ├── molecule/default/
│   ├── tasks/
│   └── templates/
├── 00-initialize-vault.sh
├── 01-setup-vault.sh
├── inventory.ini
├── playbook.yml
└── requirements.yml
```
