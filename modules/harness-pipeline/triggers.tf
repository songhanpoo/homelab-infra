# What a trigger may do is decided here, not by configuration:
#   operation  plan only (ACTION=plan), for one TARGET, on the fixed branch
#   ci         builds the release branch after a push to it
#   cd         no triggers: started by CI chaining or by hand
# No run input is taken from a webhook payload.

locals {
  triggers = { for id, t in var.triggers : id => t if t.enabled }

  # null when the trigger names a pipeline that doesn't exist; a precondition reports it
  trigger_pipeline = { for id, t in local.triggers : id => lookup(local.pipelines, t.pipeline, null) }
  trigger_kind     = { for id, p in local.trigger_pipeline : id => try(p.kind, "") }
  trigger_branch   = { for id, p in local.trigger_pipeline : id => try(p.git.branch, "") }

  # Run-input variables declared by each triggered operation pipeline, with their allowed values.
  operation_variables = {
    for id, p in local.trigger_pipeline : id => {
      for v in try(yamldecode(file("${var.repo_root}/${p.file_path}")).pipeline.variables, []) :
      v.name => try(split(",", regex("allowedValues\\(([^)]*)\\)", v.value)[0]), [])
    } if try(p.kind, "") == "operation"
  }

  trigger_inputs = {
    for id, t in local.triggers : id => yamlencode({
      pipeline = merge(
        {
          identifier = t.pipeline
          properties = {
            ci = {
              codebase = merge(
                { build = { type = "branch", spec = { branch = local.trigger_branch[id] } } },
                try(local.trigger_pipeline[id].repo_name_input, false) ? { repoName = local.trigger_pipeline[id].git.repo_name } : {}
              )
            }
          }
        },
        local.trigger_kind[id] == "operation" ? {
          variables = [
            { name = "TARGET", type = "String", value = coalesce(t.target, "missing") },
            { name = "ACTION", type = "String", value = "plan" },
            { name = "CONFIRM_DESTROY", type = "String", value = "no" },
          ]
        } : {}
      )
    })
  }

  trigger_sources = {
    for id, t in local.triggers : id => t.type == "cron" ? jsonencode({
      type = "Scheduled"
      spec = { type = "Cron", spec = { type = "UNIX", expression = coalesce(t.cron, "missing") } }
      }) : jsonencode({
      type = "Webhook"
      spec = {
        type = "Github"
        spec = {
          type = "Push"
          spec = {
            connectorRef                = try(local.trigger_pipeline[id].git.connector_ref, "")
            repoName                    = try(local.trigger_pipeline[id].git.repo_name, "")
            autoAbortPreviousExecutions = false
            payloadConditions = concat(
              [{ key = "targetBranch", operator = "Equals", value = local.trigger_branch[id] }],
              t.changed_files_regex == null ? [] : [{ key = "changedFiles", operator = "Regex", value = t.changed_files_regex }]
            )
            headerConditions = []
            actions          = []
          }
        }
      }
    })
  }
}

resource "harness_platform_triggers" "this" {
  for_each = local.triggers

  identifier = each.key
  name       = coalesce(each.value.name, each.key)
  org_id     = var.org_id
  project_id = var.project_id
  target_id  = each.value.pipeline

  yaml = yamlencode({
    trigger = merge(
      {
        identifier         = each.key
        name               = coalesce(each.value.name, each.key)
        enabled            = true
        orgIdentifier      = var.org_id
        projectIdentifier  = var.project_id
        pipelineIdentifier = each.value.pipeline
        tags               = {}
        source             = jsondecode(local.trigger_sources[each.key])
        inputYaml          = local.trigger_inputs[each.key]
      },
      each.value.webhook_secret_ref == null ? {} : { encryptedWebhookSecretIdentifier = each.value.webhook_secret_ref }
    )
  })

  depends_on = [harness_platform_pipeline.this]

  lifecycle {
    precondition {
      condition     = local.trigger_pipeline[each.key] != null
      error_message = "Trigger ${each.key}: pipeline \"${each.value.pipeline}\" is not in the pipelines map."
    }
    precondition {
      condition     = local.trigger_kind[each.key] != "cd"
      error_message = "Trigger ${each.key}: cd pipelines can't have triggers. CI chains to them, or you run them by hand."
    }
    precondition {
      condition     = local.trigger_kind[each.key] != "ci" || (each.value.type == "github_push" && each.value.target == null && each.value.cron == null)
      error_message = "Trigger ${each.key}: a ci pipeline takes only a github_push trigger, without target or cron."
    }
    precondition {
      condition = local.trigger_kind[each.key] != "operation" || (
        contains(try(local.operation_variables[each.key]["ACTION"], []), "plan") &&
        contains(try(local.operation_variables[each.key]["TARGET"], []), coalesce(each.value.target, "missing"))
      )
      error_message = "Trigger ${each.key}: only a pipeline with TARGET and ACTION inputs can be triggered, so that the run is plan only, and target must be one of its TARGET values."
    }
    precondition {
      # fixed minute and hour: at most once a day
      condition     = each.value.type != "cron" || can(regex("^([0-9]|[1-5][0-9]) ([0-9]|1[0-9]|2[0-3]) [0-9*/,?-]+ [0-9A-Z*/,-]+ [0-9A-Z*/,?-]+$", each.value.cron))
      error_message = "Trigger ${each.key}: cron needs five UTC fields with a fixed minute and hour, for example \"0 19 * * *\"."
    }
    precondition {
      condition     = each.value.type == "cron" ? each.value.changed_files_regex == null && each.value.webhook_secret_ref == null : each.value.cron == null
      error_message = "Trigger ${each.key}: cron is only for cron triggers; changed_files_regex and webhook_secret_ref only for github_push."
    }
  }
}
