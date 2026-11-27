#!/bin/sh
# Terraform runner for .harness/pipelines/iac.yaml. Run from the repository root.
#   terraform.sh plan  <outputs-file>  plan, then write HAS_CHANGES and PLAN_FINGERPRINT
#   terraform.sh apply                 plan again, and apply only if it matches PLAN_FINGERPRINT
# Env: TARGET, ACTION (plan|apply|destroy), CONFIRM_DESTROY, TF_HTTP_PASSWORD, and
# SSH_KEY_B64, SSH_KNOWN_HOSTS_B64, KUBECONFIG_B64 for the targets that need them.
set -eu

MODE="${1:?usage: terraform.sh plan <outputs-file> | apply}"
OUTPUTS="${2:-}"   # saved now: "set --" below replaces the arguments
case "$MODE" in
  plan)  [ -n "$OUTPUTS" ] || { echo "ERROR: plan mode needs an outputs file" >&2; exit 1; } ;;
  apply) ;;
  *)     echo "ERROR: unknown mode '$MODE'" >&2; exit 1 ;;
esac
fail() { echo "ERROR: $*" >&2; exit 1; }

# What each target needs. A new root is added here and in the pipeline's TARGET list.
NEEDS_SSH=no
NEEDS_KUBE=no
PARALLELISM=10
case "${TARGET:?}" in
  infra)               NEEDS_SSH=yes ;;                               # libvirt over SSH
  kube-addons/prod)    NEEDS_SSH=yes; NEEDS_KUBE=yes; PARALLELISM=1 ;; # remote Docker; Pi-hole rejects concurrent writes
  kube-addons/nonprod) NEEDS_KUBE=yes ;;
  databases/nonprod)   ;;                                             # connects to PostgreSQL only
  *) fail "unknown TARGET '$TARGET'" ;;
esac

case "${ACTION:?}" in
  plan|apply) ;;
  destroy)
    [ "${CONFIRM_DESTROY:-}" = "destroy-$TARGET" ] || fail "to destroy, set CONFIRM_DESTROY to: destroy-$TARGET" ;;
  *) fail "unknown ACTION '$ACTION'" ;;
esac

if grep -Eq 'backend "http" \{\}' "$TARGET/terraform.tf"; then
  fail "$TARGET/terraform.tf has an empty backend. Add its own Harness workspace addresses first."
fi

if command -v apk >/dev/null 2>&1; then
  apk add --no-cache make openssh-client jq >/dev/null
fi

umask 077
if [ "$NEEDS_SSH" = yes ]; then
  mkdir -p "$HOME/.ssh"
  printf '%s' "${SSH_KEY_B64:?}" | base64 -d > "$HOME/.ssh/id_ed25519"
  printf '%s' "${SSH_KNOWN_HOSTS_B64:?}" | base64 -d > "$HOME/.ssh/known_hosts"
fi
if [ "$NEEDS_KUBE" = yes ]; then
  mkdir -p "$HOME/.kube/talos-paul"
  printf '%s' "${KUBECONFIG_B64:?}" | base64 -d > "$HOME/.kube/talos-paul/kubeconfig"
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT   # plan files hold secrets

COMMIT=$(git -c safe.directory='*' rev-parse HEAD)
echo "Target $TARGET, action $ACTION, commit $COMMIT"

if [ "$MODE" = plan ]; then
  terraform -chdir="$TARGET" fmt -check -recursive
  terraform fmt -check -recursive modules
fi
make -C "$TARGET" init
terraform -chdir="$TARGET" validate

set -- -input=false -lock-timeout=5m -detailed-exitcode -out="$WORK/tfplan"
if [ "$ACTION" = destroy ]; then set -- "$@" -destroy; fi
RC=0
terraform -chdir="$TARGET" plan "$@" || RC=$?
case "$RC" in
  0) HAS_CHANGES=false ;;
  2) HAS_CHANGES=true ;;
  *) fail "terraform plan failed (exit $RC)" ;;
esac

# The summary holds addresses and actions only, never values.
terraform -chdir="$TARGET" show -json "$WORK/tfplan" > "$WORK/plan.json"
jq -r '
  [ (.resource_changes // [])[]
    | select(.change.actions != ["no-op"] and .change.actions != ["read"])
    | (.change.actions | join(",")) + " " + .address ]
  + [ (.output_changes // {}) | to_entries[]
      | select(.value.actions != ["no-op"])
      | (.value.actions | join(",")) + " output." + .key ]
  | sort | .[]' "$WORK/plan.json" > "$WORK/summary"

echo "----- change summary: $TARGET -----"
if [ -s "$WORK/summary" ]; then cat "$WORK/summary"; else echo "no changes"; fi
echo "-----------------------------------"

# Same commit, target, action and list of changes. It does not compare the new values.
FINGERPRINT=$( { echo "$COMMIT $TARGET $ACTION"; cat "$WORK/summary"; } | sha256sum | cut -d' ' -f1)

case "$MODE" in
  plan)
    {
      echo "HAS_CHANGES=$HAS_CHANGES"
      echo "PLAN_FINGERPRINT=$FINGERPRINT"
    } > "$OUTPUTS"
    ;;
  apply)
    [ "$ACTION" != plan ] || fail "ACTION=plan never applies"
    [ "$FINGERPRINT" = "${PLAN_FINGERPRINT:?}" ] ||
      fail "the commit or the list of changes differs from the approved plan. Nothing was changed; run the pipeline again."
    terraform -chdir="$TARGET" apply -input=false -lock-timeout=5m -parallelism="$PARALLELISM" "$WORK/tfplan"
    ;;
esac
