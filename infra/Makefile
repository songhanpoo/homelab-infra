# Talos cluster and libvirt VMs. Always run through make, not bare terraform: see TMPDIR below.

# libvirt_cloudinit_disk keeps its ISO under TMPDIR, and Terraform plans to create it again when
# the file at the path in state is missing. A fixed TMPDIR gives the same path on every machine,
# and "prepare" rebuilds the files there, so local and pipeline plans match.
export TMPDIR := /tmp/homelab-terraform
# Created while make reads this file, because terraform init already needs TMPDIR to exist.
TMPDIR_READY := $(shell mkdir -p $(TMPDIR) && chmod 700 $(TMPDIR))

include ../terraform.mk

CLOUDINIT_STATE = $(TMPDIR)/cloudinit-files.tfstate

# Rebuild only the current ISOs. The helper's state holds cloud-init data, so it is removed.
prepare::
	@echo "Preparing cloud-init ISOs in $(TMPDIR)"
	@rm -rf "$(TMPDIR)/terraform-provider-libvirt-cloudinit" "$(CLOUDINIT_STATE)" "$(CLOUDINIT_STATE).backup"
	@$(TF_INIT) -chdir=cloudinit-files init -input=false >/dev/null
	@$(TF) -chdir=cloudinit-files apply -input=false -auto-approve -state="$(CLOUDINIT_STATE)" >/dev/null
	@rm -f "$(CLOUDINIT_STATE)" "$(CLOUDINIT_STATE).backup"

# Write the cluster credentials from state to this machine (replaces the old local_file resources).
CLUSTER ?= talos-paul

.PHONY: kubeconfig
kubeconfig:
	@umask 077; for pair in "kubeconfig_raw:$(HOME)/.kube/$(CLUSTER)/kubeconfig" "talosconfig:$(HOME)/.talos/$(CLUSTER)/talosconfig"; do \
	  name=$${pair%%:*}; dest=$${pair#*:}; tmp="$$dest.new"; mkdir -p "$$(dirname "$$dest")" || exit 1; \
	  if $(TF) output -raw "$$name" > "$$tmp" && [ -s "$$tmp" ]; then mv "$$tmp" "$$dest" && echo "wrote $$dest"; \
	  else rm -f "$$tmp"; echo "could not read output $$name" >&2; exit 1; fi; \
	done

# One-time move of the old R2 state into Harness. Terraform asks before copying.
# Do not use -reconfigure here: it switches backend without copying the state.
.PHONY: migrate-state
migrate-state:
	$(TF) init -migrate-state
