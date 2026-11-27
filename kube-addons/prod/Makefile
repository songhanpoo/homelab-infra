TF=terraform
# Pi-hole's API can't take concurrent writes: parallel record changes fail (EOF, connection
# reset or status 400) even though a record may still be saved. Change one at a time.
SERIAL=-parallelism=1

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
	$(TF) apply $(SERIAL)

.PHONY: apply-auto
apply-auto:
	$(TF) apply -auto-approve $(SERIAL)

.PHONY: destroy
destroy:
	$(TF) destroy $(SERIAL)

.PHONY: destroy-auto
destroy-auto:
	$(TF) destroy -auto-approve $(SERIAL)
