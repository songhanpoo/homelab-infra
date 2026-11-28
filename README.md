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
| `.harness/` | Harness pipeline definition (Plan -> Approve -> Execute) and the script it runs | |

`kube-addons/prod` and `kube-addons/nonprod` are two tiers of the **same cluster**, not separate environments. Each folder (and `infra/`) has its own state in its own Harness IaCM workspace. Apply `infra`, then `kube-addons/prod`, then `databases/`, then `kube-addons/nonprod`; destroy in reverse.

## Run Terraform with make

The pipeline runs the same `make` targets (shared in `terraform.mk`), so use `make` locally too. Set `TF_HTTP_PASSWORD` to a Harness API token, then:

```sh
make -C <folder> init
make -C <folder> check
make -C <folder> plan
make -C <folder> apply
```

Local results reflect your working tree and your versions of local files. The pipeline uses the pushed branch.

**`infra` must go through `make`.** The libvirt provider keeps each cloud-init ISO as a file under `TMPDIR` and plans to create it again when that file is missing. `infra/Makefile` sets one fixed `TMPDIR` and, before each plan or apply, rebuilds the ISOs with the local-only helper `infra/cloudinit-files/`. A bare `terraform plan` skips both steps. This relies on libvirt provider 0.9.1; check it again when upgrading.

Editing cloud-init settings does **not** update the ISO volume on the host (`ignore_changes` in `modules/kvm`). Replace the volume on purpose when you need that.

Terraform no longer writes `kubeconfig` and `talosconfig`. Run `make -C infra kubeconfig` to write them to `~/.kube/talos-paul/` and `~/.talos/talos-paul/`. This replaces the files there.

## Provider downloads through Nexus

`make init` can download providers through the Nexus proxy repository `terraform-proxy` (declared in `kube-addons/nonprod/envs/kube-orchestrations/nexus.yaml`). `terraform-nexus.tfrc` redirects `registry.terraform.io`; provider sources and lock files don't change.

| Setting | Behaviour |
|---|---|
| `NEXUS=auto` (default) | Nexus if it answers over trusted TLS, otherwise direct. If `init` through Nexus fails, one direct retry |
| `NEXUS=1` | Require Nexus, e.g. `make -C infra init NEXUS=1` |
| `NEXUS=0` | Direct |

The fallback matters because Nexus runs in the cluster built from this repository.

Nexus uses a self-signed certificate. The pipeline trusts the pinned copy `certs/local-proxy.crt` for `terraform init` only. Terraform on macOS only trusts the keychain, so a Mac that doesn't trust this certificate downloads directly. The certificate is also marked as a certificate authority; replacing it with a private CA plus an ordinary server certificate is safer than trusting it on a Mac. It expires on 2027-10-18. Update `certs/local-proxy.crt` whenever the certificate changes.

