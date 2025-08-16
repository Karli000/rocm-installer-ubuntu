# Prüfen, ob HSA_OVERRIDE nötig ist
HSA_NEEDED=false
for gfx in $GFX_CODES; do
    for map in RDNA1_MAP RDNA2_MAP RDNA3_DESKTOP_MAP RDNA3_APU_MAP; do
        eval "val=\${$map[$gfx]}"
        if [[ -n "$val" ]]; then
            # Wenn die GPU erkannt wird und HSA_OVERRIDE angegeben ist
            HSA_NEEDED=true
        fi
    done
done

if $HSA_NEEDED; then
    echo -e "\n⚠️ Für einige GPUs wird HSA_OVERRIDE empfohlen."
    # Anzeige der GPUs und empfohlenen Versionen
    for gfx in $GFX_CODES; do
        HSA_VER=""
        GPU_NAME=""
        for map in RDNA1_MAP RDNA2_MAP RDNA3_DESKTOP_MAP RDNA3_APU_MAP; do
            eval "val=\${$map[$gfx]}"
            if [[ -n "$val" ]]; then
                GPU_NAME=$(echo "$val" | cut -d' ' -f1-3)
                HSA_VER=$(echo "$val" | grep -oP 'HSA_OVERRIDE_GFX_VERSION=\K[0-9.]+')
                break
            fi
        done
        if [[ -n "$HSA_VER" ]]; then
            echo "  GPU: $GPU_NAME ($gfx) -> HSA_OVERRIDE_GFX_VERSION=$HSA_VER"
        fi
    done

    # Abfrage, ob global gesetzt werden soll
    read -p $'\n💡 Soll HSA_OVERRIDE_GFX_VERSION global eingerichtet werden? (y/n) ' set_hsa
    if [[ "$set_hsa" =~ ^[Yy]$ ]]; then
        echo "#!/bin/bash" | sudo tee /etc/profile.d/hsa_override.sh >/dev/null
        for gfx in $GFX_CODES; do
            HSA_VER=""
            for map in RDNA1_MAP RDNA2_MAP RDNA3_DESKTOP_MAP RDNA3_APU_MAP; do
                eval "val=\${$map[$gfx]}"
                if [[ -n "$val" ]]; then
                    HSA_VER=$(echo "$val" | grep -oP 'HSA_OVERRIDE_GFX_VERSION=\K[0-9.]+')
                    break
                fi
            done
            if [[ -n "$HSA_VER" ]]; then
                echo "export HSA_OVERRIDE_GFX_VERSION=$HSA_VER" | sudo tee -a /etc/profile.d/hsa_override.sh >/dev/null
            fi
        done
        sudo chmod +x /etc/profile.d/hsa_override.sh
        echo "✅ HSA_OVERRIDE_GFX_VERSION global eingerichtet. Neue Sessions müssen sich ggf. neu einloggen."
    else
        echo "ℹ️ HSA_OVERRIDE_GFX_VERSION wird nicht gesetzt."
    fi
else
    echo -e "\n✅ Alle GPUs funktionieren ohne HSA_OVERRIDE. Keine Aktion erforderlich."
fi
