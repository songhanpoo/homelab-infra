# songhanpoo-talos-infra

| Folder | What | Pipeline |
|---|---|---|
| `infra/` | Terraform: Talos, KVM/libvirt VMs, nginx-proxy -> baseline cluster | `.harness/pipelines/iac.yaml` (TARGET=infra) |
| `kube-addons/` | Terraform + Helm: add-ons and services on the running cluster (`charts/`, `modules/`, `envs/`, `manifests/`) | `.harness/pipelines/iac.yaml` (TARGET=kube-addons) |
| `others/` | Unmaintained / parked: `ansible`, `airflow-dags`, `jenkins-inventory`, `crawl4ai`, `vault-examples`, `misc` | none |
| `.harness/` | Harness pipeline definition (Plan -> Approve -> Apply), one file for both targets | |

Environment config: `infra/` reads `envs/nonprod.yaml`; `kube-addons/` loads both `envs/nonprod/` and `envs/prod/`. There is no `ENV` selector. `infra/` state is in the Harness IaCM workspace `homelabinfra` (needs `TF_HTTP_PASSWORD`); `kube-addons/` state stays in R2 under the `dev` key (`STATE_ENV`).

Local use: for `infra/`, `export TF_HTTP_PASSWORD=<Harness API token>` then `make init && make plan`. For `kube-addons/`, export `R2_ACCESS_KEY`, `R2_SECRET_KEY` and `R2_ACCOUNT_ID` instead.

Order on a fresh setup: `infra` first, then `kube-addons`.
