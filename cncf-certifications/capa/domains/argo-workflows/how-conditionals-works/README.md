# CAPA Exam Prep: Argo Workflows - How Conditionals Work in Argo Workflows

This guide covers the conditional execution pattern you should know for CAPA-style lab work:

- Run a step and use its output in later conditions
- Use `when` to control whether a step runs
- Branch based on simple equality checks
- Use more complex logical expressions
- Use regex matching in conditional steps

## Prerequisites

- A working Kubernetes cluster
- Argo Workflows installed in the cluster
- `kubectl` configured for that cluster
- Optional: the `argo` CLI installed locally

This example assumes Argo Workflows is running in the `argo` namespace.

## 1. Review the Workflow

This folder includes [workflow-conditionals.yaml](/Users/parisnakitakejser/Developer/PnkCore/cncf-certifications/capa/domains/argo-workflows/Conditionals/workflow-conditionals.yaml).

It defines a workflow that flips a virtual coin, checks the result, flips again, and then runs later steps only when specific conditions are true.

Workflow definition:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: coinflip-
spec:
  entrypoint: coinflip
  serviceAccountName: argo
  templates:
    - name: coinflip
      steps:
        - - name: flip-coin
            template: flip-coin

        - - name: heads
            template: heads
            when: "{{steps.flip-coin.outputs.result}} == heads"
          - name: tails
            template: tails
            when: "{{steps.flip-coin.outputs.result}} == tails"

        - - name: flip-again
            template: flip-coin

        - - name: complex-condition
            template: heads-tails-or-twice-tails
            when: >-
              ( {{steps.flip-coin.outputs.result}} == heads &&
                {{steps.flip-again.outputs.result}} == tails
              ) ||
              ( {{steps.flip-coin.outputs.result}} == tails &&
                {{steps.flip-again.outputs.result}} == tails )

          - name: heads-regex
            template: heads
            when: "{{steps.flip-again.outputs.result}} =~ hea"

          - name: tails-regex
            template: tails
            when: "{{steps.flip-again.outputs.result}} =~ tai"

    - name: flip-coin
      script:
        image: python:alpine3.23
        command: [python]
        source: |
          import random
          result = "heads" if random.randint(0,1) == 0 else "tails"
          print(result)

    - name: heads
      container:
        image: alpine:3.23
        command: [sh, -c]
        args: ["echo \"it was heads\""]

    - name: tails
      container:
        image: alpine:3.23
        command: [sh, -c]
        args: ["echo \"it was tails\""]

    - name: heads-tails-or-twice-tails
      container:
        image: alpine:3.23
        command: [sh, -c]
        args: ["echo \"it was heads the first flip and tails the second. Or it was two times tails.\""]
```

## 2. Understand the Conditional Flow

This workflow demonstrates several conditional patterns.

First coin flip:

- `flip-coin` produces either `heads` or `tails`
- Only one of the next two steps should run:
  - `heads`
  - `tails`

Second coin flip:

- `flip-again` runs after the first branch
- Later steps inspect the second result as well

Complex condition:

- `complex-condition` runs if:
  - the first flip is `heads` and the second is `tails`
  - or both flips are `tails`

Regex examples:

- `heads-regex` runs if the second result matches `hea`
- `tails-regex` runs if the second result matches `tai`

## 3. Service Account Permissions for a Lab

In a local or lab environment, you may need to grant broader permissions so workflows can run successfully.

Only do this in a test environment. For production, follow the official Argo Workflows service account guidance:

https://argo-workflows.readthedocs.io/en/latest/service-accounts/

Example lab-friendly RoleBinding:

```bash
kubectl create rolebinding argo-admin \
  --clusterrole=admin \
  --serviceaccount=argo:argo \
  -n argo
```

## 4. Create the Workflow

Because this manifest uses `generateName`, create it with `kubectl create`:

```bash
kubectl create -f workflow-conditionals.yaml -n argo
```

You can also submit it with the Argo CLI:

```bash
argo submit workflow-conditionals.yaml -n argo
```

Do not use `kubectl apply` with this file unless you first replace `generateName` with a fixed `name`.

## 5. Inspect the Result

List workflows:

```bash
kubectl get workflows -n argo
```

Inspect the generated workflow:

```bash
argo list -n argo
argo get -n argo <workflow-name>
```

View the logs:

```bash
argo logs -n argo <workflow-name>
```

Replace `<workflow-name>` with the generated workflow name, for example `coinflip-xxxxx`.

## 6. What to Look for in the Output

When you run this workflow:

- only one of `heads` or `tails` should run after the first flip
- `flip-again` runs after that branch
- the regex-based steps depend on the second flip result
- `complex-condition` only runs when the logical expression evaluates to true

This makes it a good study example because you can see which steps were skipped and which ones were executed.

## Exam Notes

- Know that `when` controls whether a step runs
- Know that conditional expressions can use previous step outputs
- Know that Argo Workflows supports equality checks, logical operators, and regex matching
- Know that skipped steps are expected behavior when conditions evaluate to false
- Know that `generateName` works with `kubectl create` or `argo submit`
