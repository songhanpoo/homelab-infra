###############################################################################
# n8n Workflow Module - USCIS Processing Time Crawler
# Uses kodflow/n8n provider to manage n8n workflows as IaC
###############################################################################

# --------------------------------------------------------------------------- #
# Node: Manual Trigger
# --------------------------------------------------------------------------- #
resource "n8n_workflow_node" "manual_trigger" {
  name     = "Manual Trigger"
  type     = "n8n-nodes-base.manualTrigger"
  position = [250, 300]
}

# --------------------------------------------------------------------------- #
# Node: FlareSolverr - Solve Cloudflare challenge
# --------------------------------------------------------------------------- #
resource "n8n_workflow_node" "flaresolverr_request" {
  name     = "Solve Cloudflare"
  type     = "n8n-nodes-base.code"
  position = [450, 300]

  parameters = jsonencode({
    mode       = "runOnceForAllItems"
    language   = "python"
    pythonCode = <<-PYTHON
import requests
import json

FLARESOLVERR_URL = "https://flaresolver.localdev.me/v1"
TARGET_URL = "https://egov.uscis.gov/processing-times/home"

payload = {
    "cmd": "request.get",
    "url": TARGET_URL,
    "maxTimeout": 60000
}

response = requests.post(
    FLARESOLVERR_URL,
    json=payload,
    headers={"Content-Type": "application/json"},
    verify=False
)

if response.status_code != 200:
    raise Exception(f"FlareSolverr error: {response.status_code} - {response.text}")

data = response.json()
if data.get("status") != "ok":
    raise Exception(f"FlareSolverr failed: {data}")

solution = data.get("solution", {})
cookies = solution.get("cookies", [])
user_agent = solution.get("userAgent", "")

# Build cookie dict
cookie_dict = {c["name"]: c["value"] for c in cookies}

return [{
    "json": {
        "cookies": cookie_dict,
        "user_agent": user_agent,
        "raw_cookies": cookies
    }
}]
PYTHON
  })
}

# --------------------------------------------------------------------------- #
# Node: USCIS API Request - Fetch processing time data
# --------------------------------------------------------------------------- #
resource "n8n_workflow_node" "uscis_api_request" {
  name     = "Fetch USCIS Data"
  type     = "n8n-nodes-base.code"
  position = [650, 300]

  parameters = jsonencode({
    mode       = "runOnceForAllItems"
    language   = "python"
    pythonCode = <<-PYTHON
import requests
import json

items = _input.all()
data = items[0].json

cookies = data["cookies"]
user_agent = data["user_agent"]

headers = {
    "accept": "application/json, text/plain, */*",
    "accept-language": "en-US,en;q=0.9",
    "cache-control": "no-cache",
    "pragma": "no-cache",
    "priority": "u=1, i",
    "referer": "https://egov.uscis.gov/processing-times/home",
    "sec-ch-ua": '"Not-A.Brand";v="24", "Chromium";v="146"',
    "sec-ch-ua-mobile": "?0",
    "sec-ch-ua-platform": '"macOS"',
    "sec-fetch-dest": "empty",
    "sec-fetch-mode": "cors",
    "sec-fetch-site": "same-origin",
    "User-Agent": user_agent
}

resp = requests.get(
    "https://egov.uscis.gov/processing-times/api/processingtime/I-140/SCD/136A-EW3",
    cookies=cookies,
    headers=headers
)

if resp.status_code != 200:
    raise Exception(f"USCIS API error: {resp.status_code} - {resp.text}")

result = resp.json()

return [{"json": result}]
PYTHON
  })
}

# --------------------------------------------------------------------------- #
# Node: Display Result
# --------------------------------------------------------------------------- #
resource "n8n_workflow_node" "display_result" {
  name     = "Display Result"
  type     = "n8n-nodes-base.set"
  position = [850, 300]

  parameters = jsonencode({
    mode = "manual"
    fields = {
      values = [
        {
          name  = "processing_time"
          type  = "string"
          value = "={{ JSON.stringify($json) }}"
        }
      ]
    }
  })
}

# --------------------------------------------------------------------------- #
# Connections
# --------------------------------------------------------------------------- #
resource "n8n_workflow_connection" "trigger_to_flaresolverr" {
  source_node         = n8n_workflow_node.manual_trigger.name
  source_output       = "main"
  source_output_index = 0
  target_node         = n8n_workflow_node.flaresolverr_request.name
  target_input        = "main"
  target_input_index  = 0
}

resource "n8n_workflow_connection" "flaresolverr_to_uscis" {
  source_node         = n8n_workflow_node.flaresolverr_request.name
  source_output       = "main"
  source_output_index = 0
  target_node         = n8n_workflow_node.uscis_api_request.name
  target_input        = "main"
  target_input_index  = 0
}

resource "n8n_workflow_connection" "uscis_to_display" {
  source_node         = n8n_workflow_node.uscis_api_request.name
  source_output       = "main"
  source_output_index = 0
  target_node         = n8n_workflow_node.display_result.name
  target_input        = "main"
  target_input_index  = 0
}

# --------------------------------------------------------------------------- #
# Workflow: USCIS Processing Time Crawler
# --------------------------------------------------------------------------- #
resource "n8n_workflow" "uscis_processing_time_crawler" {
  name   = "USCIS Processing Time Crawler"
  active = false

  nodes_json = jsonencode([
    jsondecode(n8n_workflow_node.manual_trigger.node_json),
    jsondecode(n8n_workflow_node.flaresolverr_request.node_json),
    jsondecode(n8n_workflow_node.uscis_api_request.node_json),
    jsondecode(n8n_workflow_node.display_result.node_json)
  ])

  connections_json = jsonencode({
    (n8n_workflow_node.manual_trigger.name) = {
      main = [[{
        node  = n8n_workflow_node.flaresolverr_request.name
        type  = "main"
        index = 0
      }]]
    }
    (n8n_workflow_node.flaresolverr_request.name) = {
      main = [[{
        node  = n8n_workflow_node.uscis_api_request.name
        type  = "main"
        index = 0
      }]]
    }
    (n8n_workflow_node.uscis_api_request.name) = {
      main = [[{
        node  = n8n_workflow_node.display_result.name
        type  = "main"
        index = 0
      }]]
    }
  })
}
