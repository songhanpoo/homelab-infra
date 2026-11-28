#!/bin/sh
# Shows a Terraform plan's changes in Harness. Run from the repository root.
#   tf-report.sh <plan.json> planned|applied
# Env: TARGET. Needs jq.
#
#   Tests tab        .tf-reports/<phase>.xml (JUnit, named in the pipeline step's "reports" block).
#                    Each row is a resource change, not a test, so every row "passes".
#   Annotations tab  one card per target and phase, only where Harness provides "hcli"
#                    (needs the account's annotation feature flags).
#
# Only resource addresses and actions are read. Values are never copied: they can hold secrets.
set -eu

PLAN_JSON="${1:?usage: tf-report.sh <plan.json> planned|applied}"
PHASE="${2:?usage: tf-report.sh <plan.json> planned|applied}"
case "$PHASE" in planned|applied) ;; *) echo "tf-report: unknown phase '$PHASE'" >&2; exit 2 ;; esac
: "${TARGET:?}"
DIR="${REPORT_DIR:-$PWD/.tf-reports}"
LIST_LIMIT=100

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# The same selection as the change summary in terraform.sh.
jq '
  def clean: gsub("[\u0000-\u001f`]"; " ");
  def kind:
    if . == ["delete","create"] or . == ["create","delete"] then "replace"
    elif . == ["no-op"] then "move"
    else join("-") end;
  [ (.resource_changes // [])[]
    | select((.change.actions != ["no-op"] and .change.actions != ["read"]) or .previous_address != null)
    | { action: (.change.actions | kind),
        name: ((.address + (if .previous_address != null then " (moved from " + .previous_address + ")" else "" end)) | clean) } ]
  + [ (.output_changes // {}) | to_entries[]
      | select(.value.actions != ["no-op"])
      | { action: "output", name: (("output." + .key + " (" + (.value.actions | kind) + ")") | clean) } ]
  | sort_by(
      (.action as $a | ["delete","replace","update","create","forget","move","output"] | index($a)) // 99,
      .name)
' "$PLAN_JSON" > "$TMP/changes.json"

mkdir -p "$DIR"
jq -r --arg target "$TARGET" --arg phase "$PHASE" '
  def x: @html;
  ("terraform." + ($target | gsub("[/.]"; "-"))) as $prefix
  | (if length == 0 then [{action: "none", name: ("no changes " + $phase)}] else . end) as $rows
  | ($rows | reduce .[] as $r ([]; if (map(.action) | index($r.action)) then . else . + [{action: $r.action}] end)) as $actions
  | "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
    "<testsuites>",
    ($actions[] | .action as $a | ($rows | map(select(.action == $a))) as $in
      | "  <testsuite name=\"\("\($prefix).\($phase).\($a)" | x)\" tests=\"\($in | length)\" failures=\"0\" errors=\"0\" skipped=\"0\">",
        ($in[] | "    <testcase classname=\"\("\($prefix).\($phase).\($a)" | x)\" name=\"\(.name | x)\" time=\"0\"/>"),
        "  </testsuite>"),
    "</testsuites>"
' "$TMP/changes.json" > "$DIR/$PHASE.xml"
# Names only, no secrets: readable so that Harness can collect it whatever user it runs as.
chmod 755 "$DIR"
chmod 644 "$DIR/$PHASE.xml"
echo "tf-report: wrote $DIR/$PHASE.xml ($(jq length "$TMP/changes.json") change(s))"

if ! command -v hcli >/dev/null 2>&1; then
  echo "tf-report: hcli is not available here, so no annotation was added"
  exit 0
fi

jq -r --arg target "$TARGET" --arg phase "$PHASE" --argjson limit "$LIST_LIMIT" '
  "### Terraform \($phase): \($target)", "",
  if length == 0 then "No changes."
  else
    "| Action | Count |", "|---|---:|",
    (group_by(.action)[] | "| \(.[0].action) | \(length) |"),
    "", "```",
    (.[:$limit][] | "\(.action)  \(.name)"),
    "```",
    (if length > $limit then "", "\(length - $limit) more not listed. See the Tests tab or the step log." else empty end)
  end
' "$TMP/changes.json" > "$TMP/summary.md"

STYLE=info
if [ "$PHASE" = applied ]; then STYLE=success; fi
if jq -e 'any(.[]; .action == "delete" or .action == "replace")' "$TMP/changes.json" >/dev/null; then STYLE=warning; fi

CONTEXT="terraform-$(printf '%s' "$TARGET" | tr '/.' '--')-$PHASE"
hcli annotate --context "$CONTEXT" --summary-file "$TMP/summary.md" --style "$STYLE" ||
  echo "tf-report: hcli could not add the annotation"
