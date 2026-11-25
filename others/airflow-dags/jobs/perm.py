import os
import datetime
from datetime import timedelta
import yaml

from airflow.sdk import DAG
from airflow.providers.cncf.kubernetes.operators.pod import (
    KubernetesPodOperator,
)
from kubernetes.client import models as k8s


def create_dag(dag_id: str) -> DAG:
    # Resolve the config file location relative to this script
    config_path = os.path.join(os.path.dirname(__file__), "dags_config.yaml")
    with open(config_path, "r", encoding="utf-8") as f:
        config = yaml.safe_load(f)

    defaults = config.get("defaults", {})
    dag_configs = config.get("dags", [])

    # Find configuration for the requested DAG ID
    dag_config = next((d for d in dag_configs if d["dag_id"] == dag_id), None)
    if not dag_config:
        raise ValueError(f"DAG config not found for dag_id: {dag_id}")

    # Parse dates and schedules
    start_date_str = dag_config.get("start_date", "2021-01-01")
    start_date = datetime.datetime.strptime(start_date_str, "%Y-%m-%d")

    # Instantiate the DAG
    dag = DAG(
        dag_id=dag_id,
        start_date=start_date,
        schedule=dag_config.get("schedule", "@daily"),
        catchup=dag_config.get("catchup", False),
    )

    # Reconstruct Kubernetes API definitions
    resources_cfg = defaults.get("resources", {})
    resources = k8s.V1ResourceRequirements(
        requests=resources_cfg.get("requests", {"memory": "256Mi", "cpu": "100m"}),
        limits=resources_cfg.get("limits", {"memory": "512Mi", "cpu": "500m"}),
    )

    host_aliases = [
        k8s.V1HostAlias(ip=ha["ip"], hostnames=ha["hostnames"])
        for ha in defaults.get("host_aliases", [])
    ]

    secret_env = [
        k8s.V1EnvFromSource(
            secret_ref=k8s.V1SecretEnvSource(name=defaults["secret_env_name"])
        )
    ]

    # Create task instances
    tasks = {}
    for task_cfg in dag_config.get("tasks", []):
        task_id = task_cfg["task_id"]

        arguments = [f"--scenario={task_cfg['scenario']}"]
        arguments.extend(task_cfg.get("arguments", []))

        task = KubernetesPodOperator(
            task_id=task_id,
            name=task_cfg["name"],
            namespace=defaults["namespace"],
            image=defaults["image"],
            arguments=arguments,
            env_vars={
                "NO_PROXY": "",
                "no_proxy": "",
            },
            env_from=secret_env,
            host_aliases=host_aliases,
            image_pull_policy="Always",
            container_resources=resources,
            get_logs=True,
            is_delete_operator_pod=True,
            retries=task_cfg.get("retries", defaults.get("retries", 0)),
            retry_delay=timedelta(
                minutes=task_cfg.get("retry_delay_minutes", defaults.get("retry_delay_minutes", 5))
            ),
            dag=dag,
        )
        tasks[task_id] = (task, task_cfg.get("dependencies", []))

    # Construct the dependencies hierarchy
    for task_id, (task, dependencies) in tasks.items():
        for dep_id in dependencies:
            if dep_id in tasks:
                tasks[dep_id][0] >> task

    return dag


# Assign to a global variable so Airflow registers the DAG
dag = create_dag("perm")