#!/bin/bash
set -e

echo "🔧 Starte sauberes GPU-Docker-Setup ..."

# --- Root prüfen ---
if [[ "$EUID" -ne 0 ]]; then
  echo "❌ Bitte als root oder mit sudo ausführen!"
  exit 1
fi

# Aktuellen Benutzer bestimmen
if [[ -n "$SUDO_USER" ]]; then
  CURRENT_USER="$SUDO_USER"
else
  CURRENT_USER=$(logname 2>/dev/null || echo "$USER")
fi
echo "👤 Aktueller Benutzer: $CURRENT_USER"

# --- Gruppen anlegen ---
GROUPS=("video" "render" "docker")
for grp in "${GROUPS[@]}"; do
  if ! getent group "$grp" >/dev/null; then
    echo "➕ Erstelle Gruppe '$grp'..."
    groupadd "$grp"
  else
    echo "✔ Gruppe '$grp' existiert bereits."
  fi
done

# --- Systemweite Gruppen-Zuweisung für neue Benutzer ---
tee /usr/local/bin/auto-add-groups > /dev/null <<'EOF'
#!/bin/bash
REQUIRED_GROUPS=("video" "render" "docker")
for username in $(getent passwd | grep -E "/home/" | cut -d: -f1); do
  [[ "$username" == "root" || "$username" == "nobody" ]] && continue
  for grp in "${REQUIRED_GROUPS[@]}"; do
    if getent group "$grp" > /dev/null && ! id -nG "$username" | grep -qw "$grp"; then
      echo "➕ Füge Benutzer '$username' zur Gruppe '$grp' hinzu"
      usermod -aG "$grp" "$username"
    fi
  done
done
EOF
chmod +x /usr/local/bin/auto-add-groups

# Ergänze /etc/skel/.bashrc
if ! grep -q "auto-add-groups" /etc/skel/.bashrc 2>/dev/null; then
  echo 'if [ -x /usr/local/bin/auto-add-groups ]; then /usr/local/bin/auto-add-groups; fi' >> /etc/skel/.bashrc
fi

# --- Docker installieren ---
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg
echo "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli

# --- runc installieren falls nötig ---
if ! command -v runc >/dev/null 2>&1; then
  apt-get install -y runc || {
    wget -q https://github.com/opencontainers/runc/releases/download/v1.1.9/runc.amd64 -O /usr/bin/runc
    chmod +x /usr/bin/runc
  }
fi

# --- Benutzer zu Gruppen hinzufügen (NACH Docker-Installation!) ---
for grp in "${GROUPS[@]}"; do
  if ! id -nG "$CURRENT_USER" | grep -qw "$grp"; then
    echo "➕ Füge Benutzer '$CURRENT_USER' zur Gruppe '$grp' hinzu..."
    usermod -aG "$grp" "$CURRENT_USER"
  fi
done

# --- Original Docker sichern ---
if [[ ! -f /usr/bin/docker-original ]]; then
  cp "$(command -v docker)" /usr/bin/docker-original
fi

# --- Wrapper erstellen ---
WRAPPER="/usr/local/bin/docker"
rm -f "$WRAPPER"
tee "$WRAPPER" > /dev/null <<'EOF'
#!/bin/bash
REAL_DOCKER="/usr/bin/docker-original"

if [[ ! -x "$REAL_DOCKER" ]]; then
  echo "❌ Original-Docker nicht gefunden!"
  exit 1
fi

VIDEO_GID=$(getent group video | cut -d: -f3)
RENDER_GID=$(getent group render | cut -d: -f3)

CMD="$1"; shift
args=("$@")

ADD_KFD=1; ADD_DRI=1; ADD_VIDEO=1; ADD_RENDER=1

for ((i=0; i<${#args[@]}; i++)); do
  case "${args[i]}" in
    --device=/dev/kfd*) ADD_KFD=0 ;;
    --device=/dev/dri*) ADD_DRI=0 ;;
    --group-add)
      next=$((i+1))
      group="${args[next]}"
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
  exec "$REAL_DOCKER" "$CMD" "${EXTRA_ARGS[@]}" "${args[@]}"
else
  exec "$REAL_DOCKER" "$CMD" "${args[@]}"
fi
EOF
chmod +x "$WRAPPER"

# --- Symlink setzen ---
rm -f /usr/bin/docker
ln -s "$WRAPPER" /usr/bin/docker

echo
echo "✅ Docker-Wrapper installiert und aktiv!"

# --- Automatischer Test der GPU-Devices ---
echo
echo "🔍 Teste automatisch GPU-Devices im Container..."
if docker info >/dev/null 2>&1; then
  docker run --rm alpine sh -c 'echo "📋 /dev/kfd:"; ls -l /dev/kfd; echo; echo "📋 /dev/dri:"; ls -l /dev/dri'
else
  echo "⚠️  Docker-Test übersprungen: bitte neu einloggen oder rebooten, damit Gruppenrechte aktiv sind."
fi

echo
echo "✅ Setup abgeschlossen!"

# --- Automatischer Reboot ---
echo
echo "🔄 Alle Änderungen abgeschlossen. System wird jetzt neu gestartet, damit Gruppenrechte aktiv werden..."
sleep 5
reboot
