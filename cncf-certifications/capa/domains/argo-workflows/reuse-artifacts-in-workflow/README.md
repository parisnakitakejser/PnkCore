# CAPA Exam Prep: Argo Workflows - Reuse Artifacts in a Workflow

This guide covers a common artifact-passing pattern you should know for CAPA-style lab work:

- Configure artifact storage for Argo Workflows
- Use MinIO as an S3-compatible artifact repository
- Generate an artifact in one step
- Reuse that artifact in a later step
- Understand why artifact-backed workflows are useful across Pods

## Prerequisites

- A working Kubernetes cluster
- Argo Workflows installed in the cluster
- `kubectl` configured for that cluster
- `helm` installed locally
- Optional: the MinIO client `mc`

This example assumes Argo Workflows runs in the `argo` namespace.

## 1. Install MinIO for Artifact Storage

For local labs, MinIO is a practical way to provide S3-compatible artifact storage for Argo Workflows.

Community Helm chart:

https://github.com/minio/minio/tree/master/helm/minio

Install MinIO:

```bash
helm repo add minio https://charts.min.io/
helm repo update
helm install minio minio/minio \
  --set resources.requests.memory=512Mi \
  --set replicas=1 \
  --set persistence.enabled=false \
  --set mode=standalone \
  --set rootUser=rootuser,rootPassword=rootpass123 \
  --set fullnameOverride=argo-artifacts \
  -n minio \
  --create-namespace
```

## 2. Access MinIO

Port-forward the API service so you can test connectivity:

```bash
kubectl port-forward svc/argo-artifacts -n minio 9000:9000
```

If you want to access the MinIO web console, stop the `9000` port-forward and start this one instead:

```bash
kubectl port-forward svc/argo-artifacts-console -n minio 9001:9001
```

## 3. Prepare the MinIO Bucket and User

On macOS, install the MinIO client:

```bash
brew install minio/stable/mc
mc --version
```

Configure a local alias, create the bucket, and create an application user:

```bash
mc alias set local http://127.0.0.1:9000 rootuser rootpass123
mc mb local/argo-artifacts
mc admin user add local app-user app-user-secret-123
mc admin policy attach local readwrite --user app-user
```

You can verify the bucket exists with:

```bash
mc ls local
mc ls local/argo-artifacts
```

## 4. Configure Argo Workflows to Use MinIO

This folder includes [argo-artifacts-config.yaml](/Users/parisnakitakejser/Developer/PnkCore/cncf-certifications/capa/domains/argo-workflows/reuse-artifacts-in-workflow/argo-artifacts-config.yaml), which creates:

- a Secret named `minio-artifacts`
- a `workflow-controller-configmap` entry that points Argo Workflows to the MinIO bucket

The key configuration looks like this:

```yaml
artifactRepository:
  archiveLogs: true
  s3:
    bucket: argo-artifacts
    endpoint: argo-artifacts.minio.svc.cluster.local:9000
    insecure: true
    accessKeySecret:
      name: minio-artifacts
      key: accesskey
    secretKeySecret:
      name: minio-artifacts
      key: secretkey
```

Apply the configuration:

```bash
kubectl create -f argo-artifacts-config.yaml
```

## 5. Review the Workflow

This folder also includes [workflow.yaml](/Users/parisnakitakejser/Developer/PnkCore/cncf-certifications/capa/domains/argo-workflows/reuse-artifacts-in-workflow/workflow.yaml).

The workflow does two things:

1. `generate-artifact` writes `hello world` into a file
2. `consume-artifact` receives that file as an artifact input and prints it

Workflow definition:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: artifact-passing-
spec:
  entrypoint: artifact-example
  templates:
    - name: artifact-example
      steps:
        - - name: generate-artifact
            template: hello-world-to-file
        - - name: consume-artifact
            template: print-message-from-file
            arguments:
              artifacts:
                - name: message
                  from: "{{steps.generate-artifact.outputs.artifacts.hello-art}}"

    - name: hello-world-to-file
      container:
        image: busybox
        command: [sh, -c]
        args: ["echo hello world | tee /tmp/hello_world.txt"]
      outputs:
        artifacts:
          - name: hello-art
            path: /tmp/hello_world.txt

    - name: print-message-from-file
      inputs:
        artifacts:
          - name: message
            path: /tmp/message
      container:
        image: alpine:3.23
        command: [sh, -c]
        args: ["cat /tmp/message"]
```

The important part is this artifact reference:

```yaml
from: "{{steps.generate-artifact.outputs.artifacts.hello-art}}"
```

That tells Argo Workflows to take the artifact produced by the first step and pass it into the second step.

## 6. Create the Workflow

Because this manifest uses `generateName`, create it with `kubectl create`:

```bash
kubectl create -f workflow.yaml -n argo
```

If you use `kubectl apply`, Kubernetes will reject the manifest because `apply` does not work with `generateName`.

## 7. Inspect the Result

List workflows:

```bash
kubectl get workflows -n argo
```

Inspect the workflow:

```bash
argo list -n argo
argo get -n argo <workflow-name>
```

View the logs:

```bash
argo logs -n argo <workflow-name>
```

Replace `<workflow-name>` with the generated name, such as `artifact-passing-xxxxx`.

## Exam Notes

- Know that artifacts are useful for passing files between workflow steps
- Know that artifacts are different from parameters because they carry file or directory content
- Know that Argo Workflows needs artifact repository configuration for this pattern
- Know that `generateName` should be used with `kubectl create` or `argo submit`, not `kubectl apply`
- Remember that artifact data is not cleaned up automatically unless you configure retention or bucket lifecycle policies
- Logs may not appear for pods that are deleted unless you have `archive logs` enabled.