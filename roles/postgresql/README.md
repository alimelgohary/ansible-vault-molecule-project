# postgresql16
 
An Ansible role that installs and configures PostgreSQL 16 on Ubuntu using the official PGDG repository.
 
## Requirements
 
- Ubuntu 20.04 (Focal), 22.04 (Jammy), or 24.04 (Noble)
- Ansible 2.15+
- `community.postgresql` and `community.general` collections:
```bash
ansible-galaxy collection install -r requirements.yml
```
 
The role installs `python3-debian` automatically as it is required by the `ansible.builtin.deb822_repository` module used to add the PGDG apt repository.
 
## Role Variables
 
### General
 
| Variable | Default | Description |
|---|---|---|
| `postgresql_version` | `"16"` | PostgreSQL major version |
| `postgresql_port` | `5432` | Port PostgreSQL listens on |
| `postgresql_data_dir` | `/var/lib/postgresql/16/main` | Data directory |
| `postgresql_conf_dir` | `/etc/postgresql/16/main` | Configuration directory |
| `postgresql_bin_dir` | `/usr/lib/postgresql/16/bin` | Binary directory |
| `postgresql_service_enabled` | `true` | Enable service on boot |
| `postgresql_service_state` | `started` | Service state |
 
### postgresql.conf Settings
 
Managed via `postgresql_conf_settings` as key/value pairs:
 
```yaml
postgresql_conf_settings:
  listen_addresses: "'*'"
  max_connections: "200"
  shared_buffers: "25% of total RAM (dynamic)"
  timezone: "UTC"
  log_timezone: "UTC"
  wal_level: replica
```
 
`shared_buffers` is calculated dynamically as 25% of the host's total memory using `ansible_facts['memtotal_mb']`.
 
### pg_hba.conf Entries
 
Managed via `postgresql_hba_entries`:
 
```yaml
postgresql_hba_entries:
  - { type: local, database: all, user: postgres, auth_method: peer }
  - { type: local, database: all, user: all, auth_method: peer }
  - { type: host, database: all, user: all, address: "127.0.0.1/32", auth_method: scram-sha-256 }
  - { type: host, database: all, user: all, address: "::1/128", auth_method: scram-sha-256 }
  - { type: host, database: all, user: all, address: "0.0.0.0/0", auth_method: scram-sha-256 }
```
 
### Databases and Users
 
| Variable | Description |
|---|---|
| `postgresql_databases` | List of databases to create |
| `postgresql_users` | List of users to create |
| `postgresql_user_privileges` | List of privilege grants |
| `appuser_password` | **Required.** Password for the app user |
| `reportuser_password` | **Required.** Password for the reporting user |
 
Passwords are passed in as plain variables — the role does not dictate how they are sourced. Common approaches include Ansible Vault, HashiCorp Vault, or environment variables.
 
Defaults:
 
```yaml
postgresql_databases:
  - name: appdb
  - name: reportdb
 
postgresql_users:
  - name: appuser
    password: "{{ appuser_password }}"
  - name: reportuser
    password: "{{ reportuser_password }}"
 
postgresql_user_privileges:
  - user: appuser
    db: appdb
    privs: ALL
  - user: reportuser
    db: reportdb
    privs: ALL
```
 
## Tags
 
| Tag | Tasks |
|---|---|
| `install` | Repository setup and package installation |
| `configure` | postgresql.conf and pg_hba.conf configuration |
| `users` | Database, user, and privilege management |
 
Example:
```bash
ansible-playbook site.yml --tags configure
```
 
## Security
 
User creation tasks use `no_log: true` to prevent passwords from appearing in Ansible output or logs.
 
## Dependencies
 
None.
 
## Example Playbook
 
```yaml
- hosts: db_servers
  become: true
  roles:
    - role: postgresql16
      vars:
        postgresql_databases:
          - name: appdb
            owner: appuser
        postgresql_users:
          - name: appuser
            password: "{{ appuser_password }}"
        postgresql_user_privileges:
          - user: appuser
            db: appdb
            privs: ALL
```
 
 
## Testing
 
This role uses [Molecule](https://molecule.readthedocs.io/) with the Docker driver for testing.
 
Install dependencies:
 
```bash
python3 -m venv molecule-env
source molecule-env/bin/activate
pip install molecule molecule-docker
```
 
Run the full test cycle:
 
```bash
molecule test
```
 
Or step by step:
 
```bash
molecule create     # spin up container
molecule converge   # run the role
molecule verify     # run assertions
molecule destroy    # tear down
```
 
## License
 
MIT
 
## Author
 
[alimelgohary](https://github.com/alimelgohary)

