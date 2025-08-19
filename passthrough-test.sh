#!/bin/bash
set -e

echo "🧪 Baue GPU-Check-Container..."

TEST_IMAGE="gpu-check:latest"

# leeren Build-Kontext erstellen
mkdir -p /tmp/docker-context

cat > /tmp/docker-context/Dockerfile <<'EOF'
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    pciutils usbutils \
    && rm -rf /var/lib/apt/lists/*

CMD echo "--- Geräte im Container ---" && ls -l /dev/dri /dev/kfd || true
EOF

docker build -t $TEST_IMAGE -f /tmp/docker-context/Dockerfile /tmp/docker-context

# Cleanup
rm -rf /tmp/docker-context

echo "▶ Starte GPU-Check-Container ohne zusätzliche Flags..."
docker run --rm $TEST_IMAGE

echo "✅ GPU-Check abgeschlossen."
