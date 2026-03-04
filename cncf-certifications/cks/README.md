# Certified Kubernetes Security Specialist (CKS)

Domains:
- Cluster Setup - 15%
  - Use Network security policies to restrict cluster level access
  - Use CIS benchmark to review the security configuration of Kubernetes components (etcd, kubelet, kubedns, kubeapi)
  - Properly set up Ingress with TLS
  - Protect node metadata and endpoints
  - Verify platform binaries before deploying

- Cluster Hardening - 15%
  - Use Role Based Access Controls to minimize exposure
  - Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
  - Restrict access to Kubernetes API
  - Upgrade Kubernetes to avoid vulnerabilities

- System Hardening - 10%
  - Minimize host OS footprint (reduce attack surface)
  - Using least-privilege identity and access management
  - Minimize external access to the network
  - Appropriately use kernel hardening tools such as AppArmor, seccomp

- Minimize Microservice Vulnerabilities - 20%
  - Use appropriate pod security standards
  - Manage Kubernetes secrets
  - Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
  - Implement Pod-to-Pod encryption (Cilium, Istio)

- Supply Chain Security - 20%
  - Minimize base image footprint
  - Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
  - Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
  - Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)

- Monitoring, Logging and Runtime Security - 20%
  - Perform behavioral analytics to detect malicious activities
  - Detect threats within physical infrastructure, apps, networks, data, users and workloads
  - Investigate and identify phases of attack and bad actors within the environment
  - Ensure immutability of containers at runtime
  - Use Kubernetes audit logs to monitor access