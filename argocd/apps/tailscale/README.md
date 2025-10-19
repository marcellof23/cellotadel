First setup vault secret

kubectl create secret generic tailscale-auth \
  --from-literal=authkey='<YOUR_TAILSCALE_AUTH_KEY>' \
  -n tailscale # We will deploy the operator into the 'tailscale' namespace
