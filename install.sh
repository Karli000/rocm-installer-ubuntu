#!/bin/bash
set -e

SUCCESS_MSGS=""
ERROR_MSGS=""

function try {
  description="$1"
  shift
  echo "🔧 $description ..."
  if "$@"; then
    SUCCESS_MSGS+="✅ $description erfolgreich.\n"
  else
    ERROR_MSGS+="❌ $description fehlgeschlagen.\n"
    echo -e "\n🔴 Fehler bei: $description\n"
    echo -e "\nErfolgreiche Schritte:\n$SUCCESS_MSGS"
    echo -e "\nFehlerhafte Schritte:\n$ERROR_MSGS"
    exit 1
  fi
}

echo "🚀 Ubuntu-Version ermitteln und passende ROCm-Version auswählen"

ROCM_VERSION="6.4.2"
ROCM_VERSION_SHORT="6.4."

# Ubuntu Version auslesen und DISTRO bestimmen
if [[ -f /etc/os-release ]]; then
  VERSION_CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2 | tr -d '"')
  case "$VERSION_CODENAME" in
    jammy) DISTRO="jammy" ;;
    noble) DISTRO="noble" ;;
    *) echo "❌ Unsupported Ubuntu version: $VERSION_CODENAME"; exit 1 ;;
  esac
else
  echo "❌ /etc/os-release nicht gefunden."; exit 1
fi

echo "Gefundene Ubuntu-Version: $VERSION_CODENAME"
echo "ROCm-Distro für Installer: $DISTRO"

INSTALLER_URL="https://repo.radeon.com/amdgpu-install/${ROCM_VERSION}/ubuntu/${DISTRO}/amdgpu-install_${ROCM_VERSION_SHORT}60402-1_all.deb"
echo "ROCm Installer URL: $INSTALLER_URL"

echo "🚀 ROCm Repository und GPG-Key einrichten"

try "ROCm Paketquellen einrichten und Paketlisten aktualisieren" bash -c "
  sudo mkdir -p /etc/apt/keyrings &&
  wget -qO - https://repo.radeon.com/rocm/rocm.gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/rocm.gpg > /dev/null &&
  echo \"deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/${ROCM_VERSION} ${DISTRO} main\" | sudo tee /etc/apt/sources.list.d/rocm.list &&
  echo -e 'Package: *\nPin: release o=repo.radeon.com\nPin-Priority: 600' | sudo tee /etc/apt/preferences.d/rocm-pin-600 &&
  sudo apt update
"

try "Systempakete aktualisieren" sudo apt upgrade -y && sudo apt dist-upgrade -y && sudo apt install -y update-manager-core

echo "🚀 Starte ROCm Installation"

try "Build-Tools installieren" sudo apt install -y build-essential python3-setuptools python3-wheel wget

CURRENT_USER=$(logname)
try "Benutzer zu video und render Gruppen hinzufügen" sudo usermod -a -G video,render "$CURRENT_USER"
try "adduser.conf anpassen" bash -c "sudo sed -i '/^ADD_EXTRA_GROUPS/d' /etc/adduser.conf"
try "adduser.conf anpassen" bash -c "sudo sed -i '/^EXTRA_GROUPS/d' /etc/adduser.conf"
try "ADD_EXTRA_GROUPS setzen" bash -c "echo 'ADD_EXTRA_GROUPS=1' | sudo tee -a /etc/adduser.conf"
try "EXTRA_GROUPS setzen" bash -c "echo 'EXTRA_GROUPS=video render' | sudo tee -a /etc/adduser.conf"

try "ROCm Installer herunterladen" wget -q "$INSTALLER_URL" -O amdgpu-install.deb
try "ROCm Installer Paket installieren" sudo apt install -y --allow-downgrades ./amdgpu-install.deb

try "ROCm + SDKs installieren" bash -c "yes | sudo amdgpu-install --usecase=dkms,graphics,rocm,lrt,hip,opencl,mllib,rocmdevtools,hiplibsdk,openclsdk,openmpsdk,mlsdk --accept-eula"

echo "🔍 GPU erkennen mit rocminfo (nach ROCm-Installation)..."

if ! command -v rocminfo >/dev/null 2>&1; then
  echo "❌ rocminfo nicht gefunden. Bitte Installation überprüfen."
  exit 1
fi

GFX=$(rocminfo | grep -oP 'gfx[0-9]+' | head -n1)
GPU_NAME=$(rocminfo | grep -A1 "Agent.*GPU" | grep "Marketing Name" | head -n1 | cut -d':' -f2 | xargs)

declare -A HSA_MAP=(
  [gfx700]="9.0.0"       # Polaris 10
  [gfx701]="9.0.0"       # Polaris 11
  [gfx702]="9.0.0"       # Polaris 12
  [gfx703]="9.0.0"       # Vega 10 (FRD)
  [gfx704]="9.0.6"       # Vega 12 (FRD)
  [gfx705]="9.0.6"       # Vega 20 (FRD)
  [gfx806]="10.1.0"      # Navi 10 (RDNA1)
  [gfx900]="9.0.6"       # Vega 10 (SRD)
  [gfx906]="9.0.6"       # Vega 20 (SRD)
  [gfx908]="9.0.6"       # Vega 20 (SRD)
  [gfx1010]="10.1.0"     # Navi 10 (RDNA1)
  [gfx1030]="10.3.0"     # Navi 21 (RDNA2)
  [gfx1100]="11.0.0"     # RDNA3
  [gfx1012]="10.1.0"     # Navi 14 (RDNA1)
  [gfx1014]="10.1.0"     # Navi 12 (RDNA1)
)

HSA_OVERRIDE_GFX_VERSION="${HSA_MAP[$GFX]}"

if [[ -z "$HSA_OVERRIDE_GFX_VERSION" ]]; then
  echo "❌ Keine unterstützte GPU erkannt (GFX: $GFX). Installation wird abgebrochen."
  exit 1
fi

echo "✅ GPU erkannt: $GFX ($GPU_NAME), setze HSA_OVERRIDE_GFX_VERSION=$HSA_OVERRIDE_GFX_VERSION"


try "ROCm PATH und Umgebungsvariablen systemweit und benutzerspezifisch setzen" bash -c "\
  echo 'export ROCM_PATH=/opt/rocm-${ROCM_VERSION}' | sudo tee /etc/profile.d/rocm.sh >/dev/null && \
  echo 'export PATH=\$ROCM_PATH/bin:\$PATH' | sudo tee -a /etc/profile.d/rocm.sh >/dev/null && \
  echo 'export LD_LIBRARY_PATH=\$ROCM_PATH/lib:\$LD_LIBRARY_PATH' | sudo tee -a /etc/profile.d/rocm.sh >/dev/null && \
  echo '' >> ~/.bashrc && \
  echo '# ROCm Umgebung' >> ~/.bashrc && \
  echo 'export ROCM_PATH=/opt/rocm-${ROCM_VERSION}' >> ~/.bashrc && \
  echo 'export PATH=\$ROCM_PATH/bin:\$PATH' >> ~/.bashrc && \
  echo 'export LD_LIBRARY_PATH=\$ROCM_PATH/lib:\$LD_LIBRARY_PATH' >> ~/.bashrc && \
  source ~/.bashrc"


# Prüfen ob rocminfo ausführbar ist
if [[ -x "/opt/rocm-${ROCM_VERSION}/bin/rocminfo" ]]; then
  SUCCESS_MSGS+="✅ rocminfo gefunden und ausführbar.\n"
else
  ERROR_MSGS+="⚠️ rocminfo nicht gefunden oder nicht ausführbar. Bitte prüfen.\n"
fi

echo -e "\n🎉 Installationsergebnis:\n"
echo -e "✅ Erfolgreiche Schritte:\n$SUCCESS_MSGS"
if [[ -n "$ERROR_MSGS" ]]; then
  echo -e "❌ Fehlgeschlagene Schritte:\n$ERROR_MSGS"
else
  echo -e "Keine Fehler aufgetreten.\n"
fi

echo "ℹ️ Bitte nach dem Neustart erneut einloggen, damit Gruppen- und Umgebungsänderungen aktiv werden."

echo "🔁 System wird jetzt automatisch neu gestartet..."
sleep 5
sudo reboot
