#!/bin/bash
set -e

# --- Interaktive Abfrage der ROCm-Version ---
while [ -z "$ROCM_VERSION" ]; do
    read -p "Welche ROCm-Version soll installiert werden? (z.B. 6.4.2): " ROCM_VERSION
    if [ -z "$ROCM_VERSION" ]; then
        echo "❌ Keine Version angegeben. Bitte erneut versuchen."
    fi
done

ROCM_PATH="/opt/rocm-${ROCM_VERSION}"


# Abbruch, wenn keine Version angegeben wurde
if [ -z "$ROCM_VERSION" ]; then
    echo "❌ Keine Version angegeben. Abbruch."
    exit 1
fi

echo "ℹ️ ROCm-Version ${ROCM_VERSION} wird installiert..."

CODENAME=$(source /etc/os-release && echo "$VERSION_CODENAME")
[ -z "$CODENAME" ] && CODENAME=$(lsb_release -sc)

SUCCESS_MSGS=""
ERROR_MSGS=""

function try {
    desc="$1"; shift
    echo "🔧 $desc ..."
    if "$@"; then
        SUCCESS_MSGS+="\e[32m✅ $desc erfolgreich.\e[0m\n"
        echo -e "\e[32m✅ $desc erfolgreich.\e[0m"
    else
        ERROR_MSGS+="\e[31m❌ $desc fehlgeschlagen.\e[0m\n"
        echo -e "\e[31m❌ $desc fehlgeschlagen.\e[0m"
    fi
}

# --- System vorbereiten ---
try "apt update"           sudo apt update
try "Pakete upgrade"       sudo apt upgrade -y
try "Pakete dist-upgrade"  sudo apt dist-upgrade -y
try "Build-Tools"          sudo apt install -y build-essential python3-setuptools python3-wheel wget jq lsb-release gnupg

# --- ROCm Repo & Key ---
try "ROCm Repo & GPG-Key" bash -c "
    sudo mkdir -p --mode=0755 /etc/apt/keyrings
    wget -qO - https://repo.radeon.com/rocm/rocm.gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/rocm.gpg > /dev/null
    echo \"deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/${ROCM_VERSION} ${CODENAME} main\" | sudo tee /etc/apt/sources.list.d/rocm.list
    sudo apt update
"

# --- udev-Regeln: offen für Single-User ---
try "udev-Regeln" bash -c '
sudo tee /etc/udev/rules.d/70-amdgpu.rules >/dev/null <<EOF
KERNEL=="kfd", MODE="0666"
SUBSYSTEM=="drm", KERNEL=="renderD*", MODE="0666"
EOF
'
try "udev reload" sudo udevadm control --reload-rules && sudo udevadm trigger

# --- ROCm Installer automatisch finden & laden ---
try "ROCm Installer holen" bash -c "
LISTING_URL=https://repo.radeon.com/amdgpu-install/${ROCM_VERSION}/ubuntu/${CODENAME}/
PKG_NAME=\$(wget -qO - \"\$LISTING_URL\" | grep -oP 'amdgpu-install_[0-9.]+-[0-9]+_all\\.deb' | head -n1)
if [ -n \"\$PKG_NAME\" ]; then
    wget -q \"\${LISTING_URL}\${PKG_NAME}\" -O /tmp/amdgpu-install.deb
else
    echo 'Kein passendes amdgpu-install-Paket gefunden' >&2
    exit 1
fi
"

# --- Installer Paket ausführen ---
try "Installer Paket" bash -c "
if [ -f /tmp/amdgpu-install.deb ] && [ -s /tmp/amdgpu-install.deb ]; then
    sudo apt install -y --allow-downgrades /tmp/amdgpu-install.deb
else
    echo 'Keine neue Installer-Datei vorhanden – Schritt übersprungen.'
    exit 0
fi
"

# --- ROCm + Grafik installieren (ohne DKMS, minimalistisch) ---
try "ROCm + Grafik" bash -c "yes | sudo amdgpu-install \
  --usecase=dkms,graphics,rocm \
  --accept-eula"

# --- ld.so.conf für ROCm Libraries ---
try "ld.so.conf für ROCm" bash -c '
sudo tee --append /etc/ld.so.conf.d/rocm.conf >/dev/null <<EOF
/opt/rocm/lib
/opt/rocm/lib64
EOF
sudo ldconfig
'

# --- Env-Variablen global setzen ---
try "Env global" bash -c '
# Alte Einträge entfernen
if [ -f /etc/profile.d/rocm.sh ]; then
    sudo sed -i "/ROCM_PATH/d" /etc/profile.d/rocm.sh
    sudo sed -i "/LD_LIBRARY_PATH/d" /etc/profile.d/rocm.sh
    sudo sed -i "/PATH=.*ROCM_PATH/d" /etc/profile.d/rocm.sh
fi

# Neue Einträge
echo "export ROCM_PATH=${ROCM_PATH}"            | sudo tee /etc/profile.d/rocm.sh >/dev/null
echo "export PATH=\$ROCM_PATH/bin:\$PATH"      | sudo tee -a /etc/profile.d/rocm.sh >/dev/null
echo "export LD_LIBRARY_PATH=\$ROCM_PATH/lib:\$LD_LIBRARY_PATH" | sudo tee -a /etc/profile.d/rocm.sh >/dev/null

sudo chmod +x /etc/profile.d/rocm.sh
'

# --- Env neu laden für diese Shell ---
try "Env neu laden" bash -c "source /etc/profile.d/rocm.sh || true"

# --- ROCm-Test ---
if rocminfo 2>/dev/null | grep -q 'gfx'; then
    echo -e "\e[32m✅ ROCm-Gerät erkannt\e[0m"
else
    echo -e "\e[31m⚠️ Kein ROCm-fähiges Gerät gefunden\e[0m"
fi

# --- Neustart nur bei Erfolg ---
if [[ -z "$ERROR_MSGS" ]]; then
    echo "🔄 System wird in 10 Sekunden neu gestartet ..."
    sleep 10
    sudo reboot
else
    echo -e "\n❌ Es gab Fehler – kein automatischer Neustart."
    echo -e "\nErfolgreich:\n$SUCCESS_MSGS"
    echo -e "\nFehler:\n$ERROR_MSGS"
    exit 1
fi
