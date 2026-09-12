# Deploying to Azure for $0

Runs the full stack (Kong + auth-service + chat-service + Postgres + Redis + Kafka/Zookeeper)
on Azure's Always-Free `Standard_B1s` VM (1 vCPU / 1GB RAM, free for the first 12 months of
the account, then billed — see [Azure free account
terms](https://azure.microsoft.com/en-us/free/) for current limits). Caddy in front of Kong
gets you free automatic HTTPS via Let's Encrypt, so a browser-based frontend (e.g. Next.js on
Vercel) can call it without mixed-content errors.

1GB RAM is tight for this stack. `docker-compose.prod.yml` trims and memory-limits everything
it can (see the comments in that file); a 2GB swapfile is the safety net for the rest. Expect
this to be fine for low-traffic/demo use, not for real production load — see "Known limits"
below.

I can't run any of this for you — it needs your Azure login and GitHub repos. This is the
runbook to follow yourself (or paste to me a step at a time if something errors).

## 1. Push auth-service and chat-service to GitHub

They're currently separate git repos nested inside this one, untracked by the root repo. Push
each to its own GitHub repo (private is fine, free) if you haven't already — the VM needs to
`git clone` all three (root, auth-service, chat-service) independently.

## 2. Create the VM

```bash
# One-time: log in and pick a free-tier-eligible region (check the Azure portal's
# "Free services" page for which regions currently qualify for your subscription — this
# changes over time, so don't assume eastus/westus are still current).
az login

RESOURCE_GROUP="microservices-task-rg"
LOCATION="eastus"
VM_NAME="microservices-vm"

az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

az vm create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --admin-username azureuser \
  --generate-ssh-keys \
  --public-ip-sku Basic

# Open the ports the stack actually needs publicly (22 for SSH, 80/443 for Caddy).
# Kong's 8000/8001 stay internal to the docker network — not opened here on purpose.
az vm open-port --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" --port 22 --priority 100
az vm open-port --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" --port 80 --priority 110
az vm open-port --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" --port 443 --priority 120
```

## 3. Set the free DNS label (for HTTPS)

```bash
PUBLIC_IP_NAME=$(az vm show -g "$RESOURCE_GROUP" -n "$VM_NAME" --query "networkProfile.networkInterfaces[0].id" -o tsv | xargs -I{} az network nic show --ids {} --query "ipConfigurations[0].publicIPAddress.id" -o tsv | xargs -I{} az network public-ip show --ids {} --query "name" -o tsv)

az network public-ip update \
  --resource-group "$RESOURCE_GROUP" \
  --name "$PUBLIC_IP_NAME" \
  --dns-name "<pick-something-unique>"

# Prints your domain, e.g. myapp.eastus.cloudapp.azure.com — this is your AZURE_DNS_LABEL.
az network public-ip show --resource-group "$RESOURCE_GROUP" --name "$PUBLIC_IP_NAME" --query "dnsSettings.fqdn" -o tsv
```

## 4. Prepare and copy up `.env`

Locally: copy `.env.production.example` to `.env`, fill in a freshly generated
`POSTGRES_PASSWORD` and `JWT_SECRET` (`openssl rand -hex 32`), your `ALLOWED_ORIGINS`
(your Vercel frontend URL), and the `AZURE_DNS_LABEL` from step 3.

```bash
VM_IP=$(az vm show -d -g "$RESOURCE_GROUP" -n "$VM_NAME" --query publicIps -o tsv)
scp .env azureuser@"$VM_IP":~/microservices-task.env  # copied up before the repo exists yet
```

## 5. Bootstrap the VM

```bash
ssh azureuser@"$VM_IP"

# On the VM: edit the three repo URLs at the top of deploy/azure-vm-setup.sh (or pull it
# down directly since it's small and doesn't need the full repo first):
curl -fsSL https://raw.githubusercontent.com/<you>/microservices-task/master/deploy/azure-vm-setup.sh -o azure-vm-setup.sh
nano azure-vm-setup.sh   # fill in ROOT_REPO_URL / AUTH_SERVICE_REPO_URL / CHAT_SERVICE_REPO_URL
chmod +x azure-vm-setup.sh
./azure-vm-setup.sh   # clones everything, installs Docker, adds swap — will exit asking for .env

mv ~/microservices-task.env ~/microservices-task/.env
./azure-vm-setup.sh   # re-run: now finds .env and brings the stack up
```

## 6. Verify

```bash
docker compose -f docker-compose.prod.yml ps
curl https://<your-azure-dns-label>/auth/health
curl https://<your-azure-dns-label>/chat/health
```

Then point your Vercel frontend's API base URL at `https://<your-azure-dns-label>` and confirm
a browser request succeeds (no mixed-content or CORS errors — `ALLOWED_ORIGINS` in `.env` must
include the exact Vercel URL).

## Redeploying after a code change

```bash
ssh azureuser@"$VM_IP"
cd microservices-task && git pull
cd auth-service && git pull && cd ..     # if auth-service changed
cd chat-service && git pull && cd ..     # if chat-service changed
docker compose -f docker-compose.prod.yml up -d --build
```

## Known limits of this setup

- **1GB RAM is genuinely tight.** `docker compose -f docker-compose.prod.yml ps` and `free -h`
  are your first stop if something's flaky; `dmesg | grep -i oom` shows OOM kills. The swap
  file cushions bursts but swapping is slow — under real concurrent load, expect to outgrow
  this VM size. Kong specifically needs `KONG_NGINX_WORKER_PROCESSES: "1"` (already set) — on
  a multi-core box it defaults to one worker per CPU, and enough workers to exceed its
  mem_limit get OOM-killed in a crash loop (worker process exited on signal 9 in `docker
  compose logs kong`) even when the host itself has RAM to spare.
- **First boot only: chat-service's Kafka consumer can crash once or twice** while Kafka's
  internal coordinator is still electing a leader (`There is no leader for this
  topic-partition` / `group coordinator is not available` in `docker compose logs
  chat-service`). It recovers on its own within under a minute in testing and doesn't
  reappear afterward. If a registration made during that exact window doesn't show up via
  `/api/users/me` on chat-service, wait for the stack to settle and register again, or
  `docker compose -f docker-compose.prod.yml restart chat-service`.
- **`/auth/docs` and `/chat/docs` redirect to a 404 through Kong.** swagger-ui-express issues
  a root-relative redirect (`/docs` → `/docs/`) that doesn't know it's behind Kong's `/auth`
  prefix, so the followed redirect 404s at the gateway. The underlying REST/WebSocket routes
  are unaffected — this only breaks browsing the interactive Swagger UI through the public
  URL. Hitting docs on the container directly (`docker compose exec auth-service` and curl
  localhost:3001/docs) still works.
- **The B1S free tier lasts 12 months from account creation**, then this VM starts costing
  money unless you resize down or shut it off.
- **Kong's Admin API isn't published to the host** (by design — it shouldn't be
  internet-facing). To inspect it, `docker compose -f docker-compose.prod.yml exec kong curl
  localhost:8001/status` from inside the VM, or temporarily `docker compose -f
  docker-compose.prod.yml exec kong sh`.
- **Maintenance mode and other plugin toggles are no longer runtime Admin-API calls** — Kong
  runs DB-less here, so config changes mean editing `deploy/kong/kong.yml` and redeploying
  (`docker compose -f docker-compose.prod.yml up -d`, which reloads the mounted file). The
  root Makefile's `maintenance-on`/`maintenance-off` targets only work against the local dev
  stack (Postgres-backed Kong).
- **No automated CI/CD here** — this is a manual SSH-and-pull deploy, matching a single-VM
  personal/demo deployment. If this becomes a real service, revisit with a proper CD pipeline
  and a VM size that isn't fighting for RAM.
