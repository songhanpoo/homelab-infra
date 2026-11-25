# songhanpoo-talos-infra

| Folder | What | Pipeline |
|---|---|---|
| `infra/` | Terraform: Talos, KVM/libvirt VMs, nginx-proxy -> baseline cluster | `.harness/pipelines/iac.yaml` (TARGET=infra) |
| `kube-addons/` | Terraform + Helm: add-ons and services on the running cluster (`charts/`, `modules/`, `envs/`, `manifests/`) | `.harness/pipelines/iac.yaml` (TARGET=kube-addons) |
| `others/` | Unmaintained / parked: `ansible`, `airflow-dags`, `jenkins-inventory`, `crawl4ai`, `vault-examples`, `misc` | none |
| `.harness/` | Harness pipeline definition (Plan -> Approve -> Apply), one file for both targets | |

Environments: `nonprod` and `prod` only. `ENV` selects the env; the R2 state object stays at its existing key (`STATE_ENV=dev` in both Makefiles).

Local use: `export R2_ACCESS_KEY=... R2_SECRET_KEY=... R2_ACCOUNT_ID=...` then `cd infra && make init && make plan`.

Order on a fresh setup: `infra` first, then `kube-addons`.
