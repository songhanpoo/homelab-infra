TF=terraform
ENV ?= dev

# Credentials come from the environment (export locally, or Harness secrets in CI):
#   R2_ACCESS_KEY, R2_SECRET_KEY, R2_ACCOUNT_ID
BUCKET_NAME ?= tf-remote-state
R2_ENDPOINT = https://$(R2_ACCOUNT_ID).r2.cloudflarestorage.com
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
		-backend-config="key='/paul/infra/$(ENV)/terraform.tfstate'" \
		-backend-config="access_key=$(R2_ACCESS_KEY)" \
		-backend-config="secret_key=$(R2_SECRET_KEY)" \
		-backend-config='endpoints={s3="$(R2_ENDPOINT)"}' \
		-reconfigure

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
