#!/bin/bash
set -e

echo "🔧 Setup für Container-Wrapper mit Startprüfung beginnt..."

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

# --- Wrapper erstellen ---
BINARIES=("docker" "nerdctl" "ctr" "podman" "buildah" "runc")
WRAPPER_DIR="/usr/local/bin"
ORIGINAL_DIR="/usr/bin"

for BIN in "${BINARIES[@]}"; do
  ORIGINAL="${ORIGINAL_DIR}/${BIN}-original"
  WRAPPER="${WRAPPER_DIR}/${BIN}"

  if [[ -f "${ORIGINAL_DIR}/${BIN}" && ! -f "$ORIGINAL" ]]; then
    echo "📦 Sichere Original-Binary: $BIN"
    sudo mv "${ORIGINAL_DIR}/${BIN}" "$ORIGINAL"
    sudo chmod +x "$ORIGINAL"
  fi

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
  \$ADD_KFD && EXTRA_ARGS+=(--device=/dev/kfd)
  \$ADD_DRI && EXTRA_ARGS+=(--device=/dev/dri)
  \$ADD_VIDEO && EXTRA_ARGS+=(--group-add 44)
  \$ADD_RENDER && EXTRA_ARGS+=(--group-add 103)

  exec "\$ORIGINAL" "\$CMD" "\${EXTRA_ARGS[@]}" "\$@"
else
  exec "\$ORIGINAL" "\$CMD" "\$@"
fi
EOF

  sudo chmod +x "$WRAPPER"
  echo "🔗 Verlinke Wrapper nach /usr/bin/$BIN"
  sudo ln -sf "$WRAPPER" "${ORIGINAL_DIR}/${BIN}"
done

echo "✅ Setup abgeschlossen. Alle Wrapper sind systemweit aktiv – inklusive GPU-Erweiterung und Gruppenprüfung."
