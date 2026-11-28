# Ansible: PostgreSQL and Redis, run by Harness IaCM Ansible

| File | What | In the Harness pipeline |
|---|---|---|
| `redis.yaml` | Redis on the `redis` group | Yes |
| `postgres.yaml` | PostgreSQL 18 on the `postgres` group. **This server holds data** | No, on purpose |
| `playbooks.yaml` | Both, for local use | No |
| `requirements.yml` | `ansible.posix` collection | |
| `inventories/pg-host` | Inventory for local use | No |

Based on Harness's guide: https://developer.harness.io/infrastructure-as-code-management/use-iacm/configuration-management/get-started
It has **not been run in Harness yet**. The guide doesn't state which plan includes the Ansible step.

## Safeguards
- **Dry run by default.** Changes are made only when the variable `dry_run` is `false`.
- **PostgreSQL** also needs `postgres_confirm=apply-postgres` for real changes.
- **Redis** needs `redis_password`: 16+ characters, no spaces, not the old default (which is public in Git history, so don't use it anywhere).
- Config templates keep a backup of the previous file on the host.

Anyone who can edit the Harness variables or push to the branch can change these.

## 1. Create a new SSH key
Do **not** upload `~/.ssh/id_rsa`: that key was exposed and must be replaced.

```sh
ssh-keygen -t ed25519 -f ~/.ssh/ansible_homelab -C harness-ansible -N ''
ssh-copy-id -i ~/.ssh/ansible_homelab.pub ubuntu@192.168.1.110
ssh -i ~/.ssh/ansible_homelab -o IdentitiesOnly=yes ubuntu@192.168.1.110 'sudo -n true && echo ok'
```

`ssh-copy-id` needs a login that already works. The key has no passphrase so that automation can use it: keep it only on your machine and in Harness.
Editing cloud-init in `infra/envs/nonprod.yaml` does **not** update an existing VM. Put the new public key there too for rebuilt VMs.

After the new key works, remove the exposed key from `~/.ssh/authorized_keys` of both `ubuntu` and `root` on each VM, and replace the `root:password` login and SSH password authentication set by cloud-init. Keep one working session open while you do it.

## 2. Inventory (IaCM > Configuration > Inventories > New Inventory)
- Type **Static**; name `homelab_databases` (the identifier must be `homelab_databases`).
- Hosts tab: group `redis` with `192.168.1.110`. Add group `postgres` with `192.168.1.120` only when you set up PostgreSQL.
- Variables tab, Ansible variables:
  - `ansible_user` (string): `ubuntu`
  - `ansible_ssh_private_key_file` (**secret**): a Harness secret holding the new private key. The guide doesn't say whether a text or a file secret is expected.

A Static inventory is used because the Remote (Git file) type is in Beta.

## 3. Playbook (IaCM > Configuration > Playbooks > New Playbook)
- Name and identifier `redis`.
- Git connector `songhanpoo`, repository `homelab-infra`, branch with these files (push first), file path `others/ansible/redis.yaml`.
- Configuration tab: enable **Ansible Galaxy**, requirements file `others/ansible/requirements.yml` (if Harness can't find it, check how it resolves the path).
- Variables tab, Ansible variables:
  - `redis_password` (**secret**): a new password, for example from `openssl rand -base64 32`
  - `dry_run` (string): `true`

## 4. Pipeline
Create a pipeline in project `visabulletin` and paste `.harness/pipelines/ansible.yaml`. It runs on the `paultalos` Kubernetes connector in namespace `harness-executions`. Those pods must reach the VMs on port 22.

## 5. First runs
1. Keep `dry_run=true` and run. Check the log: it should connect, and report what would change.
   On a host that isn't configured yet, a dry run can **fail** at a task that needs a package which isn't installed. That failure alone doesn't mean a real run will fail.
2. Set `dry_run` to `false`, run, then set it back to `true`.

The guide doesn't say how the step checks SSH host keys. If a run fails on host key verification, send the error before turning host key checking off.

Redis listens on `127.0.0.1` only (`redis_bind_address`).

## PostgreSQL (later, deliberately)
`databases/nonprod` also connects to `192.168.1.120`. The role **replaces** `postgresql.conf` and `pg_hba.conf` and restarts PostgreSQL when they change.
1. Back up all databases (`pg_dumpall`) and the two config files. **Test a restore** somewhere else.
2. Compare the server's current files with `roles/postgres/templates/`. Anything set by hand that isn't in the templates will be lost. The template trusts every local (socket) connection and allows `md5` logins from `192.168.1.0/24`.
3. Create a separate `postgres` playbook (`others/ansible/postgres.yaml`) and a separate pipeline.
4. Dry run first. A dry run shows differences but cannot prove the restart is safe.
5. Only then set `dry_run=false` and `postgres_confirm=apply-postgres`, and reset both afterwards.

## Local use
```sh
cd others/ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventories/pg-host --private-key ~/.ssh/ansible_homelab redis.yaml --diff -e @/path/outside/git/redis-vars.yml
```
Put `redis_password` in that variables file rather than on the command line.
