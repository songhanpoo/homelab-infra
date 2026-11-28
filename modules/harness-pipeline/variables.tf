variable "org_id" {
  type = string
}

variable "project_id" {
  type = string
}

variable "repo_root" {
  description = "Path to this repository, used to check pipeline files that live in it."
  type        = string
}

variable "default_git" {
  description = "This repository. Operation and CD pipelines always come from it."
  type = object({
    connector_ref = string
    repo_name     = string
    branch        = string
  })
}

variable "pipelines" {
  description = "Pipelines keyed by their identifier. Disabled entries can still be trigger targets."
  type = map(object({
    enabled     = bool
    kind        = string # operation | ci | cd
    name        = string
    description = optional(string, "")
    file_path   = string
    git = optional(object({ # required for ci, not allowed otherwise
      connector_ref = string
      repo_name     = string
      branch        = string # for ci: the release branch
    }))
    repo_name_input = optional(bool, false) # the pipeline takes codebase repoName as a run input
  }))

  validation {
    condition     = alltrue([for p in values(var.pipelines) : contains(["operation", "ci", "cd"], p.kind)])
    error_message = "Pipeline kind must be operation, ci or cd."
  }
  validation {
    condition     = alltrue([for p in values(var.pipelines) : (p.kind == "ci") == (p.git != null)])
    error_message = "A ci pipeline needs its own git block. Operation and cd pipelines come from this repository and must not have one."
  }
}

variable "triggers" {
  description = "Triggers keyed by their identifier. There are deliberately no pull request triggers."
  type = map(object({
    enabled             = bool
    pipeline            = string # a key of var.pipelines
    type                = string # github_push | cron
    name                = optional(string)
    target              = optional(string) # operation pipelines: the TARGET to plan
    cron                = optional(string) # five fields, UTC
    changed_files_regex = optional(string) # github_push only
    webhook_secret_ref  = optional(string) # Harness secret for the GitHub webhook secret
  }))
  default = {}

  validation {
    condition     = alltrue([for t in values(var.triggers) : contains(["github_push", "cron"], t.type)])
    error_message = "Trigger type must be github_push or cron. Pull request triggers are not supported: a fork could run its own scripts with the pipeline's credentials."
  }
  validation {
    condition     = alltrue([for id in keys(var.triggers) : can(regex("^[A-Za-z_][A-Za-z0-9_]*$", id))])
    error_message = "A trigger key is its identifier: letters, digits and underscores, not starting with a digit."
  }
}
