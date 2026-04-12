# CAPA Exam Prep: Argo Workflows - How to Use Suspend in Argo Workflows

This guide covers the suspend pattern you should know for CAPA-style lab work:

- Pause a workflow at a specific step
- Resume a workflow manually
- Delay a workflow for a fixed amount of time
- Understand the difference between indefinite suspend and timed suspend

## Prerequisites

- A working Kubernetes cluster
- Argo Workflows installed in the cluster
- `kubectl` configured for that cluster
- Optional: the `argo` CLI installed locally

This example assumes Argo Workflows is running in the `argo` namespace.

## 1. Review the Workflow

This folder includes [workflow-suspend.yaml](/Users/parisnakitakejser/Developer/PnkCore/cncf-certifications/capa/domains/argo-workflows/how-to-use-suspend/workflow-suspend.yaml).

It defines a workflow with four stages:

- `build`
- `approve`
- `delay`
- `release`

Workflow definition:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: suspend-template-
spec:
  entrypoint: suspend
  serviceAccountName: argo
  templates:
    - name: suspend
      steps:
        - - name: build
            template: hello-world
        - - name: approve
            template: approve
        - - name: delay
            template: delay
        - - name: release
            template: hello-world

    - name: approve
      suspend: {}

    - name: delay
      suspend:
        duration: "20"

    - name: hello-world
      container:
        image: busybox
        command: [echo]
        args: ["hello world"]
```

## 2. Understand the Suspend Flow

This workflow demonstrates two kinds of suspension.

Manual suspend:

- the `approve` step uses `suspend: {}`
- this pauses the workflow indefinitely
- the workflow stays paused until someone resumes it

Timed suspend:

- the `delay` step uses `suspend.duration`
- this pauses the workflow for a fixed time
- after the duration expires, the workflow continues automatically

In this example, the workflow:

1. runs `build`
2. pauses at `approve`
3. resumes manually
4. waits 20 seconds at `delay`
5. continues to `release`

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
kubectl create -f workflow-suspend.yaml -n argo
```

You can also submit it with the Argo CLI:

```bash
argo submit workflow-suspend.yaml -n argo
```

Do not use `kubectl apply` with this file unless you replace `generateName` with a fixed `name`.

## 5. Resume the Workflow

After the workflow reaches the `approve` step, it will pause and wait.

List the workflows:

```bash
argo list -n argo
```

Then resume the paused workflow:

```bash
argo resume -n argo <workflow-name>
```

Replace `<workflow-name>` with the generated name, for example `suspend-template-xxxxx`.

## 6. Inspect the Workflow

You can inspect the workflow state with:

```bash
kubectl get workflows -n argo
argo get -n argo <workflow-name>
argo logs -n argo <workflow-name>
```

This helps you confirm:

- the workflow paused at `approve`
- it resumed when requested
- it paused again for 20 seconds at `delay`
- it eventually finished with the `release` step

## 7. What to Look For

When you run this workflow:

- `build` should run immediately
- the workflow should stop at `approve`
- after you resume it, `delay` should hold execution for 20 seconds
- `release` should run last

This makes it a good study example for understanding approval gates and timed pauses in workflow execution.

## Exam Notes

- Know that `suspend: {}` pauses a workflow until it is resumed manually
- Know that `suspend.duration` pauses a workflow for a fixed time
- Know that suspend steps are useful for approvals, waiting periods, and controlled release flows
- Know that `generateName` works with `kubectl create` or `argo submit`