TF=terraform

# Platform tier (ingress, storage, DNS, Traefik, metrics). Apply before nonprod; destroy after it.
# State: its own Harness IaCM workspace. Needs TF_HTTP_PASSWORD in the environment.
.PHONY: init
init:
	$(TF) init -input=false

.PHONY: lint
lint:
	$(TF) fmt -check -recursive
	$(TF) fmt -check -recursive ../../modules

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
