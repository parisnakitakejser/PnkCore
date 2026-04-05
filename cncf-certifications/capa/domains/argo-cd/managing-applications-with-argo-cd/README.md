# CAPA Exam Prep: Managing Applications with Argo CD

If you do not already have Argo CD set up for testing, go to the "setting up Argo CD" section first and deploy Argo CD before continuing.

When studying this topic, the important thing is not just memorizing the command. A student should understand the deployment flow inside Argo CD:

1. Your application manifests live in Git.
2. An Argo CD `Application` resource points to that Git repository and path.
3. You apply that `Application` resource into the Argo CD namespace.
4. Argo CD reads the desired state from Git.
5. Argo CD syncs that desired state into the target Kubernetes namespace.
6. Argo CD then keeps comparing Git with the live cluster state.

In this example, the `Application` manifest in [application.yaml](/Users/parisnakitakejser/Developer/PnkCore/cncf-certifications/capa/domains/argo-cd/managing-applications-with-argo-cd/application.yaml) points Argo CD to the example app manifests in the repository. Argo CD will then create and manage those Kubernetes resources for you.

Let's deploy a simple application with Argo CD using the simplest approach:

```
kubectl apply -f application.yaml -n argocd
```

After you run that command, this is the flow you should understand:

1. Kubernetes creates the Argo CD `Application` object in the `argocd` namespace.
2. Argo CD sees that new `Application`.
3. Argo CD fetches the manifests from the Git repository and the configured path.
4. Argo CD deploys the resources into the destination namespace.
5. In this example, `CreateNamespace=true` allows Argo CD to create the target namespace if it does not already exist.
6. Argo CD shows the sync status and health status in the UI.

You can then open the Argo CD UI and see the application syncing. If you click into the application, you can inspect the resources Argo CD created and how they relate to each other.

For the exam, make sure you understand the difference between:

- The `Application` resource, which tells Argo CD what to deploy.
- The application manifests in Git, which describe the Kubernetes resources Argo CD should create.
- The target cluster and namespace, which is where Argo CD deploys those resources.
