# CAPA Exam Prep: Argo Workflows - How Recursion Works in Argo Workflows

This guide covers the recursion pattern you should know for CAPA-style lab work:

- Run a workflow step that can call itself
- Use a conditional to stop recursion
- Repeat a task until a desired result is reached
- Understand how recursive templates behave in Argo Workflows

## Prerequisites

- A working Kubernetes cluster
- Argo Workflows installed in the cluster
- `kubectl` configured for that cluster
- Optional: the `argo` CLI installed locally

This example assumes Argo Workflows is running in the `argo` namespace.

## 1. Review the Workflow

This folder includes [workflow-recursion.yaml](/Users/parisnakitakejser/Developer/PnkCore/cncf-certifications/capa/domains/argo-workflows/how-recursion-works/workflow-recursion.yaml).

It defines a workflow that flips a virtual coin. If the result is `heads`, the workflow stops. If the result is `tails`, the workflow calls the same template again and keeps going until it eventually gets `heads`.

Workflow definition:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: coinflip-recursive-
spec:
  entrypoint: coinflip
  serviceAccountName: argo
  templates:
    - name: coinflip
      steps:
        - - name: flip-coin
            template: flip-coin

        - - name: heads
            template: heads
            when: "{{steps.flip-coin.outputs.result}} == heads"
          - name: tails
            template: coinflip
            when: "{{steps.flip-coin.outputs.result}} == tails"

    - name: flip-coin
      script:
        image: python:alpine3.23
        command: [python]
        source: |
          import random
          result = "heads" if random.randint(0,1) == 0 else "tails"
          print(result)

    - name: heads
      container:
        image: alpine:3.23
        command: [sh, -c]
        args: ["echo \"it was heads\""]
```

## 2. Understand the Recursive Flow

The recursive behavior comes from this step:

```yaml
- name: tails
  template: coinflip
  when: "{{steps.flip-coin.outputs.result}} == tails"
```

That means:

- run `flip-coin`
- if the result is `heads`, execute the `heads` template and stop
- if the result is `tails`, call the `coinflip` template again

So the workflow keeps recursing until the condition for `heads` becomes true.

## 3. Why This Matters

This is useful when a workflow should retry or repeat logic until a certain state is reached.

For exam purposes, the important idea is not the coin flip itself. The important idea is that a template can invoke itself indirectly through a conditional branch.

## 4. Service Account Permissions for a Lab

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

## 5. Create the Workflow

Because this manifest uses `generateName`, create it with:

```bash
kubectl create -f workflow-recursion.yaml -n argo
```

You can also submit it with the Argo CLI:

```bash
argo submit workflow-recursion.yaml -n argo
```

Do not use `kubectl apply` with this file unless you replace `generateName` with a fixed `name`.

## 6. Inspect the Workflow

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

Replace `<workflow-name>` with the generated name, for example `coinflip-recursive-xxxxx`.

## 7. What to Look For

When you run this workflow:

- the first coin flip may immediately return `heads`
- if it returns `tails`, the workflow calls the same template again
- the workflow may recurse several times before stopping
- the final successful branch is the one that prints `it was heads`

This makes it a useful study example for understanding self-referencing workflow logic.

## Exam Notes

- Know that recursion in Argo Workflows can be implemented by having a template call itself
- Know that `when` expressions can control whether recursion continues
- Know that recursion must have a stopping condition, or the workflow may keep running
- Know that `generateName` should be used with `kubectl create` or `argo submit`