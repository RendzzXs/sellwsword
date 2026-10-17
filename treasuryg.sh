#!/bin/bash
# ============================================
#   🪙 TREASURY GOLD — FINAL INSTALLER
#   (Database, User, Admin, QRIS, Grafik)
# ============================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

[[ $EUID -ne 0 ]] && { echo -e "${RED}❌ Harus root!${NC}"; exit 1; }

clear
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🪙 TREASURY GOLD — FINAL INSTALLER        ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

read -p "👉 Subdomain (contoh: gold.domain.com): " SUBDOMAIN
[[ -z "$SUBDOMAIN" ]] && { echo -e "${RED}❌ Kosong!${NC}"; exit 1; }

read -p "👉 Email SSL: " EMAIL
[[ -z "$EMAIL" ]] && EMAIL="admin@$SUBDOMAIN"

read -s -p "👉 Password Admin Panel [admin123]: " ADMIN_PASS
echo ""
ADMIN_PASS=${ADMIN_PASS:-admin123}

read -p "👉 URL QRIS (bisa pakai default catbox): " QRIS_URL
QRIS_URL=${QRIS_URL:-"https://files.catbox.moe/jpez3c.jpg"}

DB_PASS=$(openssl rand -hex 12)
DB_NAME="gold_$(echo $SUBDOMAIN | tr '.' '_' | cut -c1-15)"
WEB_ROOT="/var/www/$SUBDOMAIN"
NGINX_CONF="/etc/nginx/sites-available/$SUBDOMAIN"

echo ""
read -p "Lanjut? (y/n): " C
[[ "$C" != "y" && "$C" != "Y" ]] && exit 0

# ============ 1. PACKAGES ============
echo ""
echo -e "${CYAN}[1/6] Install packages...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt update -qq 2>/dev/null
apt install nginx php8.3-fpm php8.3-mysql php8.3-mbstring php8.3-curl php8.3-xml php8.3-zip php8.3-gd mysql-server curl wget unzip -y -qq 2>/dev/null

rm -f /etc/mysql/FROZEN 2>/dev/null
systemctl enable mysql nginx php8.3-fpm >/dev/null 2>&1
systemctl start mysql nginx php8.3-fpm >/dev/null 2>&1

if ! systemctl is-active --quiet mysql; then
    systemctl stop mysql >/dev/null 2>&1
    apt purge mysql-server mysql-server-8.0 mysql-client mysql-common -y >/dev/null 2>&1
    rm -rf /var/lib/mysql /etc/mysql
    apt install mysql-server -y -qq >/dev/null 2>&1
    systemctl start mysql >/dev/null 2>&1
    sleep 5
fi

systemctl is-active --quiet mysql && echo -e "${GREEN}  ✓ MySQL OK${NC}" || { echo -e "${RED}  ✗ MySQL gagal!${NC}"; exit 1; }

# ============ 2. DATABASE ============
echo -e "${CYAN}[2/6] Setup Database...${NC}"
mysql -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;" 2>/dev/null
mysql -e "CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS 'goldapp'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO 'goldapp'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

mysql "$DB_NAME" << 'SQLEOF'
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role ENUM('admin','user') DEFAULT 'user',
    status ENUM('active','banned') DEFAULT 'active',
    saldo_rp DECIMAL(15,2) DEFAULT 0.00,
    saldo_gram DECIMAL(10,4) DEFAULT 0.0000,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE deposits (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    amount DECIMAL(15,2) NOT NULL,
    status ENUM('pending','approved','rejected') DEFAULT 'pending',
    proof VARCHAR(255) DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE withdrawals (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    amount DECIMAL(15,2) NOT NULL,
    method VARCHAR(50) NOT NULL,
    account_no VARCHAR(50) NOT NULL,
    account_name VARCHAR(100) NOT NULL,
    status ENUM('pending','approved','rejected') DEFAULT 'pending',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    type ENUM('buy_gold','sell_gold') NOT NULL,
    amount_gram DECIMAL(10,4) NOT NULL,
    price_per_gram DECIMAL(15,2) NOT NULL,
    total_rp DECIMAL(15,2) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE broadcasts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255),
    content TEXT,
    image_url VARCHAR(255) DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE settings (
    k VARCHAR(50) PRIMARY KEY,
    v TEXT
);
SQLEOF

ADMIN_HASH=$(php -r "echo password_hash('$ADMIN_PASS', PASSWORD_BCRYPT);")
mysql "$DB_NAME" << SQLEOF
INSERT INTO users (username, email, password, role) VALUES ('admin', 'admin@$SUBDOMAIN', '$ADMIN_HASH', 'admin');
INSERT INTO settings VALUES 
('admin_password', '$ADMIN_HASH'),
('site_name', 'Treasury Gold'),
('qris_url', '$QRIS_URL'),
('harga_emas', '1350000');
SQLEOF
echo -e "${GREEN}  ✓ Database OK${NC}"

# ============ 3. FOLDERS ============
echo -e "${CYAN}[3/6] Setup Folder...${NC}"
[[ -d "$WEB_ROOT" ]] && mv "$WEB_ROOT" "/var/www/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$WEB_ROOT"/{api,includes,assets/css,assets/js,uploads,x-panel-core}
echo -e "${GREEN}  ✓ Folder OK${NC}"

# ============ 4. CONFIG ============
echo -e "${CYAN}[4/6] Setup Config...${NC}"
cat > "$WEB_ROOT/includes/config.php" << PHPEOF
<?php
session_start();
date_default_timezone_set('Asia/Jakarta');

define('DB_HOST', 'localhost');
define('DB_NAME', '$DB_NAME');
define('DB_USER', 'goldapp');
define('DB_PASS', '$DB_PASS');
define('SITE_URL', 'https://$SUBDOMAIN');
define('SITE_NAME', 'Treasury Gold');
define('ADMIN_PATH', 'x-panel-core');

try {
    \$pdo = new PDO("mysql:host=".DB_HOST.";dbname=".DB_NAME.";charset=utf8mb4", DB_USER, DB_PASS, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
} catch (PDOException \$e) { die("DB Error: " . \$e->getMessage()); }

function isLoggedIn() { return isset(\$_SESSION['user_id']); }
function isAdmin() { return isLoggedIn() && \$_SESSION['role'] === 'admin'; }
function requireLogin() { if (!isLoggedIn()) { header('Location: /login.php'); exit; } }
function requireAdmin() { if (!isAdmin()) { header('Location: /'.ADMIN_PATH.'/login.php'); exit; } }
function csrf() { if (empty(\$_SESSION['csrf'])) \$_SESSION['csrf'] = bin2hex(random_bytes(32)); return \$_SESSION['csrf']; }
function checkCsrf(\$t) { return isset(\$_SESSION['csrf']) && hash_equals(\$_SESSION['csrf'], \$t); }
function getSetting(\$pdo, \$k, \$default = '') {
    \$s = \$pdo->prepare("SELECT v FROM settings WHERE k=?"); \$s->execute([\$k]);
    \$r = \$s->fetch(); return \$r ? \$r['v'] : \$default;
}
function rupiah(\$n) { return 'Rp ' . number_format((float)\$n, 0, ',', '.'); }
function gram(\$n) { return number_format((float)\$n, 4, ',', '.') . ' gr'; }
PHPEOF
echo -e "${GREEN}  ✓ Config OK${NC}"

# ============ 5. UI & ASSETS ============
echo -e "${CYAN}[5/6] Setup UI & Assets...${NC}"

# CSS
cat > "$WEB_ROOT/assets/css/style.css" << 'CSSEOF'
:root { --bg: #0a0a0f; --bg-card: #15151f; --bg-nav: rgba(10,10,15,0.95); --text: #f0f0f5; --text-muted: #888899; --border: rgba(255,255,255,0.08); --primary: #f59e0b; --primary-2: #d97706; --success: #10b981; --danger: #ef4444; }
* { margin: 0; padding: 0; box-sizing: border-box; font-family: 'Inter', -apple-system, sans-serif; }
body { background: var(--bg); color: var(--text); line-height: 1.6; min-height: 100vh; padding-bottom: 80px; }
a { color: inherit; text-decoration: none; }
.navbar { position: sticky; top: 0; z-index: 100; background: var(--bg-nav); backdrop-filter: blur(20px); border-bottom: 1px solid var(--border); padding: 15px 20px; display: flex; justify-content: space-between; align-items: center; }
.logo { font-size: 1.2em; font-weight: 800; display: flex; align-items: center; gap: 8px; color: var(--primary); }
.container { max-width: 800px; margin: 0 auto; padding: 20px; }
.card { background: var(--bg-card); border: 1px solid var(--border); border-radius: 20px; padding: 24px; margin-bottom: 20px; }
.grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; }
@media(max-width: 600px) { .grid-2 { grid-template-columns: 1fr; } }
.btn { padding: 12px 24px; border-radius: 12px; border: none; font-weight: 700; font-family: inherit; font-size: 0.95em; cursor: pointer; display: inline-flex; align-items: center; justify-content: center; gap: 8px; transition: 0.2s; text-decoration: none; }
.btn-primary { background: linear-gradient(135deg, var(--primary), var(--primary-2)); color: #000; }
.btn-outline { background: transparent; border: 2px solid var(--border); color: var(--text); }
.btn-block { width: 100%; }
.btn-sm { padding: 6px 12px; font-size: 0.85em; }
.form-group { margin-bottom: 15px; }
.form-group label { display: block; margin-bottom: 6px; font-size: 0.85em; color: var(--text-muted); font-weight: 600; }
.form-group input, .form-group select { width: 100%; padding: 14px 16px; border: 1px solid var(--border); border-radius: 12px; background: var(--bg); color: var(--text); font-family: inherit; font-size: 1em; outline: none; }
.form-group input:focus { border-color: var(--primary); }
.bottom-nav { position: fixed; bottom: 0; left: 0; right: 0; background: var(--bg-nav); backdrop-filter: blur(20px); border-top: 1px solid var(--border); display: flex; justify-content: space-around; padding: 10px 0; z-index: 100; }
.nav-item { display: flex; flex-direction: column; align-items: center; gap: 4px; font-size: 0.7em; font-weight: 600; color: var(--text-muted); transition: 0.2s; padding: 0 10px; }
.nav-item i { font-size: 1.4em; }
.nav-item.active, .nav-item:hover { color: var(--primary); }
.alert { padding: 12px 16px; border-radius: 10px; margin-bottom: 15px; font-size: 0.9em; }
.alert-error { background: rgba(239,68,68,0.1); color: var(--danger); border: 1px solid rgba(239,68,68,0.2); }
.alert-success { background: rgba(16,185,129,0.1); color: var(--success); border: 1px solid rgba(16,185,129,0.2); }
.badge { padding: 4px 10px; border-radius: 8px; font-size: 0.75em; font-weight: 800; text-transform: uppercase; }
.table { width: 100%; border-collapse: collapse; font-size: 0.9em; }
.table th, .table td { padding: 12px; text-align: left; border-bottom: 1px solid var(--border); }
.table th { color: var(--text-muted); font-size: 0.8em; text-transform: uppercase; }
.chart-container { position: relative; height: 250px; width: 100%; margin-top: 15px; background: rgba(0,0,0,0.2); border-radius: 15px; padding: 10px; border: 1px solid var(--border); }
.tabs { display: flex; gap: 10px; margin-bottom: 20px; overflow-x: auto; padding-bottom: 5px; }
.tab-btn { padding: 10px 20px; border-radius: 10px; border: 1px solid var(--border); background: var(--bg); color: var(--text); cursor: pointer; font-weight: 600; white-space: nowrap; }
.tab-btn.active { background: var(--primary); color: #000; border-color: var(--primary); }
.tab-content { display: none; }
.tab-content.active { display: block; }
.user-card { background: rgba(255,255,255,0.02); border: 1px solid var(--border); padding: 15px; border-radius: 12px; margin-bottom: 10px; }
.action-forms { display: flex; flex-wrap: wrap; gap: 10px; margin-top: 10px; }
.mini-form { display: flex; gap: 5px; align-items: center; background: rgba(0,0,0,0.2); padding: 5px; border-radius: 8px; }
.mini-form input { width: 80px; padding: 5px 8px; border-radius: 5px; border: 1px solid var(--border); background: var(--bg); color: var(--text); font-size: 0.85em; }
.mini-form button { padding: 5px 10px; border-radius: 5px; border: none; cursor: pointer; font-size: 0.85em; font-weight: 600; }
CSSEOF

# HEADER & FOOTER
cat > "$WEB_ROOT/includes/header.php" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title><?= $pageTitle ?? 'Home' ?> — <?= SITE_NAME ?></title>
<link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>🪙</text></svg>">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<link rel="stylesheet" href="/assets/css/style.css">
</head>
<body>
<nav class="navbar">
    <a href="/" class="logo"><i class="fas fa-coins"></i> TreasuryGold</a>
    <div>
        <?php if (isLoggedIn()): ?>
            <a href="/<?= ADMIN_PATH ?>/" class="btn btn-sm btn-outline" style="border:none">Admin</a>
            <a href="/logout.php" class="btn btn-sm btn-outline" style="border:none;color:var(--danger)">Logout</a>
        <?php else: ?>
            <a href="/login.php" class="btn btn-sm btn-outline">Login</a>
        <?php endif; ?>
    </div>
</nav>
HTMLEOF

cat > "$WEB_ROOT/includes/footer.php" << 'HTMLEOF'
<div class="bottom-nav">
    <a href="/" class="nav-item <?= basename($_SERVER['PHP_SELF']) == 'index.php' ? 'active' : '' ?>"><i class="fas fa-home"></i> Home</a>
    <a href="/chart.php" class="nav-item <?= basename($_SERVER['PHP_SELF']) == 'chart.php' ? 'active' : '' ?>"><i class="fas fa-chart-line"></i> Market</a>
    <a href="/trade.php" class="nav-item <?= basename($_SERVER['PHP_SELF']) == 'trade.php' ? 'active' : '' ?>"><i class="fas fa-shopping-cart"></i> Trade</a>
    <a href="/news.php" class="nav-item <?= basename($_SERVER['PHP_SELF']) == 'news.php' ? 'active' : '' ?>"><i class="fas fa-newspaper"></i> Berita</a>
    <a href="/profile.php" class="nav-item <?= basename($_SERVER['PHP_SELF']) == 'profile.php' ? 'active' : '' ?>"><i class="fas fa-user"></i> Profil</a>
</div>
</body>
</html>
HTMLEOF

# JS (Chart)
cat > "$WEB_ROOT/assets/js/main.js" << 'JSEOF'
document.addEventListener('DOMContentLoaded', () => {
    const ctx = document.getElementById('goldChart');
    if (!ctx) return;
    fetch('/api/price.php').then(res => res.json()).then(data => {
        if (!data.ok) return;
        const basePrice = data.price;
        const labels = []; const prices = [];
        let currentPrice = basePrice - 5000;
        for (let i = 10; i >= 0; i--) {
            labels.push(`${i*2}h ago`);
            currentPrice += (Math.random() - 0.5) * 3000;
            prices.push(currentPrice);
        }
        prices[prices.length - 1] = basePrice;
        new Chart(ctx, {
            type: 'line',
            data: { labels: labels, datasets: [{ label: 'Harga', data: prices, borderColor: '#f59e0b', backgroundColor: 'rgba(245, 158, 11, 0.1)', borderWidth: 3, pointRadius: 0, fill: true, tension: 0.4 }] },
            options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } }, scales: { x: { display: false }, y: { grid: { color: 'rgba(255,255,255,0.05)' }, ticks: { color: '#888899', callback: v => 'Rp ' + (v/1000).toFixed(0) + 'k' } } } }
        });
    });
});
JSEOF

# ============ 6. PAGES & API ============
echo -e "${CYAN}[6/6] Setup Halaman & API...${NC}"

# API HARGA
cat > "$WEB_ROOT/api/price.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
header('Content-Type: application/json');
$harga = getSetting($pdo, 'harga_emas', 1350000);
echo json_encode(['ok' => true, 'price' => (float)$harga]);
PHPEOF

# HALAMAN HOME
cat > "$WEB_ROOT/index.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
$pageTitle = 'Investasi Emas Digital';
$harga = getSetting($pdo, 'harga_emas', 1350000);
include __DIR__ . '/includes/header.php';
?>
<div class="container" style="text-align:center; padding-top:40px;">
    <div style="background:linear-gradient(135deg, rgba(245,158,11,0.15), transparent); padding:40px 20px; border-radius:24px; border:1px solid rgba(245,158,11,0.3);">
        <i class="fas fa-coins" style="font-size:3.5em; color:var(--primary); margin-bottom:20px;"></i>
        <h1 style="font-size:2.2em; font-weight:800; margin-bottom:10px;">Treasury Gold</h1>
        <p style="color:var(--text-muted); font-size:1.1em; margin-bottom:25px;">Platform jual beli & investasi emas digital termurah dan terpercaya. Mulai dari 0.01 Gram.</p>
        <div style="font-size:2em; font-weight:800; color:var(--primary); margin-bottom:30px;">
            Rp <?= number_format((float)$harga, 0, ',', '.') ?> <span style="font-size:0.5em;color:var(--text-muted)">/ gram</span>
        </div>
        <div style="display:flex; gap:10px; justify-content:center; flex-wrap:wrap">
            <a href="/register.php" class="btn btn-primary" style="font-size:1.1em; padding:15px 30px;"><i class="fas fa-rocket"></i> Mulai Investasi</a>
            <?php if (isLoggedIn()): ?><a href="/trade.php" class="btn btn-outline" style="font-size:1.1em; padding:15px 30px;">Beli Emas</a>
            <?php else: ?><a href="/login.php" class="btn btn-outline" style="font-size:1.1em; padding:15px 30px;">Login</a><?php endif; ?>
        </div>
    </div>
</div>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# CHART
cat > "$WEB_ROOT/chart.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
$pageTitle = 'Grafik Emas';
$harga = getSetting($pdo, 'harga_emas', 1350000);
include __DIR__ . '/includes/header.php';
?>
<div class="container">
    <h2 style="margin-bottom:20px">Pergerakan Harga</h2>
    <div class="card">
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:20px">
            <div><div style="font-size:0.85em; color:var(--text-muted)">Harga Saat Ini</div><div style="font-size:1.8em; font-weight:800; color:var(--primary)">Rp <?= number_format((float)$harga, 0, ',', '.') ?></div></div>
            <span class="badge" style="background:rgba(16,185,129,0.15); color:var(--success)"><i class="fas fa-arrow-up"></i> Realtime</span>
        </div>
        <div class="chart-container"><canvas id="goldChart"></canvas></div>
    </div>
</div>
<script src="/assets/js/main.js"></script>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# TRADE (BELI EMAS)
cat > "$WEB_ROOT/trade.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
requireLogin();
$uid = $_SESSION['user_id'];
$s = $pdo->prepare("SELECT * FROM users WHERE id=?"); $s->execute([$uid]); $me = $s->fetch();
$harga = (float)getSetting($pdo, 'harga_emas', 1350000);
$msg = ''; $err = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $gram = (float)$_POST['gram']; $total = $gram * $harga;
    if ($gram < 0.01) $err = 'Minimal pembelian 0.01 Gram!';
    elseif ($total > $me['saldo_rp']) $err = 'Saldo Rupiah tidak cukup!';
    else {
        $pdo->beginTransaction();
        try {
            $pdo->prepare("UPDATE users SET saldo_rp = saldo_rp - ?, saldo_gram = saldo_gram + ? WHERE id=?")->execute([$total, $gram, $uid]);
            $pdo->prepare("INSERT INTO transactions (user_id, type, amount_gram, price_per_gram, total_rp) VALUES (?,?,?,?,?)")->execute([$uid, 'buy_gold', $gram, $harga, $total]);
            $pdo->commit(); $msg = "Berhasil membeli " . number_format($gram, 4) . " Gram emas!";
        } catch (Exception $e) { $pdo->rollBack(); $err = 'Gagal transaksi.'; }
    }
}
$pageTitle = 'Beli Emas';
include __DIR__ . '/includes/header.php';
?>
<div class="container">
    <h2 style="margin-bottom:20px">Beli Emas</h2>
    <div class="card" style="background:linear-gradient(135deg, rgba(245,158,11,0.1), transparent)">
        <div class="grid-2">
            <div><div style="font-size:0.85em; color:var(--text-muted)">Saldo Rupiah</div><div style="font-size:1.3em; font-weight:700"><?= rupiah($me['saldo_rp']) ?></div></div>
            <div><div style="font-size:0.85em; color:var(--text-muted)">Saldo Emas</div><div style="font-size:1.3em; font-weight:700; color:var(--primary)"><?= gram($me['saldo_gram']) ?></div></div>
        </div>
    </div>
    <div class="card">
        <?php if ($msg): ?><div class="alert alert-success"><?= $msg ?></div><?php endif; ?>
        <?php if ($err): ?><div class="alert alert-error"><?= $err ?></div><?php endif; ?>
        <form method="POST">
            <div class="form-group"><label>Jumlah Gram (Min 0.01)</label><input type="number" name="gram" step="0.01" min="0.01" value="0.01" required></div>
            <div style="font-size:0.85em;color:var(--text-muted);margin-bottom:15px">Harga per gram: <?= rupiah($harga) ?></div>
            <button class="btn btn-primary btn-block"><i class="fas fa-shopping-cart"></i> Beli Sekarang</button>
        </form>
    </div>
</div>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# PROFILE (USER DASHBOARD)
cat > "$WEB_ROOT/profile.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
requireLogin();
$uid = $_SESSION['user_id'];
$s = $pdo->prepare("SELECT * FROM users WHERE id=?"); $s->execute([$uid]); $me = $s->fetch();
$trx = $pdo->prepare("SELECT * FROM transactions WHERE user_id=? ORDER BY id DESC LIMIT 10"); $trx->execute([$uid]); $trx = $trx->fetchAll();
$pageTitle = 'Profil Saya';
include __DIR__ . '/includes/header.php';
?>
<div class="container">
    <div class="card" style="background:linear-gradient(135deg, rgba(245,158,11,0.1), transparent); margin-bottom:20px">
        <div style="display:flex; align-items:center; gap:15px; margin-bottom:20px">
            <div style="width:60px;height:60px;border-radius:50%;background:var(--primary);display:flex;align-items:center;justify-content:center;font-size:1.5em;font-weight:800;color:#000">
                <?= strtoupper(substr($me['username'],0,1)) ?>
            </div>
            <div><h2 style="margin:0">@<?= htmlspecialchars($me['username']) ?></h2><p style="color:var(--text-muted);font-size:0.9em;margin:0"><?= htmlspecialchars($me['email']) ?></p></div>
        </div>
        <div class="grid-2">
            <div style="background:rgba(0,0,0,0.2); padding:15px; border-radius:12px">
                <div style="font-size:0.85em; color:var(--text-muted)">Saldo Rupiah</div>
                <div style="font-size:1.4em; font-weight:800; color:var(--success); margin-bottom:10px"><?= rupiah($me['saldo_rp']) ?></div>
                <div style="display:flex;gap:5px"><a href="/deposit.php" class="btn btn-sm btn-primary" style="flex:1">Deposit</a><a href="/withdraw.php" class="btn btn-sm btn-outline" style="flex:1">Tarik</a></div>
            </div>
            <div style="background:rgba(0,0,0,0.2); padding:15px; border-radius:12px">
                <div style="font-size:0.85em; color:var(--text-muted)">Saldo Emas</div>
                <div style="font-size:1.4em; font-weight:800; color:var(--primary); margin-bottom:10px"><?= gram($me['saldo_gram']) ?></div>
                <a href="/trade.php" class="btn btn-sm btn-primary" style="width:100%">Beli Emas</a>
            </div>
        </div>
    </div>
    <div class="card">
        <h3 style="margin-bottom:15px; display:flex; align-items:center; gap:8px"><i class="fas fa-history" style="color:var(--primary)"></i> Riwayat Pembelian Emas</h3>
        <?php if (empty($trx)): ?><p style="color:var(--text-muted); text-align:center">Belum ada riwayat transaksi.</p>
        <?php else: ?>
            <table class="table"><tr><th>Tanggal</th><th>Gram</th><th>Total Bayar</th></tr>
                <?php foreach($trx as $t): ?><tr><td><?= date('d/m/y H:i', strtotime($t['created_at'])) ?></td><td style="color:var(--primary)"><b><?= number_format($t['amount_gram'],4) ?> gr</b></td><td><?= rupiah($t['total_rp']) ?></td></tr><?php endforeach; ?>
            </table>
        <?php endif; ?>
    </div>
    <a href="/logout.php" class="btn btn-outline" style="width:100%; border-color:var(--danger); color:var(--danger)">Logout Akun</a>
</div>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# DEPOSIT
cat > "$WEB_ROOT/deposit.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
requireLogin();
$uid = $_SESSION['user_id'];
$qris = getSetting($pdo, 'qris_url');
$msg = ''; $err = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $amount = (float)$_POST['amount'];
    if ($amount < 5000) $err = 'Minimal deposit Rp 5.000!';
    elseif (!isset($_FILES['proof']) || $_FILES['proof']['error'] !== 0) $err = 'Bukti transfer wajib diupload!';
    else {
        $ext = pathinfo($_FILES['proof']['name'], PATHINFO_EXTENSION);
        if (!in_array(strtolower($ext), ['jpg','jpeg','png'])) $err = 'Format bukti harus JPG/PNG!';
        else {
            $fname = 'proof_' . $uid . '_' . time() . '.' . $ext;
            move_uploaded_file($_FILES['proof']['tmp_name'], __DIR__ . '/uploads/' . $fname);
            $pdo->prepare("INSERT INTO deposits (user_id, amount, proof) VALUES (?,?,?)")->execute([$uid, $amount, $fname]);
            $msg = 'Deposit diajukan! Tunggu admin verifikasi.';
        }
    }
}
$pageTitle = 'Deposit';
include __DIR__ . '/includes/header.php';
?>
<div class="container">
    <h2 style="margin-bottom:20px">Deposit Rupiah</h2>
    <?php if ($msg): ?><div class="alert alert-success"><?= $msg ?></div><?php endif; ?>
    <?php if ($err): ?><div class="alert alert-error"><?= $err ?></div><?php endif; ?>
    <div class="grid-2">
        <div class="card" style="text-align:center"><p style="margin-bottom:15px">Scan QRIS dibawah ini:</p><img src="<?= htmlspecialchars($qris) ?>" style="max-width:100%; border-radius:10px; background:#fff; padding:10px;"></div>
        <div class="card">
            <form method="POST" enctype="multipart/form-data">
                <div class="form-group"><label>Nominal Deposit (Min Rp 5.000)</label><input type="number" name="amount" min="5000" value="5000" required></div>
                <div class="form-group"><label>Upload Bukti Transfer</label><input type="file" name="proof" accept="image/*" required style="padding:10px"></div>
                <button class="btn btn-primary btn-block">Kirim Konfirmasi</button>
            </form>
        </div>
    </div>
</div>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# WITHDRAW
cat > "$WEB_ROOT/withdraw.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
requireLogin();
$uid = $_SESSION['user_id'];
$s = $pdo->prepare("SELECT * FROM users WHERE id=?"); $s->execute([$uid]); $me = $s->fetch();
$msg = ''; $err = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $amount = (float)$_POST['amount']; $method = $_POST['method']; $acc_no = trim($_POST['account_no']); $acc_name = trim($_POST['account_name']);
    if ($amount < 10000) $err = 'Minimal penarikan Rp 10.000!';
    elseif ($amount > $me['saldo_rp']) $err = 'Saldo Rupiah tidak cukup!';
    else {
        $pdo->prepare("UPDATE users SET saldo_rp = saldo_rp - ? WHERE id=?")->execute([$amount, $uid]);
        $pdo->prepare("INSERT INTO withdrawals (user_id, amount, method, account_no, account_name) VALUES (?,?,?,?,?)")->execute([$uid, $amount, $method, $acc_no, $acc_name]);
        $msg = 'Penarikan diajukan! Tunggu admin proses.';
    }
}
$pageTitle = 'Tarik Dana';
include __DIR__ . '/includes/header.php';
?>
<div class="container">
    <h2 style="margin-bottom:20px">Penarikan Dana</h2>
    <?php if ($msg): ?><div class="alert alert-success"><?= $msg ?></div><?php endif; ?>
    <?php if ($err): ?><div class="alert alert-error"><?= $err ?></div><?php endif; ?>
    <div class="card">
        <div style="margin-bottom:15px; font-size:1.1em">Saldo Anda: <b style="color:var(--success)"><?= rupiah($me['saldo_rp']) ?></b></div>
        <form method="POST">
            <div class="form-group"><label>Jumlah Penarikan (Min Rp 10.000)</label><input type="number" name="amount" min="10000" required></div>
            <div class="form-group"><label>Metode Penarikan</label><select name="method" required><option value="GoPay">GoPay</option><option value="OVO">OVO</option><option value="SeaBank">SeaBank</option><option value="BNI">BNI</option><option value="BCA">BCA</option></select></div>
            <div class="form-group"><label>Nomor Rekening / HP</label><input type="text" name="account_no" required></div>
            <div class="form-group"><label>Nama Pemilik Rekening</label><input type="text" name="account_name" required></div>
            <button class="btn btn-primary btn-block">Tarik Dana</button>
        </form>
    </div>
</div>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# NEWS (BROADCAST)
cat > "$WEB_ROOT/news.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
$pageTitle = 'Berita & Pengumuman';
$news = $pdo->query("SELECT * FROM broadcasts ORDER BY id DESC")->fetchAll();
include __DIR__ . '/includes/header.php';
?>
<div class="container">
    <h2 style="margin-bottom:20px">Berita & Pengumuman</h2>
    <?php if (empty($news)): ?><div class="card" style="text-align:center; color:var(--text-muted)">Belum ada berita.</div>
    <?php else: foreach ($news as $n): ?>
        <div class="card" style="padding:15px">
            <div style="font-size:0.8em; color:var(--text-muted); margin-bottom:8px"><?= date('d M Y H:i', strtotime($n['created_at'])) ?></div>
            <h3 style="margin-bottom:10px; color:var(--primary)"><?= htmlspecialchars($n['title']) ?></h3>
            <?php if ($n['image_url']): ?><img src="<?= htmlspecialchars($n['image_url']) ?>" style="width:100%; border-radius:10px; margin-bottom:15px;"><?php endif; ?>
            <p><?= nl2br(htmlspecialchars($n['content'])) ?></p>
        </div>
    <?php endforeach; endif; ?>
</div>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# LOGIN / REGISTER / LOGOUT
cat > "$WEB_ROOT/login.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
if (isLoggedIn()) { header('Location: /profile.php'); exit; }
$err = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $u = trim($_POST['username']); $p = $_POST['password'];
    $s = $pdo->prepare("SELECT * FROM users WHERE username=?"); $s->execute([$u]); $user = $s->fetch();
    if ($user && password_verify($p, $user['password'])) {
        if ($user['status'] === 'banned') { $err = 'Akun dibanned!'; }
        else {
            $_SESSION['user_id'] = $user['id']; $_SESSION['username'] = $user['username']; $_SESSION['role'] = $user['role'];
            header('Location: /profile.php'); exit;
        }
    } else { $err = 'Kredensial salah!'; }
}
$pageTitle = 'Login'; include __DIR__ . '/includes/header.php';
?>
<div class="container" style="max-width:400px; margin-top:50px"><div class="card">
    <h2 style="text-align:center;margin-bottom:20px">Login</h2>
    <?php if ($err): ?><div class="alert alert-error"><?= $err ?></div><?php endif; ?>
    <form method="POST">
        <div class="form-group"><label>Username</label><input type="text" name="username" required></div>
        <div class="form-group"><label>Password</label><input type="password" name="password" required></div>
        <button class="btn btn-primary btn-block">Masuk</button>
    </form>
    <p style="text-align:center;margin-top:15px;font-size:0.9em"><a href="/register.php">Belum punya akun? Daftar</a></p>
</div></div>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

cat > "$WEB_ROOT/register.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
if (isLoggedIn()) { header('Location: /profile.php'); exit; }
$err = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $u = trim($_POST['username']); $e = trim($_POST['email']); $p = $_POST['password'];
    if (strlen($p) < 6) $err = 'Password min 6 karakter';
    else {
        $s = $pdo->prepare("SELECT id FROM users WHERE username=? OR email=?"); $s->execute([$u, $e]);
        if ($s->fetch()) $err = 'Username/Email sudah dipakai!';
        else {
            $h = password_hash($p, PASSWORD_BCRYPT);
            $pdo->prepare("INSERT INTO users (username, email, password) VALUES (?,?,?)")->execute([$u, $e, $h]);
            header('Location: /login.php'); exit;
        }
    }
}
$pageTitle = 'Daftar'; include __DIR__ . '/includes/header.php';
?>
<div class="container" style="max-width:400px; margin-top:50px"><div class="card">
    <h2 style="text-align:center;margin-bottom:20px">Daftar Akun</h2>
    <?php if ($err): ?><div class="alert alert-error"><?= $err ?></div><?php endif; ?>
    <form method="POST">
        <div class="form-group"><label>Username</label><input type="text" name="username" required></div>
        <div class="form-group"><label>Email</label><input type="email" name="email" required></div>
        <div class="form-group"><label>Password</label><input type="password" name="password" required></div>
        <button class="btn btn-primary btn-block">Daftar</button>
    </form>
</div></div>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

cat > "$WEB_ROOT/logout.php" << 'PHPEOF'
<?php session_start(); session_destroy(); header('Location: /'); exit; ?>
PHPEOF

# ============ ADMIN PANEL ============
cat > "$WEB_ROOT/x-panel-core/login.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
if (isAdmin()) { header('Location: /'.ADMIN_PATH.'/'); exit; }
$err = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $u = trim($_POST['username']); $p = $_POST['password'];
    $s = $pdo->prepare("SELECT * FROM users WHERE username=? AND role='admin'"); $s->execute([$u]); $user = $s->fetch();
    if ($user && password_verify($p, $user['password'])) {
        $_SESSION['user_id'] = $user['id']; $_SESSION['username'] = $user['username']; $_SESSION['role'] = 'admin';
        header('Location: /'.ADMIN_PATH.'/'); exit;
    } else { $err = 'Akses ditolak!'; }
}
?>
<!DOCTYPE html>
<html lang="id">
<head><meta charset="UTF-8"><title>Admin Login</title><link rel="stylesheet" href="/assets/css/style.css"></head>
<body style="background:#050508">
<div style="min-height:100vh; display:flex; align-items:center; justify-content:center; padding:20px;">
    <div class="card" style="max-width:400px;width:100%;text-align:center;">
        <i class="fas fa-lock" style="font-size:3em;color:var(--primary);margin-bottom:15px"></i>
        <h2>Admin Panel</h2>
        <?php if ($err): ?><div class="alert alert-error"><?= $err ?></div><?php endif; ?>
        <form method="POST" style="text-align:left;margin-top:20px">
            <div class="form-group"><label>Username</label><input type="text" name="username" required></div>
            <div class="form-group"><label>Password</label><input type="password" name="password" required></div>
            <button class="btn btn-primary btn-block">Login</button>
        </form>
    </div>
</div>
</body></html>
PHPEOF

cat > "$WEB_ROOT/x-panel-core/index.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
requireAdmin();

$msg = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action'])) {
    $act = $_POST['action'];
    if ($act === 'approve_dep') {
        $id = (int)$_POST['id']; $s = $pdo->prepare("SELECT * FROM deposits WHERE id=?"); $s->execute([$id]); $d = $s->fetch();
        if ($d && $d['status'] == 'pending') {
            $pdo->prepare("UPDATE deposits SET status='approved' WHERE id=?")->execute([$id]);
            $pdo->prepare("UPDATE users SET saldo_rp = saldo_rp + ? WHERE id=?")->execute([$d['amount'], $d['user_id']]);
            $msg = 'Deposit disetujui & saldo ditambahkan.';
        }
    } elseif ($act === 'reject_dep') { $id = (int)$_POST['id']; $pdo->prepare("UPDATE deposits SET status='rejected' WHERE id=?")->execute([$id]); $msg = 'Deposit ditolak.';
    } elseif ($act === 'approve_wd') { $id = (int)$_POST['id']; $pdo->prepare("UPDATE withdrawals SET status='approved' WHERE id=?")->execute([$id]); $msg = 'Penarikan disetujui.';
    } elseif ($act === 'reject_wd') {
        $id = (int)$_POST['id']; $s = $pdo->prepare("SELECT * FROM withdrawals WHERE id=?"); $s->execute([$id]); $w = $s->fetch();
        if ($w && $w['status'] == 'pending') {
            $pdo->prepare("UPDATE withdrawals SET status='rejected' WHERE id=?")->execute([$id]);
            $pdo->prepare("UPDATE users SET saldo_rp = saldo_rp + ? WHERE id=?")->execute([$w['amount'], $w['user_id']]);
            $msg = 'Penarikan ditolak, saldo dikembalikan.';
        }
    } elseif ($act === 'update_price') {
        $newPrice = (float)$_POST['price']; $pdo->prepare("UPDATE settings SET v=? WHERE k='harga_emas'")->execute([$newPrice]); $msg = 'Harga emas diupdate!';
    } elseif ($act === 'update_qris') {
        $newQris = trim($_POST['qris_url']);
        if (filter_var($newQris, FILTER_VALIDATE_URL)) { $pdo->prepare("UPDATE settings SET v=? WHERE k='qris_url'")->execute([$newQris]); $msg = 'URL QRIS diupdate!'; } else { $msg = 'URL QRIS tidak valid!'; }
    } elseif ($act === 'broadcast') {
        $title = trim($_POST['title']); $content = trim($_POST['content']); $image = null;
        if (isset($_FILES['image']) && $_FILES['image']['error'] === 0) {
            $ext = pathinfo($_FILES['image']['name'], PATHINFO_EXTENSION); $fname = 'bc_' . time() . '.' . $ext;
            move_uploaded_file($_FILES['image']['tmp_name'], __DIR__ . '/../uploads/' . $fname); $image = '/uploads/' . $fname;
        }
        $pdo->prepare("INSERT INTO broadcasts (title, content, image_url) VALUES (?,?,?)")->execute([$title, $content, $image]); $msg = 'Broadcast terkirim!';
    } elseif ($act === 'add_rp') {
        $uid = (int)$_POST['uid']; $amount = (float)$_POST['amount']; $pdo->prepare("UPDATE users SET saldo_rp = saldo_rp + ? WHERE id=?")->execute([$amount, $uid]); $msg = "Berhasil menambah Rp " . number_format($amount,0,',','.') . " ke user.";
    } elseif ($act === 'cut_rp') {
        $uid = (int)$_POST['uid']; $amount = (float)$_POST['amount']; $pdo->prepare("UPDATE users SET saldo_rp = GREATEST(0, saldo_rp - ?) WHERE id=?")->execute([$amount, $uid]); $msg = "Berhasil memotong Rp " . number_format($amount,0,',','.') . " dari user.";
    } elseif ($act === 'add_gram') {
        $uid = (int)$_POST['uid']; $amount = (float)$_POST['amount']; $pdo->prepare("UPDATE users SET saldo_gram = saldo_gram + ? WHERE id=?")->execute([$amount, $uid]); $msg = "Berhasil menambah " . number_format($amount,4) . " gr emas ke user.";
    } elseif ($act === 'cut_gram') {
        $uid = (int)$_POST['uid']; $amount = (float)$_POST['amount']; $pdo->prepare("UPDATE users SET saldo_gram = GREATEST(0, saldo_gram - ?) WHERE id=?")->execute([$amount, $uid]); $msg = "Berhasil memotong " . number_format($amount,4) . " gr emas dari user.";
    } elseif ($act === 'ban_user') {
        $uid = (int)$_POST['uid']; $pdo->prepare("UPDATE users SET status='banned' WHERE id=? AND role='user'")->execute([$uid]); $msg = 'User dibanned!';
    } elseif ($act === 'unban_user') {
        $uid = (int)$_POST['uid']; $pdo->prepare("UPDATE users SET status='active' WHERE id=? AND role='user'")->execute([$uid]); $msg = 'User diaktifkan!';
    } elseif ($act === 'delete_user') {
        $uid = (int)$_POST['uid']; $pdo->prepare("DELETE FROM users WHERE id=? AND role='user'")->execute([$uid]); $msg = 'User dihapus permanen!';
    }
}

$deps = $pdo->query("SELECT d.*, u.username FROM deposits d JOIN users u ON d.user_id=u.id WHERE d.status='pending' ORDER BY d.id DESC")->fetchAll();
$wds = $pdo->query("SELECT w.*, u.username FROM withdrawals w JOIN users u ON w.user_id=u.id WHERE w.status='pending' ORDER BY w.id DESC")->fetchAll();
$users = $pdo->query("SELECT * FROM users WHERE role='user' ORDER BY id DESC")->fetchAll();
$price = getSetting($pdo, 'harga_emas', 1350000);
$qris = getSetting($pdo, 'qris_url');
$totalUsers = count($users);
?>
<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8"><title>Admin Panel</title>
<link rel="stylesheet" href="/assets/css/style.css">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
</head>
<body style="padding-bottom:20px">
<nav class="navbar" style="background:#0a0a0f">
    <div class="nav-inner" style="max-width:1000px">
        <a href="/x-panel-core/" class="logo"><i class="fas fa-shield-alt"></i> ADMIN GOLD</a>
        <div><a href="/" target="_blank" style="color:var(--text-muted); margin-right:15px">Lihat Web</a><a href="/logout.php" style="color:var(--danger);font-size:0.9em">Logout</a></div>
    </div>
</nav>
<div class="container" style="max-width:1000px">
    <?php if ($msg): ?><div class="alert alert-success"><?= $msg ?></div><?php endif; ?>

    <div class="grid-2" style="margin-bottom:20px">
        <div class="card" style="text-align:center"><h3 style="color:var(--text-muted)">Total User</h3><div style="font-size:2em;font-weight:800;color:var(--primary)"><?= $totalUsers ?></div></div>
        <div class="card" style="text-align:center"><h3 style="color:var(--text-muted)">Harga Emas</h3><div style="font-size:1.5em;font-weight:800;color:var(--success)">Rp <?= number_format((float)$price,0,',','.') ?></div></div>
    </div>

    <div class="tabs">
        <button class="tab-btn active" onclick="showTab('tab-deps')">Deposit</button>
        <button class="tab-btn" onclick="showTab('tab-wds')">Penarikan</button>
        <button class="tab-btn" onclick="showTab('tab-users')">Kelola User</button>
        <button class="tab-btn" onclick="showTab('tab-settings')">Pengaturan</button>
        <button class="tab-btn" onclick="showTab('tab-bc')">Broadcast</button>
    </div>

    <div id="tab-deps" class="tab-content active card">
        <h3 style="color:var(--primary);margin-bottom:15px">Deposit Pending</h3>
        <?php if (empty($deps)): ?><p style="color:var(--text-muted)">Tidak ada deposit pending.</p><?php else: foreach ($deps as $d): ?>
            <div class="user-card" style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px">
                <div><b>@<?= $d['username'] ?></b><br><span style="color:var(--success);font-size:1.1em;font-weight:800">Rp <?= number_format($d['amount'],0,',','.') ?></span><br><small><?= date('d/m H:i', strtotime($d['created_at'])) ?></small><br><a href="/uploads/<?= $d['proof'] ?>" target="_blank" class="btn btn-sm btn-outline" style="margin-top:5px"><i class="fas fa-image"></i> Bukti</a></div>
                <form method="POST" style="display:flex;gap:5px"><input type="hidden" name="id" value="<?= $d['id'] ?>"><button name="action" value="approve_dep" class="btn btn-sm" style="background:var(--success);color:#fff">Approve</button><button name="action" value="reject_dep" class="btn btn-sm" style="background:var(--danger);color:#fff">Reject</button></form>
            </div>
        <?php endforeach; endif; ?>
    </div>

    <div id="tab-wds" class="tab-content card">
        <h3 style="color:var(--primary);margin-bottom:15px">Penarikan Pending</h3>
        <?php if (empty($wds)): ?><p style="color:var(--text-muted)">Tidak ada penarikan pending.</p><?php else: foreach ($wds as $w): ?>
            <div class="user-card" style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px">
                <div><b>@<?= $w['username'] ?></b><br><span style="color:var(--danger);font-size:1.1em;font-weight:800">Rp <?= number_format($w['amount'],0,',','.') ?></span><br><small><b><?= $w['method'] ?></b> - <?= $w['account_no'] ?> (<?= $w['account_name'] ?>)</small></div>
                <form method="POST" style="display:flex;gap:5px"><input type="hidden" name="id" value="<?= $w['id'] ?>"><button name="action" value="approve_wd" class="btn btn-sm" style="background:var(--success);color:#fff">Approve</button><button name="action" value="reject_wd" class="btn btn-sm" style="background:var(--danger);color:#fff">Reject</button></form>
            </div>
        <?php endforeach; endif; ?>
    </div>

    <div id="tab-users" class="tab-content card">
        <h3 style="color:var(--primary);margin-bottom:15px">Kelola User</h3>
        <?php foreach ($users as $u): ?>
            <div class="user-card">
                <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap">
                    <div><b>@<?= htmlspecialchars($u['username']) ?></b> <span style="color:var(--text-muted);font-size:0.85em">(<?= htmlspecialchars($u['email']) ?>)</span> <span class="badge" style="background:<?= $u['status']=='banned'?'rgba(239,68,68,0.2)':'rgba(16,185,129,0.2)' ?>;color:<?= $u['status']=='banned'?'var(--danger)':'var(--success)' ?>;margin-left:5px"><?= $u['status'] ?></span></div>
                    <form method="POST" style="margin:0"><input type="hidden" name="uid" value="<?= $u['id'] ?>">
                        <?php if($u['status']=='active'): ?><button name="action" value="ban_user" class="btn btn-sm" style="background:var(--danger);color:#fff;border-radius:8px" onclick="return confirm('Ban user ini?')">Ban</button>
                        <?php else: ?><button name="action" value="unban_user" class="btn btn-sm" style="background:var(--success);color:#fff;border-radius:8px">Unban</button><?php endif; ?>
                        <button name="action" value="delete_user" class="btn btn-sm" style="background:#333;color:#fff;border-radius:8px" onclick="return confirm('Hapus permanen?')"><i class="fas fa-trash"></i></button>
                    </form>
                </div>
                <div style="margin-top:8px;font-size:0.9em">Saldo Rp: <b style="color:var(--success)"><?= number_format($u['saldo_rp'],0,',','.') ?></b> | Saldo Emas: <b style="color:var(--primary)"><?= number_format($u['saldo_gram'],4) ?> gr</b></div>
                <div class="action-forms">
                    <form method="POST" class="mini-form"><input type="hidden" name="uid" value="<?= $u['id'] ?>"><input type="number" name="amount" placeholder="Rp" required><button name="action" value="add_rp" style="background:var(--success);color:#fff">+Rp</button></form>
                    <form method="POST" class="mini-form"><input type="hidden" name="uid" value="<?= $u['id'] ?>"><input type="number" name="amount" placeholder="Rp" required><button name="action" value="cut_rp" style="background:var(--danger);color:#fff">-Rp</button></form>
                    <form method="POST" class="mini-form"><input type="hidden" name="uid" value="<?= $u['id'] ?>"><input type="number" name="amount" step="0.01" placeholder="Gr" required><button name="action" value="add_gram" style="background:var(--primary);color:#000">+Gr</button></form>
                    <form method="POST" class="mini-form"><input type="hidden" name="uid" value="<?= $u['id'] ?>"><input type="number" name="amount" step="0.01" placeholder="Gr" required><button name="action" value="cut_gram" style="background:#d97706;color:#fff">-Gr</button></form>
                </div>
            </div>
        <?php endforeach; ?>
    </div>

    <div id="tab-settings" class="tab-content card">
        <h3 style="color:var(--primary);margin-bottom:15px">Update Harga Emas</h3>
        <form method="POST" style="display:flex;gap:10px;align-items:flex-end;margin-bottom:30px"><div class="form-group" style="flex:1;margin:0"><label>Harga / Gram</label><input type="number" name="price" value="<?= $price ?>" required></div><button name="action" value="update_price" class="btn btn-primary">Simpan Harga</button></form>
        <h3 style="color:var(--primary);margin-bottom:15px">Update Gambar QRIS</h3>
        <div style="display:flex;gap:20px;flex-wrap:wrap">
            <div style="flex:1;min-width:200px"><img src="<?= htmlspecialchars($qris) ?>" style="width:100%;max-width:200px;border-radius:10px;background:#fff;padding:5px"><p style="font-size:0.8em;color:var(--text-muted);margin-top:5px">Preview QRIS saat ini</p></div>
            <div style="flex:2;min-width:250px"><form method="POST"><div class="form-group"><label>URL Gambar QRIS Baru</label><input type="url" name="qris_url" placeholder="https://files.catbox.moe/xxx.jpg" required></div><button name="action" value="update_qris" class="btn btn-primary">Update QRIS</button></form></div>
        </div>
    </div>

    <div id="tab-bc" class="tab-content card">
        <h3 style="color:var(--primary);margin-bottom:15px">Kirim Broadcast / Berita</h3>
        <form method="POST" enctype="multipart/form-data">
            <div class="form-group"><label>Judul</label><input type="text" name="title" required></div>
            <div class="form-group"><label>Isi Teks</label><textarea name="content" rows="4" style="width:100%;padding:12px;border-radius:12px;background:var(--bg);border:1px solid var(--border);color:var(--text);font-family:inherit" required></textarea></div>
            <div class="form-group"><label>Gambar (Opsional)</label><input type="file" name="image" accept="image/*"></div>
            <button name="action" value="broadcast" class="btn btn-primary btn-block">Kirim Broadcast</button>
        </form>
    </div>
</div>
<script>
function showTab(id) {
    document.querySelectorAll('.tab-content').forEach(el => el.classList.remove('active'));
    document.querySelectorAll('.tab-btn').forEach(el => el.classList.remove('active'));
    document.getElementById(id).classList.add('active');
    event.target.classList.add('active');
}
</script>
</body>
</html>
PHPEOF

# ============ NGINX ============
cat > "$NGINX_CONF" << NGINXEOF
server {
    listen 80;
    listen [::]:80;
    server_name $SUBDOMAIN;
    root $WEB_ROOT;
    index index.php index.html;
    client_max_body_size 10M;

    location / { try_files \$uri \$uri/ =404; }
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
    }
}
NGINXEOF

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/ 2>/dev/null
[[ -f /etc/nginx/sites-enabled/default ]] && rm -f /etc/nginx/sites-enabled/default

nginx -t >/dev/null 2>&1 && systemctl reload nginx || { nginx -t; exit 1; }

chown -R www-data:www-data "$WEB_ROOT"
chmod -R 755 "$WEB_ROOT"
chmod -R 775 "$WEB_ROOT/uploads"
systemctl restart php8.3-fpm

# ============ SSL ============
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
echo -e "${GREEN}║  ✅ TREASURY GOLD BERHASIL DI-INSTALL!     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🔗 URL Publik:${NC} $PROTO://$SUBDOMAIN"
echo -e "${MAGENTA}🔒 Admin Panel:${NC} $PROTO://$SUBDOMAIN/x-panel-core"
echo -e "  User : admin"
echo -e "  Pass : $ADMIN_PASS"
echo ""
echo -e "${GREEN}🎉 Selesai! Buka webnya sekarang.${NC}"
