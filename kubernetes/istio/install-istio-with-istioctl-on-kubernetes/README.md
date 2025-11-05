# Install Istio with istioctl on Kubernetes (Kind Setup + Namespace Injection Demo)

**Install istioctl**

```sh
curl -sL https://istio.io/downloadIstioctl | sh -
export PATH=$HOME/.istioctl/bin:$PATH
``

**Install Istio into Kubernetes**

```sh
istioctl install
kubectl get pods -n istio-system
```

**Create and label test-app namespace**

```sh
kubectl create namespace test-app
kubectl label namespace test-app istio-injection=enabled
```

**Apply hello-world manifest to both namespaces**

```sh
kubectl apply -f hello-world-deployment.yaml
kubectl apply -f hello-world-deployment.yaml -n test-app
```