# ArgoCD Setup Guide

This directory contains ArgoCD configuration for GitOps-based application deployment.

## Installation

### Manual Bootstrap Script (Recommended)

After deploying your Kubernetes cluster with Terraform, install ArgoCD:

```bash
cd argocd/
./bootstrap-argocd.sh
```

The script will:
1. Create the `argocd` namespace
2. Install ArgoCD via Helm chart
3. Wait for ArgoCD to be ready
4. Apply the self-management Application
5. Apply the config Application
6. Display the admin password

### Alternative: Manual Helm Installation

```bash
kubectl create namespace argocd
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd --namespace argocd --version 7.7.0 \
  --set server.service.type=ClusterIP \
  --set configs.params."server\.insecure"=true
```

## Architecture

```
┌──────────────────────────────────────────────────┐
│          Manual Bootstrap Script                  │
│  (One-time installation via bootstrap-argocd.sh) │
└────────────────┬─────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────┐
│            ArgoCD Self-Management                 │
│  (ArgoCD manages its own Helm chart)             │
└────────────────┬─────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────┐
│          ArgoCD Configuration                     │
│  (Custom ingress, notifications, etc.)           │
└──────────────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────┐
│          Your Applications                        │
│  (Vault, Immich, Longhorn, etc.)                 │
└──────────────────────────────────────────────────┘
```

## File Structure

```
argocd/
├── README.md                        # This file
├── bootstrap-argocd.sh              # ArgoCD installation script
├── argocd-self-management.yaml      # ArgoCD manages itself
├── argocd-config-application.yaml   # Manages custom ArgoCD configs
├── argocd-server.yaml              # Legacy file (can be deleted)
├── config/
│   ├── kustomization.yaml          # Organizes custom configs
│   ├── ingress.yaml                # ArgoCD ingress configuration
│   ├── frontend-config.yaml        # UI customization
│   └── notification-catalog.yaml   # Notification templates
└── apps/                            # All application manifests
    ├── vault/                      # Vault + External Secrets
    ├── immich/                     # Photo management
    ├── longhorn/                   # Storage provider
    ├── metallb/                    # Load balancer
    ├── nginx/                      # Ingress controller
    └── tailscale/                  # VPN networking
```

## Applications

### argocd-self-management.yaml
Allows ArgoCD to manage its own Helm chart. This enables:
- Version upgrades via Git
- Configuration changes via Git
- Self-healing if configuration drifts

### argocd-config-application.yaml
Manages custom ArgoCD configurations from the `config/` directory:
- Ingress rules
- Frontend customization
- Notification catalogs

## Access ArgoCD

### Get Admin Password

```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
echo
```

### Port Forward to ArgoCD UI

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then visit: http://localhost:8080
- **Username**: `admin`
- **Password**: (from command above)

### Via Ingress (if configured)

If you have an ingress configured, access ArgoCD at your ingress URL.

## Deploying Applications

### Method 1: Via kubectl

```bash
kubectl apply -f apps/<app-name>/<app-name>-application.yaml
```

Example:
```bash
kubectl apply -f apps/vault/vault-application.yaml
kubectl apply -f apps/immich/argocd-application.yaml
```

### Method 2: Via ArgoCD UI

1. Access the ArgoCD UI
2. Click "New App"
3. Fill in the details or import from YAML

### Method 3: App of Apps Pattern

Create a parent Application that deploys all your applications:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://github.com/marcellof23/cellotadel.git'
    targetRevision: HEAD
    path: argocd/apps
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Upgrading ArgoCD

Since ArgoCD manages itself, to upgrade:

1. Edit `argocd-self-management.yaml`
2. Update the `targetRevision` to the new chart version
3. Commit and push to Git
4. ArgoCD will automatically upgrade itself

## Managing ArgoCD Configuration

All configuration changes should be made via Git:

1. Edit files in `argocd/config/`
2. Commit and push
3. ArgoCD automatically syncs the changes

## Customizations

### Add Ingress

Edit `config/ingress.yaml` to expose ArgoCD externally:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server
  namespace: argocd
spec:
  rules:
    - host: argocd.yourdomain.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 80
```

### Add Notifications

Edit `config/notification-catalog.yaml` to configure notifications for deployments (Slack, Discord, etc.)

## Troubleshooting

### Check ArgoCD Health

```bash
kubectl get pods -n argocd
kubectl get applications -n argocd
```

### View Application Status

```bash
kubectl describe application <app-name> -n argocd
```

### Check ArgoCD Logs

```bash
# Server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Application controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### Sync Issues

If an application won't sync:

```bash
# Force sync
argocd app sync <app-name>

# Or delete and recreate
kubectl delete application <app-name> -n argocd
kubectl apply -f apps/<app-name>/<app-name>-application.yaml
```

## Best Practices

1. **Always use Git as source of truth** - Don't make manual changes in the cluster
2. **Use automated sync** - Enable `prune` and `selfHeal` for automated reconciliation
3. **Tag your changes** - Use Git tags for production deployments
4. **Monitor ArgoCD** - Set up notifications for sync failures
5. **Backup ArgoCD** - Export Applications and configurations regularly

## Security Notes

- The bootstrap uses `--insecure` flag (no TLS) - add TLS for production
- Change the admin password after first login
- Consider enabling SSO (OAuth, OIDC) for team access
- Use RBAC to restrict access to specific applications
- Store sensitive values in Vault, not in Git

## Legacy Files

- `argocd-server.yaml` - Old exported manifest, no longer needed (managed by Helm now)

