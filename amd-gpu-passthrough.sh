#!/bin/bash
set -e

echo "🔧 Setup für Docker-Wrapper mit Startprüfung beginnt..."

# --- Prüfen ob Skript als root läuft ---
if [[ "$EUID" -ne 0 ]]; then
  echo "❌ Bitte Skript mit sudo ausführen!"
  exit 1
fi

if [[ "$SUDO_USER" ]]; then
  echo "🧑‍💼 Modus: sudo von Benutzer '$SUDO_USER'"
  CURRENT_USER="$SUDO_USER"
else
  echo "🧑‍🔧 Modus: direkter Root"
  CURRENT_USER="$USER"
fi

# --- Gruppen vorbereiten ---
GROUPS=("video" "render")

for grp in "${GROUPS[@]}"; do
  if ! getent group "$grp" > /dev/null; then
    echo "👥 Erstelle Gruppe '$grp'..."
    groupadd "$grp"
  else
    echo "✅ Gruppe '$grp' existiert bereits."
  fi
done

# --- Aktuellen Benutzer zu Gruppen hinzufügen ---
for grp in "${GROUPS[@]}"; do
  if ! id -nG "$CURRENT_USER" | grep -qw "$grp"; then
    echo "➕ Füge Benutzer '$CURRENT_USER' zur Gruppe '$grp' hinzu..."
    usermod -aG "$grp" "$CURRENT_USER"
  else
    echo "👤 Benutzer '$CURRENT_USER' ist bereits in Gruppe '$grp'."
  fi
done

# --- Docker-Gruppe ---
if ! id -nG "$CURRENT_USER" | grep -qw docker; then
  echo "➕ Füge Benutzer '$CURRENT_USER' zur Docker-Gruppe hinzu..."
  usermod -aG docker "$CURRENT_USER"
else
  echo "👤 Benutzer '$CURRENT_USER' ist bereits in Docker-Gruppe."
fi

# --- Systemweite Lösung für zukünftige Benutzer ---
echo "🔧 Richte systemweite Lösung für zukünftige Benutzer ein..."

# 1. Systemd-Service für automatische Gruppen-Zuweisung
echo "📋 Erstelle systemd Service für automatische Gruppen-Zuweisung..."
tee /etc/systemd/system/auto-user-groups.service > /dev/null <<'EOF'
[Unit]
Description=Automatically add users to required groups
After=user@.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/auto-add-groups

[Install]
WantedBy=multi-user.target
EOF

# 2. Skript für automatische Gruppen-Zuweisung
echo "📋 Erstelle Gruppen-Zuweisungs-Skript..."
tee /usr/local/bin/auto-add-groups > /dev/null <<'EOF'
#!/bin/bash

REQUIRED_GROUPS=("video" "render" "docker")

for username in $(getent passwd | grep -E "/home/" | cut -d: -f1); do
  # Überspringe Systembenutzer ohne Home-Verzeichnis
  if [[ "$username" == "root" || "$username" == "nobody" ]]; then
    continue
  fi
  
  for grp in "${REQUIRED_GROUPS[@]}"; do
    if getent group "$grp" > /dev/null && ! id -nG "$username" | grep -qw "$grp"; then
      echo "➕ Füge Benutzer '$username' zur Gruppe '$grp' hinzu"
      usermod -aG "$grp" "$username"
    fi
  done
done
EOF

chmod +x /usr/local/bin/auto-add-groups

# 3. PAM optional → nicht automatisch gesetzt

# 4. Skript für neue Benutzer (useradd → /etc/skel)
echo "📋 Ergänze .bashrc von neuen Benutzern..."
if ! grep -q "auto-add-groups" /etc/skel/.bashrc 2>/dev/null; then
  echo 'if [ -x /usr/local/bin/auto-add-groups ]; then /usr/local/bin/auto-add-groups; fi' >> /etc/skel/.bashrc
fi

# --- runc installieren, falls nicht vorhanden ---
ORIGINAL_RUNC="/usr/bin/runc"
if ! command -v runc &>/dev/null; then
  echo "📥 runc nicht gefunden – installiere..."
  if apt-get install -y runc; then
    echo "✅ runc über apt installiert."
  else
    echo "⚠️  apt fehlgeschlagen, lade Binary von GitHub..."
    wget -q https://github.com/opencontainers/runc/releases/download/v1.1.9/runc.amd64 -O /tmp/runc
    mv /tmp/runc "$ORIGINAL_RUNC"
    chmod +x "$ORIGINAL_RUNC"
    echo "✅ runc erfolgreich installiert (GitHub Binary)."
  fi
fi

# --- Docker installieren, falls nicht vorhanden ---
if ! command -v docker &>/dev/null; then
  echo "📦 Docker nicht gefunden – installiere docker.io..."
  apt-get update
  apt-get install -y docker.io
  systemctl enable --now docker
  echo "✅ Docker erfolgreich installiert."
fi

# --- Docker Wrapper erstellen ---
WRAPPER="/usr/local/bin/docker"
ORIGINAL_DOCKER="/usr/bin/docker-original"

if [[ -f "/usr/bin/docker" && ! -f "$ORIGINAL_DOCKER" ]]; then
  echo "📦 Sichere Original-Docker-Binary"
  mv /usr/bin/docker "$ORIGINAL_DOCKER"
  chmod +x "$ORIGINAL_DOCKER"
fi

echo "🛠️ Erstelle Docker-Wrapper"
tee "$WRAPPER" > /dev/null <<'EOF'
#!/bin/bash
CMD="$1"
shift

ORIGINAL="/usr/bin/docker-original"

VIDEO_GID=$(getent group video | cut -d: -f3)
RENDER_GID=$(getent group render | cut -d: -f3)

ADD_KFD=1
ADD_DRI=1
ADD_VIDEO=1
ADD_RENDER=1

# Parse arguments
args=("$@")
for ((i=0; i<${#args[@]}; i++)); do
  arg="${args[i]}"
  case "$arg" in
    --device=/dev/kfd*)
      ADD_KFD=0
      ;;
    --device=/dev/dri*)
      ADD_DRI=0
      ;;
    --group-add)
      next=$((i+1))
      group_arg="${args[next]}"
      if [[ "$group_arg" == "video" || "$group_arg" == "$VIDEO_GID" ]]; then
        ADD_VIDEO=0
      fi
      if [[ "$group_arg" == "render" || "$group_arg" == "$RENDER_GID" ]]; then
        ADD_RENDER=0
      fi
      ((i++)) # Skip next argument
      ;;
  esac
done

if [[ "$CMD" == "run" || "$CMD" == "create" ]]; then
  EXTRA_ARGS=()
  [[ $ADD_KFD -eq 1 ]] && EXTRA_ARGS+=(--device=/dev/kfd)
  [[ $ADD_DRI -eq 1 ]] && EXTRA_ARGS+=(--device=/dev/dri)
  [[ $ADD_VIDEO -eq 1 ]] && EXTRA_ARGS+=(--group-add "$VIDEO_GID")
  [[ $ADD_RENDER -eq 1 ]] && EXTRA_ARGS+=(--group-add "$RENDER_GID")

  exec "$ORIGINAL" "$CMD" "${EXTRA_ARGS[@]}" "$@"
else
  exec "$ORIGINAL" "$CMD" "$@"
fi
EOF

chmod +x "$WRAPPER"
ln -sf "$WRAPPER" /usr/bin/docker

# --- Services aktivieren ---
systemctl daemon-reload
systemctl enable auto-user-groups.service
systemctl start auto-user-groups.service

echo "✅ Setup abgeschlossen!"

echo ""
echo "📋 Zukünftige Benutzer werden automatisch zu folgenden Gruppen hinzugefügt:"
echo "   - video"
echo "   - render" 
echo "   - docker"
echo ""
echo "⚠️  Aktuelle Gruppenänderungen werden erst nach Neustart wirksam!"
echo ""

# Nur interaktiv fragen
if [[ -t 1 ]]; then
  read -p "🔁 Möchten Sie jetzt neu starten? (j/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Jj]$ ]]; then
    echo "🔄 Starte System neu..."
    reboot
  else
    echo "ℹ️  Bitte starten Sie später neu oder melden Sie sich ab/an."
  fi
fi
