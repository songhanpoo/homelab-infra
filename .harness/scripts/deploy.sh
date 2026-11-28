#!/bin/sh
# Deploys one service with Helm. Used by .harness/pipelines/cd.yaml; run from the repository root.
#   deploy.sh render <outputs-file>   check inputs, server-side dry run, write RENDER_FINGERPRINT
#   deploy.sh deploy                  deploy only if the commit and manifests match what was shown
# Env: SERVICE, IMAGE_TAG, KUBECONFIG_B64 (the limited "cd-deployer" account);
#      RENDER_FINGERPRINT (deploy).
# The image repository and namespace come from deploy/services/<SERVICE>.yaml, never from run inputs.
set -eu

MODE="${1:?usage: deploy.sh render <outputs-file> | deploy}"
OUTPUTS="${2:-}"
fail() { echo "ERROR: $*" >&2; exit 1; }
case "$MODE" in
  render) [ -n "$OUTPUTS" ] || fail "render needs an outputs file" ;;
  deploy) ;;
  *) fail "unknown mode '$MODE'" ;;
esac

# The whole value must match: grep alone passes if any one line does.
NL='
'
matches() {
  case "$1" in *"$NL"*) return 1 ;; esac
  printf '%s' "$1" | grep -Eqx -- "$2"
}
: "${SERVICE:?}" "${IMAGE_TAG:?}"
matches "$SERVICE" '[a-z][a-z0-9-]{0,39}' || fail "SERVICE is not a valid service name"
# A commit tag as pushed by CI. "latest" and other moving tags are refused.
matches "$IMAGE_TAG" '[0-9a-f]{7,40}' || fail "IMAGE_TAG must be a commit tag (7 to 40 hex characters)"

VALUES="deploy/services/$SERVICE.yaml"
CHART=deploy/charts/web-service
[ -f "$VALUES" ] || fail "no such service: $VALUES"
NAMESPACE=$(sed -n 's/^namespace:[[:space:]]*\([^[:space:]#]*\)[[:space:]]*$/\1/p' "$VALUES")
matches "$NAMESPACE" '[a-z][a-z0-9-]{0,62}' || fail "$VALUES needs exactly one top-level namespace"
case "$NAMESPACE" in
  default|kube-*|cd-deployer|harness-*|kestra-*|kube-orchestrations)
    fail "namespace '$NAMESPACE' is reserved for the platform" ;;
esac

umask 077
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
printf '%s' "${KUBECONFIG_B64:?}" | base64 -d > "$WORK/kubeconfig"
export KUBECONFIG="$WORK/kubeconfig"

COMMIT=$(git -c safe.directory='*' rev-parse HEAD)
echo "Service $SERVICE, tag $IMAGE_TAG, namespace $NAMESPACE, commit $COMMIT"

set -- "$SERVICE" "$CHART" --namespace "$NAMESPACE" --values "$VALUES" --set-string "image.tag=$IMAGE_TAG"
helm template "$@" > "$WORK/manifests.yaml"
FINGERPRINT=$( { echo "$COMMIT $SERVICE $IMAGE_TAG $NAMESPACE"; cat "$WORK/manifests.yaml"; } | sha256sum | cut -d' ' -f1)

if [ "$MODE" = render ]; then
  echo "----- manifests to deploy (they hold no secret values) -----"
  cat "$WORK/manifests.yaml"
  echo "------------------------------------------------------------"
  helm list --namespace "$NAMESPACE" --filter "^$SERVICE\$" --all
  # Asks the cluster to validate the change (permissions, admission rules) without saving it.
  helm upgrade --install "$@" --dry-run=server >/dev/null
  echo "Server dry run passed."
  echo "RENDER_FINGERPRINT=$FINGERPRINT" > "$OUTPUTS"
else
  [ "$FINGERPRINT" = "${RENDER_FINGERPRINT:?}" ] ||
    fail "the commit or the manifests differ from what was approved. Nothing was changed; run the pipeline again."
  # --atomic: a rollout that doesn't become ready is rolled back (a first install is removed).
  if ! helm upgrade --install "$@" --atomic --wait --timeout "${HELM_TIMEOUT:-5m}" --history-max 10; then
    fail "deployment failed and Helm rolled it back. Check the pod events and logs in namespace $NAMESPACE."
  fi
  helm status "$SERVICE" --namespace "$NAMESPACE"
fi
