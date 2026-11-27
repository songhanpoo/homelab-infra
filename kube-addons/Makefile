TF=terraform

# Scoped applies for envs/prod (cluster-wide/singleton infra) vs envs/nonprod (kube-orchestrations
# apps) - see envs/prod/** and envs/nonprod/** . This is still ONE shared state file / ONE
# terraform configuration; these targets just restrict a plan/apply to one tier's resources
# via -target, same pattern as targeting a single add-on. On a from-scratch cluster, run
# apply-prod before apply-nonprod (nonprod apps' PVCs/ingress depend on the CSI driver / ingress
# controller / storage class that apply-prod creates).
#
# NONPROD_TARGETS is hand-maintained: any new resource added to main.tf for a kube-orchestrations
# app must be appended here too (Terraform's -target has no "everything except X" shorthand).
PROD_TARGETS = -target=module.traefik -target=module.dns -target=module.floci \
	-target=helm_release.ingress-nginx-internal \
	-target=helm_release.csi-driver-nfs \
	-target=helm_release.metrics_server \
	-target=kubernetes_namespace_v1.kube-monitoring \
	-target=module.storage_classes
	

NONPROD_TARGETS = -target=helm_release.nexus \
	-target=kubernetes_secret.nexus-secret \
	-target=kubernetes_secret.nexus-docker-registries \
	-target=kubernetes_namespace_v1.kube-orchestrations \
	-target=kubernetes_secret_v1.visa_bulletin_dag_credentials \
	-target=helm_release.flaresolver \
	-target=helm_release.airflow \
	-target=kubernetes_secret_v1.git_credentials \
	-target=kubernetes_secret_v1.git_ssh_key \
	-target=helm_release.crawl4ai \
	-target=helm_release.cloudflared \
	-target=module.airflow_db \
	-target=module.visa_bulletin_db \
	-target=helm_release.kestra \
	-target=module.kestra_db \
	-target=helm_release.harness_delegate \
	-target=kubernetes_namespace_v1.harness-executions \
	-target=kubernetes_persistent_volume_claim_v1.harness_executions_nfs \
	-target=kubernetes_namespace_v1.kestra-executions \
	-target=kubernetes_secret.nexus_docker_registries_kestra \
	-target=kubernetes_secret_v1.visa_bulletin_dag_credentials_kestra

# State is stored in the Harness IaCM workspace "homelabkubeaddons" (backend "http" in terraform.tf).
# Needs TF_HTTP_PASSWORD (a Harness API token) in the environment.
init:
	$(TF) init -input=false

# One-time move of the old R2 state into Harness. Terraform asks before copying.
# Do not use -reconfigure here: it switches backend without copying the state.
.PHONY: migrate-state
migrate-state:
	$(TF) init -migrate-state

lint:
	$(TF) fmt -check -recursive
.PHONY: lint

.PHONY: validate
validate:
	$(TF) validate

.PHONY: plan
plan:
	$(TF) plan

.PHONY: plan-prod
plan-prod:
	$(TF) plan $(PROD_TARGETS) $(ARGS)

.PHONY: plan-nonprod
plan-nonprod:
	$(TF) plan $(NONPROD_TARGETS) $(ARGS)

.PHONY: apply
apply:
	$(TF) apply

.PHONY: apply-prod
apply-prod:
	# Pi-hole's API can't take concurrent writes: parallel record creates return 400 even though the record lands.
	$(TF) apply -parallelism=1 $(PROD_TARGETS) $(ARGS)

.PHONY: apply-nonprod
apply-nonprod:
	$(TF) apply $(NONPROD_TARGETS) $(ARGS)

.PHONY: apply-auto
apply-auto:
	$(TF) apply -auto-approve

.PHONY: destroy
destroy:
	$(TF) destroy

.PHONY: destroy-auto
destroy-auto:
	$(TF) destroy -auto-approve
