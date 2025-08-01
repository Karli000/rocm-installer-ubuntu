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

echo "🚀 ROCm Repository und GPG-Key einrichten"

try "ROCm Paketquellen einrichten und Paketlisten aktualisieren" bash -c "
  sudo mkdir -p /etc/apt/keyrings &&
  wget -qO - https://repo.radeon.com/rocm/rocm.gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/rocm.gpg > /dev/null &&
  echo \"deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/6.4.2 noble main\" | sudo tee /etc/apt/sources.list.d/rocm.list &&
  echo -e 'Package: *\nPin: release o=repo.radeon.com\nPin-Priority: 600' | sudo tee /etc/apt/preferences.d/rocm-pin-600 &&
  sudo apt update
"

try "Systempakete aktualisieren" sudo apt upgrade -y && sudo apt dist-upgrade -y && sudo apt install update-manager-core -y


echo "🚀 Starte ROCm Installation"

try "Build-Tools installieren" sudo apt install -y build-essential python3-setuptools python3-wheel wget

CURRENT_USER=$(logname)
try "Benutzer zu video und render Gruppen hinzufügen" sudo usermod -a -G video,render "$CURRENT_USER"
try "adduser.conf anpassen" bash -c "sudo sed -i '/^ADD_EXTRA_GROUPS/d' /etc/adduser.conf"
try "adduser.conf anpassen" bash -c "sudo sed -i '/^EXTRA_GROUPS/d' /etc/adduser.conf"
try "ADD_EXTRA_GROUPS setzen" bash -c "echo 'ADD_EXTRA_GROUPS=1' | sudo tee -a /etc/adduser.conf"
try "EXTRA_GROUPS setzen" bash -c "echo 'EXTRA_GROUPS=video render' | sudo tee -a /etc/adduser.conf"

ROCM_VERSION="6.4.2"
ROCM_PATH="/opt/rocm-${ROCM_VERSION}"
INSTALLER_URL="https://repo.radeon.com/amdgpu-install/${ROCM_VERSION}/ubuntu/noble/amdgpu-install_6.4.60402-1_all.deb"

try "ROCm Installer herunterladen" wget -q "$INSTALLER_URL" -O amdgpu-install.deb
try "ROCm Installer Paket installieren" sudo apt install -y --allow-downgrades ./amdgpu-install.deb

try "ROCm + SDKs installieren" bash -c "yes | sudo amdgpu-install --usecase=graphics,rocm,lrt,hip,opencl,mllib,graphics,rocmdevtools,hiplibsdk,openclsdk,openmpsdk,mlsdk --dkms --accept-eula"

try "ROCm PATH und Umgebungsvariablen systemweit und benutzerspezifisch setzen" bash -c "\
  echo 'export ROCM_PATH=${ROCM_PATH}' | sudo tee /etc/profile.d/rocm.sh >/dev/null && \
  echo 'export PATH=\$ROCM_PATH/bin:\$PATH' | sudo tee -a /etc/profile.d/rocm.sh >/dev/null && \
  echo 'export LD_LIBRARY_PATH=\$ROCM_PATH/lib:\$LD_LIBRARY_PATH' | sudo tee -a /etc/profile.d/rocm.sh >/dev/null && \
  echo 'export HSA_OVERRIDE_GFX_VERSION=10.3.0' | sudo tee -a /etc/profile.d/rocm.sh >/dev/null && \
  echo '' >> ~/.bashrc && \
  echo '# ROCm Umgebung' >> ~/.bashrc && \
  echo 'export ROCM_PATH=${ROCM_PATH}' >> ~/.bashrc && \
  echo 'export PATH=\$ROCM_PATH/bin:\$PATH' >> ~/.bashrc && \
  echo 'export LD_LIBRARY_PATH=\$ROCM_PATH/lib:\$LD_LIBRARY_PATH' >> ~/.bashrc && \
  echo 'export HSA_OVERRIDE_GFX_VERSION=10.3.0' >> ~/.bashrc && \
  source ~/.bashrc"



# Prüfen, ob rocminfo vorhanden und ausführbar ist
if [[ -x "${ROCM_PATH}/bin/rocminfo" ]]; then
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

read -p "🔁 System jetzt neu starten? (j/N): " answer
if [[ "$answer" =~ ^[Jj]$ ]]; then
  sudo reboot
else
  echo "⏹️ Neustart abgebrochen. Bitte manuell neu starten, um Änderungen zu aktivieren."
fi
