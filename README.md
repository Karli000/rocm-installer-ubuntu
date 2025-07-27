# ROCm Installer für Ubuntu 24.04 (v6.4.2)

Dieses Bash-Skript installiert das AMD ROCm Framework mit zusätzlichen SDKs und richtet das System für GPU-beschleunigte Entwicklung ein.

## 🚀 Funktionen

- Systemupdate & Installation notwendiger Pakete
- Zuweisung von Benutzerrechten (video/render)
- Konfiguration der `adduser.conf`
- Download & Installation des ROCm-Installers
- Einrichtung von Umgebungsvariablen
- Prüfung von `rocminfo`

## 🧩 Voraussetzungen

- Ubuntu 24.04 "Noble Numbat"
- AMD GPU mit ROCm-Kompatibilität
- Root-Berechtigungen für Systemänderungen

## 📦 Installation

```bash
wget https://raw.githubusercontent.com/Karli000/rocm-installer-ubuntu/main/install.sh -O install.sh
chmod +x install.sh
./install.sh
```

Am Ende erfolgt ein optionaler Neustart, um Gruppenänderungen zu aktivieren.

🧪 Test
Nach Installation:

```
rocminfo
```
