# CAPA Exam Prep: Argo Rollouts - Argo Rollouts Blue-Green

This guide covers the blue/green rollout pattern you should know for CAPA-style lab work:

- create a Rollout resource instead of a Deployment
- use separate active and preview Services
- deploy an initial version
- update the image to create a preview version
- manually promote the new version

## Prerequisites

- A working Kubernetes cluster
- Argo Rollouts installed in the cluster
- `kubectl` configured for that cluster
- The `kubectl argo rollouts` plugin installed

## 1. Create the Services

Blue/green rollouts usually use:

- one active Service for production traffic
- one preview Service for the new version before promotion

Apply these Services first:

```bash
kubectl apply -f https://raw.githubusercontent.com/parisnakitakejser/PnkCore/refs/heads/main/cncf-certifications/capa/domains/argo-rollouts/argo-rollouts-blue-green/bluegreen-services.yaml
```

The Rollouts controller updates the selectors behind these Services during the rollout process.

## 2. Create the Initial Blue Rollout

Apply this Rollout manifest for the first version:

Apply the resources:

```bash
kubectl apply -f https://raw.githubusercontent.com/parisnakitakejser/PnkCore/refs/heads/main/cncf-certifications/capa/domains/argo-rollouts/argo-rollouts-blue-green/rollout-blue.yaml
```

## 3. Inspect the Rollout

Check rollout status:

```bash
kubectl argo rollouts get rollout rollout-bluegreen
```

You can also watch it:

```bash
kubectl argo rollouts get rollout rollout-bluegreen --watch
```

## 4. Update the Rollout to Green

To create the new preview version, change the image from `blue` to `green`:

Apply the updated Rollout:

```bash
kubectl apply -f https://raw.githubusercontent.com/parisnakitakejser/PnkCore/refs/heads/main/cncf-certifications/capa/domains/argo-rollouts/argo-rollouts-blue-green/rollout-green.yaml
```

Because `autoPromotionEnabled: false` is set, the rollout will pause before switching production traffic.

## 5. Promote the Green Version

Manually promote the rollout:

```bash
kubectl argo rollouts promote rollout-bluegreen
```

After promotion, the active Service points to the green ReplicaSet.

## 6. Inspect the Services and Pods

Check the Rollout and Services:

```bash
kubectl argo rollouts get rollout rollout-bluegreen
kubectl get svc
kubectl get pods -l app=rollout-bluegreen
```

If you want to see the dashboard:

```bash
kubectl argo rollouts dashboard
```

## 7. What to Look For

During a blue/green rollout:

- the current version stays behind the active Service
- the new version comes up behind the preview Service
- traffic does not switch automatically when `autoPromotionEnabled: false`
- promotion moves the active Service to the new ReplicaSet

This is the key blue/green behavior you should understand for the exam.

## Exam Notes

- Know that Argo Rollouts uses a `Rollout` resource instead of a normal `Deployment`
- Know the purpose of the active and preview Services
- Know that blue/green creates a new version before switching live traffic
- Know that `autoPromotionEnabled: false` pauses the rollout before cutover
- Know how to promote the rollout manually with `kubectl argo rollouts promote`