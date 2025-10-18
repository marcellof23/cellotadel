# Vault Setup Guide

## Step 1: Install and Configure Vault

### Add the HashiCorp Helm repo

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
```

### Install Vault

Install Vault in dev mode for simplicity. For production, you must follow the full production hardening guide.

```bash
helm install vault hashicorp/vault --namespace vault --create-namespace \
  --set "server.dev.enabled=true"
```

### Initialize and Unseal Vault

Get a shell into the Vault pod and initialize it. In a real setup, you would run `vault operator init` and unseal the vault, storing the unseal keys and root token securely. For this dev setup, the root token is just `root`.

```bash
# Find the pod name
kubectl get pods -n vault

# Exec into the pod
kubectl exec -it vault-0 -n vault -- /bin/sh
```

Inside the Vault pod shell:

```bash
# Set the vault address (for this shell session)
export VAULT_ADDR='http://127.0.0.1:8200'

# Store the Immich database password in Vault
# This creates a secret named 'immich' with a key 'DB_PASSWORD' inside it.
vault kv put secret/immich DB_PASSWORD="YOUR_SUPER_SECRET_PASSWORD"

# Exit the pod
exit
```

## Step 2: Install and Configure External Secrets Operator (ESO)

### Add the ESO Helm repo

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
```

### Install External Secrets Operator

```bash
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets --create-namespace
```

## Step 3: Configure Vault and ESO to Talk to Each Other

We need to give ESO permission to read secrets from Vault. We'll use the Kubernetes Auth Method, which allows a Kubernetes Service Account to authenticate with Vault.

### Enable and Configure Kubernetes Auth in Vault

```bash
# Exec back into your Vault pod
kubectl exec -it vault-0 -n vault -- /bin/sh
```

Inside the Vault pod shell:

```bash
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root' # Use your root token here

# 1. Enable Kubernetes auth
vault auth enable kubernetes

# 2. Configure it to talk to the cluster's API server
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc"

# 3. Create a policy that allows reading the immich secret
vault policy write immich-policy - <<EOF
path "secret/data/immich" {
  capabilities = ["read"]
}
EOF

# 4. Create a role that binds the policy to the ESO Service Account
# This says "Any service account named 'external-secrets' in the 'external-secrets'
# namespace is allowed to assume the 'immich-policy' role."
vault write auth/kubernetes/role/external-secrets \
  bound_service_account_names=external-secrets \
  bound_service_account_namespaces=external-secrets \
  policies=immich-policy \
  ttl=24h

# Exit the pod
exit
```

### Create a SecretStore

This is a Kubernetes resource that tells ESO how to connect to Vault. This file goes into your Git repository for Argo CD to manage.

Create a file `apps/immich/vault-secret-store.yaml`:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: immich # Create this in the same namespace as Immich
spec:
  provider:
    vault:
      # The ClusterIP service of your Vault instance
      server: "http://vault.vault.svc.cluster.local:8200"
      path: "secret" # The default KV engine path
      version: "v2"  # Use v2 for KV secrets
      auth:
        # Authenticate using the Kubernetes Service Account method
        kubernetes:
          mountPath: "kubernetes"
          role: "external-secrets" # The role we created in Vault
          # The SA that ESO runs as, which is bound to the role
          serviceAccountRef:
            name: "external-secrets"
