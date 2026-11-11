#!/usr/bin/env bash
# Phase 0 on the BabyCare VPS (Ubuntu 22.04, ARM64): system updates, Docker, swap, and ports 80/443 for Caddy.
# Idempotent: safe to run again. Run as root: sudo bash scripts/bootstrap.sh
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a

apt-get update -y
apt-get upgrade -y
apt-get install -y ca-certificates curl gnupg unattended-upgrades fail2ban

# Docker Engine and the compose plugin from Docker's own repository.
install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
fi
codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $codename stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker ubuntu
systemctl enable --now docker

# The stock nginx only served its welcome page; Caddy takes ports 80 and 443 and handles HTTPS.
systemctl disable --now nginx || true

# 4 GB swap so a memory spike does not kill Postgres.
if ! swapon --show | grep -q /swapfile; then
  fallocate -l 4G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# Security updates install themselves; fail2ban watches sshd with its defaults.
dpkg-reconfigure -f noninteractive unattended-upgrades
systemctl enable --now fail2ban

install -d -o ubuntu -g ubuntu /srv/babycare /srv/babycare/files /srv/babycare/backups
echo "bootstrap done"
