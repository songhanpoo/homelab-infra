# CD: deploy CI images to Kubernetes

`.harness/pipelines/cd.yaml` (pipeline `k8sdeploy`) deploys `<image>:<commit tag>` with Helm: **Render** (server dry run) → **Approve** → **Deploy**. A rollout that doesn't become ready is rolled back.

| Path | What |
|---|---|
| `charts/web-service/` | Generic chart: Deployment, Service, Ingress. Non-root, read-only root filesystem |
| `services/<name>.yaml` | One service: namespace, image, port, host, user ID, writable folders |
| `snippets/ci-chain-stage.yaml` | Stage for the app's CI pipeline that starts this one |
| `../.harness/scripts/deploy.sh` | The logic: input checks, render, deploy |
| `../kube-addons/nonprod/cd-deployer.tf` | App namespaces, the limited account, the Harness secret |

## What the deploy account can do

In each app namespace only: manage Deployments, Services, Ingresses and **Secrets** (Helm stores releases there, so it can also read the app's secrets), and read ReplicaSets, Pods and Events. App namespaces enforce the `restricted` Pod Security Standard. Anyone who can run or edit pipelines in the Harness project can use the secret `cd_kubeconfig_b64`, so limit who can.

## First deployment of next-bulletin

1. **Create the namespace and account.** In `kube-addons/nonprod`, with `TF_HTTP_PASSWORD` set to a token that may create project secrets. Review the plan: it should only add the `cd_*` resources.
   ```sh
   make init
   make plan PLAN_ARGS="-target=kubernetes_namespace_v1.cd_app -target=kubernetes_role_binding_v1.cd_deployer -target=harness_platform_secret_text.cd_kubeconfig_b64 -out=/tmp/cd.tfplan"
   make apply PLANFILE=/tmp/cd.tfplan && rm /tmp/cd.tfplan   # the plan file holds secrets
   ```
2. **Create the app's Secret by hand.** Put the settings the app needs (see `application.runtime.env` in its `manifest.yaml`: at least `DATABASE_URL`, `NEXT_PUBLIC_APP_URL`, `BETTER_AUTH_SECRET`, `BETTER_AUTH_URL`) in an env file **outside any Git repository**, then:
   ```sh
   kubectl -n next-bulletin create secret generic next-bulletin-env --from-env-file=/path/outside/git/next-bulletin.env
   ```
   Without it the pods stay in `CreateContainerConfigError` and the deployment rolls back. After changing the Secret, restart: `kubectl -n next-bulletin rollout restart deploy/next-bulletin`.
3. **Prepare the database.** The image contains no migrations. Create the database and run `pnpm db:migrate` from the app repository against it, before deploying code that needs it.
4. **DNS.** Apply `kube-addons/prod` for the record `next-bulletin.localdev.me` (review the whole plan). Traefik's `*.localdev.me` route already forwards to the ingress. `NEXT_PUBLIC_APP_URL` is also fixed at build time in the app's manifest.
5. **Create the pipeline.** Merge these files to `master`, then enable `k8sdeploy` (see `modules/harness-pipeline/README.md`), or create it in Harness from Git.
6. **Run it** with `SERVICE=next-bulletin` and a tag CI pushed (the short commit SHA). The dry run does **not** check that the image tag exists. After deploying, open the site and use it: the readiness check only proves the port is open.

The user ID 100 comes from the app's Dockerfile (`adduser -S appuser`). If its base image or user changes, update the service file. The real image hasn't been run with this chart: if it fails writing a file, add that folder to `writableDirs`.

## Chain from CI

Add `snippets/ci-chain-stage.yaml` as the last stage of `next-bulletin`'s `.harness/cots-build.yaml`, through a pull request in that repository, **after** a manual deployment has worked. It runs only for the release branch (`develop`). The CD approval then appears from the CI run, which stays open until you approve or it times out. Pipeline chaining hasn't been tried on this Harness account.

## Add a service

1. Add `services/<name>.yaml` (namespace must not be a platform namespace).
2. Add `<name>` to `SERVICE` in `.harness/pipelines/cd.yaml`.
3. Apply `kube-addons/nonprod`; create the app's Secret; add DNS in `kube-addons/prod`.

Removing a service file makes Terraform delete its namespace, **with everything in it**. Run `helm uninstall` first and review the plan.

## Rotate or revoke the account's token

In `kube-addons/nonprod`: `make apply APPLY_ARGS="-replace=kubernetes_secret_v1.cd_deployer_token"`.

## Not covered
Database migrations, image scanning at deploy time (CI scans), and `visa-bulletin`, which runs a task and exits rather than serving. The infrastructure pipeline's Trivy stage doesn't scan `deploy/charts`.
