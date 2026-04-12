# CAPA Exam Prep: Argo Workflows - How to Work with Sidecars in Argo Workflows

This guide covers the sidecar pattern you should know for CAPA-style lab work:

- Run a main workflow container with a sidecar container
- Use the sidecar to provide a supporting service
- Access the sidecar from the main container over `localhost`
- Understand why sidecars are useful in workflow steps

## Prerequisites

- A working Kubernetes cluster
- Argo Workflows installed in the cluster
- `kubectl` configured for that cluster
- Optional: the `argo` CLI installed locally

This example assumes Argo Workflows is running in the `argo` namespace.

## 1. Review the Workflow

This folder includes [workflow-sidecars.yaml](/Users/parisnakitakejser/Developer/PnkCore/cncf-certifications/capa/domains/argo-workflows/how-to-work-with-sidecars/workflow-sidecars.yaml).

It defines a workflow where:

- the main container uses `curl`
- a sidecar container runs `nginx`
- the main container waits for the sidecar web server to become available
- once the server responds, the main container prints the page output

Workflow definition:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: sidecar-nginx-
spec:
  entrypoint: sidecar-nginx-example
  serviceAccountName: argo
  templates:
    - name: sidecar-nginx-example
      container:
        image: appropriate/curl
        command: [sh, -c]
        args: ["until `curl -G 'http://127.0.0.1/' >& /tmp/out`; do echo sleep && sleep 1; done && cat /tmp/out"]
      sidecars:
        - name: nginx
          image: nginx:1.13
          command: [nginx, -g, daemon off;]
```

## 2. Understand How the Sidecar Works

The key idea is that the main container and sidecar run in the same Pod.

That means:

- they can run at the same time
- they share the Pod network namespace
- the main container can reach the sidecar on `127.0.0.1`

In this example:

- the sidecar starts an `nginx` web server
- the main container repeatedly calls `http://127.0.0.1/`
- once `nginx` is ready, the main container prints the response

This is a useful pattern when a workflow step needs a local helper service such as:

- a web server
- a proxy
- a database
- a cache

## 3. Service Account Permissions for a Lab

In a local or lab environment, you may need to grant broader permissions so workflows can run successfully.

Only do this in a test environment. For production, follow the official Argo Workflows service account guidance:

https://argo-workflows.readthedocs.io/en/latest/service-accounts/

Example lab-friendly RoleBinding:

```bash
kubectl create rolebinding argo-admin \
  --clusterrole=admin \
  --serviceaccount=argo:argo \
  -n argo
```

## 4. Create the Workflow

Because this manifest uses `generateName`, create it with:

```bash
kubectl create -f workflow-sidecars.yaml -n argo
```

You can also submit it with the Argo CLI:

```bash
argo submit workflow-sidecars.yaml -n argo
```

Do not use `kubectl apply` with this file unless you replace `generateName` with a fixed `name`.

## 5. Inspect the Result

List workflows:

```bash
kubectl get workflows -n argo
```

Inspect the generated workflow:

```bash
argo list -n argo
argo get -n argo <workflow-name>
```

View the logs:

```bash
argo logs -n argo <workflow-name>
```

Replace `<workflow-name>` with the generated name, for example `sidecar-nginx-xxxxx`.

## 6. What to Look For

When you run this workflow:

- the `nginx` sidecar starts inside the same Pod as the main container
- the main container may print `sleep` while waiting for `nginx` to become ready
- once the sidecar is reachable, the main container prints the default nginx page content

This makes it a good study example for understanding how workflow sidecars provide helper services to the main step.

## Exam Notes

- Know that sidecars run alongside the main container in the same Pod
- Know that the main container can usually reach the sidecar through `localhost`
- Know that sidecars are useful when a workflow step needs a supporting service
- Know that `generateName` works with `kubectl create` or `argo submit`

## References

- Argo Workflows sidecars docs: https://argo-workflows.readthedocs.io/en/latest/walk-through/sidecars/
