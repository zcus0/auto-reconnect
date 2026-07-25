#!/bin/bash

# ==========================================
# 0. AUTO CHECK & INSTALL PACKAGES
# ==========================================
check_and_install_packages() {
    MISSING_PKGS=""
    command -v dialog >/dev/null 2>&1 || MISSING_PKGS="$MISSING_PKGS dialog"
    command -v curl >/dev/null 2>&1 || MISSING_PKGS="$MISSING_PKGS curl"

    if [ -n "$MISSING_PKGS" ]; then
        echo "==============================================="
        echo " 📦 Menginstal Paket yang Dibutuhkan... ($MISSING_PKGS)"
        echo "==============================================="
        if command -v pkg >/dev/null 2>&1; then
            pkg update -y && pkg install -y $MISSING_PKGS
        elif command -v apt-get >/dev/null 2>&1; then
            apt-get update -y && apt-get install -y $MISSING_PKGS
        fi
        sleep 1
    fi
}

check_and_install_packages

# ==========================================
# KONFIGURASI PLATOBOOST & FILE CONFIG
# ==========================================
PLATOBOOST_SERVICE="5780"
PLATOBOOST_HOST="https://api.platoboost.com"
CONFIG_FILE="/sdcard/.reconnectx_config"

# Default Variables
SAVED_LICENSE_KEY=""
PLACE_ID=""
WEBHOOK_URL=""
ROBLOX_COOKIE=""
AUTO_REJOIN="ON"
KILL_MODE="OFF"
AUTO_CLEAR_CACHE="OFF"

# ==========================================
# FUNGSI LOAD & SAVE CONFIG
# ==========================================
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}

save_config() {
    cat <<EOF > "$CONFIG_FILE"
SAVED_LICENSE_KEY="$SAVED_LICENSE_KEY"
PLACE_ID="$PLACE_ID"
WEBHOOK_URL="$WEBHOOK_URL"
ROBLOX_COOKIE="$ROBLOX_COOKIE"
AUTO_REJOIN="$AUTO_REJOIN"
KILL_MODE="$KILL_MODE"
AUTO_CLEAR_CACHE="$AUTO_CLEAR_CACHE"
EOF
}

# ==========================================
# FUNGSI VERIFIKASI PLATOBOOST KEY
# ==========================================
get_hwid_digest() {
    RAW_HWID=$(getprop ro.serialno 2>/dev/null)
    [ -z "$RAW_HWID" ] && RAW_HWID=$(settings get secure android_id 2>/dev/null)
    [ -z "$RAW_HWID" ] && RAW_HWID="mumu-emulator-5554"
    
    # Hash HWID ke SHA256
    if command -v sha256sum >/dev/null 2>&1; then
        echo -n "$RAW_HWID" | sha256sum | awk '{print $1}'
    else
        echo -n "$RAW_HWID" | md5sum | awk '{print $1}'
    fi
}

check_license() {
    IDENTIFIER=$(get_hwid_digest)

    # 1. Cek Lisensi Tersimpan
    if [ -n "$SAVED_LICENSE_KEY" ]; then
        echo "🔍 Verifikasi Key Platoboost tersimpan..."
        CHECK_URL="$PLATOBOOST_HOST/public/whitelist/$PLATOBOOST_SERVICE?identifier=$IDENTIFIER&key=$SAVED_LICENSE_KEY"
        RESP=$(curl -s "$CHECK_URL")

        if echo "$RESP" | grep -q '"valid":true'; then
            return 0
        fi
    fi

    # 2. Jika Tidak Valid / Belum Ada, Minta Input Key Baru
    USER_KEY=$(dialog --title " ReconnectX - Platoboost Key " \
        --inputbox "\nMasukkan Key Platoboost Anda:" 10 55 "$SAVED_LICENSE_KEY" \
        3>&1 1>&2 2>&3)

    if [ $? -ne 0 ] || [ -z "$USER_KEY" ]; then
        clear
        echo "❌ Verifikasi dibatalkan. Keluar dari script."
        exit 1
    fi

    echo "🔍 Memeriksa Key ke Platoboost Server..."
    CHECK_URL="$PLATOBOOST_HOST/public/whitelist/$PLATOBOOST_SERVICE?identifier=$IDENTIFIER&key=$USER_KEY"
    RESP=$(curl -s "$CHECK_URL")

    # Verifikasi Hasil dari Platoboost
    if echo "$RESP" | grep -q '"valid":true'; then
        SAVED_LICENSE_KEY="$USER_KEY"
        save_config
        dialog --title " Success " --msgbox "\n✅ Key Platoboost Valid! Selamat Datang di ReconnectX." 8 50
    else
        # Jika Format Key Redeem Baru (Prefix KEY_)
        if [[ "$USER_KEY" == KEY_* ]]; then
            echo "🔄 Meredeem Key Platoboost..."
            REDEEM_RESP=$(curl -s -X POST "$PLATOBOOST_HOST/public/redeem/$PLATOBOOST_SERVICE" \
                -H "Content-Type: application/json" \
                -d "{\"identifier\":\"$IDENTIFIER\",\"key\":\"$USER_KEY\"}")

            if echo "$REDEEM_RESP" | grep -q '"valid":true'; then
                SAVED_LICENSE_KEY="$USER_KEY"
                save_config
                dialog --title " Success " --msgbox "\n✅ Key Platoboost Berhasil Di-redeem!" 8 50
                return 0
            fi
        fi

        dialog --title " Error " --msgbox "\n❌ Key Platoboost Tidak Valid / Kadaluarsa!" 8 50
        clear
        exit 1
    fi
}

# ==========================================
# SUB-MENU REJOIN
# ==========================================
menu_rejoin() {
    while true; do
        CHOICE=$(dialog --title " ReconnectX - Rejoin Menu " --clear \
            --menu "Pilih Opsi Rejoin:" 15 55 5 \
            "1" "Set Place ID / VIP Link [$PLACE_ID]" \
            "2" "Auto Rejoin Toggle [$AUTO_REJOIN]" \
            "3" "Start Monitoring Engine" \
            "4" "Kembali ke Menu Utama" \
            3>&1 1>&2 2>&3)

        case $CHOICE in
            1)
                PLACE_ID=$(dialog --inputbox "Masukkan Place ID atau Link VIP Server:" 10 60 "$PLACE_ID" 3>&1 1>&2 2>&3)
                save_config
                ;;
            2)
                [ "$AUTO_REJOIN" = "ON" ] && AUTO_REJOIN="OFF" || AUTO_REJOIN="ON"
                save_config
                ;;
            3)
                if [ -z "$PLACE_ID" ]; then
                    dialog --msgbox "❌ Place ID / Link belum diisi!" 7 40
                else
                    start_engine
                fi
                ;;
            4) break ;;
        esac
    done
}

# ==========================================
# SUB-MENU LAINNYA
# ==========================================
menu_add_script() {
    dialog --title " Add Script " --msgbox "\nMenu untuk menambahkan custom auto-exec script." 8 50
}

menu_webhook() {
    WEBHOOK_URL=$(dialog --title " Discord Webhook " \
        --inputbox "\nMasukkan Link Discord Webhook:" 10 60 "$WEBHOOK_URL" \
        3>&1 1>&2 2>&3)
    save_config
}

menu_cookie() {
    ROBLOX_COOKIE=$(dialog --title " Roblox Cookie " \
        --inputbox "\nMasukkan .ROBLOSECURITY Cookie:" 10 60 "$ROBLOX_COOKIE" \
        3>&1 1>&2 2>&3)
    save_config
}

menu_misc() {
    dialog --title " Miscellaneous " --msgbox "\nFitur Tambahan: Memory Saver & Cleaner." 8 50
}

menu_settings() {
    while true; do
        CHOICE=$(dialog --title " Settings " --clear \
            --menu "Pengaturan Fitur:" 15 55 4 \
            "1" "Kill Mode [$KILL_MODE]" \
            "2" "Auto Clear Cache [$AUTO_CLEAR_CACHE]" \
            "3" "Kembali" \
            3>&1 1>&2 2>&3)

        case $CHOICE in
            1) 
                [ "$KILL_MODE" = "ON" ] && KILL_MODE="OFF" || KILL_MODE="ON"
                save_config
                ;;
            2) 
                [ "$AUTO_CLEAR_CACHE" = "ON" ] && AUTO_CLEAR_CACHE="OFF" || AUTO_CLEAR_CACHE="ON"
                save_config
                ;;
            3) break ;;
        esac
    done
}

# ==========================================
# ENGINE MONITORING
# ==========================================
start_engine() {
    clear
    echo "=================================================="
    echo "         ReconnectX Engine Running...             "
    echo "=================================================="
    echo " Target: $PLACE_ID"
    echo " Tekan [CTRL + C] untuk menghentikan."
    echo ""

    case "$PLACE_ID" in
        http*) LAUNCH_URL="$PLACE_ID" ;;
        *)     LAUNCH_URL="roblox://experiences/start?placeId=$PLACE_ID" ;;
    esac

    while true; do
        RUNNING=$(ps | grep "com.roblox.client")
        if [ -z "$RUNNING" ]; then
            echo "[$(date '+%H:%M:%S')] ⚠️ Roblox Disconnect/Mati! Rejoining..."
            [ "$KILL_MODE" = "ON" ] && am force-stop com.roblox.client > /dev/null 2>&1
            [ "$AUTO_CLEAR_CACHE" = "ON" ] && pm clear-cache com.roblox.client > /dev/null 2>&1
            
            am start -a android.intent.action.VIEW -d "$LAUNCH_URL" > /dev/null 2>&1
            sleep 15
        else
            echo "[$(date '+%H:%M:%S')] ✅ Roblox Normal."
        fi
        sleep 10
    done
}

# ==========================================
# MAIN DASHBOARD MENU
# ==========================================
main_menu() {
    while true; do
        MAIN_CHOICE=$(dialog --title " ReconnectX Main Dashboard " --clear \
            --menu "Silakan pilih menu di bawah ini:" 18 55 7 \
            "1" "REJOIN" \
            "2" "ADD SCRIPT" \
            "3" "DISCORD WEBHOOK" \
            "4" "COOKIE" \
            "5" "MISCELLANEOUS" \
            "6" "SETTINGS" \
            "7" "EXIT" \
            3>&1 1>&2 2>&3)

        case $MAIN_CHOICE in
            1) menu_rejoin ;;
            2) menu_add_script ;;
            3) menu_webhook ;;
            4) menu_cookie ;;
            5) menu_misc ;;
            6) menu_settings ;;
            7) clear; echo "Terima kasih telah menggunakan ReconnectX!"; exit 0 ;;
            *) break ;;
        esac
    done
}

# --- ALUR RUNNER ---
load_config
check_license
main_menu
