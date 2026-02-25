# CKS Exam Prep: Microservice Vulnerabilities - Pod Security Standard (PSS)

Docs:
- https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/
- https://kubernetes.io/docs/concepts/security/pod-security-standards/

This guide helps you practice applying Pod Security Standards and observing how
workloads behave when they violate policy.

## Step 1) Apply the demo manifests (setup)

Create the namespace and a default nginx Deployment:

```bash
kubectl apply -f manifests/namespace.yaml
kubectl apply -f manifests/deployment.yaml
```

Confirm the Pod starts successfully:

```bash
kubectl get pod -n pod-security-standart
```

## Step 2) Understand the PSS levels

Now we will change the Pod Security Standard by adding a label to the namespace.
You can choose between three policy levels. We will use **restricted** for the
strictest checks.

- **Privileged**: most permissive, minimal restrictions
- **Baseline**: blocks known privilege escalation paths
- **Restricted**: most strict, best-practice security defaults

## Step 3) Practice label-based enforcement

Label the namespace to enforce a policy level:

```bash
kubectl label ns pod-security-standart \
  pod-security.kubernetes.io/enforce=restricted
kubectl delete -f manifests/deployment.yaml
kubectl apply -f manifests/deployment.yaml
```

You should see a warning like this:

```bash
Warning: would violate PodSecurity "restricted:latest": allowPrivilegeEscalation != false (container "nginx" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "nginx" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "nginx" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "nginx" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
deployment.apps/nginx created
```

Then you can see we need some changes before the deployment will start so let's change the deployment file to look like this
Then you can see we need changes before the Deployment will start. Update the
manifest to meet the **restricted** policy:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alpine
  namespace: pod-security-standart
  labels:
    app: alpine
spec:
  replicas: 1
  selector:
    matchLabels:
      app: alpine
  template:
    metadata:
      labels:
        app: alpine
    spec:
      containers:
      - name: alpine
        image: alpine
        command:
          - sh
          - -c
          - |
            echo "Sleeping in 3600 sec..."
            sleep 3600
        securityContext:
          allowPrivilegeEscalation: false
          runAsUser: 1000
          runAsNonRoot: true
          capabilities:
            drop: ["ALL"]
          seccompProfile:
            type: RuntimeDefault
```

Now the Pod should start without any issues:

```bash
kubectl get pod -n pod-security-standart
```

## Step 4) Observe behavior when a workload violates PSS

If a Pod violates the enforced level, it will fail to schedule or be rejected
by admission. Check ReplicaSet events to see the reason.

Example commands:

```bash
kubectl -n pod-security-standart get rs
kubectl -n pod-security-standart describe rs <replicaset-name>
```

## Exam-style reminder

In many tasks, you will:

1) Apply or edit namespace labels
2) Delete a Pod and let the ReplicaSet try to recreate it
3) Capture the event/log lines explaining why it failed
