#!/bin/bash
set -e

echo "🔧 Setup für Docker-Wrapper mit Startprüfung beginnt..."

# --- Umgebung erkennen ---
if [[ "$EUID" -ne 0 ]]; then
  echo "🧑‍💻 Modus: Lokaler Benutzer"
else
  if [[ "$SUDO_USER" ]]; then
    echo "🧑‍💼 Modus: sudo -i oder sudo su"
  else
    echo "🧑‍🔧 Modus: direkter Root"
  fi
fi

# --- Gruppen vorbereiten ---
GROUPS=("video" "render")
CURRENT_USER="${SUDO_USER:-$USER}"

for grp in "${GROUPS[@]}"; do
  if ! getent group "$grp" > /dev/null; then
    echo "👥 Erstelle Gruppe '$grp'..."
    sudo groupadd "$grp"
  else
    echo "✅ Gruppe '$grp' existiert bereits."
  fi
done

for grp in "${GROUPS[@]}"; do
  if ! id -nG "$CURRENT_USER" | grep -qw "$grp"; then
    echo "➕ Füge Benutzer '$CURRENT_USER' zur Gruppe '$grp' hinzu..."
    sudo usermod -aG "$grp" "$CURRENT_USER"
  else
    echo "👤 Benutzer '$CURRENT_USER' ist bereits in Gruppe '$grp'."
  fi
done

# sicherstellen dass auch der Benutzer 'docker' in video+render ist
if id docker &>/dev/null; then
  for grp in "${GROUPS[@]}"; do
    if ! id -nG docker | grep -qw "$grp"; then
      echo "➕ Füge Benutzer 'docker' zur Gruppe '$grp' hinzu..."
      sudo usermod -aG "$grp" docker
    else
      echo "👤 Benutzer 'docker' ist bereits in Gruppe '$grp'."
    fi
  done
fi

echo "🔁 Hinweis: Gruppenrechte greifen normalerweise erst nach Re-Login oder Neustart."

# --- runc installieren, falls nicht vorhanden ---
ORIGINAL_RUNC="/usr/bin/runc"
if [[ ! -f "$ORIGINAL_RUNC" ]]; then
  echo "📥 runc nicht gefunden – lade Binary herunter..."
  wget -q https://github.com/opencontainers/runc/releases/download/v1.1.9/runc.amd64 -O /tmp/runc
  sudo mv /tmp/runc "$ORIGINAL_RUNC"
  sudo chmod +x "$ORIGINAL_RUNC"
  echo "✅ runc erfolgreich installiert."
fi

# --- Docker installieren, falls nicht vorhanden ---
if ! command -v docker &>/dev/null; then
  echo "📦 Docker nicht gefunden – installiere docker.io..."
  sudo apt-get update
  sudo apt-get install -y docker.io
  sudo systemctl enable --now docker
  echo "✅ Docker erfolgreich installiert."
fi

# --- Docker Wrapper erstellen ---
WRAPPER="/usr/local/bin/docker"
ORIGINAL_DOCKER="/usr/bin/docker-original"

if [[ -f "/usr/bin/docker" && ! -f "$ORIGINAL_DOCKER" ]]; then
  echo "📦 Sichere Original-Docker-Binary"
  sudo mv /usr/bin/docker "$ORIGINAL_DOCKER"
  sudo chmod +x "$ORIGINAL_DOCKER"
fi

echo "🛠️ Erstelle Docker-Wrapper"
sudo tee "$WRAPPER" > /dev/null <<'EOF'
#!/bin/bash
CMD="$1"
shift

ORIGINAL="/usr/bin/docker-original"

VIDEO_GID=$(getent group video | cut -d: -f3)
RENDER_GID=$(getent group render | cut -d: -f3)

if [[ "$CMD" == "run" || "$CMD" == "create" || "$CMD" == "start" ]]; then
  ADD_KFD=true
  ADD_DRI=true
  ADD_VIDEO=true
  ADD_RENDER=true

  i=0
  while [[ $i -lt $# ]]; do
    arg="${!i}"
    case "$arg" in
      --device=/dev/kfd*) ADD_KFD=false ;;
      --device=/dev/dri*) ADD_DRI=false ;;
      --group-add)
        next=$((i+1))
        if [[ "${!next}" == "video" || "${!next}" == "$VIDEO_GID" ]]; then
          ADD_VIDEO=false
        fi
        if [[ "${!next}" == "render" || "${!next}" == "$RENDER_GID" ]]; then
          ADD_RENDER=false
        fi
        ;;
    esac
    ((i++))
  done

  EXTRA_ARGS=()
  $ADD_KFD   && EXTRA_ARGS+=(--device=/dev/kfd)
  $ADD_DRI   && EXTRA_ARGS+=(--device=/dev/dri)
  $ADD_VIDEO && EXTRA_ARGS+=(--group-add "$VIDEO_GID")
  $ADD_RENDER&& EXTRA_ARGS+=(--group-add "$RENDER_GID")

  exec "$ORIGINAL" "$CMD" "${EXTRA_ARGS[@]}" "$@"
else
  exec "$ORIGINAL" "$CMD" "$@"
fi
EOF

sudo chmod +x "$WRAPPER"
sudo ln -sf "$WRAPPER" /usr/bin/docker

echo "✅ Setup abgeschlossen. Docker-Wrapper und Gruppen sind eingerichtet."

# --- Automatischer Neustart ---
echo "🔄 Starte System jetzt neu, damit Gruppenrechte sofort greifen..."
sudo reboot
