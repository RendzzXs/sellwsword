#!/bin/bash
# ============================================
#   🔧 FIX DB AUTO-DETECT (v2)
#   Cari config.php di semua path umum
# ============================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

[[ $EUID -ne 0 ]] && { echo -e "${RED}❌ Harus root!${NC}"; exit 1; }

clear
echo -e "${CYAN}╔════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🔧 FIX DB AUTO-DETECT v2          ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════╝${NC}"
echo ""

# ============ CARI CONFIG DI SEMUA PATH ============
echo -e "${CYAN}[1/5] Mencari config.php...${NC}"

SEARCH_PATHS=(
    "/var/www"
    "/home"
    "/www/wwwroot"
    "/usr/share/nginx"
    "/opt"
    "/root"
    "/home/container"
    "/srv"
)

FOUND_FILES=()
for p in "${SEARCH_PATHS[@]}"; do
    if [[ -d "$p" ]]; then
        while IFS= read -r f; do
            FOUND_FILES+=("$f")
        done < <(find "$p" -maxdepth 4 -name "config.php" -path "*includes*" 2>/dev/null)
    fi
done

if [[ ${#FOUND_FILES[@]} -eq 0 ]]; then
    echo -e "${RED}❌ Tidak ada config.php ditemukan.${NC}"
    echo ""
    echo -e "${YELLOW}💡 Cari manual dengan:${NC}"
    echo "   find / -name 'config.php' -path '*includes*' 2>/dev/null"
    echo ""
    read -p "👉 Atau input path manual: " CONFIG
    [[ ! -f "$CONFIG" ]] && { echo -e "${RED}❌ File tidak ada!${NC}"; exit 1; }
elif [[ ${#FOUND_FILES[@]} -eq 1 ]]; then
    CONFIG="${FOUND_FILES[0]}"
    echo -e "${GREEN}  ✓ Ditemukan: $CONFIG${NC}"
else
    echo -e "${YELLOW}  Ditemukan ${#FOUND_FILES[@]} config.php:${NC}"
    for i in "${!FOUND_FILES[@]}"; do
        echo "    [$i] ${FOUND_FILES[$i]}"
    done
    read -p "👉 Pilih nomor [0-$(( ${#FOUND_FILES[@]} - 1 ))]: " IDX
    CONFIG="${FOUND_FILES[$IDX]}"
    echo -e "${GREEN}  ✓ Pilih: $CONFIG${NC}"
fi

# ============ PARSE ============
echo ""
echo -e "${CYAN}[2/5] Parse config...${NC}"

DB_NAME=$(grep -oP "DB_NAME'\s*,\s*'\K[^']+" "$CONFIG" | head -1)
DB_USER=$(grep -oP "DB_USER'\s*,\s*'\K[^']+" "$CONFIG" | head -1)
DB_PASS=$(grep -oP "DB_PASS'\s*,\s*'\K[^']+" "$CONFIG" | head -1)

[[ -z "$DB_NAME" || -z "$DB_USER" || -z "$DB_PASS" ]] && { echo -e "${RED}❌ Gagal parse config!${NC}"; exit 1; }

echo -e "${GREEN}  ✓ Config OK${NC}"
echo "    📦 DB_NAME : $DB_NAME"
echo "    👤 DB_USER : $DB_USER"
echo "    🔑 DB_PASS : ${DB_PASS:0:4}****"

# ============ CEK MYSQL ============
echo ""
echo -e "${CYAN}[3/5] Cek MySQL...${NC}"
if ! systemctl is-active --quiet mysql; then
    systemctl start mysql 2>/dev/null
    sleep 3
fi
systemctl is-active --quiet mysql && echo -e "${GREEN}  ✓ MySQL aktif${NC}" || { echo -e "${RED}  ❌ MySQL mati!${NC}"; exit 1; }

# ============ FIX USER ============
echo ""
echo -e "${CYAN}[4/5] Fix user MySQL...${NC}"

mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null
mysql -u root -e "DROP USER IF EXISTS '$DB_USER'@'localhost';" 2>/dev/null
mysql -u root -e "DROP USER IF EXISTS '$DB_USER'@'127.0.0.1';" 2>/dev/null
mysql -u root -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';" 2>/dev/null
mysql -u root -e "CREATE USER '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASS';" 2>/dev/null
mysql -u root -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';" 2>/dev/null
mysql -u root -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'127.0.0.1';" 2>/dev/null
mysql -u root -e "FLUSH PRIVILEGES;" 2>/dev/null

echo -e "${GREEN}  ✓ User di-reset${NC}"

# ============ TEST ============
echo ""
echo -e "${CYAN}[5/5] Test koneksi...${NC}"

RESULT=$(mysql -u "$DB_USER" -p"$DB_PASS" -h 127.0.0.1 -e "USE \`$DB_NAME\`; SELECT 'OK';" 2>&1)

if echo "$RESULT" | grep -q "OK"; then
    echo -e "${GREEN}  ✓ BERHASIL!${NC}"
    echo ""
    echo -e "${CYAN}📊 Cek tabel:${NC}"
    TABLES=$(mysql -u "$DB_USER" -p"$DB_PASS" -h 127.0.0.1 -N -B -e "SHOW TABLES FROM \`$DB_NAME\`;" 2>/dev/null)
    if [[ -z "$TABLES" ]]; then
        echo -e "${YELLOW}  ⚠️  Database KOSONG — perlu re-run installer!${NC}"
    else
        echo "$TABLES" | while read t; do echo "    • $t"; done
    fi
else
    echo -e "${RED}  ❌ GAGAL:${NC}"
    echo "$RESULT" | head -3
fi

# ============ RESTART SERVICES ============
systemctl restart php8.3-fpm 2>/dev/null
systemctl reload nginx 2>/dev/null

echo ""
echo -e "${GREEN}✅ Selesai! Restart services...${NC}"
