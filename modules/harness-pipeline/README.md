# Module: harness-pipeline

Onboards Harness pipelines from Git and creates their triggers. Configured in
`infra/envs/nonprod.yaml` (`harness.pipelines`, `harness.triggers`) and called from
`infra/harness-pipeline.tf`. Everything starts `enabled: false`.

## Pipeline kinds

| Kind | Source | Triggers allowed | What a triggered run does |
|---|---|---|---|
| `operation` | this repository | `github_push`, `cron` | **Plan only** (`ACTION=plan`) for one `TARGET` |
| `ci` | its own `git` block | `github_push` | Builds the release branch (`git.branch`) |
| `cd` | this repository | none | Started by CI chaining or by hand |

These rules are in the module, not in configuration. Pull request triggers can't be expressed: in a pull request, someone's unreviewed scripts would run with the pipeline's credentials. Run inputs are generated with a fixed branch; nothing comes from the webhook payload. `ansible` has no `ACTION` input, so it can't be triggered (its dry run depends on a Harness playbook variable). Cron has a fixed minute and hour in **UTC**, so at most one run a day per trigger.

## Pipelines (onboard only)

Harness reads the YAML from Git. Terraform creates the pipeline with `import_from_git` and then ignores all changes: edit the file through Git. Deletion is blocked (`prevent_destroy`), including `destroy` of `infra`. To stop managing one, run `terraform state rm 'module.harness_pipeline.harness_platform_pipeline.this["<id>"]'` and set `enabled: false`.

Before enabling a pipeline:
1. Its file is on the configured branch. (`next-bulletin`: the CI file isn't on `develop` yet.)
2. No Inline pipeline has the same identifier. Copy its YAML from Harness, compare it with the file (changes made only in Harness would be lost), then delete it. Its run history may no longer be reachable.
3. For `iacm`, apply from your own machine: the pipeline doesn't exist during the change.

## Triggers

A trigger can target a pipeline Terraform doesn't manage, if it exists in Harness. For `github_push`:
- The GitHub connector needs **API access** with a token that has `repo`, `user` and `admin:repo_hook`, and admin rights on the repository, so Harness can register the webhook. Otherwise add the webhook by hand; see the output `harness_webhook_urls`.
- **Webhook secret (recommended).** Without one, anyone who knows the webhook URL (it contains the account ID, which is public in this repository) can send a fake push. The effect is limited to extra runs of the fixed branch. Create a Harness text secret, set `webhook_secret_ref` to its identifier, and put the same value in the GitHub webhook. Harness doesn't document the value format of this field: confirm in the trigger's settings that the secret is attached.
- `changed_files_regex` limits runs by path. Changes only under `.harness/` don't match the example filters.

Deleting a trigger may leave its webhook in GitHub; check the repository settings.

## Roll out one at a time

Enable one entry, then apply only the module from `infra/`, with `TF_HTTP_PASSWORD` set to a token that may manage pipelines and triggers:
```sh
make init
make plan PLAN_ARGS="-target=module.harness_pipeline -out=/tmp/homelab-terraform/harness.tfplan"
make apply PLANFILE=/tmp/homelab-terraform/harness.tfplan && rm /tmp/homelab-terraform/harness.tfplan
```
Check the plan first, check the object in Harness, and for a trigger make one harmless push (or wait for the cron time). Commit and merge the `enabled: true` change; otherwise the next `infra` run from `master` tries to remove it (and is blocked for pipelines).

## Risks

- Whatever is merged to a trigger branch runs with that pipeline's credentials. Protect `master` and the release branches, and review pull requests.
- Plan logs can show secret values, and triggered runs create more of them.
- These behaviours haven't been run against Harness: acceptance of the trigger YAML, the condition operators and webhook registration.
