#!/bin/bash

set -e

echo "🔧 Starte AMD GPU Passthrough Setup..."

# 1. Systemupdate & Docker installieren
echo "📦 Installiere Docker..."
sudo apt update
sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Docker Repo hinzufügen
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# 2. Docker Wrapper erstellen
echo "🧩 Erstelle Docker-Wrapper..."

sudo mv /usr/bin/docker /usr/bin/docker-original || true

sudo tee /usr/local/bin/docker-wrapper > /dev/null << 'EOF'
#!/bin/bash

if [[ "$1" == "run" ]]; then
  shift
  if [[ "$@" == *"--device /dev/kfd"* || "$@" == *"--device /dev/dri/renderD128"* ]]; then
    exec /usr/bin/docker-original run "$@"
  else
    exec /usr/bin/docker-original run \
      --device /dev/kfd \
      --device /dev/dri/renderD128 \
      "$@"
  fi
else
  exec /usr/bin/docker-original "$@"
fi
EOF

sudo chmod +x /usr/local/bin/docker-wrapper
sudo ln -sf /usr/local/bin/docker-wrapper /usr/bin/docker

# 3. Gruppenrechte setzen
echo "👤 Füge Benutzer zur 'video', 'render' und 'docker' Gruppe hinzu..."
sudo usermod -aG video $USER
sudo usermod -aG render $USER
sudo usermod -aG docker $USER

echo "✅ Setup abgeschlossen. Starte jetzt automatisch neu..."
sleep 3
sudo reboot
