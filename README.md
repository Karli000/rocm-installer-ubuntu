🛠️ install.sh – ROCm installieren
🚀 Funktionen

Fragt gewünschte ROCm-Version ab (z. B. 6.4.2)

Systemupdate & Paketinstallation (apt update/upgrade)

ROCm-Repository + GPG-Key einrichten

udev-Regeln mit 0666 für GPU-Zugriff (Single-User)

Installation eines amdgpu-Installer-Pakets (falls vorhanden)

Setzt PATH + LD_LIBRARY_PATH in /etc/profile.d/rocm.sh

Test via rocminfo

Optional: automatischer Neustart bei Erfolg

🧩 Hinweise

Kann ohne sudo ausgeführt werden

Nach Ausführung: source /etc/profile.d/rocm.sh oder Re-Login nötig

Kann allein ausgeführt werden, unabhängig von den anderen Skripten

📦 Download + Start

```
wget -O install.sh https://raw.githubusercontent.com/Karli000/rocm-installer-ubuntu/refs/heads/main/install.sh && chmod +x install.sh && ./install.sh
```
🛠️ amd-gpu-passthrough.sh – Gruppen & Container-Wrapper
🚀 Funktionen

Prüft Root/User-Kontext

Erstellt Gruppen video, render, docker falls nicht vorhanden

Fügt aktuellen User zu den Gruppen hinzu

Erstellt Wrapper für Tools (docker, nerdctl, podman) in /usr/local/bin

🧩 Hinweise

Muss mit Root/Sudo laufen

Gruppenzugehörigkeit wirksam nach Re-Login oder newgrp

Kann allein ausgeführt werden, auch ohne vorheriges install.sh

📦 Download + Start

```
wget -O amd-gpu-passthrough.sh https://raw.githubusercontent.com/Karli000/rocm-installer-ubuntu/refs/heads/main/amd-gpu-passthrough.sh && sudo chmod +x amd-gpu-passthrough.sh && sudo ./amd-gpu-passthrough.sh
```
🛠️ HSA-Override-test.sh – HSA_OVERRIDE prüfen/setzen
🚀 Funktionen

Erkennt GPU-Codes (RDNA1/2/3)

Zeigt empfohlene Overrides an

Fragt, ob Override global gesetzt werden soll

Hinweis, falls kein Override nötig

🧩 Hinweise

Normal ausführen möglich

Optional sudo, falls Schreibrechte in /etc/profile.d/ erforderlich

Kann allein ausgeführt werden, auch ohne install.sh

Für Single-User-Setup funktioniert das sofort, sonst Re-Login nötig

📦 Download + Start

```
wget -O HSA-Override-test.sh https://raw.githubusercontent.com/Karli000/rocm-installer-ubuntu/refs/heads/main/HSA-Override-test.sh && chmod +x HSA-Override-test.sh && ./HSA-Override-test.sh
```
