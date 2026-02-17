# CKS Exam Prep: Runtime Security - Audit Logging

Official docs (Kubernetes Audit): https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/

Audit logging is configured on the kube-apiserver (static pod). The audit
policy controls *what* is logged; API server flags control *where* logs go
and how they are rotated.

## Audit levels (quick recall)

- None
- Metadata
- Request
- RequestResponse

## Common kube-apiserver flags

```
--audit-policy-file
--audit-log-path
--audit-log-maxage
--audit-log-maxbackup
--audit-log-maxsize
```

## Step-by-step guide

### 1) Create a policy directory and policy file

```sh
sudo mkdir -p /etc/kubernetes/audit
sudo nano /etc/kubernetes/audit/policy.yaml
```

Minimal policy (logs only metadata):

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
```

Optional: slightly more useful policy (example)

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
  resources:
  - group: ""
    resources: ["pods", "services", "configmaps", "secrets"]
- level: Request
  verbs: ["create", "update", "patch", "delete"]
```

### 2) Backup the kube-apiserver manifest

If you make a mistake in the static pod manifest, the API server can fail to
start. Always make a backup first.

```sh
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml \
  /etc/kubernetes/manifests/kube-apiserver.yaml.bak
```

### 3) Edit the kube-apiserver manifest

Open the file:

```sh
sudo nano /etc/kubernetes/manifests/kube-apiserver.yaml
```

Add audit flags under the kube-apiserver command args:

```yaml
- --audit-policy-file=/etc/kubernetes/audit/policy.yaml
- --audit-log-path=/etc/kubernetes/audit/logs/audit.log
- --audit-log-maxsize=500
- --audit-log-maxbackup=5
- --audit-log-maxage=7
```

Add a volume to expose the host path:

```yaml
volumes:
- name: audit
  hostPath:
    path: /etc/kubernetes/audit
    type: DirectoryOrCreate
```

Mount it into the container:

```yaml
volumeMounts:
- name: audit
  mountPath: /etc/kubernetes/audit
```

### 4) Create the log directory (if needed)

```sh
sudo mkdir -p /etc/kubernetes/audit/logs
```

### 5) Verify audit logging is active

The kubelet will restart the kube-apiserver automatically after the manifest
changes.

```sh
sudo ls -l /etc/kubernetes/audit/logs
sudo tail -n 5 /etc/kubernetes/audit/logs/audit.log
```

If the API server fails to come back, restore the backup:

```sh
sudo mv /etc/kubernetes/manifests/kube-apiserver.yaml.bak \
  /etc/kubernetes/manifests/kube-apiserver.yaml
```

## Notes for the exam

- Always use a minimal policy first; refine if needed.
- Audit logging changes only apply on the control plane.
- The API server must have both the volume and volumeMount or it will fail.
