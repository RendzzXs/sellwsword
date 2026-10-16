#!/bin/bash
# ============================================
#   🔧 FIX CSS — Sell Ws Word
# ============================================

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'

[[ $EUID -ne 0 ]] && { echo -e "${RED}Harus root!${NC}"; exit 1; }

# Auto-detect web root
read -p "👉 Subdomain: " SUBDOMAIN
WEB_ROOT="/var/www/$SUBDOMAIN"

if [[ ! -d "$WEB_ROOT" ]]; then
    echo -e "${RED}❌ Folder tidak ada: $WEB_ROOT${NC}"
    echo "Cek: ls /var/www/"
    exit 1
fi

echo -e "${CYAN}📁 Web root: $WEB_ROOT${NC}"
echo ""

# ============ 1. BUAT FOLDER ============
mkdir -p "$WEB_ROOT/assets/css" "$WEB_ROOT/assets/js"
echo -e "${GREEN}✅ Folder assets OK${NC}"

# ============ 2. CEK FILE CSS ============
if [[ ! -f "$WEB_ROOT/assets/css/style.css" ]] || [[ ! -s "$WEB_ROOT/assets/css/style.css" ]]; then
    echo -e "${RED}⚠️  File CSS kosong / tidak ada!${NC}"
    echo -e "${CYAN}   → Tidak bisa regenerate otomatis. Copy manual dari chat.${NC}"
else
    SIZE=$(wc -c < "$WEB_ROOT/assets/css/style.css")
    echo -e "${GREEN}✅ File CSS ada ($SIZE bytes)${NC}"
fi

# ============ 3. CEK FILE JS ============
for js in main.js animate.js otp-popup.js; do
    if [[ -f "$WEB_ROOT/assets/js/$js" ]]; then
        SIZE=$(wc -c < "$WEB_ROOT/assets/js/$js")
        echo -e "${GREEN}✅ $js ($SIZE bytes)${NC}"
    else
        echo -e "${RED}⚠️  $js tidak ada${NC}"
    fi
done

# ============ 4. CEK PERMISSION ============
chown -R www-data:www-data "$WEB_ROOT/assets"
chmod -R 755 "$WEB_ROOT/assets"
echo -e "${GREEN}✅ Permission assets OK${NC}"

# ============ 5. CEK NGINX MIME TYPE ============
echo ""
echo -e "${CYAN}🔍 Cek Nginx MIME types...${NC}"
if grep -q "text/css" /etc/nginx/mime.types 2>/dev/null; then
    echo -e "${GREEN}✅ MIME types OK${NC}"
else
    echo -e "${RED}⚠️  MIME types bermasalah${NC}"
fi

# ============ 6. RESTART ============
systemctl reload nginx
systemctl restart php8.3-fpm
echo -e "${GREEN}✅ Services restarted${NC}"

# ============ 7. TEST URL ============
echo ""
echo -e "${CYAN}🌐 Test akses CSS:${NC}"
CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$SUBDOMAIN/assets/css/style.css" 2>/dev/null)
echo "   HTTP Status: $CODE"
if [[ "$CODE" == "200" ]]; then
    echo -e "${GREEN}   ✅ CSS BISA DIAKSES!${NC}"
else
    echo -e "${RED}   ❌ CSS tidak bisa diakses (HTTP $CODE)${NC}"
fi

echo ""
echo -e "${GREEN}✅ Selesai!${NC}"
