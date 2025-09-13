#!/bin/bash
set -e

echo "🔧 Installiere systemweiten Docker-Pfad-Wrapper für AMD GPUs ..."

# 1️⃣ Benutzer in Gruppen eintragen
for group in video render docker; do
    if ! getent group "$group" > /dev/null; then
        echo "ℹ️ Gruppe $group existiert nicht, erstelle..."
        sudo groupadd "$group"
    fi

    for user in root "$USER"; do
        if ! id -nG "$user" | grep -qw "$group"; then
            sudo usermod -aG "$group" "$user"
            echo "➕ $user zur Gruppe $group hinzugefügt"
        else
            echo "✔️ $user ist bereits in Gruppe $group"
        fi
    done
done    

# 2️⃣ Wrapper erstellen
WRAPPER="/usr/local/bin/docker"

sudo tee "$WRAPPER" > /dev/null <<'EOF'
#!/bin/bash
# Systemweiter Docker-Wrapper für AMD GPUs

REAL_DOCKER="$(type -a docker | awk '/is / {print $3}' | grep -v "$0" | head -n1)"

if [[ -z "$REAL_DOCKER" || "$REAL_DOCKER" == "$0" ]]; then
    echo "❌ Keine echte Docker-Binary gefunden!" >&2
    exit 1
fi

if [ "$1" == "run" ]; then
    shift
    args=("$@")
    extra_flags=()

    [[ " ${args[*]} " != *" --device=/dev/kfd "* ]]   && extra_flags+=(--device=/dev/kfd)
    [[ " ${args[*]} " != *" --device=/dev/dri "* ]]   && extra_flags+=(--device=/dev/dri)
    RENDER_GID=$(getent group render | cut -d: -f3)
    [[ -n "$RENDER_GID" && " ${args[*]} " != *" --group-add $RENDER_GID "* ]] && extra_flags+=(--group-add "$RENDER_GID")
    VIDEO_GID=$(getent group video | cut -d: -f3)
    [[ -n "$VIDEO_GID" && " ${args[*]} " != *" --group-add $VIDEO_GID "* ]] && extra_flags+=(--group-add "$VIDEO_GID")


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

# 3️⃣ Automatischer Neustart
echo "🔁 Starte das System neu, damit Gruppenmitgliedschaften wirksam werden..."
sleep 5
sudo reboot
