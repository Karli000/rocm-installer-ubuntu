#!/bin/bash
set -e

echo "🔧 Starte vollständige Einrichtung für GPU-fähige Container..."

# --- Gruppen vorbereiten ---
GROUPS=("video" "render" "docker")
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

echo "🔁 Hinweis: Gruppenrechte greifen erst nach Re-Login oder Neustart."

# --- Programme installieren ---
BINARIES=("docker" "podman" "buildah" "runc")
for BIN in "${BINARIES[@]}"; do
  if ! command -v "$BIN" &> /dev/null; then
    echo "📥 '$BIN' nicht gefunden – versuche Installation..."
    case "$BIN" in
      docker) sudo apt update && sudo apt install -y docker.io ;;
      podman) sudo apt install -y podman ;;
      buildah) sudo apt install -y buildah ;;
      runc) sudo apt install -y runc ;;
    esac
  else
    echo "✅ '$BIN' ist bereits installiert."
  fi
done

# --- Wrapper erstellen ---
WRAPPER_DIR="/usr/local/bin"
ORIGINAL_DIR="/usr/bin"

for BIN in "${BINARIES[@]}"; do
  ORIGINAL="${ORIGINAL_DIR}/${BIN}-original"
  WRAPPER="${WRAPPER_DIR}/${BIN}"

  # Dummy erzeugen, wenn Original fehlt
  if [[ ! -f "${ORIGINAL_DIR}/${BIN}" && ! -f "$ORIGINAL" ]]; then
    echo "⚠️ '$BIN' fehlt – erstelle Dummy unter '$ORIGINAL'"
    sudo mkdir -p "$(dirname "$ORIGINAL")"
    sudo tee "$ORIGINAL" > /dev/null <<EOF
#!/bin/bash
echo "❌ '$BIN' ist nicht installiert. Bitte installieren, um Container zu starten."
exit 127
EOF
    sudo chmod +x "$ORIGINAL"
  fi

  # Original sichern
  if [[ -f "${ORIGINAL_DIR}/${BIN}" && ! -f "$ORIGINAL" ]]; then
    echo "📦 Sichere Original-Binary: $BIN"
    sudo mv "${ORIGINAL_DIR}/${BIN}" "$ORIGINAL"
    sudo chmod +x "$ORIGINAL"
  fi

  # Wrapper schreiben
  echo "🛠️ Erstelle Wrapper für: $BIN"
  sudo tee "$WRAPPER" > /dev/null <<EOF
#!/bin/bash
CMD="\$1"
shift

ORIGINAL="/usr/bin/${BIN}-original"

if [[ "\$CMD" == "run" || "\$CMD" == "create" || "\$CMD" == "start" ]]; then
  ADD_KFD=true
  ADD_DRI=true
  ADD_VIDEO=true
  ADD_RENDER=true

  for arg in "\$@"; do
    [[ "\$arg" == "--device=/dev/kfd" ]] && ADD_KFD=false
    [[ "\$arg" == "--device=/dev/dri" || "\$arg" == --device=/dev/dri/* ]] && ADD_DRI=false
    [[ "\$arg" == "--group-add" && "\$arg" == *"video"* ]] && ADD_VIDEO=false
    [[ "\$arg" == "--group-add" && "\$arg" == *"render"* ]] && ADD_RENDER=false
  done

  EXTRA_ARGS=()
  \$ADD_KFD && [[ -e /dev/kfd ]] && EXTRA_ARGS+=(--device=/dev/kfd)
  \$ADD_DRI && [[ -e /dev/dri ]] && EXTRA_ARGS+=(--device=/dev/dri)
  \$ADD_VIDEO && EXTRA_ARGS+=(--group-add video)
  \$ADD_RENDER && EXTRA_ARGS+=(--group-add render)

  exec "\$ORIGINAL" "\$CMD" "\${EXTRA_ARGS[@]}" "\$@"
else
  exec "\$ORIGINAL" "\$CMD" "\$@"
fi
EOF

  sudo chmod +x "$WRAPPER"
  echo "🔗 Verlinke Wrapper nach /usr/bin/$BIN"
  sudo ln -sf "$WRAPPER" "${ORIGINAL_DIR}/${BIN}"
done

echo "✅ Einrichtung abgeschlossen. Containerbefehle sind GPU-ready und systemweit aktiv."
