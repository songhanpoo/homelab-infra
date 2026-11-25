# songhanpoo-talos-infra

| Folder | What | Pipeline |
|---|---|---|
| `infra/` | Terraform: Talos, KVM/libvirt VMs, nginx-proxy -> baseline cluster | `.harness/pipelines/iac_infra.yaml` |
| `kube-addons/` | Terraform + Helm: add-ons and services on the running cluster (`charts/`, `modules/`, `envs/`, `manifests/`) | `.harness/pipelines/iac_kube_addons.yaml` |
| `others/` | Unmaintained / parked: `ansible`, `airflow-dags`, `jenkins-inventory`, `crawl4ai`, `vault-examples`, `misc` | none |
| `.harness/` | Harness pipeline definitions (Plan -> Approve -> Apply) | |

Local use: `export R2_ACCESS_KEY=... R2_SECRET_KEY=... R2_ACCOUNT_ID=...` then `cd infra && make init && make plan`.

Order on a fresh setup: `infra` first, then `kube-addons`.
