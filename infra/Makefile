TF=terraform

# State is stored in the Harness IaCM workspace (backend "http" in versions.tf).
# Needs TF_HTTP_PASSWORD (a Harness API token) in the environment.
init:
	$(TF) init -input=false

# One-time move of the old R2 state into Harness. Terraform asks before copying.
# Do not use -reconfigure here: it switches backend without copying the state.
.PHONY: migrate-state
migrate-state:
	$(TF) init -migrate-state

lint:
  $(TF) --call-module-type=all --enable=rule=terraform_naming_convention
.PHONY: lint

.PHONY: validate
validate:
	$(TF) validate

.PHONY: plan
plan:
	$(TF) plan

.PHONY: apply
apply:
	$(TF) apply

.PHONY: apply-auto
apply-auto:
	$(TF) apply -auto-approve

.PHONY: destroy
destroy:
	$(TF) destroy

.PHONY: destroy-auto
destroy-auto:
	$(TF) destroy -auto-approve
