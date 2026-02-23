# CKS Exam Prep: Microservice Vulnerabilities - Manage Kubernetes Secrets

This lab shows how to create secrets and consume them safely in Pods. It also
explains why environment variables are riskier than mounting secrets as files.

Docs: https://kubernetes.io/docs/concepts/configuration/secret/

## 1) Create two secrets

**Fastest way**
```bash
kubectl create secret generic secret1 --from-literal=username=admin --from-literal=password='S3cr3t!'
kubectl create secret generic secret2 --from-literal=token='abc123'
```

Verify:
```bash
kubectl get secrets
kubectl describe secret secret1
kubectl describe secret secret2
```

**Manual (docs-style)**

Generate skeleton YAML:

```bash
kubectl create secret generic secret1 -o yaml --dry-run=client > secret1.yaml
kubectl create secret generic secret2 -o yaml --dry-run=client > secret2.yaml
```

Open `secret1.yaml` and add data:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: secret1
stringData:
  username: admin
  password: S3cr3t!
```

Open `secret2.yaml` and add data:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: secret2
stringData:
  token: abc123
```

Apply:

```bash
kubectl apply -f secret1.yaml
kubectl apply -f secret2.yaml
```

Verify:

```bash
kubectl get secrets
kubectl describe secret secret1
kubectl describe secret secret2
```



## 2) Create a test pod manifest

```bash
kubectl run demo-secret1 --image=nginx -o yaml --dry-run=client > pod-secret1.yaml
kubectl run demo-secret2 --image=nginx -o yaml --dry-run=client > pod-secret2.yaml
```

## 3) Bad pattern: secrets as environment variables

Environment variables are easy to leak via:

- `kubectl describe pod` (shows env values)
- process listings inside the container
- debug output and crash dumps

Example (avoid if possible):

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: demo-secret1
spec:
  containers:
  - name: nginx
    image: nginx
    env:
    - name: USERNAME
      valueFrom:
        secretKeyRef:
          name: secret1
          key: username
    - name: PASSWORD
      valueFrom:
        secretKeyRef:
          name: secret1
          key: password
```

## 4) Preferred pattern: secrets mounted as files

Mounting secrets as files limits exposure and allows fine-grained permissions.
Secrets are stored in tmpfs and not written to node disks by default.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: demo-secret2
spec:
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - name: secret-vol
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secret-vol
    secret:
      secretName: secret1
```

Check the mounted file:

```bash
kubectl exec -it demo-secret2 -- cat /etc/secrets/username
```

## 5) What it takes to exfiltrate mounted secrets

Mounted secrets are still sensitive, but attacks are harder:

- an attacker needs access to the container or the node
- the secret exists only in memory (tmpfs)
- file permissions can restrict who can read it

## Exam notes

- Prefer **mounted secrets** over env vars.
- Use `readOnly: true`.
- Limit access with RBAC and namespaces.
