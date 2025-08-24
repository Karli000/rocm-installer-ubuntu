#!/bin/bash
set -e

echo "🔧 Starte vollständiges Setup für GPU-Docker-Integration..."

# --- Root-Prüfung ---
if [[ "$EUID" -ne 0 ]]; then
  echo "❌ Bitte mit sudo ausführen!"
  exit 1
fi

CURRENT_USER="${SUDO_USER:-$USER}"
echo "👤 Aktueller Benutzer: $CURRENT_USER"

# --- Gruppen erstellen ---
GROUPS=("video" "render" "docker")
for grp in "${GROUPS[@]}"; do
  getent group "$grp" >/dev/null || groupadd "$grp"
  usermod -aG "$grp" "$CURRENT_USER"
done

# --- Systemweite Gruppen-Zuweisung ---
tee /usr/local/bin/auto-add-groups > /dev/null <<'EOF'
#!/bin/bash
REQUIRED_GROUPS=("video" "render" "docker")
for username in $(getent passwd | grep -E "/home/" | cut -d: -f1); do
  [[ "$username" == "root" || "$username" == "nobody" ]] && continue
  for grp in "${REQUIRED_GROUPS[@]}"; do
    getent group "$grp" >/dev/null && ! id -nG "$username" | grep -qw "$grp" && usermod -aG "$grp" "$username"
  done
done
EOF
chmod +x /usr/local/bin/auto-add-groups

tee /etc/systemd/system/auto-user-groups.service > /dev/null <<'EOF'
[Unit]
Description=Auto-add users to GPU/Docker groups
After=user@.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/auto-add-groups
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable auto-user-groups.service
systemctl start auto-user-groups.service

# --- Docker installieren ---
echo "📦 Installiere Docker Engine..."
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg
echo "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

# --- runc installieren ---
if ! command -v runc &>/dev/null; then
  apt-get install -y runc || {
    wget -q https://github.com/opencontainers/runc/releases/download/v1.1.9/runc.amd64 -O /usr/bin/runc
    chmod +x /usr/bin/runc
  }
fi

# --- Docker-Wrapper mit automatischer Pfaderkennung ---
WRAPPER="/usr/local/bin/docker"

tee "$WRAPPER" > /dev/null <<'EOF'
#!/bin/bash
CMD="$1"; shift

ORIGINAL=$(command -v docker-original || true)
if [[ -z "$ORIGINAL" || "$(readlink -f "$ORIGINAL")" == "$(readlink -f "$0")" ]]; then
  ORIGINAL=$(command -v docker)
  if [[ -z "$ORIGINAL" ]]; then
    echo "❌ Kein Docker-Binary gefunden!"
    exit 1
  fi
fi

VIDEO_GID=$(getent group video | cut -d: -f3)
RENDER_GID=$(getent group render | cut -d: -f3)

ADD_KFD=1; ADD_DRI=1; ADD_VIDEO=1; ADD_RENDER=1
args=("$@")

for ((i=0; i<${#args[@]}; i++)); do
  case "${args[i]}" in
    --device=/dev/kfd*) ADD_KFD=0 ;;
    --device=/dev/dri*) ADD_DRI=0 ;;
    --group-add)
      next=$((i+1)); group="${args[next]}"
      [[ "$group" == "video" || "$group" == "$VIDEO_GID" ]] && ADD_VIDEO=0
      [[ "$group" == "render" || "$group" == "$RENDER_GID" ]] && ADD_RENDER=0
      ((i++))
      ;;
  esac
done

if [[ "$CMD" == "run" || "$CMD" == "create" ]]; then
  EXTRA_ARGS=()
  [[ $ADD_KFD -eq 1 ]] && EXTRA_ARGS+=(--device=/dev/kfd)
  [[ $ADD_DRI -eq 1 ]] && EXTRA_ARGS+=(--device=/dev/dri)
  [[ $ADD_VIDEO -eq 1 ]] && EXTRA_ARGS+=(--group-add "$VIDEO_GID")
  [[ $ADD_RENDER -eq 1 ]] && EXTRA_ARGS+=(--group-add "$RENDER_GID")
  exec "$ORIGINAL" "$CMD" "${EXTRA_ARGS[@]}" "${args[@]}"
else
  exec "$ORIGINAL" "$CMD" "${args[@]}"
fi
EOF

chmod +x "$WRAPPER"

DOCKER_BIN=$(command -v docker)
if [[ -f "$DOCKER_BIN" ]]; then
  mv "$DOCKER_BIN" "$(dirname "$DOCKER_BIN")/docker-original"
  ln -sf "$WRAPPER" "$DOCKER_BIN"
  echo "✅ Docker-Wrapper aktiviert!"
else
  echo "⚠️ Docker-Binary nicht gefunden – Wrapper nicht aktiviert."
fi

# --- Abschluss mit intelligentem Neustart ---
echo ""
echo "✅ Setup erfolgreich abgeschlossen!"
echo "📋 Benutzer '$CURRENT_USER' wurde zu den Gruppen video, render, docker hinzugefügt."
echo "🔄 Starte automatischen Neustart in 10 Sekunden..."
sleep 10
reboot
