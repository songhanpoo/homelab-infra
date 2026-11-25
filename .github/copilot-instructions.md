# Copilot instructions for this Terraform/Talos/libvirt infra repo

Goal

- Manage a Talos Kubernetes cluster (and related infra) via Terraform, primarily on KVM/libvirt, using the Talos provider.
- Root config orchestrates providers and environment; [modules/talos/main.tf](modules/talos/main.tf) encapsulates Talos cluster setup. Secondary module exists at [modules/dockers/main.tf](modules/dockers/main.tf).

Repo layout (open these first)

- Root Terraform: [main.tf](main.tf), [providers.tf](providers.tf), [versions.tf](versions.tf), [variables.tf](variables.tf), [locals.tf](locals.tf), [outputs.tf](outputs.tf)
- Modules: [modules/talos](modules/talos), [modules/dockers](modules/dockers)
- Env example: [envs/dev.yaml](envs/dev.yaml)
- Editor config: [.vscode/settings.json](.vscode/settings.json)
- Provider caches (versions, debug docs): [.terraform](.terraform), including Talos provider [README](.terraform/providers/registry.terraform.io/siderolabs/talos/0.9.0/darwin_arm64/README.md) and libvirt provider [README](.terraform/providers/registry.terraform.io/dmacvicar/libvirt/0.9.1/darwin_arm64/README.md)

Architecture & data flow

- Root defines providers and passes variables/locals into modules. Outputs expose cluster artifacts.
- Module resolution: see [.terraform/modules/modules.json](.terraform/modules/modules.json) where key "kvm" maps to [modules/talos](modules/talos). Treat [modules/talos/main.tf](modules/talos/main.tf) as the primary cluster module.
- Talos-specific resources typically include generating machine secrets/configs, applying configs, bootstrapping, and kubeconfig management. In this repo, file writes are currently commented out in [`modules/talos/main.tf`](modules/talos/main.tf):
  ```
  # resource "local_file" "kubeconfig" { ... depends_on = [talos_cluster_kubeconfig.this] }
  # resource "local_file" "talosconfig" { ... depends_on = [data.talos_client_configuration.this] }
  ```
  Prefer the Talos provider’s resource-based kubeconfig flow (see “Talos provider notes”).

Developer workflow

- Init/plan/apply:
  - terraform init
  - terraform plan
  - terraform apply
- Formatting: VS Code enforces HashiCorp Terraform formatter and 2-space tabs via [.vscode/settings.json](.vscode/settings.json). Avoid reformatting to different styles.
- Provider versioning:
  - Pinning is via [versions.tf](versions.tf) and [.terraform.lock.hcl](.terraform.lock.hcl). Use `terraform init -upgrade` if you intentionally bump versions.

Talos provider notes (based on provider docs present in repo cache)

- Use the resource `talos_cluster_kubeconfig` (data source is deprecated) to auto-regenerate kubeconfig before expiry (~< 1 month). See provider changelog excerpts in [.terraform/providers/.../CHANGELOG.md](.terraform/providers/registry.terraform.io/siderolabs/talos/0.9.0/darwin_arm64/CHANGELOG.md).
- `talos_cluster_health` can skip Kubernetes checks via `skip_kubernetes_checks = true` when desired.
- `talos_machine_configuration` defaults to `docs = false` and `examples = false` in v0.6.x+; set them to true only if you explicitly need documentation in generated configs.
- Provider debugging (when needed): follow [.terraform/providers/registry.terraform.io/siderolabs/talos/0.9.0/darwin_arm64/README.md](.terraform/providers/registry.terraform.io/siderolabs/talos/0.9.0/darwin_arm64/README.md) to run the provider in VS Code debug and use TF_REATTACH_PROVIDERS.

libvirt provider notes

- New libvirt provider requires explicit disk `format` (e.g., "qcow2" or "raw"); capacity is auto-computed. See example and notes in [.terraform/providers/registry.terraform.io/dmacvicar/libvirt/0.9.1/darwin_arm64/README.md](.terraform/providers/registry.terraform.io/dmacvicar/libvirt/0.9.1/darwin_arm64/README.md).
- Schema aims to mirror libvirt XML with minimal abstraction; model what you need directly.

Patterns & conventions in this repo

- Keep module boundaries clean: define inputs in [variables.tf](variables.tf)/[modules/talos/variables.tf](modules/talos/variables.tf), compute in [locals.tf](locals.tf)/[modules/talos/locals.tf](modules/talos/locals.tf), expose artifacts in [outputs.tf](outputs.tf)/[modules/talos/outputs.tf](modules/talos/outputs.tf).
- Use explicit provider version constraints in [versions.tf](versions.tf); don’t rely on implicit upgrades.
- File outputs (kubeconfig/talosconfig) are currently commented; if you enable them, write under `${pathexpand("~")}/.kube/${var.cluster.name}` and `${pathexpand("~")}/.talos/${var.cluster.name}` as shown in [modules/talos/main.tf](modules/talos/main.tf).

Gotchas

- Mixing Talos provider data sources and resources: prefer resource forms where available (e.g., `talos_cluster_kubeconfig` resource).
- When updating Talos provider, check deprecations in the cached [CHANGELOG](.terraform/providers/registry.terraform.io/siderolabs/talos/0.9.0/darwin_arm64/CHANGELOG.md) before changing data sources/resources.
- Avoid editing files under [.terraform](.terraform) directly; they are managed by Terraform.

If any section is unclear (e.g., envs usage, module inputs/outputs in your [main.tf](main.tf)), tell me which pieces to expand and I will iterate.
