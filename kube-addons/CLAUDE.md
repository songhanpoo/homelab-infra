# CLAUDE.md

> **Layout changed:** this folder is now two Terraform roots, `prod/` (platform tier) and
> `nonprod/` (applications), each with its own `envs/`, Makefile and Harness workspace.
> `charts/` and `../modules/` are shared. The scoped `*_TARGETS` Make variables, the R2 backend
> and the single `envs/` tree described further down no longer exist.

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A standalone Terraform root that installs add-ons **onto an already-running Talos Kubernetes
cluster**: Helm releases, Kubernetes secrets/namespaces/storage classes, Pi-hole DNS records, a
Dockerised Traefik edge proxy, and per-app PostgreSQL role bootstrapping.

The cluster itself is built by the sibling root `../infra` (Talos/libvirt — see
`../.github/copilot-instructions.md`, which describes *that* root, not this one). Both the
`helm` and `kubernetes` providers here point at `~/.kube/talos-paul/kubeconfig`
(`providers.tf`).

## Commands

All targets live in `Makefile` and wrap `terraform` (`ENV ?= dev`):

- `make init` — **required first step.** `versions.tf` declares a bare `backend "s3" {}`, so a
  plain `terraform init` fails; this target injects the whole Cloudflare R2 backend config
  (bucket, endpoint, keys, state key `/paul/kube-addons/$(ENV)/terraform.tfstate`) and runs
  `-reconfigure`.
- `make validate` / `make plan` / `make apply` / `make apply-auto`
- `make destroy` / `make destroy-auto`

Two Makefile defects — don't mistake these for working targets:

- `lint` is broken: it is indented with spaces (not a tab) and its flags are tflint's, not
  terraform's; tflint isn't installed. Use `terraform fmt -recursive` instead.
- The `.PHONY` declarations are misspelled `.PHONE`, so they are inert.

A full plan touches every release, which is slow. The practical inner loop is to target one
add-on: `terraform plan -target='helm_release.airflow'`,
`terraform apply -target='module.airflow_db'`.

Toolchain in use: Terraform v1.12.2, Helm v3.11.0.

## Architecture: everything is driven by `envs/dev.yaml`

`main.tf:1-3` decodes `envs/dev.yaml` once into `local.config`. Almost every resource then
reads `local.config.<addon>.{name,repository,chart,version,namespace,values_yaml}` — `main.tf`
is a thin shell, and **reconfiguring an add-on is normally a YAML edit, not an HCL edit**.

`helm_release.nexus` (`main.tf:48-59`) is the canonical shape; a new add-on is one copy of that
~10-line block plus a YAML key. Known variations, all deliberate:

- `ingress_nginx_internal` and `csi_driver_nfs` use the `set = [...]` list form instead of
  `values = [yamlencode(...)]`.
- `airflow` is parked (replaced by Kestra): `envs/dev/kube-orchestrations/airflow.yaml` is fully
  commented out and `helm_release.airflow` uses `for_each = local.airflow` (like `jenkins`), so
  the release is destroyed; `module.airflow_db` is kept so the database survives. Uncomment the
  YAML to bring it back (its password/secret resources in `main.tf` are commented too).
- `airflow` (when enabled) and `crawl4ai` wrap the repo in `try(local.config.X.repository, null)` because they
  point at local charts; `cloudflared` uses `lookup(..., "version", null)`.
- `wait = false` nearly everywhere (homelab churn); `upgrade_install` varies per release —
  don't normalise it.
- The large commented-out blocks in `main.tf` (supabase, drone, vault, harness, stump, floci,
  n8n, nginxproxymanager) are parked add-ons whose config is still live in `envs/dev.yaml`.
  Leave them in place.

### `envs/dev.yaml` map (1083 lines)

`dns` (1), `ingress_nginx_internal` (20), `traefik` (29), `csi_driver_nfs` (107), `n8n` (114),
`thinkread` (192), `nexus` (203), `flaresolver` (346), `outline` (365), `jenkins` (405),
`airflow` (762), `crawl4ai` (964), `metrics_server` (994), `stump` (1014), `floci` (1041),
`cloudflared` (1063).

A chart is vendored locally **iff** `chart:` starts with `./charts/` — there is no other
marker. Vendored: `airflow`, `crawl4ai`, `thinkread`, `stump`, `floci`, `harness`. Everything
else is pulled from its `repository`. Note `charts/airflow` is a full copy of the upstream
Apache Airflow chart: treat it as third-party, don't hand-edit its templates, override through
`values_yaml`.

## Modules

- `../modules/traefik` — runs Traefik + whoami as **Docker containers on a remote host over SSH**
  (`provider "docker"` with `host = "ssh://..."` in `providers.tf`), not in Kubernetes. The
  interesting file is `modules/traefik/locals.tf`: it re-decodes the raw YAML and mechanically
  flattens `traefik.http.routers.*` / `traefik.http.services.*` into Docker labels, so adding a
  router or service needs no HCL change.
- `../modules/pihole-dns` — `for_each` over the `dns.records` map. Adding a hostname is one YAML line.
- `../modules/pg-bootstrap` — reusable per-app bootstrap: creates `<app>_production_db`, an
  optional `<app>_schema`, and up to five roles (`admin_cicd`, `owner`, `app`, `read_only`,
  `support`) gated by `is_create_*` booleans. The grants are chained with explicit `depends_on`
  in that order to dodge provider races — preserve the chain if you add a role. Instantiated as
  `module.airflow_db` and `module.visa_bulletin_db`.
- `../modules/n8n-workflows` — **not wired into `main.tf`**; needs the `kodflow/n8n` provider,
  which is commented out in `versions.tf`. Dormant.
- `../modules/k8s-rbac` — `main.tf` is empty; a stub.

## Conventions

- Terraform fmt, 2-space indent (enforced by `../.vscode/settings.json`). Don't reformat to
  another style.
- Pin every provider in `versions.tf` and keep `.terraform.lock.hcl` in step; use `-upgrade`
  only deliberately. Never edit anything under `.terraform/`.
- Namespaces: add-ons go in `kube-orchestrations`, infra-level in `kube-system`, metrics in
  `kube-monitoring`. Job/task pods run in `harness-executions` (Harness) and `kestra-executions`
  (Kestra task runner / `PodCreate`); each needs its own copies of any secrets the pods use.
- Persistence uses `storageClassName: nfs-csi`, defined at `main.tf:103-115` (Synology NFS at
  `192.168.1.17`, share `/volume2/talos-clusters`).
- Ingress uses `ingressClassName: nginx-internal` with hosts under `*.localdev.me`, resolved by
  Pi-hole and fronted by Traefik; registry hosts use `*.local.proxy`.
- Container images are pulled through the in-cluster Nexus proxy — new `values_yaml` image refs
  should set `registry`/`repository` to `nexus-docker.local.proxy` (private:
  `nexus-docker-private.local.proxy`) rather than Docker Hub.

## Credentials in this tree

This root currently carries **real credentials in plaintext**: `Makefile` (R2 backend keys,
plus commented-out Vault unseal keys and root token), `main.tf` (a GitHub PAT, R2 keys and DB
URLs inside the `kubernetes_secret_v1` blocks), `providers.tf` (Postgres and Pi-hole
passwords), and `envs/dev.yaml` (Jenkins admin, the Airflow metadata DB connection, the
Cloudflare tunnel secret).

Consequences when working here:

- Don't echo those values, and don't paste raw `terraform plan` / `apply` output into chat — it
  renders secret values.
- `make init` places the R2 keys on the command line; don't widen their exposure.
- `main.tf:125` reads `~/.ssh/id_rsa` off the operator's machine, so plans are
  machine-dependent.
