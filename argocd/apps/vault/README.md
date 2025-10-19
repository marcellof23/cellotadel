# Vault Setup Guide

This guide shows you how to integrate HashiCorp Vault with Kubernetes using ArgoCD for GitOps deployment and External Secrets Operator for secret management.

In this tutorial, I'll provide you step-by-step how to connect Vault to a Kubernetes deployment. In this case, I use Immich as an example.

## Architecture Overview

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────┐
│   ArgoCD    │────▶│      Vault       │◀────│ External    │
│             │     │   (Dev Mode)     │     │  Secrets    │
└─────────────┘     └──────────────────┘     │  Operator   │
                            │                 └─────────────┘
                            │                        │
                            ▼                        ▼
                    ┌──────────────┐        ┌──────────────┐
                    │ Kubernetes   │        │ SecretStore  │
                    │   Secrets    │◀───────│ External     │
                    │              │        │   Secret     │
                    └──────────────┘        └──────────────┘
```

## Quick Start

### Step 1: Deploy Vault via ArgoCD

Apply the Vault ArgoCD Application:

```bash
kubectl apply -f argocd/apps/vault/vault-application.yaml
```

This will:
- Install Vault in dev mode in the `vault` namespace
- Expose the Vault UI as a ClusterIP service
- Use the root token: `root` (dev mode only)

### Step 2: Deploy External Secrets Operator

Apply the External Secrets Operator ArgoCD Application:

```bash
kubectl apply -f argocd/apps/vault/external-secrets-application.yaml
```

This will:
- Install External Secrets Operator in the `external-secrets` namespace
- Install all necessary CRDs (SecretStore, ExternalSecret, etc.)

### Step 3: Configure Vault

Apply the Vault configuration:

```bash
kubectl apply -f argocd/apps/vault/vault-config-application.yaml
```

This will automatically:
- Enable Kubernetes authentication in Vault
- Configure Kubernetes auth to talk to your cluster
- Create policies for reading secrets
- Create roles binding the policies to the External Secrets Operator service account
- Store initial secrets (you need to update the secrets in `config/vault-secrets-job.yaml`)

### Step 4: Update Your Secrets

Before applying the configuration, update the secrets in `argocd/apps/vault/config/vault-secrets-job.yaml`:

```yaml
# Change this line:
vault kv put secret/immich \
  DB_PASSWORD="YOUR_SUPER_SECRET_PASSWORD"
```

## Using Vault with Your Applications

### 1. Create a SecretStore

In your application namespace (e.g., `immich`), create a SecretStore that references Vault:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: immich
spec:
  provider:
    vault:
      server: "http://vault.vault.svc.cluster.local:8200"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "external-secrets"
          serviceAccountRef:
            name: "external-secrets"
```

### 2. Create an ExternalSecret

Create an ExternalSecret resource to pull secrets from Vault:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: immich-secret
  namespace: immich
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: immich-secret
    creationPolicy: Owner
  data:
    - secretKey: DB_PASSWORD
      remoteRef:
        key: immich
        property: DB_PASSWORD
```

### 3. Reference the Secret in Your Deployment

```yaml
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: immich-secret
        key: DB_PASSWORD
```

## Troubleshooting

### Secret Not Found Error

If you see `message: secret "immich-secret" not found`, you need to restart your deployment:

```bash
kubectl rollout restart deployment/<your-deployment> -n <namespace>
```

This is because the deployment will consume the new secret after restart, unless it will point to the previous secret.

### Check Vault Status

```bash
kubectl exec -it vault-0 -n vault -- vault status
```

### Check External Secrets Operator Logs

```bash
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets
```

### Verify SecretStore Status

```bash
kubectl get secretstore -n <your-namespace>
kubectl describe secretstore vault-backend -n <your-namespace>
```

### Verify ExternalSecret Status

```bash
kubectl get externalsecret -n <your-namespace>
kubectl describe externalsecret <name> -n <your-namespace>
```

## Adding Secrets for New Applications

### 1. Store the Secret in Vault

Edit `argocd/apps/vault/config/vault-secrets-job.yaml` and add your secret:

```bash
vault kv put secret/myapp \
  API_KEY="your-api-key" \
  DATABASE_URL="postgresql://..."
```

### 2. Create a Policy (Optional)

If you want separate policies per app, edit `argocd/apps/vault/config/vault-init-job.yaml`:

```bash
vault policy write myapp-policy - <<EOF
path "secret/data/myapp" {
  capabilities = ["read"]
}
EOF
```

### 3. Update the Role

Add the new policy to the External Secrets role:

```bash
vault write auth/kubernetes/role/external-secrets \
  bound_service_account_names=external-secrets \
  bound_service_account_namespaces=external-secrets \
  policies=immich-policy,myapp-policy \
  ttl=24h
```

### 4. Create SecretStore and ExternalSecret

Follow the pattern shown above in your application's namespace.

## Production Considerations

⚠️ **This setup uses Vault in dev mode for homelab/testing purposes.**

For production, you should:
1. Disable dev mode and use proper storage backend
2. Initialize Vault properly with `vault operator init`
3. Store unseal keys securely (consider using Shamir's Secret Sharing)
4. Use proper TLS certificates
5. Implement proper backup strategy
6. Use separate policies per application
7. Consider using Vault Agent Injector for pod-level secrets
8. Enable audit logging

## File Structure

```
argocd/apps/vault/
├── README.md                           # This file
├── vault-application.yaml              # ArgoCD App for Vault
├── external-secrets-application.yaml   # ArgoCD App for External Secrets Operator
├── vault-config-application.yaml       # ArgoCD App for Vault configuration
└── config/
    ├── kustomization.yaml             # Kustomize config
    ├── vault-init-job.yaml            # Job to initialize Vault auth
    └── vault-secrets-job.yaml         # Job to store initial secrets
```

## Next Steps

After deployment:
1. Access Vault UI via port-forward: `kubectl port-forward -n vault svc/vault 8200:8200`
2. Login with token `root` (dev mode)
3. Verify your secrets are stored: `vault kv get secret/immich`
4. Deploy your applications with ExternalSecret resources
