#!/bin/bash
# One-time bootstrap for a fresh Azure Standard_B1s (Ubuntu 22.04) VM. Run as a user with
# sudo. Idempotent — safe to re-run. See deploy/README.md for the full runbook (creating the
# VM itself, DNS label, NSG rules, and copying .env up before running this).
set -euo pipefail

# ---- EDIT THESE before running ----
ROOT_REPO_URL="https://github.com/<you>/microservices-task.git"
AUTH_SERVICE_REPO_URL="https://github.com/<you>/auth-service.git"
CHAT_SERVICE_REPO_URL="https://github.com/<you>/chat-service.git"
APP_DIR="$HOME/microservices-task"
# ------------------------------------

echo "==> Installing Docker + Compose plugin"
if ! command -v docker &>/dev/null; then
	sudo apt-get update
	sudo apt-get install -y ca-certificates curl gnupg
	sudo install -m 0755 -d /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	sudo chmod a+r /etc/apt/keyrings/docker.gpg
	echo \
		"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
		$(. /etc/os-release && echo "$VERSION_CODENAME") stable" |
		sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
	sudo apt-get update
	sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
	sudo usermod -aG docker "$USER"
	echo "Added $USER to the docker group — log out/in (or re-run this script over a fresh SSH session) if 'docker ps' below fails with a permission error."
fi

echo "==> Creating 2GB swapfile (safety net for the 1GB RAM box)"
if [ ! -f /swapfile ]; then
	sudo fallocate -l 2G /swapfile
	sudo chmod 600 /swapfile
	sudo mkswap /swapfile
	sudo swapon /swapfile
	echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
else
	echo "Swapfile already exists, skipping"
fi
# Tame swap aggressiveness a bit — prefer RAM, only swap under real pressure.
sudo sysctl -w vm.swappiness=10 >/dev/null
grep -q '^vm.swappiness' /etc/sysctl.conf 2>/dev/null || echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf >/dev/null

echo "==> Cloning repos into $APP_DIR"
if [ ! -d "$APP_DIR/.git" ]; then
	git clone "$ROOT_REPO_URL" "$APP_DIR"
else
	git -C "$APP_DIR" pull
fi
if [ ! -d "$APP_DIR/auth-service/.git" ]; then
	git clone "$AUTH_SERVICE_REPO_URL" "$APP_DIR/auth-service"
else
	git -C "$APP_DIR/auth-service" pull
fi
if [ ! -d "$APP_DIR/chat-service/.git" ]; then
	git clone "$CHAT_SERVICE_REPO_URL" "$APP_DIR/chat-service"
else
	git -C "$APP_DIR/chat-service" pull
fi

if [ ! -f "$APP_DIR/.env" ]; then
	echo "!! $APP_DIR/.env is missing. Copy .env.production.example up (scp from your machine)"
	echo "   and fill in real values before running 'docker compose -f docker-compose.prod.yml up -d --build'."
	exit 1
fi

echo "==> Building and starting the production stack"
cd "$APP_DIR"
docker compose -f docker-compose.prod.yml up -d --build

echo "==> Done. Check status with: docker compose -f docker-compose.prod.yml ps"
