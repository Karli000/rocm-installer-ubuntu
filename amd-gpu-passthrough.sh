#!/bin/bash
set -e

echo "🔧 Installiere systemweiten Docker-Pfad-Wrapper für AMD GPUs ..."

# 1️⃣ Benutzer in Gruppen eintragen (video & render)
for group in video render; do
    if ! getent group "$group" > /dev/null; then
        echo "ℹ️ Gruppe $group existiert nicht, erstelle..."
        sudo groupadd "$group"
    fi
done

# Alle Benutzer in Gruppen eintragen
for user in $(cut -f1 -d: /etc/passwd); do
    for group in video render docker; do
        sudo usermod -aG "$group" "$user" 2>/dev/null || true
    done
done

# 2️⃣ Wrapper erstellen
WRAPPER="/usr/local/bin/docker"

sudo tee "$WRAPPER" > /dev/null <<'EOF'
#!/bin/bash
# Systemweiter Docker-Wrapper für AMD GPUs

REAL_DOCKER="/usr/bin/docker"

if [ "$1" == "run" ]; then
    shift
    args=("$@")
    extra_flags=()

    # Flags nur hinzufügen, wenn sie noch nicht gesetzt sind
    [[ " ${args[*]} " != *" --device=/dev/kfd "* ]]   && extra_flags+=(--device=/dev/kfd)
    [[ " ${args[*]} " != *" --device=/dev/dri "* ]]   && extra_flags+=(--device=/dev/dri)
    [[ " ${args[*]} " != *" --group-add video "* ]]   && extra_flags+=(--group-add video)

    for dev in /dev/dri/card* /dev/dri/renderD*; do
        [ -e "$dev" ] && [[ " ${args[*]} " != *" $dev "* ]] && extra_flags+=(--device="$dev")
    done

    exec "$REAL_DOCKER" run "${extra_flags[@]}" "${args[@]}"
else
    exec "$REAL_DOCKER" "$@"
fi
EOF

sudo chmod +x "$WRAPPER"

echo "✅ Docker-Pfad-Wrapper installiert."
echo "ℹ️ Jetzt greifen alle Docker-Run-Aufrufe automatisch die AMD-Flags, auch für root."
