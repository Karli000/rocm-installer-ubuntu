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

```
nano install.sh
```
```
chmod +x install.sh
./install.sh
```

```
nano HSA-Override-test.sh
```
```
chmod +x HSA-Override-test.sh
./HSA-Override-test.sh
```
```
sudo nano amd-gpu-passthrough.sh
```
```
sudo chmod +x amd-gpu-passthrough.sh
sudo ./amd-gpu-passthrough.sh
```
