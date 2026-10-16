#!/bin/bash
# ============================================
#   📱 RENDZZ NOKOS v5.0 — TELEGRAM NOTIF
#   User Jual Nomor • Admin Approve • Bot TG
# ============================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

[[ $EUID -ne 0 ]] && { echo -e "${RED}Harus root!${NC}"; exit 1; }

clear
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  📱 RENDZZ NOKOS v5.0 — FINAL            ║${NC}"
echo -e "${CYAN}║  + Telegram Bot Integration              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

read -p "👉 Subdomain: " SUBDOMAIN
[[ -z "$SUBDOMAIN" ]] && { echo -e "${RED}Kosong!${NC}"; exit 1; }

read -p "👉 Email SSL: " EMAIL
[[ -z "$EMAIL" ]] && EMAIL="admin@$SUBDOMAIN"

read -p "👉 Username admin [admin]: " ADMIN_USER
ADMIN_USER=${ADMIN_USER:-admin}

read -s -p "👉 Password admin [123456]: " ADMIN_PASS
echo ""
ADMIN_PASS=${ADMIN_PASS:-123456}

read -p "👉 Email admin [$ADMIN_USER@$SUBDOMAIN]: " ADMIN_EMAIL
ADMIN_EMAIL=${ADMIN_EMAIL:-$ADMIN_USER@$SUBDOMAIN}

read -p "👉 Nomor Dana admin [08xxx]: " DANA_ADMIN
read -p "👉 Nama Dana admin [$ADMIN_USER]: " DANA_NAME
DANA_NAME=${DANA_NAME:-$ADMIN_USER}

read -p "👉 Telegram Bot Token (dari @BotFather) [kosong=skip]: " BOT_TOKEN
read -p "👉 Telegram Bot Username (contoh: shellnumberwsbot) [kosong=skip]: " BOT_USERNAME

BANNER_URL="https://files.catbox.moe/mj5tmf.jpg"
TELEGRAM_BOT_BASE="https://t.me"

DB_PASS=$(openssl rand -hex 12)
DB_NAME="nokos_$(echo $SUBDOMAIN | tr '.' '_' | cut -c1-15)"
WEB_ROOT="/var/www/$SUBDOMAIN"
NGINX_CONF="/etc/nginx/sites-available/$SUBDOMAIN"

echo ""
read -p "Lanjut? (y/n): " C
[[ "$C" != "y" && "$C" != "Y" ]] && exit 0

# ============ STEP 1: PACKAGES ============
echo ""
echo -e "${CYAN}[1/8] Install packages...${NC}"
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
    systemctl enable mysql >/dev/null 2>&1
    systemctl start mysql >/dev/null 2>&1
    sleep 5
fi

for i in {1..15}; do
    [[ -S /var/run/mysqld/mysqld.sock ]] && break
    sleep 1
done

systemctl is-active --quiet mysql && echo -e "${GREEN}  ✓ MySQL OK${NC}" || { echo -e "${RED}  ✗ MySQL gagal!${NC}"; exit 1; }

# ============ STEP 2: DATABASE ============
echo -e "${CYAN}[2/8] Database...${NC}"
mysql -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;" 2>/dev/null
mysql -e "CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS 'webuser'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO 'webuser'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

mysql "$DB_NAME" << 'SQLEOF'
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role ENUM('admin','user') DEFAULT 'user',
    status ENUM('active','banned') DEFAULT 'active',
    saldo INT DEFAULT 0,
    total_income INT DEFAULT 0,
    total_submit INT DEFAULT 0,
    total_approved INT DEFAULT 0,
    total_rejected INT DEFAULT 0,
    ref_code VARCHAR(20) UNIQUE NOT NULL,
    ref_by INT DEFAULT NULL,
    ref_earning INT DEFAULT 0,
    tos_agreed_at DATETIME DEFAULT NULL,
    tg_token VARCHAR(64) DEFAULT NULL,
    tg_chat_id VARCHAR(32) DEFAULT NULL,
    tg_username VARCHAR(64) DEFAULT NULL,
    tg_connected_at DATETIME DEFAULT NULL,
    last_login DATETIME DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE submissions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    sub_code VARCHAR(20) UNIQUE NOT NULL,
    tipe ENUM('limit','nonlimit') NOT NULL,
    negara VARCHAR(50) NOT NULL,
    nomor VARCHAR(30) NOT NULL,
    harga INT NOT NULL,
    status ENUM('pending','approved','rejected') DEFAULT 'pending',
    admin_note TEXT DEFAULT NULL,
    approved_by INT DEFAULT NULL,
    approved_at DATETIME DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE store (
    id INT AUTO_INCREMENT PRIMARY KEY,
    submission_id INT,
    seller_id INT,
    nomor VARCHAR(30) NOT NULL,
    negara VARCHAR(50),
    tipe ENUM('limit','nonlimit'),
    harga_beli INT,
    status ENUM('available','sold') DEFAULT 'available',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    sold_at DATETIME DEFAULT NULL
);

CREATE TABLE withdrawals (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    amount INT NOT NULL,
    dana_number VARCHAR(20) NOT NULL,
    dana_name VARCHAR(100) NOT NULL,
    status ENUM('pending','approved','rejected') DEFAULT 'pending',
    admin_note TEXT DEFAULT NULL,
    processed_by INT DEFAULT NULL,
    processed_at DATETIME DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE activity_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    action VARCHAR(255),
    ip VARCHAR(45),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE settings (
    k VARCHAR(50) PRIMARY KEY,
    v TEXT
);

INSERT INTO settings VALUES
('dana_admin', 'DANA_ADMIN_PLACEHOLDER'),
('dana_name', 'DANA_NAME_PLACEHOLDER'),
('harga_limit', '1000'),
('harga_nonlimit_min', '1000'),
('harga_nonlimit_max', '5000'),
('min_withdraw', '1000'),
('komisi_referral', '250'),
('banner_url', 'BANNER_PLACEHOLDER'),
('tg_bot_token', 'TG_TOKEN_PLACEHOLDER'),
('tg_bot_username', 'TG_USERNAME_PLACEHOLDER');
SQLEOF

mysql "$DB_NAME" -e "UPDATE settings SET v='$DANA_ADMIN' WHERE k='dana_admin';"
mysql "$DB_NAME" -e "UPDATE settings SET v='$DANA_NAME' WHERE k='dana_name';"
mysql "$DB_NAME" -e "UPDATE settings SET v='$BANNER_URL' WHERE k='banner_url';"
mysql "$DB_NAME" -e "UPDATE settings SET v='$BOT_TOKEN' WHERE k='tg_bot_token';"
mysql "$DB_NAME" -e "UPDATE settings SET v='$BOT_USERNAME' WHERE k='tg_bot_username';"

ADMIN_HASH=$(php -r "echo password_hash('$ADMIN_PASS', PASSWORD_BCRYPT);")
ADMIN_REF="ADMIN"$(openssl rand -hex 3 | tr 'a-f' 'A-F')
mysql "$DB_NAME" -e "INSERT INTO users (username, email, password, role, ref_code, tos_agreed_at) VALUES ('$ADMIN_USER', '$ADMIN_EMAIL', '$ADMIN_HASH', 'admin', '$ADMIN_REF', NOW());"
echo -e "${GREEN}  ✓ Database OK${NC}"

# ============ STEP 3: FOLDER ============
echo -e "${CYAN}[3/8] Folder...${NC}"
[[ -d "$WEB_ROOT" ]] && mv "$WEB_ROOT" "/var/www/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$WEB_ROOT"/{admin,user,includes,assets/{css,js},uploads}
echo -e "${GREEN}  ✓ Folder OK${NC}"

# ============ STEP 4: CONFIG + TELEGRAM HELPER ============
echo -e "${CYAN}[4/8] Config...${NC}"
cat > "$WEB_ROOT/includes/config.php" << PHPEOF
<?php
session_start();
date_default_timezone_set('Asia/Jakarta');

define('DB_HOST', 'localhost');
define('DB_NAME', '$DB_NAME');
define('DB_USER', 'webuser');
define('DB_PASS', '$DB_PASS');
define('SITE_URL', 'https://$SUBDOMAIN');
define('SITE_NAME', 'Rendzz Nokos');
define('MIN_WITHDRAW', 1000);
define('BANNER_URL', '$BANNER_URL');
define('TG_BOT_BASE', '$TELEGRAM_BOT_BASE');

try {
    \$pdo = new PDO("mysql:host=".DB_HOST.";dbname=".DB_NAME.";charset=utf8mb4", DB_USER, DB_PASS, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
} catch (PDOException \$e) { die("DB Error: " . \$e->getMessage()); }

function isLoggedIn() { return isset(\$_SESSION['user_id']); }
function isAdmin() { return isLoggedIn() && \$_SESSION['role'] === 'admin'; }
function requireLogin() { if (!isLoggedIn()) { header('Location: /login.php'); exit; } }
function requireAdmin() { if (!isAdmin()) { header('Location: /user/'); exit; } }
function csrf() { if (empty(\$_SESSION['csrf'])) \$_SESSION['csrf'] = bin2hex(random_bytes(32)); return \$_SESSION['csrf']; }
function checkCsrf(\$t) { return isset(\$_SESSION['csrf']) && hash_equals(\$_SESSION['csrf'], \$t); }

function logAct(\$pdo, \$uid, \$action) {
    \$s = \$pdo->prepare("INSERT INTO activity_log (user_id, action, ip) VALUES (?,?,?)");
    \$s->execute([\$uid, \$action, \$_SERVER['REMOTE_ADDR'] ?? '']);
}

function getSetting(\$pdo, \$k, \$default = '') {
    \$s = \$pdo->prepare("SELECT v FROM settings WHERE k=?"); \$s->execute([\$k]);
    \$r = \$s->fetch(); return \$r ? \$r['v'] : \$default;
}

function rupiah(\$n) { return 'Rp ' . number_format((int)\$n, 0, ',', '.'); }

function hitungHargaBeli(\$pdo, \$tipe) {
    if (\$tipe === 'limit') return (int)getSetting(\$pdo, 'harga_limit', 1000);
    \$min = (int)getSetting(\$pdo, 'harga_nonlimit_min', 1000);
    \$max = (int)getSetting(\$pdo, 'harga_nonlimit_max', 5000);
    return rand(\$min, \$max);
}

function payUserAndReferral(\$pdo, \$userId, \$harga, \$subCode) {
    \$pdo->prepare("UPDATE users SET saldo=saldo+?, total_income=total_income+?, total_approved=total_approved+1 WHERE id=?")
        ->execute([\$harga, \$harga, \$userId]);
    logAct(\$pdo, \$userId, "Setoran \$subCode disetujui, dapat " . rupiah(\$harga));

    \$s = \$pdo->prepare("SELECT ref_by FROM users WHERE id=?"); \$s->execute([\$userId]);
    \$u = \$s->fetch();
    if (\$u && \$u['ref_by']) {
        \$komisi = (int)getSetting(\$pdo, 'komisi_referral', 250);
        \$pdo->prepare("UPDATE users SET saldo=saldo+?, total_income=total_income+?, ref_earning=ref_earning+? WHERE id=?")
            ->execute([\$komisi, \$komisi, \$komisi, \$u['ref_by']]);
        logAct(\$pdo, \$u['ref_by'], "Komisi referral " . rupiah(\$komisi) . " dari \$subCode");
    }
}

function validPhone(\$nomor) {
    \$n = preg_replace('/\D/', '', \$nomor);
    return strlen(\$n) >= 9 && strlen(\$n) <= 15;
}

// ============ TELEGRAM HELPER ============
function tgSendMessage(\$pdo, \$chatId, \$text, \$opts = []) {
    if (!\$chatId) return false;
    \$token = getSetting(\$pdo, 'tg_bot_token', '');
    if (!\$token) return false;

    \$url = "https://api.telegram.org/bot\$token/sendMessage";
    \$payload = array_merge([
        'chat_id' => \$chatId,
        'text' => \$text,
        'parse_mode' => 'HTML',
        'disable_web_page_preview' => true,
    ], \$opts);

    \$ch = curl_init(\$url);
    curl_setopt_array(\$ch, [
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 15,
        CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
        CURLOPT_POSTFIELDS => json_encode(\$payload),
        CURLOPT_SSL_VERIFYPEER => false,
    ]);
    \$res = curl_exec(\$ch);
    curl_close(\$ch);
    return \$res;
}

function tgGetBotUsername(\$pdo) {
    \$u = getSetting(\$pdo, 'tg_bot_username', '');
    return ltrim(\$u, '@');
}

function tgGetConnectLink(\$pdo, \$token) {
    \$username = tgGetBotUsername(\$pdo);
    if (!\$username) return null;
    return TG_BOT_BASE . '/' . \$username . '?start=' . urlencode(\$token);
}

// Generate token untuk user (untuk connect TG)
function tgGenerateToken(\$pdo, \$userId) {
    \$token = bin2hex(random_bytes(16));
    \$pdo->prepare("UPDATE users SET tg_token=? WHERE id=?")->execute([\$token, \$userId]);
    return \$token;
}

// Notifikasi: Withdraw baru diajukan
function tgNotifyWithdrawRequest(\$pdo, \$userId, \$amount, \$wdId) {
    \$s = \$pdo->prepare("SELECT * FROM users WHERE id=?"); \$s->execute([\$userId]);
    \$u = \$s->fetch();
    if (!\$u || !\$u['tg_chat_id']) return;

    \$msg = "<b>💸 Withdraw Diajukan</b>\n\n"
         . "📋 ID: <code>#" . \$wdId . "</code>\n"
         . "💰 Jumlah: <b>" . rupiah(\$amount) . "</b>\n"
         . "🏦 Tujuan: <b>Dana</b>\n\n"
         . "⏳ Status: <b>Menunggu approve admin</b>\n"
         . "Kamu akan dapat notifikasi lagi saat diproses.";

    tgSendMessage(\$pdo, \$u['tg_chat_id'], \$msg);
}

// Notifikasi: Withdraw di-approve
function tgNotifyWithdrawApproved(\$pdo, \$userId, \$amount, \$wdId) {
    \$s = \$pdo->prepare("SELECT * FROM users WHERE id=?"); \$s->execute([\$userId]);
    \$u = \$s->fetch();
    if (!\$u || !\$u['tg_chat_id']) return;

    \$msg = "<b>✅ Withdraw DISETUJUI!</b>\n\n"
         . "📋 ID: <code>#" . \$wdId . "</code>\n"
         . "💰 Jumlah: <b>" . rupiah(\$amount) . "</b>\n"
         . "🏦 Tujuan: <b>Dana</b>\n\n"
         . "🎉 Uang akan segera masuk ke akun Dana kamu!\n"
         . "Terima kasih sudah pakai " . SITE_NAME;

    tgSendMessage(\$pdo, \$u['tg_chat_id'], \$msg);
}

// Notifikasi: Withdraw di-reject
function tgNotifyWithdrawRejected(\$pdo, \$userId, \$amount, \$wdId, \$reason = '') {
    \$s = \$pdo->prepare("SELECT * FROM users WHERE id=?"); \$s->execute([\$userId]);
    \$u = \$s->fetch();
    if (!\$u || !\$u['tg_chat_id']) return;

    \$msg = "<b>❌ Withdraw DITOLAK</b>\n\n"
         . "📋 ID: <code>#" . \$wdId . "</code>\n"
         . "💰 Jumlah: <b>" . rupiah(\$amount) . "</b>\n"
         . "🏦 Tujuan: <b>Dana</b>\n\n"
         . (\$reason ? "📝 Alasan: <i>" . htmlspecialchars(\$reason) . "</i>\n\n" : "")
         . "💵 Saldo <b>dikembalikan</b> ke akun kamu.";

    tgSendMessage(\$pdo, \$u['tg_chat_id'], \$msg);
}

// Notifikasi: Setoran diapprove (saldo masuk)
function tgNotifySubmissionApproved(\$pdo, \$userId, \$nomor, \$harga, \$subCode) {
    \$s = \$pdo->prepare("SELECT * FROM users WHERE id=?"); \$s->execute([\$userId]);
    \$u = \$s->fetch();
    if (!\$u || !\$u['tg_chat_id']) return;

    \$msg = "<b>🎉 Setoran DISETUJUI!</b>\n\n"
         . "📋 Kode: <code>" . \$subCode . "</code>\n"
         . "📱 Nomor: <code>" . \$nomor . "</code>\n"
         . "💰 Bayaran: <b>" . rupiah(\$harga) . "</b>\n\n"
         . "✅ Saldo sudah masuk ke akun kamu!\n"
         . "Cek dashboard untuk withdraw.";

    tgSendMessage(\$pdo, \$u['tg_chat_id'], \$msg);
}

// Notifikasi: Setoran direject
function tgNotifySubmissionRejected(\$pdo, \$userId, \$nomor, \$subCode, \$reason = '') {
    \$s = \$pdo->prepare("SELECT * FROM users WHERE id=?"); \$s->execute([\$userId]);
    \$u = \$s->fetch();
    if (!\$u || !\$u['tg_chat_id']) return;

    \$msg = "<b>❌ Setoran DITOLAK</b>\n\n"
         . "📋 Kode: <code>" . \$subCode . "</code>\n"
         . "📱 Nomor: <code>" . \$nomor . "</code>\n\n"
         . (\$reason ? "📝 Alasan: <i>" . htmlspecialchars(\$reason) . "</i>\n\n" : "")
         . "Silakan coba setor nomor lain.";

    tgSendMessage(\$pdo, \$u['tg_chat_id'], \$msg);
}

// Notifikasi: Komisi referral masuk
function tgNotifyReferralBonus(\$pdo, \$uplineId, \$amount, \$fromUsername) {
    \$s = \$pdo->prepare("SELECT * FROM users WHERE id=?"); \$s->execute([\$uplineId]);
    \$u = \$s->fetch();
    if (!\$u || !\$u['tg_chat_id']) return;

    \$msg = "<b>💎 Komisi Referral!</b>\n\n"
         . "👤 Dari: <b>" . htmlspecialchars(\$fromUsername) . "</b>\n"
         . "💰 Komisi: <b>" . rupiah(\$amount) . "</b>\n\n"
         . "✅ Saldo sudah masuk ke akun kamu!";

    tgSendMessage(\$pdo, \$u['tg_chat_id'], \$msg);
}
PHPEOF
echo -e "${GREEN}  ✓ Config + TG helper OK${NC}"

# ============ STEP 5: LAYOUT ============
echo -e "${CYAN}[5/8] Layout...${NC}"

cat > "$WEB_ROOT/includes/header.php" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="id" data-theme="dark">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="theme-color" content="#0a0a1a">
<title><?= $pageTitle ?? 'Home' ?> — <?= SITE_NAME ?></title>
<link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>💰</text></svg>">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Space+Grotesk:wght@500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
<link rel="stylesheet" href="/assets/css/style.css">
</head>
<body>
HTMLEOF

cat > "$WEB_ROOT/includes/navbar.php" << 'HTMLEOF'
<nav class="navbar">
    <a href="/" class="logo">
        <span class="logo-icon">💰</span>
        <span class="logo-text">Rendzz<span class="logo-accent">Nokos</span></span>
    </a>
    <div class="nav-menu">
        <a href="/"><i class="fas fa-house"></i> Home</a>
        <?php if (isLoggedIn()): ?>
            <a href="/user/"><i class="fas fa-gauge-high"></i> Dashboard</a>
            <a href="/user/setor.php"><i class="fas fa-plus-circle"></i> Setor Nomor</a>
            <a href="/user/riwayat.php"><i class="fas fa-clock-rotate-left"></i> Riwayat</a>
            <a href="/user/referral.php"><i class="fas fa-user-group"></i> Referral</a>
            <?php if (isAdmin()): ?><a href="/admin/"><i class="fas fa-shield-halved"></i> Admin</a><?php endif; ?>
        <?php endif; ?>
        <button id="themeToggle" class="icon-btn" aria-label="Theme"><i class="fas fa-sun"></i></button>
        <?php if (isLoggedIn()): ?>
            <a href="/logout.php" class="btn btn-outline" title="Logout"><i class="fas fa-arrow-right-from-bracket"></i></a>
        <?php else: ?>
            <a href="/login.php" class="btn btn-primary"><i class="fas fa-arrow-right-to-bracket"></i> Login</a>
        <?php endif; ?>
    </div>
</nav>
HTMLEOF

cat > "$WEB_ROOT/includes/footer.php" << 'HTMLEOF'
<div class="bottom-nav">
    <a href="/user/" class="bn-item"><i class="fas fa-gauge-high"></i><span>Home</span></a>
    <a href="/user/setor.php" class="bn-item"><i class="fas fa-plus-circle"></i><span>Setor</span></a>
    <a href="/user/riwayat.php" class="bn-item"><i class="fas fa-clock-rotate-left"></i><span>Riwayat</span></a>
    <a href="/user/withdraw.php" class="bn-item"><i class="fas fa-money-bill-transfer"></i><span>WD</span></a>
    <a href="/user/profile.php" class="bn-item"><i class="fas fa-user"></i><span>Profil</span></a>
</div>

<footer class="footer">
    <div class="footer-content">
        <div class="footer-brand"><span class="logo-icon">💰</span> <span>Rendzz Nokos</span></div>
        <p>© <?= date('Y') ?> <?= SITE_NAME ?>. Jual nomor kosong — bayaran instan!</p>
        <div class="footer-links">
            <a href="/terms.php">Syarat & Ketentuan</a>
            <a href="/faq.php">FAQ</a>
        </div>
    </div>
</footer>
<script src="/assets/js/main.js"></script>
</body>
</html>
HTMLEOF

echo -e "${GREEN}  ✓ Layout OK${NC}"

# ============ STEP 6: HOME ============
cat > "$WEB_ROOT/index.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
$pageTitle = 'Jual Nomor Kosong';

$totalUsers = (int)$pdo->query("SELECT COUNT(*) FROM users WHERE status='active'")->fetchColumn();
$totalSub = (int)$pdo->query("SELECT COUNT(*) FROM submissions WHERE status='approved'")->fetchColumn();
$totalPaid = (int)$pdo->query("SELECT COALESCE(SUM(total_income),0) FROM users")->fetchColumn();

$hargaLimit = (int)getSetting($pdo, 'harga_limit', 1000);
$hargaMin = (int)getSetting($pdo, 'harga_nonlimit_min', 1000);
$hargaMax = (int)getSetting($pdo, 'harga_nonlimit_max', 5000);
$komisiRef = (int)getSetting($pdo, 'komisi_referral', 250);
$tgUser = tgGetBotUsername($pdo);

$top = $pdo->query("SELECT username, total_income FROM users WHERE status='active' ORDER BY total_income DESC LIMIT 10")->fetchAll();

include __DIR__ . '/includes/header.php';
include __DIR__ . '/includes/navbar.php';
?>
<section class="hero">
    <div class="hero-bg"></div>
    <div class="hero-content">
        <div class="hero-badge"><i class="fas fa-fire"></i> Bayaran Instan • Minimal Rp 1.000</div>
        <h1>
            <span class="gradient-text">Jual Nomor Kosong</span>
            <span class="hero-line">Dapat Uang, Cair ke Dana! 💸</span>
        </h1>
        <p class="hero-sub">
            Punya nomor kosong nganggur? <b>Setor sekarang</b> — dapat <b>Rp 1.000 - Rp 5.000</b> per nomor.
            Admin approve langsung, saldo masuk, withdraw ke Dana min Rp 1.000. <b>GRATIS, tanpa modal!</b>
        </p>
        <div class="hero-actions">
            <?php if (isLoggedIn()): ?>
                <a href="/user/setor.php" class="btn btn-primary btn-lg pulse-btn"><i class="fas fa-plus-circle"></i> Setor Nomor</a>
                <a href="/user/referral.php" class="btn btn-gold btn-lg"><i class="fas fa-user-group"></i> Ajak Teman (+<?= rupiah($komisiRef) ?>)</a>
            <?php else: ?>
                <a href="/register.php" class="btn btn-primary btn-lg pulse-btn"><i class="fas fa-rocket"></i> Daftar Gratis</a>
                <a href="/login.php" class="btn btn-outline btn-lg"><i class="fas fa-arrow-right-to-bracket"></i> Login</a>
            <?php endif; ?>
        </div>
        <div class="hero-stats">
            <div class="hs-item"><strong><?= number_format($totalUsers) ?>+</strong><span>User Aktif</span></div>
            <div class="hs-item"><strong><?= number_format($totalSub) ?>+</strong><span>Nomor Disetor</span></div>
            <div class="hs-item"><strong><?= rupiah($totalPaid) ?></strong><span>Total Dibayarkan</span></div>
        </div>
    </div>
</section>

<section class="banner-section">
    <div class="banner-card">
        <img src="<?= BANNER_URL ?>" alt="Banner Rendzz Nokos" class="banner-img" loading="lazy">
    </div>
</section>

<section class="section">
    <div class="section-head">
        <h2><i class="fas fa-fire"></i> Harga Setoran</h2>
        <p>Makin banyak setor, makin banyak cuan</p>
    </div>
    <div class="price-grid">
        <div class="price-card price-featured">
            <div class="pc-badge">RANDOM BONUS</div>
            <div class="pc-flag">👑</div>
            <h3>Nomor Non-Limit</h3>
            <p class="pc-desc">Tanpa batas waktu — harga random dari sistem</p>
            <div class="pc-price"><?= rupiah($hargaMin) ?> - <?= rupiah($hargaMax) ?></div>
            <ul class="pc-list">
                <li><i class="fas fa-check"></i> Semua negara</li>
                <li><i class="fas fa-check"></i> Harga random dari sistem</li>
                <li><i class="fas fa-check"></i> Bayaran instan setelah approve</li>
            </ul>
            <a href="/user/setor.php" class="btn btn-gold btn-block">Setor Sekarang</a>
        </div>

        <div class="price-card">
            <div class="pc-flag">🌍</div>
            <h3>Nomor Limit 24 Jam</h3>
            <p class="pc-desc">Berlaku semua negara</p>
            <div class="pc-price"><?= rupiah($hargaLimit) ?></div>
            <ul class="pc-list">
                <li><i class="fas fa-check"></i> Semua negara</li>
                <li><i class="fas fa-check"></i> Limit 24 jam</li>
                <li><i class="fas fa-check"></i> Harga fix</li>
            </ul>
            <a href="/user/setor.php" class="btn btn-primary btn-block">Setor Sekarang</a>
        </div>

        <div class="price-card">
            <div class="pc-flag">💰</div>
            <h3>Komisi Referral</h3>
            <p class="pc-desc">Ajak teman, dapat komisi tiap teman setor!</p>
            <div class="pc-price"><?= rupiah($komisiRef) ?></div>
            <ul class="pc-list">
                <li><i class="fas fa-check"></i> Per teman yang setor</li>
                <li><i class="fas fa-check"></i> Saldo langsung masuk</li>
                <li><i class="fas fa-check"></i> Tanpa batas</li>
            </ul>
            <a href="/user/referral.php" class="btn btn-primary btn-block">Ajak Teman</a>
        </div>
    </div>
</section>

<?php if ($tgUser): ?>
<section class="section">
    <div class="tg-promo-box">
        <div class="tg-promo-left">
            <i class="fab fa-telegram tg-promo-icon"></i>
        </div>
        <div class="tg-promo-right">
            <h3>📬 Notifikasi Telegram</h3>
            <p>Dapat notifikasi <b>real-time</b> saat setoran & withdraw kamu diproses admin — langsung via Telegram!</p>
            <a href="https://t.me/<?= htmlspecialchars($tgUser) ?>" class="btn btn-primary" target="_blank">
                <i class="fab fa-telegram"></i> Buka Bot Telegram
            </a>
        </div>
    </div>
</section>
<?php endif; ?>

<section class="section">
    <div class="section-head">
        <h2><i class="fas fa-trophy"></i> Top 10 Penjual</h2>
        <p>User paling banyak setor (realtime)</p>
    </div>
    <div class="top10-card">
        <?php if (empty($top)): ?>
            <p class="empty">Belum ada data — jadilah yang pertama! 🚀</p>
        <?php else: foreach ($top as $i => $u):
            $medal = ['🥇','🥈','🥉'][$i] ?? ('#' . ($i+1));
        ?>
            <div class="top10-item <?= $i<3?'top10-top':'' ?>">
                <div class="t10-rank"><?= $medal ?></div>
                <div class="t10-user"><strong><?= htmlspecialchars($u['username']) ?></strong></div>
                <div class="t10-income"><?= rupiah($u['total_income']) ?></div>
            </div>
        <?php endforeach; endif; ?>
    </div>
</section>

<section class="section">
    <div class="section-head">
        <h2><i class="fas fa-shield-halved"></i> Kenapa Pilih Kami?</h2>
    </div>
    <div class="features">
        <div class="feature-card">
            <div class="fc-icon" style="background:linear-gradient(135deg,#43e97b,#38f9d7)"><i class="fas fa-bolt"></i></div>
            <h3>Bayaran Instan</h3>
            <p>Admin approve → saldo langsung masuk</p>
        </div>
        <div class="feature-card">
            <div class="fc-icon" style="background:linear-gradient(135deg,#f093fb,#f5576c)"><i class="fas fa-hand-holding-dollar"></i></div>
            <h3>Harga Tinggi</h3>
            <p>Non-limit sampai Rp 5.000 per nomor!</p>
        </div>
        <div class="feature-card">
            <div class="fc-icon" style="background:linear-gradient(135deg,#4facfe,#00f2fe)"><i class="fas fa-wallet"></i></div>
            <h3>Withdraw Mudah</h3>
            <p>Dana only, min Rp 1.000, proses cepat</p>
        </div>
        <div class="feature-card">
            <div class="fc-icon" style="background:linear-gradient(135deg,#667eea,#764ba2)"><i class="fas fa-users"></i></div>
            <h3>Referral <?= rupiah($komisiRef) ?></h3>
            <p>Ajak teman, dapat komisi tiap teman setor</p>
        </div>
    </div>
</section>

<section class="section">
    <div class="section-head">
        <h2><i class="fas fa-question-circle"></i> Cara Jual Nomor</h2>
    </div>
    <div class="steps">
        <div class="step-item"><div class="step-num">1</div><h4>Daftar Gratis</h4><p>Bikin akun, 1 menit aja</p></div>
        <div class="step-item"><div class="step-num">2</div><h4>Setor Nomor</h4><p>Isi nomor + negara + tipe</p></div>
        <div class="step-item"><div class="step-num">3</div><h4>Tunggu Approve</h4><p>Admin cek 1-24 jam</p></div>
        <div class="step-item"><div class="step-num">4</div><h4>Saldo Masuk</h4><p>Otomatis ke akun kamu</p></div>
        <div class="step-item"><div class="step-num">5</div><h4>Withdraw</h4><p>Tarik ke Dana min Rp 1.000</p></div>
    </div>
</section>

<section class="cta-final">
    <div class="cta-box">
        <h2>Siap Cuan dari Nomor Kosong? 💰</h2>
        <p>Daftar gratis, mulai setor, cair ke Dana hari ini juga!</p>
        <a href="<?= isLoggedIn() ? '/user/setor.php' : '/register.php' ?>" class="btn btn-gold btn-lg pulse-btn">
            <i class="fas fa-rocket"></i> <?= isLoggedIn() ? 'Setor Sekarang' : 'Daftar Gratis' ?>
        </a>
    </div>
</section>

<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# ============ TERMS ============
cat > "$WEB_ROOT/terms.php" << 'PHPEOF'
<?php require_once __DIR__ . '/includes/config.php'; $pageTitle = 'Syarat & Ketentuan'; include __DIR__ . '/includes/header.php'; include __DIR__ . '/includes/navbar.php'; ?>
<div class="container">
    <div class="page-head"><h1><i class="fas fa-file-contract"></i> Syarat & Ketentuan</h1></div>
    <div class="card terms-card">
        <h2>1. Ketentuan Umum</h2>
        <p>Dengan mendaftar di <?= SITE_NAME ?>, kamu menyetujui seluruh syarat dan ketentuan yang berlaku.</p>
        <h2>2. Kewajiban Penjual</h2>
        <ul>
            <li>Nomor yang disetor <b>HARUS MILIK SENDIRI</b> dan legal</li>
            <li>Dilarang menyetor nomor hasil kejahatan / penipuan</li>
            <li>Setiap setoran <b>wajib tervalidasi</b> — admin berhak menolak</li>
        </ul>
        <h2>3. Proses Setoran</h2>
        <ul>
            <li>Setoran <b>tidak otomatis disetujui</b> (1-24 jam)</li>
            <li>Harga non-limit <b>random dari sistem</b></li>
            <li>Saldo masuk <b>setelah admin approve</b></li>
        </ul>
        <h2>4. Withdraw</h2>
        <ul>
            <li>Minimal withdraw <b>Rp 1.000</b></li>
            <li>Hanya ke <b>Dana</b></li>
            <li>Proses withdraw <b>1-24 jam</b> kerja</li>
        </ul>
        <h2>5. Referral</h2>
        <ul>
            <li>Komisi <b>Rp 250</b> per teman yang <b>berhasil setor</b></li>
            <li>Bonus diberikan setelah admin approve setoran temanmu</li>
        </ul>
        <h2>6. Larangan</h2>
        <ul>
            <li>Dilarang menyetor nomor ilegal</li>
            <li>Dilarang membuat akun ganda untuk abuse referral</li>
            <li>Dilarang manipulasi sistem — akan di-ban permanen</li>
        </ul>
        <h2>7. Konsekuensi Pelanggaran</h2>
        <ul>
            <li>Akun di-<b>ban permanen</b></li>
            <li>Saldo di-<b>hangus</b></li>
            <li>Bisa <b>dilaporkan ke pihak berwenang</b> jika terbukti pidana</li>
        </ul>
        <h2>8. Notifikasi Telegram</h2>
        <p>Kami menyediakan notifikasi real-time via Telegram Bot. Untuk mengaktifkan, klik tombol <b>Connect Telegram</b> di halaman profile kamu.</p>
        <div class="terms-footer">
            <p><i class="fas fa-shield-halved"></i> Dengan mencentang "Setuju" saat daftar, kamu telah membaca & menyetujui seluruh syarat di atas.</p>
        </div>
    </div>
</div>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# ============ FAQ ============
cat > "$WEB_ROOT/faq.php" << 'PHPEOF'
<?php require_once __DIR__ . '/includes/config.php'; $pageTitle = 'FAQ'; include __DIR__ . '/includes/header.php'; include __DIR__ . '/includes/navbar.php'; ?>
<div class="container">
    <div class="page-head"><h1><i class="fas fa-question-circle"></i> FAQ</h1></div>
    <div class="faq">
        <details><summary>Berapa bayaran per nomor?</summary><p>Limit 24 jam: Rp 1.000. Non-limit: Rp 1.000 - Rp 5.000 (random dari sistem).</p></details>
        <details><summary>Berapa lama approve?</summary><p>Admin approve 1-24 jam. Kebanyakan dalam 1-3 jam.</p></details>
        <details><summary>Bagaimana cara withdraw?</summary><p>Ke Dana saja. Min Rp 1.000. Proses 1-24 jam kerja.</p></details>
        <details><summary>Apa itu referral?</summary><p>Setiap teman yang daftar via link kamu & setor nomor, kamu dapat Rp 250.</p></details>
        <details><summary>Bagaimana cara dapat notifikasi Telegram?</summary><p>Buka profile → klik tombol Connect Telegram → start bot. Kamu akan dapat notifikasi real-time.</p></details>
        <details><summary>Apakah aman?</summary><p>Kami hanya terima nomor legal. Data user dilindungi. Jangan share password ke siapapun.</p></details>
    </div>
</div>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# ============ LOGIN ============
cat > "$WEB_ROOT/login.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
if (isLoggedIn()) { header('Location: /user/'); exit; }
$error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!checkCsrf($_POST['csrf'] ?? '')) $error = 'CSRF error';
    else {
        $u = trim($_POST['username'] ?? ''); $p = $_POST['password'] ?? '';
        $s = $pdo->prepare("SELECT * FROM users WHERE username=? OR email=? LIMIT 1");
        $s->execute([$u, $u]); $user = $s->fetch();
        if ($user && password_verify($p, $user['password'])) {
            if ($user['status'] === 'banned') $error = 'Akun dibanned!';
            else {
                $_SESSION['user_id'] = $user['id'];
                $_SESSION['username'] = $user['username'];
                $_SESSION['role'] = $user['role'];
                $pdo->prepare("UPDATE users SET last_login=NOW() WHERE id=?")->execute([$user['id']]);
                logAct($pdo, $user['id'], 'Login');
                header('Location: /user/'); exit;
            }
        } else $error = 'Username/password salah';
    }
}
$pageTitle = 'Login'; include __DIR__ . '/includes/header.php'; include __DIR__ . '/includes/navbar.php';
?>
<div class="auth-wrap"><div class="auth-card">
    <div class="auth-icon"><i class="fas fa-arrow-right-to-bracket"></i></div>
    <h1>Selamat Datang</h1>
    <p class="auth-sub">Login untuk jual nomor kosong</p>
    <?php if ($error): ?><div class="alert alert-error"><?= $error ?></div><?php endif; ?>
    <form method="POST">
        <input type="hidden" name="csrf" value="<?= csrf() ?>">
        <div class="form-group"><label>Username / Email</label><input type="text" name="username" required autofocus></div>
        <div class="form-group"><label>Password</label><input type="password" name="password" required></div>
        <button class="btn btn-primary btn-block btn-lg"><i class="fas fa-arrow-right-to-bracket"></i> Login</button>
    </form>
    <p class="auth-footer">Belum punya akun? <a href="/register.php">Daftar Gratis</a></p>
</div></div>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# ============ REGISTER (dengan ToS wajib centang) ============
cat > "$WEB_ROOT/register.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
if (isLoggedIn()) { header('Location: /user/'); exit; }
$error = ''; $success = '';
$ref = $_GET['ref'] ?? $_POST['ref'] ?? '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!checkCsrf($_POST['csrf'] ?? '')) $error = 'CSRF error';
    else {
        $u = trim($_POST['username'] ?? ''); $e = trim($_POST['email'] ?? '');
        $p = $_POST['password'] ?? ''; $c = $_POST['confirm'] ?? '';
        $refCode = trim($_POST['ref'] ?? '');
        $tos = isset($_POST['tos']) ? true : false;
        if (!$tos) $error = '⚠️ Kamu HARUS menyetujui Syarat & Ketentuan!';
        elseif (strlen($u) < 3) $error = 'Username min 3';
        elseif (!filter_var($e, FILTER_VALIDATE_EMAIL)) $error = 'Email tidak valid';
        elseif (strlen($p) < 6) $error = 'Password min 6';
        elseif ($p !== $c) $error = 'Konfirmasi tidak sama';
        else {
            $s = $pdo->prepare("SELECT id FROM users WHERE username=? OR email=?");
            $s->execute([$u, $e]);
            if ($s->fetch()) $error = 'Sudah terdaftar';
            else {
                $h = password_hash($p, PASSWORD_BCRYPT);
                $newRef = strtoupper(substr(md5($u . time()), 0, 8));
                $refBy = null;
                if ($refCode) {
                    $r = $pdo->prepare("SELECT id FROM users WHERE ref_code=?");
                    $r->execute([$refCode]);
                    $ru = $r->fetch();
                    if ($ru) $refBy = $ru['id'];
                }
                $pdo->prepare("INSERT INTO users (username,email,password,ref_code,ref_by,tos_agreed_at) VALUES (?,?,?,?,?,NOW())")
                    ->execute([$u, $e, $h, $newRef, $refBy]);
                $success = 'Daftar berhasil! Silakan login.';
                logAct($pdo, (int)$pdo->lastInsertId(), 'Register' . ($refBy ? " (ref #$refBy)" : ''));
            }
        }
    }
}
$pageTitle = 'Register'; include __DIR__ . '/includes/header.php'; include __DIR__ . '/includes/navbar.php';
?>
<div class="auth-wrap"><div class="auth-card auth-card-lg">
    <div class="auth-icon"><i class="fas fa-user-plus"></i></div>
    <h1>Daftar Akun</h1>
    <p class="auth-sub">Gratis • 1 menit • Langsung bisa jual nomor</p>
    <?php if ($error): ?><div class="alert alert-error"><i class="fas fa-circle-exclamation"></i> <?= $error ?></div><?php endif; ?>
    <?php if ($success): ?><div class="alert alert-success"><i class="fas fa-check-circle"></i> <?= $success ?> <a href="/login.php">Login →</a></div><?php endif; ?>
    <form method="POST">
        <input type="hidden" name="csrf" value="<?= csrf() ?>">
        <input type="hidden" name="ref" value="<?= htmlspecialchars($ref) ?>">
        <?php if ($ref): ?><div class="alert alert-success">🎁 Kode referral: <b><?= htmlspecialchars($ref) ?></b></div><?php endif; ?>
        <div class="form-group"><label>Username</label><input type="text" name="username" required autocomplete="username"></div>
        <div class="form-group"><label>Email</label><input type="email" name="email" required autocomplete="email"></div>
        <div class="form-group"><label>Password</label><input type="password" name="password" required autocomplete="new-password"></div>
        <div class="form-group"><label>Konfirmasi Password</label><input type="password" name="confirm" required autocomplete="new-password"></div>

        <!-- TOS CHECKBOX -->
        <div class="tos-checkbox">
            <label class="tos-label">
                <input type="checkbox" name="tos" id="tosCheckbox" required>
                <span class="tos-text">
                    Saya telah membaca dan menyetujui <a href="/terms.php" target="_blank"><b>Syarat & Ketentuan</b></a> yang berlaku di <?= SITE_NAME ?>.
                    Saya menyatakan bahwa <b>nomor yang akan saya setor adalah milik saya sendiri dan legal</b>.
                </span>
            </label>
        </div>

        <button class="btn btn-primary btn-block btn-lg" id="submitBtn" disabled><i class="fas fa-user-plus"></i> Daftar Sekarang</button>
    </form>
    <p class="auth-footer">Sudah punya akun? <a href="/login.php">Login</a></p>
</div></div>

<script>
document.getElementById('tosCheckbox').addEventListener('change', function() {
    document.getElementById('submitBtn').disabled = !this.checked;
});
</script>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

cat > "$WEB_ROOT/logout.php" << 'PHPEOF'
<?php require_once __DIR__ . '/includes/config.php'; if (isLoggedIn()) logAct($pdo, $_SESSION['user_id'], 'Logout'); session_destroy(); header('Location: /login.php'); exit;
PHPEOF

echo -e "${GREEN}  ✓ Auth + ToS OK${NC}"

# ============ STEP 7: USER PAGES ============
echo -e "${CYAN}[6/8] User pages...${NC}"

cat > "$WEB_ROOT/user/index.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
requireLogin();
$uid = $_SESSION['user_id'];
$s = $pdo->prepare("SELECT * FROM users WHERE id=?"); $s->execute([$uid]); $me = $s->fetch();
$subs = $pdo->prepare("SELECT * FROM submissions WHERE user_id=? ORDER BY id DESC LIMIT 5");
$subs->execute([$uid]); $subs = $subs->fetchAll();
$wds = $pdo->prepare("SELECT * FROM withdrawals WHERE user_id=? ORDER BY id DESC LIMIT 5");
$wds->execute([$uid]); $wds = $wds->fetchAll();
$rs = $pdo->prepare("SELECT COUNT(*) FROM users WHERE ref_by=?"); $rs->execute([$uid]); $refCount = (int)$rs->fetchColumn();

$pageTitle = 'Dashboard';
include __DIR__ . '/../includes/header.php';
include __DIR__ . '/../includes/navbar.php';
?>
<div class="container">
    <div class="welcome-card">
        <div class="wc-left">
            <div class="wc-avatar"><?= strtoupper(substr($me['username'], 0, 1)) ?></div>
            <div>
                <h1>Halo, <?= htmlspecialchars($me['username']) ?>! 👋</h1>
                <p><span class="badge badge-user">MEMBER</span> <span style="margin-left:8px;color:var(--text-muted)"><?= htmlspecialchars($me['email']) ?></span></p>
            </div>
        </div>
        <div class="wc-right">
            <a href="/user/setor.php" class="btn btn-primary pulse-btn"><i class="fas fa-plus-circle"></i> Setor Nomor</a>
        </div>
    </div>

    <div class="stats-grid">
        <div class="stat-card">
            <div class="stat-icon" style="background:linear-gradient(135deg,#43e97b,#38f9d7)"><i class="fas fa-wallet"></i></div>
            <div class="stat-info"><h3><?= rupiah($me['saldo']) ?></h3><p>Saldo</p></div>
        </div>
        <div class="stat-card">
            <div class="stat-icon" style="background:linear-gradient(135deg,#667eea,#764ba2)"><i class="fas fa-plus-circle"></i></div>
            <div class="stat-info"><h3><?= (int)$me['total_submit'] ?></h3><p>Total Setor</p></div>
        </div>
        <div class="stat-card">
            <div class="stat-icon" style="background:linear-gradient(135deg,#f093fb,#f5576c)"><i class="fas fa-hand-holding-dollar"></i></div>
            <div class="stat-info"><h3><?= rupiah($me['total_income']) ?></h3><p>Total Income</p></div>
        </div>
        <div class="stat-card">
            <div class="stat-icon" style="background:linear-gradient(135deg,#4facfe,#00f2fe)"><i class="fas fa-user-group"></i></div>
            <div class="stat-info"><h3><?= $refCount ?></h3><p>Referral</p></div>
        </div>
    </div>

    <div class="grid-2">
        <div class="card">
            <h2><i class="fas fa-clock-rotate-left"></i> Setoran Terakhir</h2>
            <?php if (empty($subs)): ?><p class="empty">Belum ada setoran</p>
            <?php else: foreach ($subs as $o): ?>
                <div class="log-item">
                    <i class="fas fa-<?= $o['status']==='approved'?'check-circle':($o['status']==='rejected'?'xmark-circle':'hourglass-half') ?>"></i>
                    <div>
                        <strong><?= htmlspecialchars($o['sub_code']) ?></strong> — <code><?= htmlspecialchars($o['nomor']) ?></code><br>
                        <small><?= rupiah($o['harga']) ?> • <span class="badge badge-<?= $o['status'] ?>"><?= $o['status'] ?></span></small>
                    </div>
                </div>
            <?php endforeach; endif; ?>
            <a href="/user/riwayat.php" class="btn btn-outline btn-block" style="margin-top:15px">Lihat Semua →</a>
        </div>
        <div class="card">
            <h2><i class="fas fa-money-bill-transfer"></i> Withdraw Terakhir</h2>
            <?php if (empty($wds)): ?><p class="empty">Belum ada withdraw</p>
            <?php else: foreach ($wds as $w): ?>
                <div class="log-item">
                    <i class="fas fa-<?= $w['status']==='approved'?'check-circle':($w['status']==='rejected'?'xmark-circle':'hourglass-half') ?>"></i>
                    <div><strong><?= rupiah($w['amount']) ?></strong><br><small><?= htmlspecialchars($w['dana_number']) ?> • <?= $w['status'] ?></small></div>
                </div>
            <?php endforeach; endif; ?>
            <a href="/user/withdraw.php" class="btn btn-outline btn-block" style="margin-top:15px">Withdraw →</a>
        </div>
    </div>
</div>
<?php include __DIR__ . '/../includes/footer.php'; ?>
PHPEOF

cat > "$WEB_ROOT/user/setor.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
requireLogin();
$uid = $_SESSION['user_id'];
$msg = ''; $err = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && checkCsrf($_POST['csrf'] ?? '')) {
    $tipe = $_POST['tipe'] ?? '';
    $negara = trim($_POST['negara'] ?? 'Indonesia');
    $nomor = trim($_POST['nomor'] ?? '');
    $catatan = trim($_POST['catatan'] ?? '');

    if (!in_array($tipe, ['limit','nonlimit'])) $err = 'Tipe tidak valid';
    elseif (!validPhone($nomor)) $err = 'Format nomor tidak valid (9-15 digit)';
    elseif (strlen($negara) < 2) $err = 'Negara tidak valid';
    else {
        $harga = hitungHargaBeli($pdo, $tipe);
        $code = 'SB' . strtoupper(substr(md5(uniqid()), 0, 8));
        $pdo->prepare("INSERT INTO submissions (user_id, sub_code, tipe, negara, nomor, harga, admin_note) VALUES (?,?,?,?,?,?,?)")
            ->execute([$uid, $code, $tipe, $negara, $nomor, $harga, $catatan]);
        $pdo->prepare("UPDATE users SET total_submit=total_submit+1 WHERE id=?")->execute([$uid]);
        $msg = "✅ Setoran <b>$code</b> dibuat! Nomor: <code>$nomor</code>. Harga: " . rupiah($harga) . ". Tunggu admin approve.";
        logAct($pdo, $uid, "Setor $code ($tipe) $nomor = " . rupiah($harga));
    }
}

$hargaLimit = (int)getSetting($pdo, 'harga_limit', 1000);
$hargaMin = (int)getSetting($pdo, 'harga_nonlimit_min', 1000);
$hargaMax = (int)getSetting($pdo, 'harga_nonlimit_max', 5000);

$pageTitle = 'Setor Nomor';
include __DIR__ . '/../includes/header.php';
include __DIR__ . '/../includes/navbar.php';
?>
<div class="container">
    <div class="page-head">
        <h1><i class="fas fa-plus-circle"></i> Setor Nomor Kosong</h1>
        <p>Isi form di bawah, tunggu admin approve</p>
    </div>

    <?php if ($msg): ?><div class="alert alert-success"><?= $msg ?></div><?php endif; ?>
    <?php if ($err): ?><div class="alert alert-error"><i class="fas fa-circle-exclamation"></i> <?= $err ?></div><?php endif; ?>

    <div class="dana-box">
        <div class="db-head"><i class="fas fa-info-circle"></i> Ketentuan Setoran</div>
        <ul class="dana-list">
            <li>✅ Nomor harus <b>MILIK SENDIRI</b> dan legal</li>
            <li>✅ Format: <code>08xxxxxxxxxx</code> atau <code>+62xxxxxxxxxx</code></li>
            <li>✅ Harga otomatis dari sistem</li>
            <li>⏳ Approve 1-24 jam kerja</li>
        </ul>
    </div>

    <div class="price-grid">
        <div class="price-card">
            <div class="pc-flag">🌍</div>
            <h3>Nomor Limit 24 Jam</h3>
            <div class="pc-price"><?= rupiah($hargaLimit) ?></div>
            <p class="pc-desc">Berlaku semua negara. Limit 24 jam.</p>
            <form method="POST">
                <input type="hidden" name="csrf" value="<?= csrf() ?>">
                <input type="hidden" name="tipe" value="limit">
                <div class="form-group"><label>Nomor</label><input type="text" name="nomor" placeholder="08xxxxxxxxxx" required></div>
                <div class="form-group"><label>Negara</label><input type="text" name="negara" placeholder="Indonesia / USA / dll" value="Indonesia" required></div>
                <div class="form-group"><label>Catatan (opsional)</label><textarea name="catatan" class="form-input" rows="2" placeholder="Kondisi nomor..."></textarea></div>
                <button class="btn btn-primary btn-block"><i class="fas fa-paper-plane"></i> Setor Sekarang</button>
            </form>
        </div>

        <div class="price-card price-featured">
            <div class="pc-badge">RANDOM <?= rupiah($hargaMin) ?> - <?= rupiah($hargaMax) ?></div>
            <div class="pc-flag">👑</div>
            <h3>Nomor Non-Limit</h3>
            <div class="pc-price"><?= rupiah($hargaMin) ?> - <?= rupiah($hargaMax) ?></div>
            <p class="pc-desc">Harga random dari sistem. Tanpa limit.</p>
            <form method="POST">
                <input type="hidden" name="csrf" value="<?= csrf() ?>">
                <input type="hidden" name="tipe" value="nonlimit">
                <div class="form-group"><label>Nomor</label><input type="text" name="nomor" placeholder="08xxxxxxxxxx" required></div>
                <div class="form-group"><label>Negara</label><input type="text" name="negara" placeholder="Indonesia / USA / dll" value="Indonesia" required></div>
                <div class="form-group"><label>Catatan (opsional)</label><textarea name="catatan" class="form-input" rows="2" placeholder="Kondisi nomor..."></textarea></div>
                <button class="btn btn-gold btn-block"><i class="fas fa-paper-plane"></i> Setor Sekarang</button>
            </form>
        </div>
    </div>
</div>
<?php include __DIR__ . '/../includes/footer.php'; ?>
PHPEOF

cat > "$WEB_ROOT/user/riwayat.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
requireLogin();
$uid = $_SESSION['user_id'];
$subs = $pdo->prepare("SELECT * FROM submissions WHERE user_id=? ORDER BY id DESC");
$subs->execute([$uid]); $subs = $subs->fetchAll();
$wds = $pdo->prepare("SELECT * FROM withdrawals WHERE user_id=? ORDER BY id DESC");
$wds->execute([$uid]); $wds = $wds->fetchAll();

$pageTitle = 'Riwayat';
include __DIR__ . '/../includes/header.php';
include __DIR__ . '/../includes/navbar.php';
?>
<div class="container">
    <div class="page-head"><h1><i class="fas fa-clock-rotate-left"></i> Riwayat Transaksi</h1></div>

    <div class="tabs">
        <button class="tab active" data-tab="subs"><i class="fas fa-plus-circle"></i> Setoran (<?= count($subs) ?>)</button>
        <button class="tab" data-tab="wds"><i class="fas fa-money-bill-transfer"></i> Withdraw (<?= count($wds) ?>)</button>
    </div>

    <div class="tab-content active" id="tab-subs">
        <div class="card">
            <?php if (empty($subs)): ?><p class="empty">Belum ada setoran</p>
            <?php else: foreach ($subs as $o): ?>
                <div class="riwayat-item">
                    <div class="ri-left">
                        <div class="ri-status ri-<?= $o['status'] ?>">
                            <i class="fas fa-<?= $o['status']==='approved'?'check':($o['status']==='rejected'?'xmark':'clock') ?>"></i>
                        </div>
                        <div>
                            <strong><?= htmlspecialchars($o['sub_code']) ?></strong><br>
                            <small>📱 <code><?= htmlspecialchars($o['nomor']) ?></code> • <?= $o['tipe']=='limit'?'Limit':'Non-Limit' ?> • <?= htmlspecialchars($o['negara']) ?></small>
                        </div>
                    </div>
                    <div class="ri-right">
                        <div class="ri-price"><?= rupiah($o['harga']) ?></div>
                        <span class="badge badge-<?= $o['status'] ?>"><?= $o['status'] ?></span>
                        <small><?= date('d/m/y H:i', strtotime($o['created_at'])) ?></small>
                    </div>
                </div>
            <?php endforeach; endif; ?>
        </div>
    </div>

    <div class="tab-content" id="tab-wds">
        <div class="card">
            <?php if (empty($wds)): ?><p class="empty">Belum ada withdraw</p>
            <?php else: foreach ($wds as $w): ?>
                <div class="riwayat-item">
                    <div class="ri-left">
                        <div class="ri-status ri-<?= $w['status'] ?>"><i class="fas fa-<?= $w['status']==='approved'?'check':($w['status']==='rejected'?'xmark':'clock') ?>"></i></div>
                        <div>
                            <strong><?= rupiah($w['amount']) ?></strong><br>
                            <small>Dana: <?= htmlspecialchars($w['dana_number']) ?> (<?= htmlspecialchars($w['dana_name']) ?>)</small>
                        </div>
                    </div>
                    <div class="ri-right">
                        <span class="badge badge-<?= $w['status'] ?>"><?= $w['status'] ?></span>
                        <small><?= date('d/m/y H:i', strtotime($w['created_at'])) ?></small>
                    </div>
                </div>
            <?php endforeach; endif; ?>
        </div>
    </div>
</div>

<script>
document.querySelectorAll('.tab').forEach(t => t.addEventListener('click', () => {
    document.querySelectorAll('.tab').forEach(x => x.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach(x => x.classList.remove('active'));
    t.classList.add('active');
    document.getElementById('tab-' + t.dataset.tab).classList.add('active');
}));
</script>
<?php include __DIR__ . '/../includes/footer.php'; ?>
PHPEOF

cat > "$WEB_ROOT/user/withdraw.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
requireLogin();
$uid = $_SESSION['user_id'];
$s = $pdo->prepare("SELECT * FROM users WHERE id=?"); $s->execute([$uid]); $me = $s->fetch();
$msg = ''; $err = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && checkCsrf($_POST['csrf'] ?? '')) {
    $amount = (int)($_POST['amount'] ?? 0);
    $dana = trim($_POST['dana_number'] ?? '');
    $name = trim($_POST['dana_name'] ?? '');
    $minWd = (int)getSetting($pdo, 'min_withdraw', 1000);
    if ($amount < $minWd) $err = "Minimal withdraw " . rupiah($minWd);
    elseif ($amount > (int)$me['saldo']) $err = 'Saldo tidak cukup';
    elseif (!preg_match('/^08\d{8,13}$/', $dana)) $err = 'Nomor Dana tidak valid (08xxx)';
    elseif (strlen($name) < 3) $err = 'Nama Dana min 3 karakter';
    else {
        $pdo->prepare("UPDATE users SET saldo=saldo-? WHERE id=?")->execute([$amount, $uid]);
        $pdo->prepare("INSERT INTO withdrawals (user_id, amount, dana_number, dana_name) VALUES (?,?,?,?)")
            ->execute([$uid, $amount, $dana, $name]);
        $wdId = (int)$pdo->lastInsertId();
        $msg = '✅ Withdraw diajukan! Admin akan proses 1-24 jam.';
        logAct($pdo, $uid, "Withdraw " . rupiah($amount) . " ke $dana");
        $me['saldo'] -= $amount;

        // ✅ Notif ke user via Telegram
        tgNotifyWithdrawRequest($pdo, $uid, $amount, $wdId);
    }
}

$wds = $pdo->prepare("SELECT * FROM withdrawals WHERE user_id=? ORDER BY id DESC LIMIT 20");
$wds->execute([$uid]); $wds = $wds->fetchAll();
$minWd = (int)getSetting($pdo, 'min_withdraw', 1000);

$pageTitle = 'Withdraw';
include __DIR__ . '/../includes/header.php';
include __DIR__ . '/../includes/navbar.php';
?>
<div class="container">
    <div class="page-head"><h1><i class="fas fa-money-bill-transfer"></i> Withdraw ke Dana</h1></div>

    <?php if ($msg): ?><div class="alert alert-success"><?= $msg ?></div><?php endif; ?>
    <?php if ($err): ?><div class="alert alert-error"><?= $err ?></div><?php endif; ?>

    <div class="grid-2">
        <div class="card">
            <h2><i class="fas fa-wallet"></i> Saldo Saat Ini</h2>
            <div class="big-number"><?= rupiah($me['saldo']) ?></div>
            <p style="color:var(--text-muted);text-align:center">Minimal withdraw: <b><?= rupiah($minWd) ?></b></p>

            <hr style="margin:20px 0;border:none;border-top:1px solid var(--border)">

            <h3 style="margin-bottom:15px"><i class="fas fa-paper-plane"></i> Ajukan Withdraw</h3>
            <form method="POST">
                <input type="hidden" name="csrf" value="<?= csrf() ?>">
                <div class="form-group"><label>Jumlah (Rp)</label><input type="number" name="amount" min="<?= $minWd ?>" max="<?= $me['saldo'] ?>" required placeholder="<?= $minWd ?>"></div>
                <div class="form-group"><label>Nomor Dana</label><input type="text" name="dana_number" placeholder="08xxxxxxxxxx" required></div>
                <div class="form-group"><label>Nama Pemilik Dana</label><input type="text" name="dana_name" placeholder="Sesuai akun Dana" required></div>
                <button class="btn btn-primary btn-block btn-lg"><i class="fas fa-paper-plane"></i> Ajukan Withdraw</button>
            </form>
        </div>

        <div class="card">
            <h2><i class="fas fa-clock-rotate-left"></i> Riwayat Withdraw</h2>
            <?php if (empty($wds)): ?><p class="empty">Belum ada withdraw</p>
            <?php else: foreach ($wds as $w): ?>
                <div class="log-item">
                    <i class="fas fa-<?= $w['status']==='approved'?'check-circle':($w['status']==='rejected'?'xmark-circle':'hourglass-half') ?>"></i>
                    <div>
                        <strong><?= rupiah($w['amount']) ?></strong> — <span class="badge badge-<?= $w['status'] ?>"><?= $w['status'] ?></span><br>
                        <small><?= htmlspecialchars($w['dana_number']) ?> • <?= date('d/m H:i', strtotime($w['created_at'])) ?></small>
                    </div>
                </div>
            <?php endforeach; endif; ?>
        </div>
    </div>
</div>
<?php include __DIR__ . '/../includes/footer.php'; ?>
PHPEOF

cat > "$WEB_ROOT/user/referral.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
requireLogin();
$uid = $_SESSION['user_id'];
$s = $pdo->prepare("SELECT * FROM users WHERE id=?"); $s->execute([$uid]); $me = $s->fetch();
$refs = $pdo->prepare("SELECT username, created_at, total_submit FROM users WHERE ref_by=? ORDER BY id DESC");
$refs->execute([$uid]); $refs = $refs->fetchAll();
$komisi = (int)getSetting($pdo, 'komisi_referral', 250);
$refLink = SITE_URL . '/register.php?ref=' . $me['ref_code'];

$pageTitle = 'Referral';
include __DIR__ . '/../includes/header.php';
include __DIR__ . '/../includes/navbar.php';
?>
<div class="container">
    <div class="page-head"><h1><i class="fas fa-user-group"></i> Program Referral</h1><p>Ajak teman, dapat <?= rupiah($komisi) ?> per setoran temanmu</p></div>

    <div class="stats-grid">
        <div class="stat-card">
            <div class="stat-icon" style="background:linear-gradient(135deg,#667eea,#764ba2)"><i class="fas fa-user-group"></i></div>
            <div class="stat-info"><h3><?= count($refs) ?></h3><p>Total Referral</p></div>
        </div>
        <div class="stat-card">
            <div class="stat-icon" style="background:linear-gradient(135deg,#43e97b,#38f9d7)"><i class="fas fa-hand-holding-dollar"></i></div>
            <div class="stat-info"><h3><?= rupiah($me['ref_earning']) ?></h3><p>Total Komisi</p></div>
        </div>
        <div class="stat-card">
            <div class="stat-icon" style="background:linear-gradient(135deg,#f093fb,#f5576c)"><i class="fas fa-tag"></i></div>
            <div class="stat-info"><h3><?= $me['ref_code'] ?></h3><p>Kode Referral</p></div>
        </div>
    </div>

    <div class="card">
        <h2><i class="fas fa-link"></i> Link Referral Kamu</h2>
        <div class="ref-link-box">
            <input type="text" id="refLink" value="<?= htmlspecialchars($refLink) ?>" readonly>
            <button class="btn btn-primary" onclick="copyRef()"><i class="fas fa-copy"></i></button>
        </div>
        <p style="color:var(--text-muted);font-size:.9em;margin-top:10px">Teman daftar via link ini & setor nomor = kamu dapat <b><?= rupiah($komisi) ?></b>.</p>
    </div>

    <div class="card">
        <h2><i class="fas fa-users"></i> Daftar Referral</h2>
        <?php if (empty($refs)): ?><p class="empty">Belum ada referral. Ajak temanmu!</p>
        <?php else: foreach ($refs as $r): ?>
            <div class="log-item">
                <i class="fas fa-user-check"></i>
                <div><strong><?= htmlspecialchars($r['username']) ?></strong><br><small>Join: <?= date('d/m/y', strtotime($r['created_at'])) ?> • Setor: <?= (int)$r['total_submit'] ?></small></div>
            </div>
        <?php endforeach; endif; ?>
    </div>
</div>

<script>
function copyRef() {
    const el = document.getElementById('refLink');
    el.select();
    document.execCommand('copy');
    alert('Link disalin!');
}
</script>
<?php include __DIR__ . '/../includes/footer.php'; ?>
PHPEOF

cat > "$WEB_ROOT/user/profile.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
requireLogin();
$uid = $_SESSION['user_id'];
$msg = ''; $err = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && checkCsrf($_POST['csrf'] ?? '')) {
    $act = $_POST['act'] ?? '';
    if ($act === 'password') {
        $old = $_POST['old'] ?? ''; $new = $_POST['new'] ?? ''; $c = $_POST['confirm'] ?? '';
        $s = $pdo->prepare("SELECT password FROM users WHERE id=?"); $s->execute([$uid]);
        $p = $s->fetch()['password'];
        if (!password_verify($old, $p)) $err = 'Password lama salah';
        elseif (strlen($new) < 6) $err = 'Password baru min 6';
        elseif ($new !== $c) $err = 'Konfirmasi beda';
        else {
            $pdo->prepare("UPDATE users SET password=? WHERE id=?")->execute([password_hash($new, PASSWORD_BCRYPT), $uid]);
            $msg = 'Password diupdate!';
            logAct($pdo, $uid, 'Ganti password');
        }
    } elseif ($act === 'generate_tg_token') {
        $newToken = tgGenerateToken($pdo, $uid);
        $msg = 'Token baru dibuat. Klik tombol Connect Telegram untuk hubungkan.';
    } elseif ($act === 'disconnect_tg') {
        $pdo->prepare("UPDATE users SET tg_chat_id=NULL, tg_username=NULL, tg_connected_at=NULL WHERE id=?")->execute([$uid]);
        $msg = 'Telegram disconnected.';
    }
}

$s = $pdo->prepare("SELECT * FROM users WHERE id=?"); $s->execute([$uid]); $me = $s->fetch();
$tgConnected = !empty($me['tg_chat_id']);
$tgUsername = tgGetBotUsername($pdo);

// Generate token kalau belum ada
if (empty($me['tg_token'])) {
    $me['tg_token'] = tgGenerateToken($pdo, $uid);
}

$connectLink = tgGetConnectLink($pdo, $me['tg_token']);

$pageTitle = 'Profile';
include __DIR__ . '/../includes/header.php';
include __DIR__ . '/../includes/navbar.php';
?>
<div class="container">
    <div class="page-head"><h1><i class="fas fa-user-circle"></i> Profile Saya</h1></div>

    <?php if ($msg): ?><div class="alert alert-success"><?= $msg ?></div><?php endif; ?>
    <?php if ($err): ?><div class="alert alert-error"><?= $err ?></div><?php endif; ?>

    <div class="grid-2">
        <div class="card">
            <div class="profile-head">
                <div class="profile-avatar"><?= strtoupper(substr($me['username'], 0, 1)) ?></div>
                <div>
                    <h2><?= htmlspecialchars($me['username']) ?></h2>
                    <p><?= htmlspecialchars($me['email']) ?></p>
                    <span class="badge badge-user">MEMBER</span>
                </div>
            </div>
            <div class="profile-info">
                <div class="pi-row"><span>User ID</span><code>#<?= $me['id'] ?></code></div>
                <div class="pi-row"><span>Saldo</span><strong><?= rupiah($me['saldo']) ?></strong></div>
                <div class="pi-row"><span>Total Setor</span><strong><?= (int)$me['total_submit'] ?></strong></div>
                <div class="pi-row"><span>Total Income</span><strong style="color:var(--success)"><?= rupiah($me['total_income']) ?></strong></div>
                <div class="pi-row"><span>Kode Referral</span><code><?= $me['ref_code'] ?></code></div>
                <div class="pi-row"><span>Bergabung</span><strong><?= date('d M Y', strtotime($me['created_at'])) ?></strong></div>
            </div>
        </div>

        <div class="card">
            <!-- TELEGRAM CONNECT -->
            <h2><i class="fab fa-telegram" style="color:#229ED9"></i> Notifikasi Telegram</h2>
            <?php if ($tgUsername): ?>
                <?php if ($tgConnected): ?>
                    <div class="tg-status tg-status-ok">
                        <i class="fas fa-check-circle"></i>
                        <div>
                            <strong>✅ Terhubung</strong>
                            <p>Chat ID: <code><?= htmlspecialchars($me['tg_chat_id']) ?></code></p>
                            <?php if ($me['tg_username']): ?><p>Username: @<?= htmlspecialchars($me['tg_username']) ?></p><?php endif; ?>
                        </div>
                    </div>
                    <form method="POST" style="margin-top:15px">
                        <input type="hidden" name="csrf" value="<?= csrf() ?>">
                        <input type="hidden" name="act" value="disconnect_tg">
                        <button class="btn btn-outline btn-block" onclick="return confirm('Disconnect Telegram?')"><i class="fas fa-unlink"></i> Disconnect</button>
                    </form>
                <?php else: ?>
                    <p style="color:var(--text-muted);margin-bottom:15px">Klik tombol di bawah untuk connect ke bot Telegram & dapat notifikasi real-time saat setoran/withdraw diproses.</p>
                    <div class="tg-connect-box">
                        <a href="<?= htmlspecialchars($connectLink) ?>" target="_blank" class="btn btn-tg btn-block btn-lg">
                            <i class="fab fa-telegram"></i> Connect ke @<?= htmlspecialchars($tgUsername) ?>
                        </a>
                    </div>
                    <div class="tg-instruction">
                        <p><b>📋 Cara connect:</b></p>
                        <ol>
                            <li>Klik tombol di atas</li>
                            <li>Telegram akan buka bot</li>
                            <li>Klik <b>START</b> di bot</li>
                            <li>Notifikasi otomatis aktif! ✅</li>
                        </ol>
                    </div>
                <?php endif; ?>

                <form method="POST" style="margin-top:15px">
                    <input type="hidden" name="csrf" value="<?= csrf() ?>">
                    <input type="hidden" name="act" value="generate_tg_token">
                    <button class="btn btn-outline btn-block btn-sm"><i class="fas fa-rotate"></i> Generate Token Baru</button>
                </form>
            <?php else: ?>
                <div class="alert alert-warning"><i class="fas fa-info-circle"></i> Bot Telegram belum dikonfigurasi admin.</div>
            <?php endif; ?>

            <hr style="margin:25px 0;border:none;border-top:1px solid var(--border)">

            <h2><i class="fas fa-key"></i> Ganti Password</h2>
            <form method="POST">
                <input type="hidden" name="csrf" value="<?= csrf() ?>">
                <input type="hidden" name="act" value="password">
                <div class="form-group"><label>Password Lama</label><input type="password" name="old" required></div>
                <div class="form-group"><label>Password Baru</label><input type="password" name="new" required></div>
                <div class="form-group"><label>Konfirmasi</label><input type="password" name="confirm" required></div>
                <button class="btn btn-primary"><i class="fas fa-save"></i> Simpan</button>
            </form>

            <hr style="margin:25px 0;border:none;border-top:1px solid var(--border)">

            <a href="/logout.php" class="btn btn-outline btn-block"><i class="fas fa-arrow-right-from-bracket"></i> Logout</a>
        </div>
    </div>
</div>
<?php include __DIR__ . '/../includes/footer.php'; ?>
PHPEOF

echo -e "${GREEN}  ✓ User pages OK${NC}"

# ============ STEP 8: ADMIN PAGES ============
echo -e "${CYAN}[7/8] Admin panel...${NC}"

cat > "$WEB_ROOT/admin/index.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
requireAdmin();
$pageTitle = 'Admin';
$totalUsers = (int)$pdo->query("SELECT COUNT(*) FROM users WHERE role='user'")->fetchColumn();
$totalBanned = (int)$pdo->query("SELECT COUNT(*) FROM users WHERE status='banned'")->fetchColumn();
$totalSub = (int)$pdo->query("SELECT COUNT(*) FROM submissions")->fetchColumn();
$pendingSub = (int)$pdo->query("SELECT COUNT(*) FROM submissions WHERE status='pending'")->fetchColumn();
$pendingWd = (int)$pdo->query("SELECT COUNT(*) FROM withdrawals WHERE status='pending'")->fetchColumn();
$totalSaldo = (int)$pdo->query("SELECT COALESCE(SUM(saldo),0) FROM users")->fetchColumn();
$totalPaid = (int)$pdo->query("SELECT COALESCE(SUM(total_income),0) FROM users")->fetchColumn();
$tgConnected = (int)$pdo->query("SELECT COUNT(*) FROM users WHERE tg_chat_id IS NOT NULL")->fetchColumn();

$top = $pdo->query("SELECT username, total_income FROM users WHERE status='active' ORDER BY total_income DESC LIMIT 10")->fetchAll();
$recentSubs = $pdo->query("SELECT s.*, u.username FROM submissions s LEFT JOIN users u ON s.user_id=u.id ORDER BY s.id DESC LIMIT 8")->fetchAll();

include __DIR__ . '/../includes/header.php';
include __DIR__ . '/../includes/navbar.php';
?>
<div class="container">
    <div class="page-head"><h1><i class="fas fa-shield-halved"></i> Admin Control Center</h1><p>Full control</p></div>

    <?php if ($pendingSub > 0): ?>
    <div class="alert alert-warning pulse-warn"><i class="fas fa-bell"></i> <b><?= $pendingSub ?></b> setoran menunggu approve! <a href="/admin/submissions.php" class="btn btn-sm btn-primary">Review</a></div>
    <?php endif; ?>
    <?php if ($pendingWd > 0): ?>
    <div class="alert alert-warning"><i class="fas fa-money-bill-transfer"></i> <b><?= $pendingWd ?></b> withdraw pending. <a href="/admin/withdraw.php" class="btn btn-sm btn-primary">Review</a></div>
    <?php endif; ?>

    <div class="stats-grid">
        <div class="stat-card"><div class="stat-icon" style="background:linear-gradient(135deg,#667eea,#764ba2)"><i class="fas fa-users"></i></div><div class="stat-info"><h3><?= $totalUsers ?></h3><p>Total User</p></div></div>
        <div class="stat-card"><div class="stat-icon" style="background:linear-gradient(135deg,#4facfe,#00f2fe)"><i class="fas fa-plus-circle"></i></div><div class="stat-info"><h3><?= $totalSub ?></h3><p>Total Setoran</p></div></div>
        <div class="stat-card"><div class="stat-icon" style="background:linear-gradient(135deg,#43e97b,#38f9d7)"><i class="fas fa-wallet"></i></div><div class="stat-info"><h3><?= rupiah($totalSaldo) ?></h3><p>Saldo User</p></div></div>
        <div class="stat-card"><div class="stat-icon" style="background:linear-gradient(135deg,#f093fb,#f5576c)"><i class="fas fa-arrow-trend-up"></i></div><div class="stat-info"><h3><?= rupiah($totalPaid) ?></h3><p>Total Dibayarkan</p></div></div>
    </div>

    <div class="admin-grid">
        <a href="/admin/submissions.php" class="admin-card <?= $pendingSub>0?'admin-card-alert':'' ?>"><i class="fas fa-plus-circle"></i><h3>Setoran <?= $pendingSub>0?"($pendingSub)":'' ?></h3><p>Approve / reject</p></a>
        <a href="/admin/store.php" class="admin-card"><i class="fas fa-store"></i><h3>Store</h3><p>Stok nomor</p></a>
        <a href="/admin/withdraw.php" class="admin-card <?= $pendingWd>0?'admin-card-alert':'' ?>"><i class="fas fa-money-bill-transfer"></i><h3>Withdraw <?= $pendingWd>0?"($pendingWd)":'' ?></h3><p>Proses withdraw</p></a>
        <a href="/admin/users.php" class="admin-card"><i class="fas fa-users-cog"></i><h3>Kelola User</h3><p>Ban, ubah password</p></a>
        <a href="/admin/logs.php" class="admin-card"><i class="fas fa-list-alt"></i><h3>Activity Log</h3><p>Semua aktivitas</p></a>
        <a href="/admin/settings.php" class="admin-card"><i class="fas fa-cog"></i><h3>Pengaturan</h3><p>Config & Telegram</p></a>
    </div>

    <div class="card">
        <h2><i class="fab fa-telegram" style="color:#229ED9"></i> Telegram Integration</h2>
        <div class="stats-grid">
            <div class="stat-card"><div class="stat-icon" style="background:#229ED9"><i class="fab fa-telegram"></i></div><div class="stat-info"><h3><?= $tgConnected ?></h3><p>User Terhubung TG</p></div></div>
        </div>
        <p style="color:var(--text-muted)">Bot aktif: <b>@<?= htmlspecialchars(tgGetBotUsername($pdo) ?: 'BELUM DIKONFIGURASI') ?></b></p>
        <a href="/admin/settings.php" class="btn btn-outline">Konfigurasi Bot →</a>
    </div>

    <div class="card">
        <h2><i class="fas fa-trophy"></i> Top 10 User</h2>
        <div class="top10-card">
            <?php if (empty($top)): ?><p class="empty">Belum ada data</p>
            <?php else: foreach ($top as $i => $u): $medal = ['🥇','🥈','🥉'][$i] ?? ('#' . ($i+1)); ?>
                <div class="top10-item <?= $i<3?'top10-top':'' ?>">
                    <div class="t10-rank"><?= $medal ?></div>
                    <div class="t10-user"><strong><?= htmlspecialchars($u['username']) ?></strong></div>
                    <div class="t10-income"><?= rupiah($u['total_income']) ?></div>
                </div>
            <?php endforeach; endif; ?>
        </div>
    </div>

    <div class="card">
        <h2><i class="fas fa-clock-rotate-left"></i> Setoran Terbaru</h2>
        <table class="table">
            <thead><tr><th>Code</th><th>User</th><th>Nomor</th><th>Tipe</th><th>Harga</th><th>Status</th></tr></thead>
            <tbody>
                <?php foreach ($recentSubs as $o): ?>
                <tr>
                    <td><code><?= htmlspecialchars($o['sub_code']) ?></code></td>
                    <td><?= htmlspecialchars($o['username'] ?? '-') ?></td>
                    <td><code><?= htmlspecialchars($o['nomor']) ?></code></td>
                    <td><?= $o['tipe']=='limit'?'Limit':'Non-Limit' ?></td>
                    <td><?= rupiah($o['harga']) ?></td>
                    <td><span class="badge badge-<?= $o['status'] ?>"><?= $o['status'] ?></span></td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>
<?php include __DIR__ . '/../includes/footer.php'; ?>
PHPEOF

cat > "$WEB_ROOT/admin/submissions.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
requireAdmin();
$msg = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST' && checkCsrf($_POST['csrf'] ?? '')) {
    $sid = (int)($_POST['sid'] ?? 0); $act = $_POST['act'] ?? '';
    $note = trim($_POST['admin_note'] ?? '');
    $s = $pdo->prepare("SELECT s.*, u.username FROM submissions s LEFT JOIN users u ON s.user_id=u.id WHERE s.id=?");
    $s->execute([$sid]); $sub = $s->fetch();
    if ($sub && $sub['status'] === 'pending') {
        if ($act === 'approve') {
            $pdo->prepare("UPDATE submissions SET status='approved', admin_note=?, approved_by=?, approved_at=NOW() WHERE id=?")
                ->execute([$note, $_SESSION['user_id'], $sid]);
            // Tambah ke store
            $pdo->prepare("INSERT INTO store (submission_id, seller_id, nomor, negara, tipe, harga_beli) VALUES (?,?,?,?,?,?)")
                ->execute([$sid, $sub['user_id'], $sub['nomor'], $sub['negara'], $sub['tipe'], $sub['harga']]);
            // Bayar user + referral
            payUserAndReferral($pdo, $sub['user_id'], $sub['harga'], $sub['sub_code']);
            // Notif TG ke user
            tgNotifySubmissionApproved($pdo, $sub['user_id'], $sub['nomor'], $sub['harga'], $sub['sub_code']);
            // Notif TG ke upline
            $rs = $pdo->prepare("SELECT ref_by FROM users WHERE id=?"); $rs->execute([$sub['user_id']]);
            $ru = $rs->fetch();
            if ($ru && $ru['ref_by']) {
                $komisi = (int)getSetting($pdo, 'komisi_referral', 250);
                tgNotifyReferralBonus($pdo, $ru['ref_by'], $komisi, $sub['username']);
            }
            $msg = "✅ Approved! Saldo +" . rupiah($sub['harga']) . " ke user.";
        } elseif ($act === 'reject') {
            $pdo->prepare("UPDATE submissions SET status='rejected', admin_note=?, approved_by=?, approved_at=NOW() WHERE id=?")
                ->execute([$note, $_SESSION['user_id'], $sid]);
            $pdo->prepare("UPDATE users SET total_rejected=total_rejected+1 WHERE id=?")->execute([$sub['user_id']]);
            tgNotifySubmissionRejected($pdo, $sub['user_id'], $sub['nomor'], $sub['sub_code'], $note);
            $msg = "❌ Rejected.";
        }
        logAct($pdo, $_SESSION['user_id'], "Admin $act setoran {$sub['sub_code']}");
    }
}
$filter = $_GET['status'] ?? 'all';
$where = $filter !== 'all' ? "WHERE s.status=?" : "";
$sql = "SELECT s.*, u.username, u.email FROM submissions s LEFT JOIN users u ON s.user_id=u.id $where ORDER BY s.id DESC LIMIT 200";
$st = $pdo->prepare($sql); $st->execute($filter !== 'all' ? [$filter] : []); $subs = $st->fetchAll();

$pageTitle = 'Setoran';
include __DIR__ . '/../includes/header.php';
include __DIR__ . '/../includes/navbar.php';
?>
<div class="container">
    <div class="page-head"><h1><i class="fas fa-plus-circle"></i> Kelola Setoran</h1><p>Approve → saldo masuk otomatis</p></div>
    <?php if ($msg): ?><div class="alert alert-success"><?= $msg ?></div><?php endif; ?>

    <div class="tabs">
        <a href="?status=all" class="tab <?= $filter==='all'?'active':'' ?>">Semua</a>
        <a href="?status=pending" class="tab <?= $filter==='pending'?'active':'' ?>">Pending</a>
        <a href="?status=approved" class="tab <?= $filter==='approved'?'active':'' ?>">Approved</a>
        <a href="?status=rejected" class="tab <?= $filter==='rejected'?'active':'' ?>">Rejected</a>
    </div>

    <div class="card">
        <table class="table">
            <thead><tr><th>Code</th><th>User</th><th>Nomor</th><th>Tipe</th><th>Negara</th><th>Harga</th><th>Status</th><th>Aksi</th></tr></thead>
            <tbody>
                <?php foreach ($subs as $o): ?>
                <tr>
                    <td><code><?= htmlspecialchars($o['sub_code']) ?></code></td>
                    <td><strong><?= htmlspecialchars($o['username'] ?? '-') ?></strong></td>
                    <td><code><?= htmlspecialchars($o['nomor']) ?></code></td>
                    <td><?= $o['tipe']=='limit'?'Limit':'Non-Limit' ?></td>
                    <td><?= htmlspecialchars($o['negara']) ?></td>
                    <td><?= rupiah($o['harga']) ?></td>
                    <td><span class="badge badge-<?= $o['status'] ?>"><?= $o['status'] ?></span></td>
                    <td>
                        <?php if ($o['status'] === 'pending'): ?>
                        <form method="POST" style="display:inline-flex;gap:4px">
                            <input type="hidden" name="csrf" value="<?= csrf() ?>">
                            <input type="hidden" name="sid" value="<?= $o['id'] ?>">
                            <button name="act" value="approve" class="btn-icon btn-ok" title="Approve" onclick="return confirm('Approve? Saldo akan masuk.')"><i class="fas fa-check"></i></button>
                            <button name="act" value="reject" class="btn-icon btn-danger" title="Reject" onclick="return confirm('Reject?')"><i class="fas fa-xmark"></i></button>
                        </form>
                        <?php else: ?><small><?= htmlspecialchars($o['admin_note'] ?? '-') ?></small><?php endif; ?>
                    </td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>
<?php include __DIR__ . '/../includes/footer.php'; ?>
PHPEOF

cat > "$WEB_ROOT/admin/withdraw.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
requireAdmin();
$msg = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST' && checkCsrf($_POST['csrf'] ?? '')) {
    $wid = (int)($_POST['wid'] ?? 0); $act = $_POST['act'] ?? ''; $note = trim($_POST['admin_note'] ?? '');
    $s = $pdo->prepare("SELECT * FROM withdrawals WHERE id=?"); $s->execute([$wid]); $w = $s->fetch();
    if ($w && $w['status'] === 'pending') {
        if ($act === 'approve') {
            $pdo->prepare("UPDATE withdrawals SET status='approved', admin_note=?, processed_by=?, processed_at=NOW() WHERE id=?")
                ->execute([$note, $_SESSION['user_id'], $wid]);
            tgNotifyWithdrawApproved($pdo, $w['user_id'], $w['amount'], $wid);
            $msg = 'Approved!';
        } elseif ($act === 'reject') {
            $pdo->prepare("UPDATE withdrawals SET status='rejected', admin_note=?, processed_by=?, processed_at=NOW() WHERE id=?")
                ->execute([$note, $_SESSION['user_id'], $wid]);
            $pdo->prepare("UPDATE users SET saldo=saldo+? WHERE id=?")->execute([$w['amount'], $w['user_id']]);
            tgNotifyWithdrawRejected($pdo, $w['user_id'], $w['amount'], $wid, $note);
            $msg = 'Rejected & saldo dikembalikan.';
        }
        logAct($pdo, $_SESSION['user_id'], "Withdraw $act #$wid");
    }
}
$wds = $pdo->query("SELECT w.*, u.username FROM withdrawals w LEFT JOIN users u ON w.user_id=u.id ORDER BY w.id DESC LIMIT 200")->fetchAll();
$pageTitle = 'Withdraw';
include __DIR__ . '/../includes/header.php';
include __DIR__ . '/../includes/navbar.php';
?>
<div class="container">
    <div class="page-head"><h1><i class="fas fa-money-bill-transfer"></i> Kelola Withdraw</h1></div>
    <?php if ($msg): ?><div class="alert alert-success"><?= $msg ?></div><?php endif; ?>
    <div class="card">
        <table class="table">
            <thead><tr><th>ID</th><th>User</th><th>Nominal</th><th>Dana</th><th>Nama</th><th>Status</th><th>Waktu</th><th>Aksi</th></tr></thead>
            <tbody>
                <?php foreach ($wds as $w): ?>
                <tr>
                    <td>#<?= $w['id'] ?></td>
                    <td><?= htmlspecialchars($w['username'] ?? '-') ?></td>
                    <td><strong><?= rupiah($w['amount']) ?></strong></td>
                    <td><code><?= htmlspecialchars($w['dana_number']) ?></code></td>
                    <td><?= htmlspecialchars($w['dana_name']) ?></td>
                    <td><span class="badge badge-<?= $w['status'] ?>"><?= $w['status'] ?></span></td>
                    <td><small><?= $w['created_at'] ?></small></td>
                    <td>
                        <?php if ($w['status']=='pending'): ?>
                        <form method="POST" style="display:inline-flex;gap:4px">
                            <input type="hidden" name="csrf" value="<?= csrf() ?>">
                            <input type="hidden" name="wid" value="<?= $w['id'] ?>">
                            <button name="act" value="approve" class="btn-icon btn-ok" onclick="return confirm('Approve? Notif akan dikirim ke user.')"><i class="fas fa-check"></i></button>
                            <button name="act" value="reject" class="btn-icon btn-danger" onclick="return confirm('Reject & kembalikan saldo?')"><i class="fas fa-xmark"></i></button>
                        </form>
                        <?php else: ?><small><?= htmlspecialchars($w['admin_note'] ?? '-') ?></small><?php endif; ?>
                    </td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>
<?php include __DIR__ . '/../includes/footer.php'; ?>
PHPEOF

cat > "$WEB_ROOT/admin/store.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
requireAdmin();
$store = $pdo->query("SELECT s.*, u.username FROM store s LEFT JOIN users u ON s.seller_id=u.id ORDER BY s.id DESC LIMIT 300")->fetchAll();
$available = (int)$pdo->query("SELECT COUNT(*) FROM store WHERE status='available'")->fetchColumn();
$sold = (int)$pdo->query("SELECT COUNT(*) FROM store WHERE status='sold'")->fetchColumn();
$totalValue = (int)$pdo->query("SELECT COALESCE(SUM(harga_beli),0) FROM store WHERE status='available'")->fetchColumn();
$pageTitle = 'Store';
include __DIR__ . '/../includes/header.php';
include __DIR__ . '/../includes/navbar.php';
?>
<div class="container">
    <div class="page-head"><h1><i class="fas fa-store"></i> Store (Stok Nomor)</h1></div>

    <div class="stats-grid">
        <div class="stat-card"><div class="stat-icon" style="background:linear-gradient(135deg,#43e97b,#38f9d7)"><i class="fas fa-box"></i></div><div class="stat-info"><h3><?= $available ?></h3><p>Tersedia</p></div></div>
        <div class="stat-card"><div class="stat-icon" style="background:linear-gradient(135deg,#667eea,#764ba2)"><i class="fas fa-check"></i></div><div class="stat-info"><h3><?= $sold ?></h3><p>Terjual</p></div></div>
        <div class="stat-card"><div class="stat-icon" style="background:linear-gradient(135deg,#f093fb,#f5576c)"><i class="fas fa-coins"></i></div><div class="stat-info"><h3><?= rupiah($totalValue) ?></h3><p>Nilai Stok</p></div></div>
    </div>

    <div class="card">
        <table class="table">
            <thead><tr><th>ID</th><th>Nomor</th><th>Negara</th><th>Tipe</th><th>Harga Beli</th><th>Seller</th><th>Status</th><th>Waktu</th></tr></thead>
            <tbody>
                <?php foreach ($store as $s): ?>
                <tr>
                    <td>#<?= $s['id'] ?></td>
                    <td><code><?= htmlspecialchars($s['nomor']) ?></code></td>
                    <td><?= htmlspecialchars($s['negara']) ?></td>
                    <td><?= $s['tipe']=='limit'?'Limit':'Non-Limit' ?></td>
                    <td><?= rupiah($s['harga_beli']) ?></td>
                    <td><?= htmlspecialchars($s['username'] ?? '-') ?></td>
                    <td><span class="badge badge-<?= $s['status']=='available'?'active':'sold' ?>"><?= $s['status'] ?></span></td>
                    <td><small><?= $s['created_at'] ?></small></td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>
<?php include __DIR__ . '/../includes/footer.php'; ?>
PHPEOF

cat > "$WEB_ROOT/admin/users.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
requireAdmin();
$msg = ''; $err = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST' && checkCsrf($_POST['csrf'] ?? '')) {
    $uid = (int)($_POST['uid'] ?? 0); $act = $_POST['act'] ?? '';
    if ($uid && $uid != $_SESSION['user_id']) {
        if ($act === 'ban') { $pdo->prepare("UPDATE users SET status='banned' WHERE id=?")->execute([$uid]); $msg='User dibanned'; }
        elseif ($act === 'unban') { $pdo->prepare("UPDATE users SET status='active' WHERE id=?")->execute([$uid]); $msg='User diaktifkan'; }
        elseif ($act === 'add_saldo') {
            $amount = (int)($_POST['amount'] ?? 0);
            $pdo->prepare("UPDATE users SET saldo=saldo+?, total_income=total_income+? WHERE id=?")->execute([$amount, $amount, $uid]);
            $msg = "Saldo +" . rupiah($amount);
        } elseif ($act === 'reset_saldo') { $pdo->prepare("UPDATE users SET saldo=0 WHERE id=?")->execute([$uid]); $msg='Saldo direset'; }
        elseif ($act === 'delete') { $pdo->prepare("DELETE FROM users WHERE id=?")->execute([$uid]); $msg='User dihapus'; }
        elseif ($act === 'change_password') {
            $new = $_POST['new_password'] ?? '';
            if (strlen($new) < 6) $err = 'Password min 6';
            else { $pdo->prepare("UPDATE users SET password=? WHERE id=?")->execute([password_hash($new, PASSWORD_BCRYPT), $uid]); $msg = 'Password diubah!'; }
        }
        logAct($pdo, $_SESSION['user_id'], "Admin: $act user #$uid");
    }
}
$users = $pdo->query("SELECT * FROM users ORDER BY id DESC")->fetchAll();
$pageTitle = 'Users';
include __DIR__ . '/../includes/header.php';
include __DIR__ . '/../includes/navbar.php';
?>
<div class="container">
    <div class="page-head"><h1><i class="fas fa-users-cog"></i> Kelola User</h1></div>
    <?php if ($msg): ?><div class="alert alert-success"><?= $msg ?></div><?php endif; ?>
    <?php if ($err): ?><div class="alert alert-error"><?= $err ?></div><?php endif; ?>

    <div class="card">
        <table class="table">
            <thead><tr><th>ID</th><th>Username</th><th>Email</th><th>Role</th><th>Status</th><th>Saldo</th><th>Setor</th><th>TG</th></tr></thead>
            <tbody>
                <?php foreach ($users as $u): ?>
                <tr>
                    <td>#<?= $u['id'] ?></td>
                    <td><strong><?= htmlspecialchars($u['username']) ?></strong></td>
                    <td><small><?= htmlspecialchars($u['email']) ?></small></td>
                    <td><span class="badge badge-<?= $u['role'] ?>"><?= $u['role'] ?></span></td>
                    <td><span class="badge badge-<?= $u['status'] ?>"><?= $u['status'] ?></span></td>
                    <td><?= rupiah($u['saldo']) ?></td>
                    <td><?= (int)$u['total_submit'] ?></td>
                    <td><?= $u['tg_chat_id'] ? '<i class="fas fa-check" style="color:#229ED9"></i>' : '<i class="fas fa-minus" style="color:#555"></i>' ?></td>
                </tr>
                <tr class="row-actions">
                    <td colspan="8">
                        <?php if ($u['id'] != $_SESSION['user_id']): ?>
                        <form method="POST" class="inline-form" onsubmit="return confirm('Yakin?')">
                            <input type="hidden" name="csrf" value="<?= csrf() ?>">
                            <input type="hidden" name="uid" value="<?= $u['id'] ?>">
                            <?php if ($u['status']=='active'): ?>
                                <button name="act" value="ban" class="btn btn-sm btn-danger"><i class="fas fa-ban"></i> Ban</button>
                            <?php else: ?>
                                <button name="act" value="unban" class="btn btn-sm btn-ok"><i class="fas fa-check"></i> Unban</button>
                            <?php endif; ?>
                            <input type="number" name="amount" placeholder="Rp" style="width:90px;padding:4px 8px;border-radius:6px;border:1px solid var(--border);background:var(--bg);color:var(--text)">
                            <button name="act" value="add_saldo" class="btn btn-sm btn-primary"><i class="fas fa-plus"></i> Saldo</button>
                            <button name="act" value="reset_saldo" class="btn btn-sm btn-warn"><i class="fas fa-eraser"></i> Reset</button>
                            <input type="text" name="new_password" placeholder="Pass baru" style="width:110px;padding:4px 8px;border-radius:6px;border:1px solid var(--border);background:var(--bg);color:var(--text)">
                            <button name="act" value="change_password" class="btn btn-sm btn-info"><i class="fas fa-key"></i> Ganti Pass</button>
                            <button name="act" value="delete" class="btn btn-sm btn-danger"><i class="fas fa-trash"></i> Hapus</button>
                        </form>
                        <?php else: ?><span class="badge badge-info">Kamu (admin)</span><?php endif; ?>
                    </td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>
<?php include __DIR__ . '/../includes/footer.php'; ?>
PHPEOF

cat > "$WEB_ROOT/admin/logs.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
requireAdmin();
$logs = $pdo->query("SELECT l.*, u.username FROM activity_log l LEFT JOIN users u ON l.user_id=u.id ORDER BY l.id DESC LIMIT 300")->fetchAll();
$pageTitle = 'Logs';
include __DIR__ . '/../includes/header.php';
include __DIR__ . '/../includes/navbar.php';
?>
<div class="container">
    <div class="page-head"><h1><i class="fas fa-list-alt"></i> Activity Logs</h1><p>300 terakhir</p></div>
    <div class="card">
        <table class="table">
            <thead><tr><th>ID</th><th>User</th><th>Action</th><th>IP</th><th>Waktu</th></tr></thead>
            <tbody>
                <?php foreach ($logs as $l): ?>
                <tr><td>#<?= $l['id'] ?></td><td><?= htmlspecialchars($l['username'] ?? 'Guest') ?></td><td><?= htmlspecialchars($l['action']) ?></td><td><code><?= $l['ip'] ?></code></td><td><small><?= $l['created_at'] ?></small></td></tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>
<?php include __DIR__ . '/../includes/footer.php'; ?>
PHPEOF

cat > "$WEB_ROOT/admin/settings.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
requireAdmin();
$msg = ''; $err = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && checkCsrf($_POST['csrf'] ?? '')) {
    $act = $_POST['act'] ?? '';
    if ($act === 'general') {
        $keys = ['dana_admin','dana_name','harga_limit','harga_nonlimit_min','harga_nonlimit_max','min_withdraw','komisi_referral','banner_url'];
        foreach ($keys as $k) {
            if (isset($_POST[$k])) $pdo->prepare("UPDATE settings SET v=? WHERE k=?")->execute([trim($_POST[$k]), $k]);
        }
        $msg = 'Pengaturan umum disimpan!';
    } elseif ($act === 'telegram') {
        $token = trim($_POST['tg_bot_token'] ?? '');
        $username = trim($_POST['tg_bot_username'] ?? '');
        $username = ltrim($username, '@');
        $pdo->prepare("UPDATE settings SET v=? WHERE k='tg_bot_token'")->execute([$token]);
        $pdo->prepare("UPDATE settings SET v=? WHERE k='tg_bot_username'")->execute([$username]);
        $msg = 'Pengaturan Telegram disimpan!';
    } elseif ($act === 'test_telegram') {
        $test = tgSendMessage($pdo, $_POST['test_chat_id'] ?? '', "🧪 <b>Test Notifikasi</b>\n\nBot <b>" . SITE_NAME . "</b> aktif & siap kirim notifikasi!");
        if ($test) $msg = 'Test terkirim!';
        else $err = 'Gagal kirim test. Cek token & chat ID.';
    }
}

$pageTitle = 'Settings';
include __DIR__ . '/../includes/header.php';
include __DIR__ . '/../includes/navbar.php';
?>
<div class="container">
    <div class="page-head"><h1><i class="fas fa-cog"></i> Pengaturan</h1></div>
    <?php if ($msg): ?><div class="alert alert-success"><?= $msg ?></div><?php endif; ?>
    <?php if ($err): ?><div class="alert alert-error"><?= $err ?></div><?php endif; ?>

    <div class="card">
        <h2><i class="fab fa-telegram" style="color:#229ED9"></i> Telegram Bot</h2>
        <p style="color:var(--text-muted);margin-bottom:20px">Isi bot token & username dari @BotFather. Bot ini akan kirim notifikasi ke user saat setoran/withdraw diproses.</p>

        <form method="POST">
            <input type="hidden" name="csrf" value="<?= csrf() ?>">
            <input type="hidden" name="act" value="telegram">
            <div class="form-group">
                <label>Bot Token (dari @BotFather)</label>
                <input type="text" name="tg_bot_token" value="<?= htmlspecialchars(getSetting($pdo,'tg_bot_token','')) ?>" placeholder="1234567890:ABC-xxx...">
                <small style="color:var(--text-muted);font-size:.8em">Dapatkan dari @BotFather → /newbot</small>
            </div>
            <div class="form-group">
                <label>Bot Username (tanpa @)</label>
                <input type="text" name="tg_bot_username" value="<?= htmlspecialchars(getSetting($pdo,'tg_bot_username','')) ?>" placeholder="shellnumberwsbot">
            </div>
            <button class="btn btn-primary"><i class="fas fa-save"></i> Simpan Telegram Config</button>
        </form>

        <hr style="margin:25px 0;border:none;border-top:1px solid var(--border)">

        <h3 style="margin-bottom:15px">🧪 Test Notifikasi</h3>
        <form method="POST">
            <input type="hidden" name="csrf" value="<?= csrf() ?>">
            <input type="hidden" name="act" value="test_telegram">
            <div class="form-group"><label>Chat ID Kamu (dari @userinfobot)</label><input type="text" name="test_chat_id" placeholder="123456789"></div>
            <button class="btn btn-outline"><i class="fas fa-paper-plane"></i> Kirim Test</button>
        </form>

        <?php if (tgGetBotUsername($pdo)): ?>
        <div style="margin-top:20px;padding:15px;background:rgba(34,158,217,.1);border-radius:12px">
            <p><b>🔗 Link Bot:</b> <a href="https://t.me/<?= htmlspecialchars(tgGetBotUsername($pdo)) ?>" target="_blank">https://t.me/<?= htmlspecialchars(tgGetBotUsername($pdo)) ?></a></p>
            <p style="color:var(--text-muted);font-size:.85em;margin-top:8px">User akan klik link ini dari profile mereka untuk connect & dapat notifikasi.</p>
        </div>
        <?php endif; ?>
    </div>

    <div class="card">
        <h2><i class="fas fa-wallet"></i> Dana Admin & Harga</h2>
        <form method="POST">
            <input type="hidden" name="csrf" value="<?= csrf() ?>">
            <input type="hidden" name="act" value="general">
            <div class="grid-2">
                <div class="form-group"><label>Nomor Dana</label><input type="text" name="dana_admin" value="<?= htmlspecialchars(getSetting($pdo,'dana_admin','')) ?>"></div>
                <div class="form-group"><label>Nama Pemilik Dana</label><input type="text" name="dana_name" value="<?= htmlspecialchars(getSetting($pdo,'dana_name','')) ?>"></div>
                <div class="form-group"><label>Harga Limit (Rp)</label><input type="number" name="harga_limit" value="<?= (int)getSetting($pdo,'harga_limit',1000) ?>"></div>
                <div class="form-group"><label>Min Withdraw (Rp)</label><input type="number" name="min_withdraw" value="<?= (int)getSetting($pdo,'min_withdraw',1000) ?>"></div>
                <div class="form-group"><label>Non-Limit Min (Rp)</label><input type="number" name="harga_nonlimit_min" value="<?= (int)getSetting($pdo,'harga_nonlimit_min',1000) ?>"></div>
                <div class="form-group"><label>Non-Limit Max (Rp)</label><input type="number" name="harga_nonlimit_max" value="<?= (int)getSetting($pdo,'harga_nonlimit_max',5000) ?>"></div>
                <div class="form-group"><label>Komisi Referral (Rp)</label><input type="number" name="komisi_referral" value="<?= (int)getSetting($pdo,'komisi_referral',250) ?>"></div>
                <div class="form-group"><label>Banner URL</label><input type="text" name="banner_url" value="<?= htmlspecialchars(getSetting($pdo,'banner_url', BANNER_URL)) ?>"></div>
            </div>
            <button class="btn btn-primary btn-lg"><i class="fas fa-save"></i> Simpan</button>
        </form>
    </div>
</div>
<?php include __DIR__ . '/../includes/footer.php'; ?>
PHPEOF

echo -e "${GREEN}  ✓ Admin + TG config OK${NC}"

# ============ STEP 9: CSS ============
echo -e "${CYAN}[8/8] CSS mewah...${NC}"

cat > "$WEB_ROOT/assets/css/style.css" << 'CSSEOF'
:root {
    --bg:#0a0a1a; --bg-2:#12122a; --bg-card:rgba(30,30,60,.6);
    --bg-nav:rgba(15,15,35,.85); --text:#e8e8ff; --text-muted:#8888aa;
    --border:rgba(120,120,200,.15);
    --primary:#7c5cff; --primary-2:#b066ff;
    --gold:#ffb700; --gold-2:#ff8c00;
    --success:#00e676; --danger:#ff4757; --warning:#ffa726; --info:#29b6f6;
    --tg:#229ED9;
    --shadow:0 8px 40px rgba(0,0,0,.4);
    --glow:0 0 40px rgba(124,92,255,.4);
}
[data-theme="light"] {
    --bg:#f0f2ff; --bg-2:#e8ebff; --bg-card:rgba(255,255,255,.8);
    --bg-nav:rgba(255,255,255,.9); --text:#1a1a2e; --text-muted:#666688;
    --border:rgba(100,100,180,.15);
    --shadow:0 8px 40px rgba(80,80,180,.12);
}
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Plus Jakarta Sans',system-ui,sans-serif;background:var(--bg);color:var(--text);line-height:1.6;min-height:100vh;padding-bottom:70px;background-image:radial-gradient(circle at 20% 0%,rgba(124,92,255,.15),transparent 40%),radial-gradient(circle at 80% 100%,rgba(176,102,255,.1),transparent 40%)}
a{color:var(--primary);text-decoration:none;transition:.2s}
a:hover{color:var(--primary-2)}
img{max-width:100%}

/* NAVBAR */
.navbar{display:flex;justify-content:space-between;align-items:center;padding:14px 30px;background:var(--bg-nav);backdrop-filter:blur(20px);border-bottom:1px solid var(--border);position:sticky;top:0;z-index:100}
.logo{display:flex;align-items:center;gap:10px;font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:1.15em}
.logo-icon{font-size:1.5em}
.logo-accent{background:linear-gradient(135deg,var(--primary),var(--primary-2));-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text}
.nav-menu{display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.nav-menu a{color:var(--text-muted);font-weight:600;padding:8px 14px;border-radius:10px;display:flex;align-items:center;gap:6px;font-size:.9em}
.nav-menu a:hover{color:var(--text);background:rgba(124,92,255,.1)}
.icon-btn{background:transparent;border:1px solid var(--border);color:var(--text);padding:8px 12px;border-radius:10px;cursor:pointer}
.icon-btn:hover{border-color:var(--primary);background:rgba(124,92,255,.1)}

/* BUTTONS */
.btn{padding:10px 20px;border-radius:12px;border:none;cursor:pointer;font-weight:700;font-family:inherit;display:inline-flex;align-items:center;gap:8px;transition:.25s;font-size:.9em;text-decoration:none}
.btn-primary{background:linear-gradient(135deg,var(--primary),var(--primary-2));color:#fff;box-shadow:0 4px 20px rgba(124,92,255,.4)}
.btn-primary:hover{transform:translateY(-2px);box-shadow:0 8px 30px rgba(124,92,255,.6)}
.btn-outline{background:transparent;border:2px solid var(--primary);color:var(--primary)}
.btn-outline:hover{background:var(--primary);color:#fff}
.btn-gold{background:linear-gradient(135deg,var(--gold),var(--gold-2));color:#000;box-shadow:0 4px 20px rgba(255,183,0,.4)}
.btn-gold:hover{transform:translateY(-2px)}
.btn-tg{background:var(--tg);color:#fff;box-shadow:0 4px 20px rgba(34,158,217,.4)}
.btn-tg:hover{background:#1a8bc4;transform:translateY(-2px)}
.btn-danger{background:var(--danger);color:#fff}
.btn-ok{background:var(--success);color:#000}
.btn-warn{background:var(--warning);color:#000}
.btn-info{background:var(--info);color:#fff}
.btn-block{width:100%;justify-content:center}
.btn-lg{padding:14px 32px;font-size:1.05em}
.btn-sm{padding:6px 12px;font-size:.8em}
.btn-icon{background:rgba(255,255,255,.05);border:1px solid var(--border);padding:8px 12px;border-radius:8px;cursor:pointer;color:var(--text)}
.btn-icon:hover{color:#fff;transform:scale(1.05)}
.btn-icon.btn-ok:hover{background:var(--success);color:#000}
.btn-icon.btn-danger:hover{background:var(--danger);color:#fff}
.btn-icon.btn-warn:hover{background:var(--warning);color:#000}
.btn-icon.btn-info:hover{background:var(--info);color:#fff}

.pulse-btn{position:relative;overflow:hidden}
.pulse-btn::before{content:'';position:absolute;inset:0;background:radial-gradient(circle,rgba(255,255,255,.3),transparent 70%);animation:pulse 2s infinite}
@keyframes pulse{0%{transform:scale(.8);opacity:1}100%{transform:scale(1.5);opacity:0}}

/* HERO */
.hero{min-height:80vh;display:flex;align-items:center;justify-content:center;text-align:center;padding:60px 20px;position:relative;overflow:hidden}
.hero-bg{position:absolute;inset:0;z-index:-1;background:radial-gradient(circle at 30% 20%,rgba(124,92,255,.3),transparent 45%),radial-gradient(circle at 70% 80%,rgba(255,183,0,.15),transparent 45%)}
.hero-content{max-width:850px;z-index:1}
.hero-badge{display:inline-flex;align-items:center;gap:6px;background:rgba(124,92,255,.15);border:1px solid rgba(124,92,255,.3);padding:8px 18px;border-radius:30px;font-size:.85em;color:var(--primary-2);margin-bottom:25px;font-weight:600}
.hero h1{font-family:'Space Grotesk',sans-serif;font-size:3.8em;line-height:1.1;font-weight:800;margin-bottom:20px}
.gradient-text{background:linear-gradient(135deg,#7c5cff,#b066ff,#ff6b9d);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text;display:block}
.hero-line{display:block;color:var(--text)}
.hero-sub{font-size:1.1em;color:var(--text-muted);margin-bottom:35px;max-width:650px;margin-left:auto;margin-right:auto}
.hero-actions{display:flex;gap:15px;justify-content:center;flex-wrap:wrap;margin-bottom:50px}
.hero-stats{display:flex;gap:40px;justify-content:center;flex-wrap:wrap}
.hs-item{text-align:center}
.hs-item strong{display:block;font-size:1.6em;font-family:'Space Grotesk',sans-serif;color:var(--primary-2)}
.hs-item span{font-size:.85em;color:var(--text-muted)}

/* BANNER */
.banner-section{max-width:1100px;margin:0 auto;padding:40px 20px}
.banner-card{background:var(--bg-card);backdrop-filter:blur(20px);border:1px solid var(--border);border-radius:22px;overflow:hidden;box-shadow:var(--shadow);transition:.3s}
.banner-card:hover{transform:translateY(-5px);box-shadow:0 15px 60px rgba(124,92,255,.3);border-color:var(--primary)}
.banner-img{width:100%;height:auto;display:block}

/* SECTIONS */
.section{max-width:1200px;margin:0 auto;padding:60px 20px}
.section-head{text-align:center;margin-bottom:45px}
.section-head h2{font-family:'Space Grotesk',sans-serif;font-size:2.1em;margin-bottom:10px}
.section-head h2 i{color:var(--primary)}
.section-head p{color:var(--text-muted)}

.features{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:20px}
.feature-card{background:var(--bg-card);backdrop-filter:blur(20px);padding:30px;border-radius:20px;border:1px solid var(--border);text-align:center;transition:.3s}
.feature-card:hover{transform:translateY(-5px);border-color:var(--primary);box-shadow:var(--glow)}
.fc-icon{width:70px;height:70px;border-radius:20px;margin:0 auto 20px;display:flex;align-items:center;justify-content:center;color:#fff;font-size:1.8em}
.feature-card h3{margin-bottom:10px;font-family:'Space Grotesk',sans-serif}
.feature-card p{color:var(--text-muted);font-size:.92em}

.price-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:20px}
.price-card{background:var(--bg-card);backdrop-filter:blur(20px);padding:30px;border-radius:22px;border:1px solid var(--border);position:relative;transition:.3s}
.price-card:hover{transform:translateY(-5px);border-color:var(--primary)}
.price-featured{border-color:var(--gold);background:linear-gradient(135deg,rgba(255,183,0,.1),rgba(255,140,0,.05))}
.pc-badge{position:absolute;top:-12px;right:20px;background:linear-gradient(135deg,var(--gold),var(--gold-2));color:#000;padding:5px 14px;border-radius:20px;font-size:.75em;font-weight:800}
.pc-flag{font-size:3em;text-align:center;margin-bottom:15px}
.price-card h3{text-align:center;margin-bottom:8px;font-family:'Space Grotesk',sans-serif}
.pc-desc{text-align:center;color:var(--text-muted);font-size:.9em;margin-bottom:20px}
.pc-price{text-align:center;font-size:1.8em;font-family:'Space Grotesk',sans-serif;color:var(--primary-2);font-weight:800;margin-bottom:20px}
.price-featured .pc-price{color:var(--gold)}
.pc-list{list-style:none;margin-bottom:20px}
.pc-list li{padding:8px 0;border-bottom:1px solid var(--border);display:flex;align-items:center;gap:8px;font-size:.9em}
.pc-list li:last-child{border-bottom:none}
.pc-list i{color:var(--success)}
.price-card form textarea,.price-card form input{font-size:.9em;padding:10px}

/* TOP10 */
.top10-card{background:var(--bg-card);backdrop-filter:blur(20px);border-radius:20px;border:1px solid var(--border);padding:20px;max-width:700px;margin:0 auto}
.top10-item{display:flex;align-items:center;gap:15px;padding:12px 16px;border-bottom:1px solid var(--border)}
.top10-item:last-child{border-bottom:none}
.top10-top{background:linear-gradient(90deg,rgba(255,183,0,.08),transparent)}
.t10-rank{font-size:1.4em;font-weight:800;width:45px;text-align:center}
.t10-user{flex:1}
.t10-income{font-weight:800;color:var(--success);font-family:'Space Grotesk',sans-serif}

/* TG PROMO */
.tg-promo-box{background:linear-gradient(135deg,rgba(34,158,217,.15),rgba(34,158,217,.05));border:2px solid rgba(34,158,217,.4);border-radius:22px;padding:30px;display:flex;align-items:center;gap:25px;flex-wrap:wrap;justify-content:center;text-align:center}
.tg-promo-icon{font-size:5em;color:var(--tg)}
.tg-promo-right{flex:1;min-width:250px}
.tg-promo-right h3{font-family:'Space Grotesk',sans-serif;font-size:1.5em;margin-bottom:10px}
.tg-promo-right p{color:var(--text-muted);margin-bottom:15px}

/* STEPS */
.steps{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:20px;max-width:1100px;margin:0 auto}
.step-item{background:var(--bg-card);padding:25px;border-radius:18px;border:1px solid var(--border);text-align:center;transition:.2s}
.step-item:hover{border-color:var(--primary);transform:translateY(-3px)}
.step-num{width:50px;height:50px;border-radius:50%;background:linear-gradient(135deg,var(--primary),var(--primary-2));color:#fff;font-size:1.3em;font-weight:800;display:flex;align-items:center;justify-content:center;margin:0 auto 15px;font-family:'Space Grotesk',sans-serif}
.step-item h4{margin-bottom:5px;font-family:'Space Grotesk',sans-serif}
.step-item p{color:var(--text-muted);font-size:.85em}

/* CTA FINAL */
.cta-final{max-width:900px;margin:60px auto;padding:0 20px}
.cta-box{background:linear-gradient(135deg,var(--primary),var(--primary-2));padding:50px 30px;border-radius:25px;text-align:center;box-shadow:0 20px 60px rgba(124,92,255,.4);position:relative;overflow:hidden}
.cta-box::before{content:'';position:absolute;inset:0;background:radial-gradient(circle at 30% 30%,rgba(255,255,255,.2),transparent 50%)}
.cta-box h2{color:#fff;font-family:'Space Grotesk',sans-serif;font-size:2em;margin-bottom:10px;position:relative}
.cta-box p{color:rgba(255,255,255,.9);margin-bottom:25px;position:relative}
.cta-box .btn{position:relative}

/* AUTH */
.auth-wrap{min-height:80vh;display:flex;align-items:center;justify-content:center;padding:40px 20px}
.auth-card{background:var(--bg-card);backdrop-filter:blur(20px);padding:45px 40px;border-radius:25px;border:1px solid var(--border);width:100%;max-width:440px;box-shadow:var(--shadow)}
.auth-card-lg{max-width:520px}
.auth-icon{width:70px;height:70px;border-radius:20px;margin:0 auto 20px;background:linear-gradient(135deg,var(--primary),var(--primary-2));display:flex;align-items:center;justify-content:center;color:#fff;font-size:1.7em;box-shadow:0 8px 30px rgba(124,92,255,.4)}
.auth-card h1{text-align:center;font-family:'Space Grotesk',sans-serif;margin-bottom:8px}
.auth-sub{text-align:center;color:var(--text-muted);margin-bottom:30px;font-size:.9em}
.auth-footer{text-align:center;color:var(--text-muted);margin-top:25px;font-size:.9em}

/* TOS */
.tos-checkbox{background:rgba(124,92,255,.08);border:1px solid rgba(124,92,255,.2);border-radius:12px;padding:15px;margin:15px 0}
.tos-label{display:flex;gap:12px;cursor:pointer;align-items:flex-start}
.tos-label input[type="checkbox"]{width:22px;height:22px;margin-top:2px;cursor:pointer;accent-color:var(--primary);flex-shrink:0}
.tos-text{font-size:.9em;color:var(--text-muted);line-height:1.5}
.tos-text a{font-weight:700}
.tos-text b{color:var(--text)}

/* TERMS PAGE */
.terms-card h2{font-family:'Space Grotesk',sans-serif;font-size:1.3em;margin-top:25px;margin-bottom:12px;color:var(--primary-2)}
.terms-card h2:first-child{margin-top:0}
.terms-card p,.terms-card li{color:var(--text-muted);margin-bottom:10px}
.terms-card ul{margin-left:25px;margin-bottom:15px}
.terms-card li{margin-bottom:6px}
.terms-footer{background:rgba(124,92,255,.1);border:1px solid rgba(124,92,255,.3);padding:20px;border-radius:12px;margin-top:30px}
.terms-footer p{margin:0;color:var(--primary-2);font-weight:600}

/* FORMS */
.form-group{margin-bottom:18px}
.form-group label{display:block;margin-bottom:8px;font-weight:600;font-size:.9em}
.form-group input,.form-input,.form-group textarea,.form-group select{width:100%;padding:13px 16px;border:1px solid var(--border);border-radius:12px;background:rgba(0,0,0,.2);color:var(--text);font-size:.95em;font-family:inherit}
.form-group input:focus,.form-input:focus{outline:none;border-color:var(--primary);box-shadow:0 0 0 4px rgba(124,92,255,.15)}
[data-theme="light"] .form-group input,[data-theme="light"] .form-input{background:rgba(255,255,255,.7)}

/* ALERTS */
.alert{padding:14px 18px;border-radius:12px;margin-bottom:20px;font-size:.9em;display:flex;align-items:center;gap:10px;flex-wrap:wrap}
.alert-success{background:rgba(0,230,118,.1);color:var(--success);border-left:4px solid var(--success)}
.alert-error{background:rgba(255,71,87,.1);color:var(--danger);border-left:4px solid var(--danger)}
.alert-warning{background:rgba(255,167,38,.15);color:var(--warning);border-left:4px solid var(--warning)}
.pulse-warn{animation:pulseWarn 2s infinite}
@keyframes pulseWarn{0%,100%{box-shadow:0 0 0 0 rgba(255,167,38,.4)}50%{box-shadow:0 0 0 10px rgba(255,167,38,0)}}

/* CONTAINER */
.container{max-width:1200px;margin:0 auto;padding:30px 20px}
.page-head{margin-bottom:30px}
.page-head h1{font-family:'Space Grotesk',sans-serif;font-size:1.9em;display:flex;align-items:center;gap:12px}
.page-head h1 i{color:var(--primary)}
.page-head p{color:var(--text-muted);margin-top:5px}

.card{background:var(--bg-card);backdrop-filter:blur(20px);padding:28px;border-radius:20px;border:1px solid var(--border);margin-bottom:25px;box-shadow:var(--shadow)}
.card h2{font-family:'Space Grotesk',sans-serif;margin-bottom:20px;font-size:1.3em;display:flex;align-items:center;gap:10px}
.card h2 i{color:var(--primary)}

.stats-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:18px;margin-bottom:25px}
.stat-card{background:var(--bg-card);backdrop-filter:blur(20px);padding:22px;border-radius:18px;border:1px solid var(--border);display:flex;align-items:center;gap:16px;transition:.25s}
.stat-card:hover{transform:translateY(-3px);border-color:var(--primary)}
.stat-icon{width:55px;height:55px;border-radius:14px;display:flex;align-items:center;justify-content:center;color:#fff;font-size:1.5em;flex-shrink:0}
.stat-info h3{font-size:1.4em;font-family:'Space Grotesk',sans-serif;margin:0}
.stat-info p{color:var(--text-muted);font-size:.85em;margin:0}

.welcome-card{background:linear-gradient(135deg,rgba(124,92,255,.2),rgba(176,102,255,.1));border:1px solid rgba(124,92,255,.3);border-radius:22px;padding:28px;display:flex;justify-content:space-between;align-items:center;margin-bottom:25px;gap:20px;flex-wrap:wrap}
.wc-left{display:flex;align-items:center;gap:18px}
.wc-avatar{width:70px;height:70px;border-radius:20px;background:linear-gradient(135deg,var(--primary),var(--primary-2));display:flex;align-items:center;justify-content:center;font-size:1.8em;font-weight:800;color:#fff;box-shadow:0 8px 30px rgba(124,92,255,.5)}
.welcome-card h1{font-family:'Space Grotesk',sans-serif;font-size:1.5em;margin-bottom:5px}

.table{width:100%;border-collapse:collapse}
.table th{text-align:left;padding:13px 12px;font-size:.78em;letter-spacing:.5px;text-transform:uppercase;color:var(--text-muted);border-bottom:2px solid var(--border);background:rgba(0,0,0,.2)}
.table td{padding:13px 12px;border-bottom:1px solid var(--border);font-size:.9em}
.table tr:hover td{background:rgba(124,92,255,.05)}
.table code{background:rgba(124,92,255,.15);padding:3px 8px;border-radius:6px;font-size:.85em;color:var(--primary-2)}
.row-actions td{background:rgba(0,0,0,.15);padding:8px 12px}
.inline-form{display:flex;gap:6px;flex-wrap:wrap;align-items:center}

.badge{padding:4px 12px;border-radius:20px;font-size:.72em;font-weight:800;text-transform:uppercase;display:inline-flex;align-items:center;gap:5px}
.badge-admin{background:rgba(255,71,87,.15);color:var(--danger)}
.badge-user{background:rgba(41,182,246,.15);color:var(--info)}
.badge-active{background:rgba(0,230,118,.15);color:var(--success)}
.badge-banned{background:rgba(255,71,87,.15);color:var(--danger)}
.badge-pending{background:rgba(255,167,38,.15);color:var(--warning)}
.badge-approved{background:rgba(0,230,118,.15);color:var(--success)}
.badge-rejected{background:rgba(255,71,87,.15);color:var(--danger)}
.badge-sold{background:rgba(120,120,150,.15);color:var(--text-muted)}
.badge-info{background:rgba(124,92,255,.15);color:var(--primary-2)}

.grid-2{display:grid;grid-template-columns:1fr 1fr;gap:20px}
@media (max-width:800px){.grid-2{grid-template-columns:1fr}}

.log-item{display:flex;gap:12px;padding:12px 0;border-bottom:1px solid var(--border);font-size:.9em;align-items:flex-start}
.log-item:last-child{border-bottom:none}
.log-item i{color:var(--primary);margin-top:4px;flex-shrink:0}
.log-item small{color:var(--text-muted);font-size:.8em}

.dana-box{background:linear-gradient(135deg,rgba(41,182,246,.1),rgba(41,182,246,.05));border:1px solid rgba(41,182,246,.3);border-radius:18px;padding:20px;margin-bottom:25px}
.db-head{display:flex;align-items:center;gap:10px;font-weight:800;color:var(--info);margin-bottom:15px;font-size:1.1em}
.dana-list{list-style:none;padding-left:5px}
.dana-list li{padding:6px 0;color:var(--text-muted);font-size:.9em}

.tabs{display:flex;gap:8px;margin-bottom:20px;flex-wrap:wrap}
.tab{padding:10px 18px;border-radius:12px;border:1px solid var(--border);background:var(--bg-card);color:var(--text-muted);font-weight:600;cursor:pointer;transition:.2s;text-decoration:none;display:inline-flex;align-items:center;gap:6px;font-size:.9em}
.tab:hover,.tab.active{background:var(--primary);color:#fff;border-color:var(--primary)}
.tab-content{display:none}
.tab-content.active{display:block}

.riwayat-item{display:flex;justify-content:space-between;gap:15px;padding:15px 0;border-bottom:1px solid var(--border);flex-wrap:wrap}
.riwayat-item:last-child{border-bottom:none}
.ri-left{display:flex;gap:12px;align-items:flex-start}
.ri-status{width:40px;height:40px;border-radius:50%;display:flex;align-items:center;justify-content:center;flex-shrink:0}
.ri-status.ri-approved{background:rgba(0,230,118,.2);color:var(--success)}
.ri-status.ri-rejected{background:rgba(255,71,87,.2);color:var(--danger)}
.ri-status.ri-pending{background:rgba(255,167,38,.2);color:var(--warning)}
.ri-right{text-align:right;display:flex;flex-direction:column;gap:5px;align-items:flex-end}
.ri-price{font-weight:800;color:var(--primary-2);font-family:'Space Grotesk',sans-serif}

.admin-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:18px;margin-bottom:25px}
.admin-card{background:var(--bg-card);backdrop-filter:blur(20px);padding:25px;border-radius:20px;border:1px solid var(--border);text-align:center;transition:.25s;color:var(--text)}
.admin-card:hover{transform:translateY(-4px);border-color:var(--primary);box-shadow:var(--glow)}
.admin-card i{font-size:2.3em;color:var(--primary);margin-bottom:12px;display:block}
.admin-card h3{font-family:'Space Grotesk',sans-serif;margin-bottom:5px}
.admin-card p{color:var(--text-muted);font-size:.85em}
.admin-card-alert{border-color:var(--warning);background:linear-gradient(135deg,rgba(255,167,38,.15),rgba(255,167,38,.05))}
.admin-card-alert i{color:var(--warning)}

.big-number{font-size:2.5em;font-family:'Space Grotesk',sans-serif;color:var(--success);font-weight:800;text-align:center;padding:20px 0}

.profile-head{display:flex;gap:20px;align-items:center;margin-bottom:25px}
.profile-avatar{width:80px;height:80px;border-radius:24px;background:linear-gradient(135deg,var(--primary),var(--primary-2));display:flex;align-items:center;justify-content:center;font-size:2em;font-weight:800;color:#fff;box-shadow:0 8px 30px rgba(124,92,255,.5);flex-shrink:0}
.profile-head h2{font-family:'Space Grotesk',sans-serif;font-size:1.4em;margin-bottom:3px}
.profile-head p{color:var(--text-muted);font-size:.9em;margin-bottom:8px}
.profile-info{display:flex;flex-direction:column;gap:12px}
.pi-row{display:flex;justify-content:space-between;padding:10px 0;border-bottom:1px solid var(--border);font-size:.9em}
.pi-row:last-child{border-bottom:none}
.pi-row span{color:var(--text-muted)}

.ref-link-box{display:flex;gap:10px}
.ref-link-box input{flex:1;padding:13px 16px;border:1px solid var(--border);border-radius:12px;background:rgba(0,0,0,.2);color:var(--primary-2);font-family:'Space Grotesk',monospace;font-size:.9em}

/* TELEGRAM CONNECT */
.tg-status{display:flex;gap:12px;padding:15px;border-radius:12px;background:rgba(34,158,217,.1);border:1px solid rgba(34,158,217,.3);margin-bottom:15px}
.tg-status i{color:var(--tg);font-size:1.5em;margin-top:5px}
.tg-status-ok i{color:var(--success)}
.tg-status strong{display:block;margin-bottom:5px}
.tg-status p{color:var(--text-muted);font-size:.85em;margin:3px 0}
.tg-status code{background:rgba(34,158,217,.2);padding:2px 8px;border-radius:6px;font-size:.85em;color:var(--tg)}
.tg-connect-box{margin:15px 0}
.tg-instruction{background:rgba(0,0,0,.2);padding:15px;border-radius:12px;font-size:.88em;color:var(--text-muted)}
.tg-instruction p{margin-bottom:8px;color:var(--text)}
.tg-instruction ol{margin-left:20px}
.tg-instruction li{margin-bottom:4px}

.empty{text-align:center;color:var(--text-muted);padding:25px;font-style:italic}

.bottom-nav{position:fixed;bottom:0;left:0;right:0;display:flex;justify-content:space-around;align-items:center;background:var(--bg-nav);backdrop-filter:blur(20px);border-top:1px solid var(--border);padding:8px 0;z-index:99;box-shadow:0 -4px 30px rgba(0,0,0,.3)}
.bn-item{display:flex;flex-direction:column;align-items:center;gap:3px;padding:6px 12px;color:var(--text-muted);font-size:.7em;font-weight:600;border-radius:10px;transition:.2s;min-width:55px}
.bn-item i{font-size:1.3em}
.bn-item:hover,.bn-item.active{color:var(--primary)}
@media (min-width:768px){.bottom-nav{display:none}body{padding-bottom:0}}

.footer{margin-top:60px;padding:40px 20px;border-top:1px solid var(--border);background:rgba(0,0,0,.2);text-align:center}
.footer-content{max-width:1200px;margin:0 auto}
.footer-brand{display:flex;align-items:center;justify-content:center;gap:10px;font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:1.1em;margin-bottom:15px}
.footer p{color:var(--text-muted);font-size:.9em;margin-bottom:15px}
.footer-links{display:flex;gap:20px;justify-content:center;flex-wrap:wrap}
.footer-links a{color:var(--text-muted);font-size:.9em}

@media (max-width:768px){
    .hero h1{font-size:2.3em}
    .hero-sub{font-size:.95em}
    .navbar{padding:12px 16px}
    .nav-menu{gap:4px}
    .nav-menu a{padding:6px 10px;font-size:.85em}
    .logo-text{display:none}
    .container{padding:20px 15px}
    .section{padding:45px 15px}
    .auth-card{padding:30px 25px}
    .welcome-card{padding:20px}
    .welcome-card h1{font-size:1.2em}
    .stat-card{padding:16px}
    .stat-info h3{font-size:1.2em}
    .table{font-size:.82em}
    .table th,.table td{padding:8px 6px}
    .card{padding:20px}
    .big-number{font-size:1.8em}
    .ref-link-box{flex-direction:column}
    .row-actions form{flex-direction:column}
    .inline-form button{flex:1}
    .tg-promo-icon{font-size:3.5em}
    .cta-box h2{font-size:1.5em}
}
CSSEOF

cat > "$WEB_ROOT/assets/js/main.js" << 'JSEOF'
const tt = document.getElementById('themeToggle');
const saved = localStorage.getItem('theme') || 'dark';
document.documentElement.setAttribute('data-theme', saved);
if (tt) {
    const icon = tt.querySelector('i');
    if (icon) icon.className = saved === 'dark' ? 'fas fa-sun' : 'fas fa-moon';
    tt.addEventListener('click', () => {
        const c = document.documentElement.getAttribute('data-theme');
        const n = c === 'dark' ? 'light' : 'dark';
        document.documentElement.setAttribute('data-theme', n);
        localStorage.setItem('theme', n);
        if (icon) icon.className = n === 'dark' ? 'fas fa-sun' : 'fas fa-moon';
    });
}

// Bottom nav active
const path = location.pathname;
document.querySelectorAll('.bn-item').forEach(el => {
    const href = el.getAttribute('href');
    if (href && href !== '/' && path.startsWith(href)) el.classList.add('active');
    else if (href === '/' && path === '/') el.classList.add('active');
});
JSEOF

echo -e "${GREEN}  ✓ CSS OK${NC}"

# ============ STEP 10: NGINX ============
echo -e "${CYAN}[9/9] Nginx & SSL...${NC}"

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
    location ~ /\.(?!well-known).* { deny all; }
    location ~* \.(env|log|sql|md)\$ { deny all; }
    location = /includes/config.php { deny all; }

    access_log /var/log/nginx/$SUBDOMAIN.access.log;
    error_log /var/log/nginx/$SUBDOMAIN.error.log;
}
NGINXEOF

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/ 2>/dev/null
[[ -f /etc/nginx/sites-enabled/default ]] && rm -f /etc/nginx/sites-enabled/default

if nginx -t >/dev/null 2>&1; then
    systemctl reload nginx
    echo -e "${GREEN}  ✓ Nginx OK${NC}"
else
    echo -e "${RED}  ✗ Nginx error!${NC}"; nginx -t; exit 1
fi

chown -R www-data:www-data "$WEB_ROOT"
chmod -R 755 "$WEB_ROOT"
chmod 640 "$WEB_ROOT/includes/config.php"
chmod -R 775 "$WEB_ROOT/uploads"
systemctl restart php8.3-fpm
echo -e "${GREEN}  ✓ Permission OK${NC}"

# SSL
SERVER_IP=$(curl -4 -s --max-time 5 ifconfig.me 2>/dev/null)
DOMAIN_IP=$(dig +short A "$SUBDOMAIN" @8.8.8.8 2>/dev/null | head -1)
[[ -z "$DOMAIN_IP" ]] && DOMAIN_IP=$(getent ahostsv4 "$SUBDOMAIN" 2>/dev/null | awk '{print $1}' | head -1)

SSL_STATUS="dilewati"
if [[ "$SERVER_IP" == "$DOMAIN_IP" ]] || [[ -f "/etc/letsencrypt/live/$SUBDOMAIN/fullchain.pem" ]]; then
    apt install certbot python3-certbot-nginx -y -qq 2>/dev/null
    if certbot --nginx -d "$SUBDOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect >/dev/null 2>&1; then
        SSL_STATUS="aktif ✅"
    fi
fi

command -v ufw >/dev/null 2>&1 && { ufw allow 80/tcp >/dev/null 2>&1; ufw allow 443/tcp >/dev/null 2>&1; }

PROTO="https"; [[ "$SSL_STATUS" == "dilewati" ]] && PROTO="http"

clear
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ INSTALLASI BERHASIL!                    ║${NC}"
echo -e "${GREEN}║  📱 RENDZZ NOKOS v5.0 + TELEGRAM            ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🔗 URL:${NC}"
echo -e "  🏠 Home       : $PROTO://$SUBDOMAIN"
echo -e "  🔐 Login      : $PROTO://$SUBDOMAIN/login.php"
echo -e "  📝 Register   : $PROTO://$SUBDOMAIN/register.php"
echo -e "  🛡️  Admin      : $PROTO://$SUBDOMAIN/admin/"
echo ""
echo -e "${MAGENTA}🔑 Admin:${NC}"
echo -e "  👤 User : $ADMIN_USER"
echo -e "  🔑 Pass : $ADMIN_PASS"
echo ""
echo -e "${CYAN}🤖 Telegram Bot:${NC}"
if [[ -n "$BOT_TOKEN" && -n "$BOT_USERNAME" ]]; then
    echo -e "  ✅ Terkonfigurasi: @$BOT_USERNAME"
    echo -e "  🔗 Link: https://t.me/$BOT_USERNAME"
else
    echo -e "  ⚠️  Belum dikonfigurasi. Isi di /admin/settings.php"
fi
echo ""
echo -e "${CYAN}📌 Cara Setup Telegram (kalau belum):${NC}"
echo -e "  1. Buka @BotFather di Telegram"
echo -e "  2. /newbot → dapat token"
echo -e "  3. Login admin → /admin/settings.php"
echo -e "  4. Isi bot token & username"
echo ""
echo -e "${GREEN}🎉 Done! Semua fitur siap pakai! 🚀${NC}"
