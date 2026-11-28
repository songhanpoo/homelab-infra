# Targets shared by every Terraform root, used both locally and by .harness/scripts/terraform.sh.
# A root's Makefile sets its variables and then includes this file.
# State lives in Harness IaCM: set TF_HTTP_PASSWORD (a Harness API token) first.
#
#   make init | check | plan | apply | destroy      apply-auto and destroy-auto skip the prompt
#   PLAN_ARGS / APPLY_ARGS   extra terraform flags
#   PLANFILE                 saved plan for "make apply"
#   PARALLELISM              limit concurrent changes during apply and destroy
# Works with GNU make 3.81 (macOS) and 4 (pipeline). Recipes must be indented with tabs.

# Must come before any other include: the folder that holds this file.
REPO_ROOT := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))

TF ?= terraform
# "init" downloads providers, through Nexus when it is available (NEXUS=auto|1|0).
TF_INIT = sh $(REPO_ROOT)/scripts/tf-registry.sh $(TF)
MODULES_DIR ?= ../modules
PARALLELISM ?=
PARALLEL_FLAG = $(if $(PARALLELISM),-parallelism=$(PARALLELISM))
PLAN_ARGS ?=
APPLY_ARGS ?=
PLANFILE ?=

.PHONY: init check lint validate prepare plan apply apply-auto destroy destroy-auto

init:
	$(TF_INIT) init -input=false

lint:
	$(TF) fmt -check -recursive
	$(TF) fmt -check -recursive $(MODULES_DIR)

validate:
	$(TF) validate

check: lint validate

# Runs before anything that plans or changes infrastructure. A root adds steps with "prepare::".
prepare::
	@:

plan: prepare
	$(TF) plan $(PLAN_ARGS)

apply: prepare
	$(TF) apply $(APPLY_ARGS) $(PARALLEL_FLAG) $(if $(PLANFILE),"$(PLANFILE)")

apply-auto: prepare
	$(TF) apply -auto-approve $(APPLY_ARGS) $(PARALLEL_FLAG)

destroy: prepare
	$(TF) destroy $(APPLY_ARGS) $(PARALLEL_FLAG)

destroy-auto: prepare
	$(TF) destroy -auto-approve $(APPLY_ARGS) $(PARALLEL_FLAG)
