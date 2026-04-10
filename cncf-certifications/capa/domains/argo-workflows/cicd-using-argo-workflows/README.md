# CAPA Exam Prep: Argo Workflows - CI/CD Using Argo Workflows

This guide covers a simple CI/CD-style workflow pattern you should know for CAPA-style lab work:

- Define a workflow with build, test, and deploy stages
- Run those stages in sequence with Argo Workflows
- Submit the workflow to the cluster
- Inspect workflow status, pods, and logs

## Prerequisites

- A working Kubernetes cluster
- Argo Workflows installed in the cluster
- `kubectl` configured for that cluster
- Optional: the `argo` CLI installed locally

This example assumes Argo Workflows is running in the `argo` namespace.

## 1. Review the Workflow Definition

This folder includes a workflow file named `workflow-ci.yaml`.

It defines three stages:

- `build`
- `test`
- `deploy`

The workflow runs them in order using a `steps` template:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: python-app
spec:
  entrypoint: python-app
  templates:
    - name: python-app
      steps:
        - - name: build
            template: build
        - - name: test
            template: test
          - name: trivy
            template: trivy
        - - name: deploy
            template: deploy

    - name: build
      container:
        image: python:3.14
        command: [python]
        args: ["-c", "print('build')"]

    - name: test
      container:
        image: python:3.14
        command: [python]
        args: ["-c", "print('test')"]

    - name: trivy
      container:
        image: python:3.14
        command: [python]
        args: ["-c", "print('trivy')"]

    - name: deploy
      container:
        image: python:3.14
        command: [python]
        args: ["-c", "print('deploy')"]
```

This is a simplified study example. In a real pipeline, the build and deploy stages would usually do more than print a message.

## 2. Submit the Workflow

Apply the workflow file to create a run:

```bash
kubectl apply -n argo -f https://raw.githubusercontent.com/parisnakitakejser/PnkCore/refs/heads/main/cncf-certifications/capa/domains/argo-workflows/cicd-using-argo-workflows/workflow-ci.yaml
```

Because this workflow uses a fixed `metadata.name`, applying it creates or updates the same named workflow resource: `python-app`.

## 3. Inspect the Workflow

Check the workflow details with the Argo CLI:

```bash
argo -n argo get python-app
```

This shows the workflow status and the result of each step.

## 4. Inspect the Pods

You can also look at the Pods created for the workflow:

```bash
kubectl get pods -n argo
```

This is useful if you want to confirm which workflow step is running or troubleshoot a failed container.

## 5. View the Logs

To see the workflow output:

```bash
argo -n argo logs python-app
```

This helps you verify that the `build`, `test`, and `deploy` stages executed as expected.

## Notes About the Test Stage

The `test` step mounts a local path with `hostPath`:

```yaml
hostPath:
  path: /path/to/tests
```

That path is still a placeholder. In a real lab, you would replace it with a valid path on the node, or use a more portable approach such as a ConfigMap, artifact, or image-based test bundle.

## Exam Notes

- Know how to define multiple workflow stages with a `steps` template
- Know that each step can call a separate named template
- Know how to submit a workflow file with `kubectl`
- Know how to inspect workflow state with `argo get`
- Know how to inspect workflow output with `argo logs`