# crawl4ai Helm Chart

A Helm chart for deploying [crawl4ai](https://github.com/unclecode/crawl4ai) web crawler service on Kubernetes.

## Overview

crawl4ai is an advanced web crawler that can extract structured data from web pages using AI and traditional extraction methods. This Helm chart deploys crawl4ai as a stateless service, perfect for integration with N8n workflows and other automation tools.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- At least 2GB RAM available for the crawler service

## Installation

### Basic Installation

```bash
# Add the chart repository (if published)
helm repo add crawl4ai https://your-repo.com/charts
helm repo update

# Or install from local directory
helm install my-crawl4ai ./crawl4ai
```

### Installation with Custom Values

```bash
helm install my-crawl4ai ./crawl4ai -f custom-values.yaml
```

## Configuration

The following table lists the configurable parameters and their default values:

### Basic Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of crawler replicas | `1` |
| `image.repository` | Docker image repository | `unclecode/crawl4ai` |
| `image.tag` | Docker image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |

### Service Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | Service port | `11235` |
| `service.targetPort` | Container target port | `11235` |

### Resources

| Parameter | Description | Default |
|-----------|-------------|---------|
| `resources.limits.cpu` | CPU limit | `1000m` |
| `resources.limits.memory` | Memory limit | `2Gi` |
| `resources.requests.cpu` | CPU request | `500m` |
| `resources.requests.memory` | Memory request | `1Gi` |

### crawl4ai Specific Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `crawl4ai.llm.enabled` | Enable LLM features | `false` |
| `crawl4ai.llm.existingSecret` | Secret containing LLM API keys | `""` |
| `crawl4ai.config.enabled` | Enable custom config | `false` |
| `crawl4ai.config.existingConfigMap` | ConfigMap with config.yml | `""` |

## Usage Examples

### Basic Deployment

```yaml
# values.yaml
replicaCount: 1
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

### With LLM Support

1. Create a secret with your LLM API keys:

```bash
# Create .llm.env file
cat > .llm.env << EOF
OPENAI_API_KEY=sk-your-openai-key
ANTHROPIC_API_KEY=your-anthropic-key
EOF

# Create Kubernetes secret
kubectl create secret generic crawl4ai-llm-env --from-env-file=.llm.env
```

2. Update your values:

```yaml
# values.yaml
crawl4ai:
  llm:
    enabled: true
    existingSecret: "crawl4ai-llm-env"
```

### With Custom Configuration

1. Create a custom config.yml:

```yaml
# config.yml
app:
  title: "My crawl4ai API"
  host: "0.0.0.0"
  port: 8020

llm:
  provider: "openai/gpt-4o-mini"
  api_key_env: "OPENAI_API_KEY"

rate_limiting:
  enabled: true
  default_limit: "500/minute"
```

2. Create a ConfigMap:

```bash
kubectl create configmap crawl4ai-config --from-file=config.yml
```

3. Update your values:

```yaml
# values.yaml
crawl4ai:
  config:
    enabled: true
    existingConfigMap: "crawl4ai-config"
```

### For Production Use

```yaml
# production-values.yaml
replicaCount: 3

resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

crawl4ai:
  llm:
    enabled: true
    existingSecret: "crawl4ai-llm-env"

podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

## Integration with N8n

This chart is designed to work seamlessly with N8n workflows. Here's how to integrate:

### 1. Service-to-Service Communication

Since both services run in the same cluster, N8n can call crawl4ai directly:

```javascript
// N8n HTTP Request Node configuration
{
  "method": "POST",
  "url": "http://my-crawl4ai:11235/crawl",
  "headers": {
    "Content-Type": "application/json"
  },
  "body": {
    "url": "https://example-coffee-shop.com/products",
    "extraction_strategy": {
      "type": "llm",
      "llm_provider": "openai/gpt-4o-mini",
      "instruction": "Extract coffee product information including name, price, origin, and roast level"
    }
  }
}
```

### 2. Coffee Product Extraction Workflow

Example N8n workflow for coffee product crawling:

1. **Trigger Node**: Schedule or webhook
2. **HTTP Request Node**: Call crawl4ai API
3. **Data Processing Node**: Parse and structure the response
4. **Storage Node**: Save to database or send to another service

## API Endpoints

Once deployed, crawl4ai exposes these endpoints:

- `/` - API root
- `/playground` - Interactive testing interface
- `/health` - Health check endpoint
- `/metrics` - Prometheus metrics
- `/crawl` - Main crawling API
- `/schema` - API schema documentation

## Monitoring

The chart includes Prometheus metrics collection:

```yaml
# Enable metrics collection
livenessProbe:
  httpGet:
    path: /health
    port: http
readinessProbe:
  httpGet:
    path: /health
    port: http
```

## Troubleshooting

### Common Issues

1. **Pod OOMKilled**: Increase memory limits
2. **Slow crawling**: Adjust CPU resources or enable autoscaling
3. **LLM errors**: Verify API keys in the secret

### Debug Commands

```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=crawl4ai

# View logs
kubectl logs -l app.kubernetes.io/name=crawl4ai

# Port forward for testing
kubectl port-forward svc/my-crawl4ai 11235:11235

# Test the service
curl http://localhost:11235/health
```

## Upgrading

```bash
helm upgrade my-crawl4ai ./crawl4ai -f values.yaml
```

## Uninstalling

```bash
helm uninstall my-crawl4ai
```

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Links

- [crawl4ai Documentation](https://docs.crawl4ai.com/)
- [crawl4ai GitHub Repository](https://github.com/unclecode/crawl4ai)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/) 