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
| `others/ansible/` | PostgreSQL and Redis roles, run by Harness IaCM Ansible ([setup](others/ansible/README.md)) | `.harness/pipelines/ansible.yaml` (input `PLAYBOOK`) |
| `others/` | Otherwise unmaintained / parked: `airflow-dags`, `jenkins-inventory`, `crawl4ai`, `vault-examples`, `misc` | none |
| `manifest.yaml` | Repository metadata and the Trivy scan settings the pipeline reads | |
| `.harness/` | Harness pipeline definition (Plan -> Scan -> Approve -> Execute) and the scripts it runs | |

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

## Changes shown in Harness

`.harness/scripts/tf-report.sh` publishes each run's resource addresses and actions, never values.

| Where | What you see |
|---|---|
| **Tests** tab | One group per target, phase (`planned`, `applied`) and action: create, update, replace, delete, forget, move, output. **Rows are resource changes, not tests**, so all of them show as passed. Don't read "passed" as approved or safe |
| **Annotations** tab | A card with counts and up to 100 addresses; warning style when something is deleted or replaced |
| Step log | The change summary, as before |

`applied` appears only after a successful apply or destroy. After a failed one, read the log to see what completed.

Annotations need the `CI_ENABLE_HARNESS_ANNOTATIONS` and `PIPE_HARNESS_ANNOTATIONS` feature flags; ask Harness Support to enable them. Without `hcli` in the step, the log says so and the run continues.

## Trivy scan before approval

The pipeline runs Plan -> **Scan** -> Approve -> Execute. `.harness/scripts/trivy-scan.sh` scans the target's `.tf` files, the modules they use, and local Helm charts referenced by the target's env files. Charts are rendered with their **own default values**, not the values Terraform deploys. Remote charts (Nexus, Kestra and others) are not scanned. This is a misconfiguration scan only: no secret or image scanning.

**A clean Terraform result is weak evidence.** Trivy has few or no checks for libvirt, Talos, Pi-hole or PostgreSQL. In testing it caught an open AWS rule but missed a privileged Kubernetes pod written in Terraform and a `root:password` cloud-init.

- Settings are in `manifest.yaml` under `pipeline.platformScans.iac`; `.harness/scripts/read-manifest.sh` checks them in the first step of each run.

| Key | Effect |
|---|---|
| `enabled` | `false` skips the whole Scan stage |
| `severity` | Levels that fail the gate (default here: HIGH, CRITICAL) |
| `ignoreFailure` | `true` scans and reports, but never blocks |
| `ignoreFile` | Accepted finding IDs, one per line with a reason. An ID there is ignored for **every** target |
| `version`, `digest` | The Trivy image; both required |

- One target can override `enabled` or `ignoreFailure`, under `pipeline.targets.<name>.scan`.
- A failed gate stops Approve and Execute. `ACTION=destroy` always skips the scan.
- **A commit can turn the scan off.** The approval message and the `read manifest` log show the setting: review changes to `manifest.yaml` like pipeline code.
- Findings go to Harness as SARIF through the STO `CustomIngest` step. If that step fails, it is ignored and the gate still applies; the findings are also in the `trivy scan` log.
- The image runs offline with its built-in checks. Trivy 0.69.4-0.69.6 releases were malicious (CVE-2026-33634): verify a new version and digest before updating `manifest.yaml`.

## Provider downloads through Nexus

`make init` can download providers through the Nexus proxy repository `terraform-proxy` (declared in `kube-addons/nonprod/envs/kube-orchestrations/nexus.yaml`). `terraform-nexus.tfrc` redirects `registry.terraform.io`; provider sources and lock files don't change.

| Setting | Behaviour |
|---|---|
| `NEXUS=auto` (default) | Nexus if it answers over trusted TLS, otherwise direct. If `init` through Nexus fails, one direct retry |
| `NEXUS=1` | Require Nexus, e.g. `make -C infra init NEXUS=1` |
| `NEXUS=0` | Direct |

The fallback matters because Nexus runs in the cluster built from this repository.

Nexus uses a self-signed certificate. The pipeline trusts the pinned copy `certs/local-proxy.crt` for `terraform init` only. Terraform on macOS only trusts the keychain, so a Mac that doesn't trust this certificate downloads directly. The certificate is also marked as a certificate authority; replacing it with a private CA plus an ordinary server certificate is safer than trusting it on a Mac. It expires on 2027-10-18. Update `certs/local-proxy.crt` whenever the certificate changes.

