#!/bin/bash
# ============================================
#   📱 RENDZZ SMS — TEMP NUMBER RECEIVER
#   Free API • Auto Refresh • Dark UI
# ============================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

[[ $EUID -ne 0 ]] && { echo -e "${RED}❌ Harus root!${NC}"; exit 1; }

clear
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  📱 RENDZZ SMS — TEMP NUMBER               ║${NC}"
echo -e "${CYAN}║  Free API • Real-time SMS                  ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

read -p "👉 Subdomain (contoh: sms.domain.com): " SUBDOMAIN
[[ -z "$SUBDOMAIN" ]] && { echo -e "${RED}❌ Kosong!${NC}"; exit 1; }

read -p "👉 Email SSL: " EMAIL
[[ -z "$EMAIL" ]] && EMAIL="admin@$SUBDOMAIN"

WEB_ROOT="/var/www/$SUBDOMAIN"
NGINX_CONF="/etc/nginx/sites-available/$SUBDOMAIN"

read -p "Lanjut? (y/n): " C
[[ "$C" != "y" && "$C" != "Y" ]] && exit 0

# ============ 1. PACKAGES ============
echo -e "\n${CYAN}[1/5] Install packages...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt update -qq 2>/dev/null
apt install nginx php8.3-fpm php8.3-curl php8.3-mbstring php8.3-xml php8.3-zip curl unzip -y -qq 2>/dev/null

systemctl enable nginx php8.3-fpm >/dev/null 2>&1
systemctl start nginx php8.3-fpm >/dev/null 2>&1

# ============ 2. FOLDERS ============
echo -e "${CYAN}[2/5] Setup folder...${NC}"
[[ -d "$WEB_ROOT" ]] && mv "$WEB_ROOT" "/var/www/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$WEB_ROOT"/{api,includes,assets/css,assets/js}
echo -e "${GREEN}  ✓ Folder OK${NC}"

# ============ 3. CONFIG & ASSETS ============
echo -e "${CYAN}[3/5] Setup UI & Config...${NC}"

cat > "$WEB_ROOT/includes/config.php" << 'PHPEOF'
<?php
date_default_timezone_set('Asia/Jakarta');
define('SITE_NAME', 'Rendzz SMS');
define('SITE_URL', 'https://' . $_SERVER['HTTP_HOST']);
PHPEOF

# CSS (Modern Dark Mode)
cat > "$WEB_ROOT/assets/css/style.css" << 'CSSEOF'
:root {
    --bg: #09090b;
    --card: #18181b;
    --text: #fafafa;
    --muted: #a1a1aa;
    --border: #27272a;
    --primary: #10b981;
    --primary-hover: #059669;
    --danger: #ef4444;
}
* { margin: 0; padding: 0; box-sizing: border-box; font-family: 'Inter', sans-serif; }
body { background: var(--bg); color: var(--text); line-height: 1.6; min-height: 100vh; }
a { color: inherit; text-decoration: none; }

.navbar {
    position: sticky; top: 0; z-index: 100;
    background: rgba(9,9,11,0.9); backdrop-filter: blur(12px);
    border-bottom: 1px solid var(--border);
    padding: 16px 24px;
    display: flex; justify-content: space-between; align-items: center;
}
.logo { font-size: 1.1em; font-weight: 800; color: var(--primary); display: flex; align-items: center; gap: 8px; }

.container { max-width: 800px; margin: 0 auto; padding: 30px 20px; }

.hero { text-align: center; margin-bottom: 40px; }
.hero h1 { font-size: 2.2em; font-weight: 800; margin-bottom: 10px; }
.hero h1 span { color: var(--primary); }
.hero p { color: var(--muted); font-size: 1.05em; max-width: 500px; margin: 0 auto; }

.card {
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: 16px;
    padding: 24px;
    margin-bottom: 20px;
}

.form-group { margin-bottom: 20px; }
.form-group label {
    display: block; margin-bottom: 8px;
    font-size: 0.85em; color: var(--muted); font-weight: 600;
    text-transform: uppercase; letter-spacing: 0.5px;
}
.form-group select {
    width: 100%; padding: 14px 16px;
    border: 1px solid var(--border);
    border-radius: 12px;
    background: var(--bg);
    color: var(--text);
    font-family: inherit; font-size: 0.95em;
    outline: none; cursor: pointer;
    transition: 0.2s;
}
.form-group select:focus { border-color: var(--primary); }

.btn {
    padding: 14px 24px;
    border-radius: 12px;
    border: none;
    font-weight: 700;
    font-family: inherit;
    font-size: 0.95em;
    cursor: pointer;
    display: inline-flex; align-items: center; justify-content: center; gap: 8px;
    transition: 0.2s;
    width: 100%;
}
.btn-primary { background: var(--primary); color: #000; }
.btn-primary:hover { background: var(--primary-hover); }
.btn-sm { padding: 8px 16px; font-size: 0.85em; width: auto; }

/* NUMBER CARD */
.number-display {
    background: linear-gradient(135deg, rgba(16,185,129,0.15), transparent);
    border: 1px solid rgba(16,185,129,0.3);
    border-radius: 16px;
    padding: 30px 20px;
    text-align: center;
    margin-bottom: 20px;
    display: none;
}
.number-display.active { display: block; animation: slideDown 0.3s; }
@keyframes slideDown { from { opacity: 0; transform: translateY(-10px); } to { opacity: 1; transform: translateY(0); } }

.num-label { font-size: 0.8em; color: var(--muted); text-transform: uppercase; letter-spacing: 1px; margin-bottom: 8px; }
.num-value { font-size: 2em; font-weight: 800; color: var(--primary); letter-spacing: 1px; margin-bottom: 15px; word-break: break-all; }
.num-actions { display: flex; gap: 10px; justify-content: center; flex-wrap: wrap; }

/* SMS INBOX */
.inbox-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px; }
.inbox-header h2 { font-size: 1.1em; display: flex; align-items: center; gap: 8px; }
.status-dot { width: 8px; height: 8px; border-radius: 50%; background: var(--primary); animation: pulse 2s infinite; }
@keyframes pulse { 0%,100% { opacity: 1; } 50% { opacity: 0.3; } }

.sms-item {
    background: rgba(0,0,0,0.2);
    padding: 15px;
    border-radius: 12px;
    margin-bottom: 10px;
    border-left: 3px solid var(--primary);
    animation: slideDown 0.3s;
}
.sms-from { font-size: 0.8em; color: var(--muted); margin-bottom: 5px; display: flex; justify-content: space-between; }
.sms-text { font-size: 0.95em; word-break: break-word; }

.empty-state { text-align: center; padding: 40px 20px; color: var(--muted); }
.empty-state i { font-size: 3em; opacity: 0.3; margin-bottom: 15px; display: block; }

.alert { padding: 14px 18px; border-radius: 12px; margin-bottom: 20px; font-size: 0.9em; display: none; }
.alert.show { display: block; }
.alert-error { background: rgba(239,68,68,0.1); color: var(--danger); border: 1px solid rgba(239,68,68,0.2); }

/* FOOTER */
.footer { text-align: center; padding: 30px; color: var(--muted); font-size: 0.85em; border-top: 1px solid var(--border); margin-top: 40px; }

@media(max-width: 600px) {
    .hero h1 { font-size: 1.6em; }
    .num-value { font-size: 1.4em; }
}
CSSEOF

# HEADER
cat > "$WEB_ROOT/includes/header.php" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title><?= $pageTitle ?? 'Home' ?> — <?= SITE_NAME ?></title>
<link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>📱</text></svg>">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
<link rel="stylesheet" href="/assets/css/style.css">
</head>
<body>
<nav class="navbar">
    <a href="/" class="logo"><i class="fas fa-sim-card"></i> RendzzSMS</a>
    <div><a href="https://t.me/rendzz" target="_blank" class="btn btn-sm" style="background:rgba(255,255,255,0.1);color:#fff;text-decoration:none"><i class="fab fa-telegram"></i> Support</a></div>
</nav>
HTMLEOF

# ============ 4. API ENDPOINTS ============
echo -e "${CYAN}[4/5] Setup API (SMS Provider)...${NC}"

# API untuk ambil nomor & pesan
# Kita pakai API publik gratis: receive-smss.com (web scraping via PHP)
cat > "$WEB_ROOT/api/sms.php" << 'PHPEOF'
<?php
header('Content-Type: application/json');
require_once __DIR__ . '/../includes/config.php';

$action = $_GET['action'] ?? '';
$country = $_GET['country'] ?? 'id';

// Provider API Gratis (Public)
// Menggunakan receive-smss.com (scraping HTML)
function getPublicNumbers($country) {
    // Peta kode negara
    $countries = [
        'id' => 'indonesia',
        'us' => 'united-states',
        'uk' => 'united-kingdom',
        'in' => 'india',
        'ph' => 'philippines',
        'my' => 'malaysia',
        'ru' => 'russia',
        'de' => 'germany',
        'fr' => 'france',
        'nl' => 'netherlands',
    ];
    
    $slug = $countries[$country] ?? 'indonesia';
    $url = "https://receive-smss.com/sms/{$slug}/";
    
    $ctx = stream_context_create([
        'http' => [
            'timeout' => 15,
            'user_agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0'
        ],
        'ssl' => ['verify_peer' => false, 'verify_peer_name' => false]
    ]);
    
    $html = @file_get_contents($url, false, $ctx);
    if (!$html) return [];
    
    $numbers = [];
    // Regex ambil nomor (contoh: +62 812 3456 7890)
    if (preg_match_all('/<a[^>]*href="\/sms\/[^"]*"[^>]*>\s*(?:\+?\d[\d\s\-()]{7,})\s*<\/a>/i', $html, $m)) {
        foreach ($m[0] as $link) {
            if (preg_match('/href="([^"]+)"/', $link, $href)) {
                if (preg_match('/>\s*(\+?\d[\d\s\-()]{7,})\s*</', $link, $num)) {
                    $numbers[] = [
                        'number' => trim($num[1]),
                        'link' => 'https://receive-smss.com' . $href[1]
                    ];
                }
            }
        }
    }
    
    return array_slice($numbers, 0, 10);
}

// Scrape SMS dari halaman nomor
function getSMS($numberUrl) {
    $ctx = stream_context_create([
        'http' => [
            'timeout' => 15,
            'user_agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0'
        ],
        'ssl' => ['verify_peer' => false, 'verify_peer_name' => false]
    ]);
    
    $html = @file_get_contents($numberUrl, false, $ctx);
    if (!$html) return [];
    
    $messages = [];
    
    // Ambil dari tabel SMS
    if (preg_match_all('/<tr[^>]*>(.*?)<\/tr>/is', $html, $rows)) {
        foreach ($rows[1] as $row) {
            // Ambil kolom dari / sender / text
            $cols = [];
            if (preg_match_all('/<td[^>]*>(.*?)<\/td>/is', $row, $tds)) {
                foreach ($tds[1] as $td) {
                    $cols[] = trim(strip_tags($td));
                }
            }
            if (count($cols) >= 2 && !empty($cols[1])) {
                $messages[] = [
                    'from' => $cols[0] ?? 'Unknown',
                    'text' => $cols[1] ?? $cols[0] ?? '',
                    'time' => $cols[2] ?? date('H:i')
                ];
            }
        }
    }
    
    // Fallback: cari div SMS
    if (empty($messages)) {
        if (preg_match_all('/<div[^>]*class="[^"]*sms[^"]*"[^>]*>(.*?)<\/div>/is', $html, $divs)) {
            foreach ($divs[1] as $div) {
                $text = trim(strip_tags($div));
                if (strlen($text) > 10) {
                    $messages[] = ['from' => 'Unknown', 'text' => $text, 'time' => date('H:i')];
                }
            }
        }
    }
    
    return array_slice($messages, 0, 15);
}

// === ACTION HANDLER ===
if ($action === 'numbers') {
    $nums = getPublicNumbers($country);
    if (empty($nums)) {
        echo json_encode(['ok' => false, 'error' => 'Gagal ambil nomor. Coba negara lain atau tunggu sebentar.']);
    } else {
        echo json_encode(['ok' => true, 'numbers' => $nums]);
    }
    exit;
}

if ($action === 'messages') {
    $url = $_GET['url'] ?? '';
    if (!$url || strpos($url, 'receive-smss.com') === false) {
        echo json_encode(['ok' => false, 'error' => 'URL tidak valid']);
        exit;
    }
    $msgs = getSMS($url);
    echo json_encode(['ok' => true, 'messages' => $msgs, 'count' => count($msgs)]);
    exit;
}

echo json_encode(['ok' => false, 'error' => 'Action tidak valid']);
PHPEOF

# ============ 5. HALAMAN UTAMA ============
echo -e "${CYAN}[5/5] Setup Halaman...${NC}"

cat > "$WEB_ROOT/index.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
$pageTitle = 'Temp Number';
include __DIR__ . '/includes/header.php';
?>
<div class="container">
    <div class="hero">
        <h1>Terima SMS <span>Tanpa Nomor Pribadi</span></h1>
        <p>Dapatkan nomor virtual gratis untuk verifikasi WhatsApp, Telegram, Instagram, dan lainnya.</p>
    </div>

    <div class="card">
        <div class="form-group">
            <label><i class="fas fa-globe"></i> Pilih Negara</label>
            <select id="countrySelect">
                <option value="id" selected>Indonesia (+62)</option>
                <option value="us">United States (+1)</option>
                <option value="uk">United Kingdom (+44)</option>
                <option value="in">India (+91)</option>
                <option value="ph">Philippines (+63)</option>
                <option value="my">Malaysia (+60)</option>
                <option value="ru">Russia (+7)</option>
                <option value="de">Germany (+49)</option>
                <option value="fr">France (+33)</option>
                <option value="nl">Netherlands (+31)</option>
            </select>
        </div>
        <button class="btn btn-primary" onclick="loadNumbers()">
            <i class="fas fa-sync"></i> Generate Nomor Baru
        </button>
    </div>

    <div id="alertBox" class="alert alert-error"></div>

    <div id="numberBox" class="number-display">
        <div class="num-label">Nomor Virtual Anda</div>
        <div class="num-value" id="numValue">-</div>
        <div class="num-actions">
            <button class="btn btn-sm" style="background:rgba(255,255,255,0.1);color:#fff" onclick="copyNumber()"><i class="fas fa-copy"></i> Copy Nomor</button>
            <button class="btn btn-sm btn-primary" onclick="loadMessages(true)"><i class="fas fa-rotate"></i> Refresh SMS</button>
        </div>
    </div>

    <div class="card" id="inboxBox" style="display:none">
        <div class="inbox-header">
            <h2><span class="status-dot"></span> Inbox SMS</h2>
            <small id="lastUpdate" style="color:var(--muted);font-size:0.8em"></small>
        </div>
        <div id="smsList">
            <div class="empty-state">
                <i class="fas fa-inbox"></i>
                <p>Belum ada SMS masuk. Menunggu...</p>
            </div>
        </div>
    </div>
</div>

<script>
let currentNumberUrl = '';
let refreshInterval = null;

async function loadNumbers() {
    const country = document.getElementById('countrySelect').value;
    const alertBox = document.getElementById('alertBox');
    const btn = event.target;
    
    alertBox.classList.remove('show');
    btn.disabled = true;
    btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Mencari Nomor...';
    
    try {
        const res = await fetch('/api/sms.php?action=numbers&country=' + country);
        const data = await res.json();
        
        if (!data.ok || !data.numbers || data.numbers.length === 0) {
            throw new Error(data.error || 'Nomor tidak tersedia. Coba negara lain.');
        }
        
        // Ambil nomor pertama
        const num = data.numbers[0];
        document.getElementById('numValue').textContent = num.number;
        document.getElementById('numberBox').classList.add('active');
        document.getElementById('inboxBox').style.display = 'block';
        currentNumberUrl = num.link;
        
        // Langsung cek SMS
        loadMessages(true);
        
        // Auto refresh tiap 8 detik
        if (refreshInterval) clearInterval(refreshInterval);
        refreshInterval = setInterval(() => loadMessages(false), 8000);
        
    } catch(e) {
        alertBox.textContent = e.message;
        alertBox.classList.add('show');
    }
    
    btn.disabled = false;
    btn.innerHTML = '<i class="fas fa-sync"></i> Generate Nomor Baru';
}

async function loadMessages(showLoading) {
    if (!currentNumberUrl) return;
    
    const list = document.getElementById('smsList');
    if (showLoading) {
        list.innerHTML = '<div class="empty-state"><i class="fas fa-spinner fa-spin"></i><p>Mengecek SMS...</p></div>';
    }
    
    try {
        const res = await fetch('/api/sms.php?action=messages&url=' + encodeURIComponent(currentNumberUrl));
        const data = await res.json();
        
        if (!data.ok || data.messages.length === 0) {
            if (showLoading) {
                list.innerHTML = '<div class="empty-state"><i class="fas fa-inbox"></i><p>Belum ada SMS masuk. Menunggu...</p></div>';
            }
            return;
        }
        
        list.innerHTML = data.messages.map(m => `
            <div class="sms-item">
                <div class="sms-from">
                    <span><i class="fas fa-user"></i> ${escapeHtml(m.from)}</span>
                    <span>${escapeHtml(m.time)}</span>
                </div>
                <div class="sms-text">${escapeHtml(m.text)}</div>
            </div>
        `).join('');
        
        document.getElementById('lastUpdate').textContent = 'Update: ' + new Date().toLocaleTimeString('id-ID');
        
    } catch(e) {
        if (showLoading) {
            list.innerHTML = '<div class="empty-state"><i class="fas fa-exclamation-triangle"></i><p>Gagal memuat SMS.</p></div>';
        }
    }
}

function copyNumber() {
    const num = document.getElementById('numValue').textContent;
    navigator.clipboard.writeText(num).then(() => {
        alert('Nomor berhasil dicopy!\n\n' + num);
    });
}

function escapeHtml(text) {
    const d = document.createElement('div');
    d.textContent = text;
    return d.innerHTML;
}
</script>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# FOOTER
cat > "$WEB_ROOT/includes/footer.php" << 'HTMLEOF'
<footer class="footer">
    <p>&copy; <?= date('Y') ?> <?= SITE_NAME ?>. Free Virtual Number Service.</p>
    <p style="margin-top:5px;font-size:0.9em">⚠️ Nomor ini bersifat publik. Jangan gunakan untuk akun penting.</p>
</footer>
</body>
</html>
HTMLEOF

# ============ NGINX ============
echo -e "${CYAN}📝 Setup Nginx...${NC}"
cat > "$NGINX_CONF" << NGINXEOF
server {
    listen 80;
    listen [::]:80;
    server_name $SUBDOMAIN;
    root $WEB_ROOT;
    index index.php index.html;
    location / { try_files \$uri \$uri/ =404; }
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
    }
}
NGINXEOF

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/ 2>/dev/null
[[ -f /etc/nginx/sites-enabled/default ]] && rm -f /etc/nginx/sites-enabled/default
nginx -t >/dev/null 2>&1 && systemctl reload nginx || exit 1

chown -R www-data:www-data "$WEB_ROOT"
chmod -R 755 "$WEB_ROOT"
systemctl restart php8.3-fpm

# SSL
SERVER_IP=$(curl -4 -s --max-time 5 ifconfig.me 2>/dev/null)
DOMAIN_IP=$(dig +short A "$SUBDOMAIN" @8.8.8.8 2>/dev/null | head -1)
[[ -z "$DOMAIN_IP" ]] && DOMAIN_IP=$(getent ahostsv4 "$SUBDOMAIN" 2>/dev/null | awk '{print $1}' | head -1)

if [[ "$SERVER_IP" == "$DOMAIN_IP" ]] || [[ -f "/etc/letsencrypt/live/$SUBDOMAIN/fullchain.pem" ]]; then
    apt install certbot python3-certbot-nginx -y -qq 2>/dev/null
    certbot --nginx -d "$SUBDOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect >/dev/null 2>&1
fi

PROTO="https"; [[ ! -f "/etc/letsencrypt/live/$SUBDOMAIN/fullchain.pem" ]] && PROTO="http"

clear
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ RENDZZ SMS BERHASIL DI-INSTALL!        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🔗 URL:${NC} $PROTO://$SUBDOMAIN"
echo ""
echo -e "${YELLOW}⚠️  PENTING:${NC}"
echo -e "  • Nomor yang didapat adalah PUBLIK (gratisan)."
echo -e "  • Jangan dipakai buat akun bank / akun penting."
echo -e "  • Cocok buat test OTP / verifikasi sekali pakai."
echo ""
echo -e "${GREEN}🎉 Selesai!${NC}"
