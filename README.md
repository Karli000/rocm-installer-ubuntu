# ROCm Installer for Ubuntu 24.04 (Single-User, Flexible)

This repository contains three Bash scripts for installing and configuring ROCm on Ubuntu systems with AMD GPUs.
The scripts can be executed individually – it is not necessary to use all of them.

## 🛠️ install.sh – Install ROCm
### 🚀 Features

Prompts for desired ROCm version (e.g., 6.4.2)
System update & package installation (apt update/upgrade)
Sets up ROCm repository + GPG key
Adds udev rules with 0666 for GPU access (single-user)
Installs an amdgpu-installer package (if available)
Sets PATH + LD_LIBRARY_PATH in /etc/profile.d/rocm.sh
Test via rocminfo
Optional: automatic reboot on success

### 🧩 Notes

Can be run without sudo
After execution: source /etc/profile.d/rocm.sh or re-login required
Can be executed standalone, independent of the other scripts

### 📦 Download + Run

```
wget -O install.sh https://raw.githubusercontent.com/Karli000/rocm-installer-ubuntu/refs/heads/main/install.sh && chmod +x install.sh && ./install.sh
```

## 🛠️ amd-gpu-passthrough.sh – Groups & Container Wrapper
### 🚀 Features

Checks root/user context
Creates groups video, render, docker if missing
Adds current user to these groups
Creates wrappers for tools (docker, nerdctl, podman) in /usr/local/bin

### 🧩 Notes

Must be run with root/sudo
Group membership effective after re-login or newgrp
Can be executed standalone, even without running install.sh first

### 📦 Download + Run

```
wget -O amd-gpu-passthrough.sh https://raw.githubusercontent.com/Karli000/rocm-installer-ubuntu/refs/heads/main/amd-gpu-passthrough.sh && sudo chmod +x amd-gpu-passthrough.sh && sudo ./amd-gpu-passthrough.sh
```

## 🛠️ HSA-Override-test.sh – Check/Set HSA_OVERRIDE
### 🚀 Features

Detects GPU codes (RDNA1/2/3)
Displays recommended overrides
Asks whether to set override globally
Notes if no override is needed

### 🧩 Notes

Can be run normally
Optional sudo if write access in /etc/profile.d/ is required
Can be executed standalone, even without install.sh
Works immediately for single-user setups, otherwise re-login required

### 📦 Download + Run

```
wget -O HSA-Override-test.sh https://raw.githubusercontent.com/Karli000/rocm-installer-ubuntu/refs/heads/main/HSA-Override-test.sh && chmod +x HSA-Override-test.sh && ./HSA-Override-test.sh
```
## 🛠️ passthrough-test.sh – Test GPU Passthrough in Container
### 🚀 Features

Builds a temporary Docker image to check GPU access inside containers
Shows whether /dev/kfd and /dev/dri are available in the container
Useful for validating ROCm compatibility in containerized setups

### 🧩 Notes

Can be run without root privileges
Only shows devices that were correctly passed through at container start

### 📦 Download + Run
```
wget -O passthrough-test.sh https://raw.githubusercontent.com/Karli000/rocm-installer-ubuntu/refs/heads/main/passthrough-test.sh && chmod +x passthrough-test.sh && ./passthrough-test.sh
```

### ⚠️ Important Notes

udev rules set to 0666 → full access for all users to GPU devices.
For multi-user systems, use 0660 + video/render groups instead.
Changes in /etc/profile.d/ take effect only after re-login or source of the respective file.
The scripts can be executed individually or in any order.
For full ROCm usage: run install.sh first, then optionally amd-gpu-passthrough.sh and/or HSA-Override-test.sh.


# ROCm-Installer für Ubuntu 24.04 (Single-User, flexibel)

Dieses Repository enthält drei Bash-Skripte zur Installation und Konfiguration von ROCm auf Ubuntu-Systemen mit AMD-GPUs.  
Die Skripte können einzeln ausgeführt werden – es ist nicht notwendig, alle Skripte zu nutzen.

## 🛠️ install.sh – ROCm installieren  
### 🚀 Funktionen

Fragt gewünschte ROCm-Version (z. B. 6.4.2)  
Systemupdate & Paketinstallation (apt update/upgrade)  
ROCm-Repository + GPG-Key einrichten  
udev-Regeln mit 0666 für GPU-Zugriff (Single-User)  
Installation eines amdgpu-Installer-Pakets (falls vorhanden)  
Setzt PATH + LD_LIBRARY_PATH in /etc/profile.d/rocm.sh  
Test via rocminfo  
Optional: automatischer Neustart bei Erfolg

### 🧩 Hinweise

Kann ohne sudo ausgeführt werden  
Nach Ausführung: source /etc/profile.d/rocm.sh oder Re-Login nötig  
Kann allein ausgeführt werden, unabhängig von den anderen Skripten

### 📦 Download + Start  
```
wget -O install.sh https://raw.githubusercontent.com/Karli000/rocm-installer-ubuntu/refs/heads/main/install.sh && chmod +x install.sh && ./install.sh
```

## 🛠️ amd-gpu-passthrough.sh – Gruppen & Container-Wrapper  
### 🚀 Funktionen

Prüft Root/User-Kontext  
Erstellt Gruppen video, render, docker falls nicht vorhanden  
Fügt aktuellen User zu den Gruppen hinzu  
Erstellt Wrapper für Tools (docker, nerdctl, podman) in /usr/local/bin

### 🧩 Hinweise

Muss mit Root/Sudo laufen  
Gruppenzugehörigkeit wirksam nach Re-Login oder newgrp  
Kann allein ausgeführt werden, auch ohne vorheriges install.sh

### 📦 Download + Start  
```
wget -O amd-gpu-passthrough.sh https://raw.githubusercontent.com/Karli000/rocm-installer-ubuntu/refs/heads/main/amd-gpu-passthrough.sh && sudo chmod +x amd-gpu-passthrough.sh && sudo ./amd-gpu-passthrough.sh
```

## 🛠️ HSA-Override-test.sh – HSA_OVERRIDE prüfen/setzen  
### 🚀 Funktionen

Erkennt GPU-Codes (RDNA1/2/3)  
Zeigt empfohlene Overrides an  
Fragt, ob Override global gesetzt werden soll  
Hinweis, falls kein Override nötig

### 🧩 Hinweise

Normal ausführen möglich  
Optional sudo, falls Schreibrechte in /etc/profile.d/ erforderlich  
Kann allein ausgeführt werden, auch ohne install.sh  
Für Single-User-Setup funktioniert das sofort, sonst Re-Login nötig

### 📦 Download + Start  
```
wget -O HSA-Override-test.sh https://raw.githubusercontent.com/Karli000/rocm-installer-ubuntu/refs/heads/main/HSA-Override-test.sh && chmod +x HSA-Override-test.sh && ./HSA-Override-test.sh
```

## 🛠️ passthrough-test.sh – GPU-Passthrough im Container testen
### 🚀 Funktionen

Erstellt temporäres Docker-Image zur Prüfung von GPU-Zugriff im Container
Zeigt, ob /dev/kfd und /dev/dri im Container verfügbar sind
Nützlich zur Validierung von ROCm-Kompatibilität bei Containerisierung

### 🧩 Hinweise

Kann ohne Root-Rechte ausgeführt werden
Zeigt nur Geräte, die beim Containerstart korrekt durchgereicht wurden

### 📦 Download + Start

```
wget -O passthrough-test.sh https://raw.githubusercontent.com/Karli000/rocm-installer-ubuntu/refs/heads/main/passthrough-test.sh && chmod +x passthrough-test.sh && ./passthrough-test.sh
```

### Wichtige Hinweise

udev-Regeln auf 0666 → volle Rechte für alle User auf GPU-Devices.  
In Multi-User-Systemen lieber 0660 + Gruppen video/render verwenden.  
Änderungen in /etc/profile.d/ greifen erst nach Re-Login oder source der jeweiligen Datei.  
Die Skripte können einzeln oder in beliebiger Reihenfolge ausgeführt werden.  
Für vollständige ROCm-Nutzung: zuerst install.sh, dann optional amd-gpu-passthrough.sh und/oder HSA-Override-test.sh.
