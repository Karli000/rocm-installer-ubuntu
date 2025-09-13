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

REAL_DOCKER="$(command -v docker)"

# Prüfen, ob der erkannte Pfad auf den Wrapper selbst zeigt
if [[ "$REAL_DOCKER" == "$0" ]]; then
    echo "⚠️ Docker verweist auf den Wrapper selbst – versuche echten Pfad zu finden..."

    for candidate in $(type -a docker | awk '/is / {print $3}'); do
        if [[ "$candidate" != "$0" && -x "$candidate" ]]; then
            REAL_DOCKER="$candidate"
            break
        fi
    done

    if [[ "$REAL_DOCKER" == "$0" ]]; then
        echo "❌ Keine echte Docker-Binary gefunden!" >&2
        exit 1
    fi
fi  

if [ "$1" == "run" ]; then
    shift
    args=("$@")
    extra_flags=()

    # Flags nur hinzufügen, wenn sie noch nicht gesetzt sind
    [[ " ${args[*]} " != *" --device=/dev/kfd "* ]]   && extra_flags+=(--device=/dev/kfd)
    [[ " ${args[*]} " != *" --device=/dev/dri "* ]]   && extra_flags+=(--device=/dev/dri)
    [[ " ${args[*]} " != *" --group-add video "* ]]   && extra_flags+=(--group-add video)
    [[ " ${args[*]} " != *" --group-add render "* ]]  && extra_flags+=(--group-add render)

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
