# songhanpoo-talos-infra

| Folder | What | Pipeline |
|---|---|---|
| `infra/` | Terraform: Talos, KVM/libvirt VMs, nginx-proxy -> baseline cluster | `.harness/pipelines/iac.yaml` (TARGET=infra) |
| `kube-addons/` | Terraform + Helm: add-ons and services on the running cluster (`charts/`, `envs/`, `manifests/`) | `.harness/pipelines/iac.yaml` (TARGET=kube-addons) |
| `modules/` | Terraform modules for both roots, referenced as `../modules/<name>` | `.harness/pipelines/iac.yaml` (format check) |
| `others/` | Unmaintained / parked: `ansible`, `airflow-dags`, `jenkins-inventory`, `crawl4ai`, `vault-examples`, `misc` | none |
| `.harness/` | Harness pipeline definition (Plan -> Approve -> Apply), one file for both targets | |

Environment config: `infra/` reads `envs/nonprod.yaml`; `kube-addons/` loads both `envs/nonprod/` and `envs/prod/`. There is no `ENV` selector. State is in Harness IaCM workspaces: `homelabinfra` for `infra/`, `homelabkubeaddons` for `kube-addons/`.

Local use: `export TF_HTTP_PASSWORD=<Harness API token>`, then `make -C <folder> init` and `make -C <folder> plan`.

Order on a fresh setup: `infra` first, then `kube-addons`.
