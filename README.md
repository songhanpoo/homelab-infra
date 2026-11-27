# songhanpoo-talos-infra

| Folder | What | Pipeline |
|---|---|---|
| `infra/` | Terraform: Talos, KVM/libvirt VMs, nginx-proxy -> baseline cluster | `.harness/pipelines/iac.yaml` (TARGET=infra) |
| `databases/nonprod/` | PostgreSQL databases, roles and grants (apply before `kube-addons/nonprod`) | `.harness/pipelines/iac.yaml` (TARGET=databases/nonprod) |
| `databases/prod/` | Empty placeholder for production databases | Not in the pipeline yet |
| `kube-addons/prod/` | Platform tier: ingress, NFS storage, DNS, Traefik, metrics | `.harness/pipelines/iac.yaml` (TARGET=kube-addons/prod) |
| `kube-addons/nonprod/` | Application tier: Nexus, Kestra, Harness delegate, apps, databases | `.harness/pipelines/iac.yaml` (TARGET=kube-addons/nonprod) |
| `kube-addons/charts/` | Local Helm charts (`nonprod/charts` links here) | |
| `modules/` | Terraform modules for both roots, referenced as `../modules/<name>` | `.harness/pipelines/iac.yaml` (format check) |
| `others/` | Unmaintained / parked: `ansible`, `airflow-dags`, `jenkins-inventory`, `crawl4ai`, `vault-examples`, `misc` | none |
| `.harness/` | Harness pipeline definition (Plan -> Approve -> Apply), one file for both targets | |

`kube-addons/prod` and `kube-addons/nonprod` are two tiers of the **same cluster**, not separate environments. Each folder (and `infra/`) has its own state in its own Harness IaCM workspace. Apply `infra`, then `kube-addons/prod`, then `databases/`, then `kube-addons/nonprod`; destroy in reverse.

Local use: `export TF_HTTP_PASSWORD=<Harness API token>`, then `make -C <folder> init` and `make -C <folder> plan`.

