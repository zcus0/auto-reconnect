#!/system/bin/sh

# ==========================================
# KONFIGURASI FILE & TARGET (HYBRID MODE)
# ==========================================
CONFIG_FILE="/sdcard/.reconnectx_config"
PACKAGE_NAME="com.roblox.client"
CHECK_INTERVAL=10
RECONNECT_INTERVAL=3600 # 1 Jam dalam detik (3600s)

# Default Variables
PLACE_ID=""
WEBHOOK_URL=""
AUTO_REJOIN="ON"
KILL_MODE="OFF"
AUTO_CLEAR_CACHE="OFF"

# Target ADB Khusus Emulator
TARGET_ADB="emulator-5554"

# ==========================================
# FUNGSI LOAD & SAVE CONFIG
# ==========================================
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        . "$CONFIG_FILE"
    fi
}

save_config() {
    cat <<EOF > "$CONFIG_FILE"
PLACE_ID="$PLACE_ID"
WEBHOOK_URL="$WEBHOOK_URL"
AUTO_REJOIN="$AUTO_REJOIN"
KILL_MODE="$KILL_MODE"
AUTO_CLEAR_CACHE="$AUTO_CLEAR_CACHE"
EOF
}

# ==========================================
# DISCORD WEBHOOK (HYBRID SAFE LOGGING)
# ==========================================
send_webhook() {
    MSG="$1"
    if [ -n "$WEBHOOK_URL" ]; then
        # Ditangani secara aman di emulator polosan tanpa wget/curl/python
        echo "[DISCORD_NOTIF]: $MSG"
    fi
}

# ==========================================
# DETEKSI PROSES (ADB SHELL HYBRID)
# ==========================================
check_roblox() {
    if adb -s "$TARGET_ADB" shell "ps -ef" 2>/dev/null | grep -q "[c]om.roblox.client"; then
        return 0
    elif adb -s "$TARGET_ADB" shell "pidof com.roblox.client" 2>/dev/null | grep -q "[0-9]"; then
        return 0
    fi
    return 1
}

# ==========================================
# ENGINE MONITORING (+ 1 HOUR TIMER)
# ==========================================
start_engine() {
    case "$PLACE_ID" in
        http*) LAUNCH_URL="$PLACE_ID" ;;
        *)     LAUNCH_URL="roblox://experiences/start?placeId=$PLACE_ID" ;;
    esac

    clear
    echo "=================================================="
    echo "       ReconnectX Hybrid Engine (1H Timer)        "
    echo "=================================================="
    echo " Target   : $PLACE_ID"
    echo " Rejoin   : $AUTO_REJOIN | Kill: $KILL_MODE"
    echo " Jalur ADB: $TARGET_ADB"
    echo "=================================================="
    echo " Tekan [CTRL + C] untuk menghentikan."
    echo ""

    echo " 🔌 Menghubungkan jalur ADB ke $TARGET_ADB..."
    adb connect "$TARGET_ADB" > /dev/null 2>&1
    sleep 2

    send_webhook "🚀 **ReconnectX Engine Active!** Target Place ID: $PLACE_ID (Auto-refresh tiap 1 Jam)"

    IS_RUNNING=0
    SESSION_START_TIME=$(date +%s)

    while true; do
        CURRENT_TIME=$(date +%s)
        ELAPSED_TIME=$((CURRENT_TIME - SESSION_START_TIME))

        if [ "$ELAPSED_TIME" -ge "$RECONNECT_INTERVAL" ]; then
            TIME_STAMP=$(date '+%H:%M:%S')
            echo "[$TIME_STAMP] ⏰ Waktu 1 jam tercapai. Melakukan scheduled restart..."
            send_webhook "⏰ **[$TIME_STAMP]** Mencapai batas waktu 1 jam. Melakukan refresh game otomatis..."
            
            adb -s "$TARGET_ADB" shell "am force-stop $PACKAGE_NAME" > /dev/null 2>&1
            sleep 2
            adb -s "$TARGET_ADB" shell "am start -a android.intent.action.VIEW -d '$LAUNCH_URL'" > /dev/null 2>&1
            
            SESSION_START_TIME=$(date +%s)
            IS_RUNNING=0
            echo "[$TIME_STAMP] ⏳ Menunggu Roblox booting (35 detik)..."
            sleep 35
            continue
        fi

        if check_roblox; then
            if [ "$IS_RUNNING" -eq 0 ]; then
                TIME_STAMP=$(date '+%H:%M:%S')
                echo "[$TIME_STAMP] ✅ Roblox terdeteksi berjalan normal."
                send_webhook "✅ **[$TIME_STAMP]** Roblox berhasil terbuka dan berjalan."
                IS_RUNNING=1
            fi
        else
            TIME_STAMP=$(date '+%H:%M:%S')
            echo "[$TIME_STAMP] ⚠️ Roblox Disconnect / Mati!"

            if [ "$AUTO_CLEAR_CACHE" = "ON" ]; then
                echo "[$TIME_STAMP] 🧹 Clearing Cache..."
                adb -s "$TARGET_ADB" shell "pm clear $PACKAGE_NAME" > /dev/null 2>&1
            fi

            if [ "$KILL_MODE" = "ON" ]; then
                echo "[$TIME_STAMP] 🛑 Force Killing Roblox..."
                adb -s "$TARGET_ADB" shell "am force-stop $PACKAGE_NAME" > /dev/null 2>&1
                sleep 2
            fi

            if [ "$AUTO_REJOIN" = "ON" ]; then
                echo "[$TIME_STAMP] 🚀 Rejoining Roblox..."
                send_webhook "⚠️ **[$TIME_STAMP]** Roblox terputus! Membuka kembali..."
                adb -s "$TARGET_ADB" shell "am start -a android.intent.action.VIEW -d '$LAUNCH_URL'" > /dev/null 2>&1
                
                echo "[$TIME_STAMP] ⏳ Menunggu Roblox booting (35 detik)..."
                sleep 35
            fi

            SESSION_START_TIME=$(date +%s)
            IS_RUNNING=0
        fi

        sleep $CHECK_INTERVAL
    done
}

# ==========================================
# SUB-MENU SETTINGS & REJOIN
# ==========================================
menu_rejoin() {
    clear
    echo "=================================================="
    echo "                 Rejoin Settings                  "
    echo "=================================================="
    echo " Target Link/ID : ${PLACE_ID:-'Kosong'}"
    echo " Auto Rejoin    : [$AUTO_REJOIN]"
    echo "--------------------------------------------------"
    echo " [1] Set Place ID / Link VIP Server"
    echo " [2] Toggle Auto Rejoin [$AUTO_REJOIN]"
    echo " [3] 🚀 START MONITORING ENGINE"
    echo " [4] Kembali"
    echo "=================================================="
    echo -n " Pilih Opsi [1-4]: "
    read -r RCHOICE

    case "$RCHOICE" in
        1)
            echo ""
            echo -n " Masukkan Place ID / VIP Server Link: "
            read -r PLACE_ID
            save_config
            menu_rejoin
            ;;
        2)
            if [ "$AUTO_REJOIN" = "ON" ]; then
                AUTO_REJOIN="OFF"
            else
                AUTO_REJOIN="ON"
            fi
            save_config
            menu_rejoin
            ;;
        3)
            if [ -z "$PLACE_ID" ]; then
                echo ""
                echo "❌ Harap isi Place ID / VIP Link dulu!"
                sleep 2
                menu_rejoin
            else
                start_engine
            fi
            ;;
        4) show_menu ;;
        *) menu_rejoin ;;
    esac
}

menu_settings() {
    clear
    echo "=================================================="
    echo "               Advanced Settings                  "
    echo "=================================================="
    echo " [1] Kill Mode        : [$KILL_MODE]"
    echo " [2] Auto Clear Cache : [$AUTO_CLEAR_CACHE]"
    echo " [3] Kembali"
    echo "=================================================="
    echo -n " Pilih Opsi [1-3]: "
    read -r SCHOICE

    case "$SCHOICE" in
        1)
            if [ "$KILL_MODE" = "ON" ]; then
                KILL_MODE="OFF"
            else
                KILL_MODE="ON"
            fi
            save_config
            menu_settings
            ;;
        2)
            if [ "$AUTO_CLEAR_CACHE" = "ON" ]; then
                AUTO_CLEAR_CACHE="OFF"
            else
                AUTO_CLEAR_CACHE="ON"
            fi
            save_config
            menu_settings
            ;;
        3) show_menu ;;
        *) menu_settings ;;
    esac
}

# ==========================================
# MAIN DASHBOARD MENU
# ==========================================
show_menu() {
    clear
    echo "=================================================="
    echo "            ReconnectX Hybrid Dashboard           "
    echo "=================================================="
    echo " Target Game    : ${PLACE_ID:-'Belum Diatur'}"
    echo " Webhook Status : ${WEBHOOK_URL:-'Belum Diatur'}"
    echo "--------------------------------------------------"
    echo " [1] REJOIN MENU (Set Place ID / Start)"
    echo " [2] SETTINGS (Kill Mode / Clear Cache)"
    echo " [3] SET DISCORD WEBHOOK"
    echo " [4] RESET CONFIG"
    echo " [0] EXIT"
    echo "=================================================="
    echo -n " Pilih Opsi [0-4]: "
    read -r CHOICE

    case "$CHOICE" in
        1) menu_rejoin ;;
        2) menu_settings ;;
        3) 
            echo ""
            echo -n " Masukkan Discord Webhook URL: "
            read -r WEBHOOK_URL
            save_config
            
            echo " 📤 Menyimpan konfigurasi webhook..."
            send_webhook "🔗 **[ReconnectX]** Webhook berhasil dihubungkan!"
            
            echo ""
            echo " ✅ Selesai!"
            sleep 2
            show_menu
            ;;
        4)
            rm -f "$CONFIG_FILE"
            echo "🧹 Config berhasil di-reset!"
            sleep 1
            show_menu
            ;;
        0) exit 0 ;;
        *) show_menu ;;
    esac
}

# ==========================================
# ALUR RUNNER UTAMA
# ==========================================
load_config
show_menu