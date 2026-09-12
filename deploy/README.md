# Deploying to Azure

Runs the full stack (Kong + auth-service + chat-service + Postgres + Redis + Kafka/Zookeeper)
on an Azure VM, with Caddy in front of Kong for free automatic HTTPS via Let's Encrypt, so a
browser-based frontend (e.g. Next.js on Vercel) can call it without mixed-content errors.

## Currently deployed

| | |
|---|---|
| URL | `https://nasser-microservices.uaenorth.cloudapp.azure.com` |
| Resource group | `microservices-task-rg` |
| VM | `microservices-vm`, Standard_D2s_v3 (2 vCPU / 8GB), UAE North |
| Cost | ~$0.12/hr (~$86/month if left running 24/7) — see "Managing cost" below |

## Why not the free B1s VM?

The original plan targeted Azure's Always-Free `Standard_B1s` (1 vCPU/1GB, free for 12
months). In practice, for this subscription (Azure for Students), two separate restrictions
blocked it:

1. **A subscription-level region policy** limits deployment to 5 regions only. Check yours
   with:
   ```bash
   az policy assignment show --name "sys.regionrestriction" --scope "/subscriptions/<id>" \
     --query "parameters.listOfAllowedLocations.value" -o tsv
   ```
2. **Capacity restrictions**: `Standard_B1s` (and `B1ms`, `B2s`) had zero available capacity
   in every one of those 5 allowed regions at the time of deployment — confirmed by trying
   each size in each region via both `az vm create` and the Portal's VM size picker. This can
   change over time; worth retrying later if you want to chase the genuinely-free tier.

`Standard_D2s_v3` was the cheapest size that actually had capacity, in UAE North. It draws
against the $100 Azure for Students credit rather than being free, but comfortably runs the
whole stack (8GB vs. the 1GB the trimmed compose file was originally budgeted for).

## 1. Push auth-service and chat-service to GitHub

They're separate git repos nested inside this one, untracked by the root repo. Push each to
its own GitHub repo (private is fine, free) if you haven't already — the VM needs to
`git clone` all three (root, auth-service, chat-service) independently.

## 2. Create the VM

```bash
az login

RESOURCE_GROUP="microservices-task-rg"
VM_NAME="microservices-vm"

az group create --name "$RESOURCE_GROUP" --location "eastus"   # RG location is just metadata

# Find your allowed regions first (see "Why not the free B1s VM?" above), then try the
# cheapest available size in each until one is accepted. Standard_B1s is worth trying first —
# capacity availability changes over time.
az vm create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --location "uaenorth" \
  --image Ubuntu2204 \
  --size Standard_D2s_v3 \
  --admin-username azureuser \
  --generate-ssh-keys \
  --public-ip-sku Standard

# Open the ports the stack actually needs publicly (22 for SSH is opened by default by
# az vm create; 80/443 for Caddy need opening explicitly).
# Kong's 8000/8001 stay internal to the docker network — not opened here on purpose.
az vm open-port --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" --port 80 --priority 110
az vm open-port --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" --port 443 --priority 120
```

## 3. Set the free DNS label (for HTTPS)

```bash
NIC_ID=$(az vm show -g "$RESOURCE_GROUP" -n "$VM_NAME" --query "networkProfile.networkInterfaces[0].id" -o tsv)
IP_ID=$(az network nic show --ids "$NIC_ID" --query "ipConfigurations[0].publicIPAddress.id" -o tsv)
PUBLIC_IP_NAME=$(az network public-ip show --ids "$IP_ID" --query "name" -o tsv)

az network public-ip update \
  --resource-group "$RESOURCE_GROUP" \
  --name "$PUBLIC_IP_NAME" \
  --dns-name "<pick-something-unique>"

# Prints your domain, e.g. myapp.uaenorth.cloudapp.azure.com — this is your AZURE_DNS_LABEL.
az network public-ip show --resource-group "$RESOURCE_GROUP" --name "$PUBLIC_IP_NAME" --query "dnsSettings.fqdn" -o tsv
```

## 4. Prepare and copy up `.env`

Locally: copy `.env.production.example` to `.env`, fill in a freshly generated
`POSTGRES_PASSWORD` and `JWT_SECRET` (a random hex string works for both), your
`ALLOWED_ORIGINS` (your Vercel frontend URL), and the `AZURE_DNS_LABEL` from step 3.

```bash
VM_IP=$(az vm show -d -g "$RESOURCE_GROUP" -n "$VM_NAME" --query publicIps -o tsv)
scp -i ~/.ssh/id_rsa .env azureuser@"$VM_IP":~/microservices-task.env  # copied up before the repo exists yet
```

## 5. Bootstrap the VM

```bash
ssh -i ~/.ssh/id_rsa azureuser@"$VM_IP"

# On the VM: edit the three repo URLs at the top of deploy/azure-vm-setup.sh (or pull it
# down directly since it's small and doesn't need the full repo first):
curl -fsSL https://raw.githubusercontent.com/<you>/microservices-project/master/deploy/azure-vm-setup.sh -o azure-vm-setup.sh
nano azure-vm-setup.sh   # fill in ROOT_REPO_URL / AUTH_SERVICE_REPO_URL / CHAT_SERVICE_REPO_URL / APP_DIR
chmod +x azure-vm-setup.sh
./azure-vm-setup.sh   # clones everything, installs Docker, adds swap — will exit asking for .env

mv ~/microservices-task.env ~/<APP_DIR>/.env
./azure-vm-setup.sh   # re-run: now finds .env and brings the stack up
```

## 6. Verify

```bash
sudo docker compose -f docker-compose.prod.yml ps
curl https://<your-azure-dns-label>/auth/health
curl https://<your-azure-dns-label>/chat/health
```

Then point your Vercel frontend's API base URL at `https://<your-azure-dns-label>` and confirm
a browser request succeeds (no mixed-content or CORS errors — `ALLOWED_ORIGINS` in `.env` must
include the exact Vercel URL).

## Redeploying after a code change

```bash
ssh -i ~/.ssh/id_rsa azureuser@"$VM_IP"
cd ~/<APP_DIR> && git pull
cd auth-service && git pull && cd ..     # if auth-service changed
cd chat-service && git pull && cd ..     # if chat-service changed
sudo docker compose -f docker-compose.prod.yml up -d --build
```

## Managing cost

This deployment draws against the Azure for Students $100 credit at ~$0.12/hour
(~$86/month if left running continuously — confirm current pricing since it changes:
`az vm list-usage`/the Azure pricing calculator, or the retail prices API for
`Standard_D2s_v3` in your region). To conserve credit between sessions:

```bash
# Stops compute billing almost entirely (small disk storage cost remains, ~$5-8/month for a
# 30GB OS disk). The public IP is retained (Standard SKU), so the DNS label keeps working
# once you start it again.
az vm deallocate --resource-group "microservices-task-rg" --name "microservices-vm"

# Resume later:
az vm start --resource-group "microservices-task-rg" --name "microservices-vm"
# Containers with `restart: unless-stopped` come back up automatically once Docker starts.
```

## Known limits of this setup

- **This VM (8GB RAM) isn't the resource-constrained box the compose file's memory limits
  were originally tuned for** (that was written for the 1GB B1s that turned out to be
  unavailable — see above). The limits in `docker-compose.prod.yml` are still in effect and
  harmless (just extra headroom), not a problem, but nothing in this deploy still needs the
  aggressive tuning they represent.
- **First boot only: chat-service's Kafka consumer can crash once or twice** while Kafka's
  internal coordinator is still electing a leader (`There is no leader for this
  topic-partition` / `group coordinator is not available` in `docker compose logs
  chat-service`). It recovers on its own within under a minute in testing and doesn't
  reappear afterward. If a registration made during that exact window doesn't show up via
  `/api/users/me` on chat-service, wait for the stack to settle and register again, or
  `sudo docker compose -f docker-compose.prod.yml restart chat-service`.
- **`/auth/docs` and `/chat/docs` redirect to a 404 through Kong.** swagger-ui-express issues
  a root-relative redirect (`/docs` → `/docs/`) that doesn't know it's behind Kong's `/auth`
  prefix, so the followed redirect 404s at the gateway. The underlying REST/WebSocket routes
  are unaffected — this only breaks browsing the interactive Swagger UI through the public
  URL. Hitting docs on the container directly (`docker compose exec auth-service` and curl
  localhost:3001/docs) still works.
- **Kong's Admin API isn't published to the host** (by design — it shouldn't be
  internet-facing). To inspect it, `sudo docker compose -f docker-compose.prod.yml exec kong
  curl localhost:8001/status` from inside the VM, or temporarily `sudo docker compose -f
  docker-compose.prod.yml exec kong sh`.
- **Maintenance mode and other plugin toggles are no longer runtime Admin-API calls** — Kong
  runs DB-less here, so config changes mean editing `deploy/kong/kong.yml` and redeploying
  (`sudo docker compose -f docker-compose.prod.yml up -d`, which reloads the mounted file).
  The root Makefile's `maintenance-on`/`maintenance-off` targets only work against the local
  dev stack (Postgres-backed Kong).
- **No automated CI/CD here** — this is a manual SSH-and-pull deploy, matching a single-VM
  personal/demo deployment. If this becomes a real service, revisit with a proper CD pipeline.
- **`docker compose` needs `sudo` on the VM** (`azure-vm-setup.sh` uses `sudo docker compose`)
  because the `usermod -aG docker` group change earlier in the same script doesn't take effect
  until a fresh login. If you SSH in as a new session afterward, plain `docker compose` (no
  sudo) works fine.
