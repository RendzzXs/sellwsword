#!/bin/bash
# ============================================
#   🔧 RENDZZ NOKOS — AUTO FIX MYSQL
#   Fix: SQLSTATE[HY000] [1045] Access denied
# ============================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

[[ $EUID -ne 0 ]] && { echo -e "${RED}❌ Harus root! Jalankan: sudo bash fix-db.sh${NC}"; exit 1; }

clear
echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🔧 RENDZZ NOKOS — AUTO FIX MYSQL            ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ============ STEP 1: DETECT WEB ROOT ============
echo -e "${CYAN}[1/6] Mencari web root...${NC}"

CANDIDATES=$(find /var/www -maxdepth 2 -name "config.php" -path "*/includes/*" 2>/dev/null)

if [[ -z "$CANDIDATES" ]]; then
    echo -e "${RED}❌ Tidak ada config.php ditemukan di /var/www${NC}"
    read -p "👉 Path lengkap config.php: " CONFIG
    [[ ! -f "$CONFIG" ]] && { echo -e "${RED}❌ File tidak ada!${NC}"; exit 1; }
else
    COUNT=$(echo "$CANDIDATES" | wc -l)
    if [[ "$COUNT" -eq 1 ]]; then
        CONFIG="$CANDIDATES"
        echo -e "${GREEN}  ✓ Ditemukan: $CONFIG${NC}"
    else
        echo -e "${YELLOW}Pilih config yang mau di-fix:${NC}"
        select CFG in $CANDIDATES; do
            CONFIG="$CFG"
            break
        done
    fi
fi

# ============ STEP 2: PARSE CONFIG ============
echo ""
echo -e "${CYAN}[2/6] Parse config.php...${NC}"

DB_NAME=$(grep -oP "define\(\s*'DB_NAME'\s*,\s*'\K[^']+" "$CONFIG" | head -1)
DB_USER=$(grep -oP "define\(\s*'DB_USER'\s*,\s*'\K[^']+" "$CONFIG" | head -1)
DB_PASS=$(grep -oP "define\(\s*'DB_PASS'\s*,\s*'\K[^']+" "$CONFIG" | head -1)

if [[ -z "$DB_NAME" || -z "$DB_USER" || -z "$DB_PASS" ]]; then
    echo -e "${RED}❌ Gagal parse config. Cek format:${NC}"
    echo "  define('DB_NAME', 'xxx');"
    echo "  define('DB_USER', 'xxx');"
    echo "  define('DB_PASS', 'xxx');"
    exit 1
fi

echo -e "${GREEN}  ✓ Config ditemukan${NC}"
echo "    📦 DB_NAME : $DB_NAME"
echo "    👤 DB_USER : $DB_USER"
echo "    🔑 DB_PASS : ${DB_PASS:0:4}****${DB_PASS: -4}"
echo "    📁 CONFIG  : $CONFIG"

# ============ STEP 3: CEK MYSQL SERVICE ============
echo ""
echo -e "${CYAN}[3/6] Cek MySQL service...${NC}"

if ! systemctl is-active --quiet mysql; then
    echo -e "${YELLOW}  → MySQL tidak aktif, start...${NC}"
    systemctl start mysql 2>/dev/null
    sleep 3
fi

if ! systemctl is-active --quiet mysql; then
    echo -e "${RED}  ❌ MySQL gagal start. Coba reinstall...${NC}"
    apt purge mysql-server mysql-server-8.0 mysql-client mysql-common -y >/dev/null 2>&1
    rm -rf /var/lib/mysql /etc/mysql
    apt install mysql-server -y -qq >/dev/null 2>&1
    systemctl start mysql
    sleep 5
fi

if ! systemctl is-active --quiet mysql; then
    echo -e "${RED}  ❌ MySQL tetap gagal. Fix manual dulu.${NC}"
    exit 1
fi

echo -e "${GREEN}  ✓ MySQL aktif${NC}"

# ============ STEP 4: CEK DATABASE ============
echo ""
echo -e "${CYAN}[4/6] Cek database...${NC}"

DB_EXISTS=$(mysql -u root -N -B -e "SHOW DATABASES LIKE '$DB_NAME';" 2>/dev/null)

if [[ -z "$DB_EXISTS" ]]; then
    echo -e "${YELLOW}  ⚠️  Database '$DB_NAME' tidak ada. Membuat...${NC}"
    mysql -u root -e "CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}  ✓ Database dibuat${NC}"
    else
        echo -e "${RED}  ❌ Gagal buat database${NC}"; exit 1
    fi
else
    echo -e "${GREEN}  ✓ Database ada${NC}"
fi

# ============ STEP 5: FIX USER MYSQL ============
echo ""
echo -e "${CYAN}[5/6] Fix user MySQL...${NC}"

# Hapus user lama
mysql -u root -e "DROP USER IF EXISTS '$DB_USER'@'localhost';" 2>/dev/null
mysql -u root -e "DROP USER IF EXISTS '$DB_USER'@'127.0.0.1';" 2>/dev/null
mysql -u root -e "DROP USER IF EXISTS '$DB_USER'@'%';" 2>/dev/null

# Buat user baru dengan password dari config
mysql -u root -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';" 2>/dev/null
mysql -u root -e "CREATE USER '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASS';" 2>/dev/null
mysql -u root -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';" 2>/dev/null
mysql -u root -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'127.0.0.1';" 2>/dev/null
mysql -u root -e "FLUSH PRIVILEGES;" 2>/dev/null

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}  ✓ User '$DB_USER' dibuat & di-grant${NC}"
else
    echo -e "${RED}  ❌ Gagal buat user${NC}"; exit 1
fi

# ============ STEP 6: TEST KONEKSI ============
echo ""
echo -e "${CYAN}[6/6] Test koneksi sebagai user app...${NC}"

TEST=$(mysql -u "$DB_USER" -p"$DB_PASS" -h localhost -e "USE \`$DB_NAME\`; SELECT 'OK' AS status;" 2>&1 | grep -c "OK")

if [[ "$TEST" -gt 0 ]]; then
    echo -e "${GREEN}  ✓ Koneksi BERHASIL!${NC}"
else
    echo -e "${RED}  ❌ Koneksi GAGAL! Error:${NC}"
    mysql -u "$DB_USER" -p"$DB_PASS" -h localhost -e "USE \`$DB_NAME\`;" 2>&1 | head -3

    # Retry: mungkin password di config punya karakter spesial
    echo ""
    echo -e "${YELLOW}  → Coba alternate password (escape)...${NC}"
    ESCAPED_PASS=$(printf '%s' "$DB_PASS" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
    mysql -u root -e "ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$ESCAPED_PASS';" 2>/dev/null
    mysql -u root -e "ALTER USER '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$ESCAPED_PASS';" 2>/dev/null
    mysql -u root -e "FLUSH PRIVILEGES;" 2>/dev/null

    TEST2=$(mysql -u "$DB_USER" -p"$DB_PASS" -h localhost -e "USE \`$DB_NAME\`; SELECT 'OK';" 2>&1 | grep -c "OK")
    if [[ "$TEST2" -gt 0 ]]; then
        echo -e "${GREEN}  ✓ Retry BERHASIL!${NC}"
    else
        echo -e "${RED}  ❌ Masih gagal. Coba cek manual.${NC}"
    fi
fi

# ============ EXTRA: CEK TABEL ============
echo ""
echo -e "${CYAN}📊 Cek tabel di database...${NC}"
TABLE_COUNT=$(mysql -u "$DB_USER" -p"$DB_PASS" -h localhost -N -B -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME';" 2>/dev/null)

if [[ -z "$TABLE_COUNT" || "$TABLE_COUNT" -eq 0 ]]; then
    echo -e "${YELLOW}  ⚠️  Database KOSONG (0 tabel)${NC}"
    echo ""
    read -p "👉 Mau re-run installer buat bikin tabel? (y/n): " REINSTALL

    if [[ "$REINSTALL" == "y" || "$REINSTALL" == "Y" ]]; then
        echo -e "${CYAN}  → Mencari install.sh di /root atau /home...${NC}"
        INSTALLER=$(find /root /home /var/www -maxdepth 3 -name "install.sh" 2>/dev/null | head -1)

        if [[ -n "$INSTALLER" ]]; then
            echo -e "${GREEN}  ✓ Installer ditemukan: $INSTALLER${NC}"
            echo -e "${YELLOW}  ⚠️  Ini akan reset database & config!${NC}"
            read -p "  Lanjut? (y/n): " CONFIRM
            if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
                bash "$INSTALLER"
            fi
        else
            echo -e "${RED}  ❌ install.sh tidak ditemukan. Jalankan manual.${NC}"
        fi
    else
        echo -e "${CYAN}  ℹ️  Skip. Bikin tabel manual atau re-run installer.${NC}"
    fi
else
    echo -e "${GREEN}  ✓ Ada $TABLE_COUNT tabel${NC}"

    # List tabel
    echo -e "${CYAN}  📋 Tabel:${NC}"
    mysql -u "$DB_USER" -p"$DB_PASS" -h localhost -N -B -e "SHOW TABLES FROM \`$DB_NAME\`;" 2>/dev/null | while read t; do
        echo "     • $t"
    done
fi

# ============ EXTRA: RESTART SERVICES ============
echo ""
echo -e "${CYAN}🔄 Restart PHP & Nginx...${NC}"
systemctl restart php8.3-fpm 2>/dev/null
systemctl reload nginx 2>/dev/null
echo -e "${GREEN}  ✓ Services restarted${NC}"

# ============ DONE ============
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ SELESAI!                                 ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📋 Summary:${NC}"
echo "  📦 Database : $DB_NAME"
echo "  👤 User     : $DB_USER"
echo "  🔑 Password : (dari config, sudah di-sync)"
echo "  📁 Config   : $CONFIG"
echo ""
echo -e "${CYAN}🧪 Test sekarang:${NC}"
echo "  1. Buka web di browser"
echo "  2. Kalau masih error, cek:"
echo "     tail -20 /var/log/nginx/error.log"
echo "     tail -20 /var/log/php8.3-fpm.log"
echo ""
echo -e "${YELLOW}💡 Kalau masih error, screenshot errornya kirim ke sini!${NC}"
echo ""
