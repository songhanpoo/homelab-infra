TF=terraform
# Physical R2 state object, pinned to the original "dev" key (changing it would make Terraform
# read a different state file). prod and nonprod share this one state file by design.
STATE_ENV ?= dev

# Credentials come from the environment (export locally, or Harness secrets in CI):
#   R2_ACCESS_KEY, R2_SECRET_KEY, R2_ACCOUNT_ID
BUCKET_NAME ?= tf-remote-state
R2_ENDPOINT = https://$(R2_ACCOUNT_ID).r2.cloudflarestorage.com

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

init:
	$(TF) init \
		-backend-config="bucket=$(BUCKET_NAME)" \
		-backend-config="region=auto" \
		-backend-config="skip_credentials_validation=true" \
		-backend-config="skip_metadata_api_check=true" \
		-backend-config="skip_region_validation=true" \
		-backend-config="skip_requesting_account_id=true" \
		-backend-config="skip_s3_checksum=true" \
		-backend-config="use_path_style=true" \
		-backend-config="key='/paul/kube-addons/$(STATE_ENV)/terraform.tfstate'" \
		-backend-config="access_key=$(R2_ACCESS_KEY)" \
		-backend-config="secret_key=$(R2_SECRET_KEY)" \
		-backend-config='endpoints={s3="$(R2_ENDPOINT)"}' \
		-reconfigure

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
