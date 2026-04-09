# CAPA Exam Prep: Argo Workflows - A Simple DAG Workflow

This guide covers the basic DAG workflow pattern you should know for CAPA-style lab work:

- Create a reusable workflow template
- Build a DAG workflow that references that template
- Understand task dependencies in a diamond-shaped DAG
- Submit the workflow and inspect the result
- Review the workflow from the UI and CLI

## Prerequisites

- A working Kubernetes cluster
- Argo Workflows installed in the cluster
- `kubectl` configured for that cluster
- Optional: the `argo` CLI installed locally

This example assumes Argo Workflows is running in the `argo` namespace.

## 1. Create a Reusable Workflow Template

Create a workflow template that accepts a `message` parameter and echoes it:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: echo-template
  namespace: argo
spec:
  serviceAccountName: argo
  templates:
    - name: echo
      inputs:
        parameters:
          - name: message
      container:
        image: alpine:latest
        command: [echo, "{{inputs.parameters.message}}"]
```

This template gives you a reusable building block for multiple workflow steps.

Apply the template first so the DAG workflow can reference it by name:

```bash
kubectl apply -f https://raw.githubusercontent.com/parisnakitakejser/PnkCore/refs/heads/main/cncf-certifications/capa/domains/argo-workflows/a-simple-dag-workflow/echo-workflow-template.yaml
```

## 2. Create a DAG Workflow

Create a workflow that uses a diamond dependency pattern:

- `A` runs first
- `B` depends on `A`
- `C` depends on `A`
- `D` depends on both `B` and `C`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: dag-diamond-
  namespace: argo
spec:
  entrypoint: diamond
  serviceAccountName: argo
  templates:
    - name: diamond
      dag:
        tasks:
          - name: A
            arguments:
              parameters:
                - name: message
                  value: A
            templateRef:
              name: echo-template
              template: echo

          - name: B
            dependencies: [A]
            arguments:
              parameters:
                - name: message
                  value: B
            templateRef:
              name: echo-template
              template: echo

          - name: C
            dependencies: [A]
            arguments:
              parameters:
                - name: message
                  value: C
            templateRef:
              name: echo-template
              template: echo

          - name: D
            dependencies: [B, C]
            arguments:
              parameters:
                - name: message
                  value: D
            templateRef:
              name: echo-template
              template: echo
```

This is a common exam-style example because it shows how DAG dependencies control execution order.

Once the template exists in the cluster, create a workflow run from the DAG definition:

```bash
kubectl create -f https://raw.githubusercontent.com/parisnakitakejser/PnkCore/refs/heads/main/cncf-certifications/capa/domains/argo-workflows/a-simple-dag-workflow/simple-dag-workflow.yaml
```

## 3. Service Account Permissions for a Lab

In a local or lab environment, you may need to grant broader permissions so workflows can run successfully.

Only do this in a test environment. For production, follow the official Argo Workflows service account guidance:

https://argo-workflows.readthedocs.io/en/latest/service-accounts/

Example lab-friendly RoleBinding:

```bash
kubectl create rolebinding default-admin \
  --clusterrole=admin \
  --serviceaccount=argo:default \
  -n argo
```

## 4. Apply the Template and Create the Workflow

The order matters here:

- Apply the reusable template first
- Create the DAG workflow second

In this folder, the files are named `echo-workflow-template.yaml` and `simple-dag-workflow.yaml`:

```bash
kubectl apply -f echo-workflow-template.yaml
kubectl create -f simple-dag-workflow.yaml
```

`kubectl apply` is a good fit for the reusable template, while `kubectl create` is useful for submitting a fresh workflow run.

## 5. Check the Workflow

You can inspect the workflow in the Argo Workflows UI, where the diamond-shaped execution graph is easy to see.

You can also list workflows with Kubernetes:

```bash
kubectl -n argo get workflows
```

Or use the Argo CLI:

```bash
argo list -n argo
argo get -n argo <workflow-name>
```

If your generated workflow name starts with `dag-diamond-`, replace `<workflow-name>` with the actual name from the list output.

## 6. Watch Progress and View Logs

Use these commands to follow execution and inspect output:

```bash
argo watch -n argo <workflow-name>
argo logs -n argo <workflow-name>
```

These are especially useful during labs because they help you verify dependency order and task completion.

## Exam Notes

- Know the difference between a reusable `WorkflowTemplate` and a `Workflow`
- Know that DAG tasks can declare dependencies with `dependencies`
- Know that tasks without a dependency between them can run in parallel
- Know how `generateName` creates a unique workflow name at submission time
- Know how to inspect workflows with both `kubectl` and the `argo` CLI
