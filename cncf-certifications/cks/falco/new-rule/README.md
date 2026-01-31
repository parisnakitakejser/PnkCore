# CKS Exam Preparation: Falco Custom Rule (New Rule)

This lab shows how to add a custom Falco rule via a ConfigMap and mount it into
the Falco DaemonSet.

## Prerequisites

- Falco is installed in the `falco` namespace
- You have `kubectl` access to the cluster

## Step 1: Create the demo workload

```bash
kubectl apply -f https://raw.githubusercontent.com/parisnakitakejser/PnkCore/refs/heads/main/cncf-certifications/cks/falco/new-rule/deployment.yaml
```

## Step 2: Create the ConfigMap for the rule

This file name must match the `subPath` and the key in the ConfigMap.

```bash
curl https://raw.githubusercontent.com/parisnakitakejser/PnkCore/refs/heads/main/cncf-certifications/cks/falco/new-rule/custom-falco-rule.yaml
kubectl -n falco create configmap falco-custom-rules \
  --from-file=custom-falco-rule.yaml
```

## Step 3: Mount the rule into the Falco DaemonSet

There are two ways to do this:

### Option A: Use `kubectl patch` (quick CLI)

Add a volume for the ConfigMap:

```bash
kubectl -n falco patch daemonset falco --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/volumes/-",
    "value": {
      "name": "custom-rules",
      "configMap": {
        "name": "falco-custom-rules"
      }
    }
  }
]'
```

Add the volume mount for the rule file:

```bash
kubectl -n falco patch daemonset falco --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/volumeMounts/-",
    "value": {
      "name": "custom-rules",
      "mountPath": "/etc/falco/rules.d/custom-falco-rule.yaml",
      "subPath": "custom-falco-rule.yaml"
    }
  }
]'
```

Restart Falco to load the new rules:

```bash
kubectl -n falco rollout restart daemonset falco
```

### Option B: Edit the DaemonSet manifest (easier to remember)

If you prefer not to remember JSON patch paths, edit the DaemonSet and add the
volume + mount manually:

```bash
kubectl -n falco edit daemonset falco
```

Add this under the `falco` container:

```yaml
volumeMounts:
  - mountPath: /etc/falco/rules.d/custom-falco-rule.yaml
    name: custom-rules
    subPath: custom-falco-rule.yaml
```

Add this under `spec.template.spec.volumes`:

```yaml
volumes:
  - name: custom-rules
    configMap:
      name: falco-custom-rules
      defaultMode: 420
```

Save and exit. The DaemonSet will roll out automatically. If not, restart:

```bash
kubectl -n falco rollout restart daemonset falco
```

## Step 4: Verify the rule is firing

```bash
kubectl -n falco logs -l app.kubernetes.io/name=falco --tail=50 -f | grep /tmp/mem
```

When you identify the noisy container/deployment, scale it down to stop the
events:

```bash
kubectl -n <namespace> scale deployment <name> --replicas=0
```

## Cleanup

```bash
kubectl delete -f https://raw.githubusercontent.com/parisnakitakejser/PnkCore/refs/heads/main/cncf-certifications/cks/falco/new-rule/deployment.yaml
kubectl -n falco delete configmap falco-custom-rules
```

## Notes

- The ConfigMap name `falco-custom-rules` and file name
  `custom-falco-rule.yaml` must match the `subPath` and mount.
- If you change the rule file name, update both the ConfigMap and the mount.
