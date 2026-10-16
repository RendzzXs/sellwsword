#!/bin/bash
# ============================================
#   📱 SELL WS WORD v8.0 — FULL INSTALLER
#   Nomor → Popup OTP (WA Device) → Saldo
#   Animated Counter + Auto Increment + Full Admin
# ============================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

[[ $EUID -ne 0 ]] && { echo -e "${RED}❌ Harus root!${NC}"; exit 1; }

clear
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  📱 SELL WS WORD v8.0 — FULL INSTALLER     ║${NC}"
echo -e "${CYAN}║  Nomor → Popup OTP (WA Device) → Saldo     ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

read -p "👉 Subdomain (contoh: sellws.domain.com): " SUBDOMAIN
[[ -z "$SUBDOMAIN" ]] && { echo -e "${RED}❌ Kosong!${NC}"; exit 1; }

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

DB_PASS=$(openssl rand -hex 12)
DB_NAME="sellws_$(echo $SUBDOMAIN | tr '.' '_' | cut -c1-15)"
WEB_ROOT="/var/www/$SUBDOMAIN"
NGINX_CONF="/etc/nginx/sites-available/$SUBDOMAIN"

echo ""
echo -e "${CYAN}📋 Summary:${NC}"
echo "  Subdomain : $SUBDOMAIN"
echo "  Web Root  : $WEB_ROOT"
echo "  Database  : $DB_NAME"
echo "  Admin     : $ADMIN_USER / $ADMIN_PASS"
echo "  Dana      : $DANA_ADMIN ($DANA_NAME)"
echo "  TG Bot    : $([[ -n "$BOT_TOKEN" ]] && echo "✅ Set" || echo "⏭️ Skip")"
echo ""
read -p "Lanjut? (y/n): " C
[[ "$C" != "y" && "$C" != "Y" ]] && exit 0

# ============ STEP 1: PACKAGES ============
echo ""
echo -e "${CYAN}[1/9] Install packages...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt update -qq 2>/dev/null
apt install nginx php8.3-fpm php8.3-mysql php8.3-mbstring php8.3-curl php8.3-xml php8.3-zip php8.3-gd mysql-server curl wget unzip -y -qq 2>/dev/null

rm -f /etc/mysql/FROZEN 2>/dev/null
systemctl enable mysql nginx php8.3-fpm >/dev/null 2>&1
systemctl start mysql nginx php8.3-fpm >/dev/null 2>&1

if ! systemctl is-active --quiet mysql; then
    echo -e "${YELLOW}  → Fix MySQL...${NC}"
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
echo -e "${CYAN}[2/9] Database...${NC}"
mysql -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;" 2>/dev/null
mysql -e "CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS 'sellws'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "CREATE USER IF NOT EXISTS 'sellws'@'127.0.0.1' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO 'sellws'@'localhost';"
mysql -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO 'sellws'@'127.0.0.1';"
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
    status ENUM('pending','waiting_otp','otp_sent','approved','rejected') DEFAULT 'pending',
    otp_code VARCHAR(20) DEFAULT NULL,
    otp_submitted_at DATETIME DEFAULT NULL,
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
('tg_bot_username', 'TG_USERNAME_PLACEHOLDER'),
('auto_increment', '1'),
('last_auto_inc', '0'),
('boost_users', '0'),
('boost_subs', '0'),
('boost_paid', '0');
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
echo -e "${CYAN}[3/9] Folder...${NC}"
[[ -d "$WEB_ROOT" ]] && mv "$WEB_ROOT" "/var/www/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$WEB_ROOT"/{admin,user,api,includes,assets/{css,js},uploads}
echo -e "${GREEN}  ✓ Folder OK${NC}"

# ============ STEP 4: CONFIG ============
echo -e "${CYAN}[4/9] Config...${NC}"
cat > "$WEB_ROOT/includes/config.php" << PHPEOF
<?php
session_start();
date_default_timezone_set('Asia/Jakarta');

define('DB_HOST', 'localhost');
define('DB_NAME', '$DB_NAME');
define('DB_USER', 'sellws');
define('DB_PASS', '$DB_PASS');
define('SITE_URL', 'https://$SUBDOMAIN');
define('SITE_NAME', 'Sell Ws Word');
define('MIN_WITHDRAW', 1000);
define('BANNER_URL', '$BANNER_URL');
define('TG_BOT_BASE', 'https://t.me');

try {
    \$pdo = new PDO("mysql:host=".DB_HOST.";dbname=".DB_NAME.";charset=utf8mb4", DB_USER, DB_PASS, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
} catch (PDOException \$e) { die("DB Error: " . \$e->getMessage()); }

require_once __DIR__ . '/helpers.php';

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

function tgSendMessage(\$pdo, \$chatId, \$text, \$opts = []) {
    if (!\$chatId) return false;
    \$token = getSetting(\$pdo, 'tg_bot_token', '');
    if (!\$token) return false;
    \$url = "https://api.telegram.org/bot\$token/sendMessage";
    \$payload = array_merge(['chat_id'=>\$chatId,'text'=>\$text,'parse_mode'=>'HTML','disable_web_page_preview'=>true], \$opts);
    \$ch = curl_init(\$url);
    curl_setopt_array(\$ch, [CURLOPT_POST=>true,CURLOPT_RETURNTRANSFER=>true,CURLOPT_TIMEOUT=>15,CURLOPT_HTTPHEADER=>['Content-Type: application/json'],CURLOPT_POSTFIELDS=>json_encode(\$payload),CURLOPT_SSL_VERIFYPEER=>false]);
    \$res = curl_exec(\$ch); curl_close(\$ch);
    return \$res;
}

function tgGetBotUsername(\$pdo) { return ltrim(getSetting(\$pdo, 'tg_bot_username', ''), '@'); }
function tgGetConnectLink(\$pdo, \$token) {
    \$u = tgGetBotUsername(\$pdo);
    if (!\$u) return null;
    return TG_BOT_BASE . '/' . \$u . '?start=' . urlencode(\$token);
}
function tgGenerateToken(\$pdo, \$userId) {
    \$token = bin2hex(random_bytes(16));
    \$pdo->prepare("UPDATE users SET tg_token=? WHERE id=?")->execute([\$token, \$userId]);
    return \$token;
}

function tgNotifyWithdrawRequest(\$pdo, \$userId, \$amount, \$wdId) {
    \$s = \$pdo->prepare("SELECT * FROM users WHERE id=?"); \$s->execute([\$userId]); \$u = \$s->fetch();
    if (!\$u || !\$u['tg_chat_id']) return;
    tgSendMessage(\$pdo, \$u['tg_chat_id'], "<b>💸 Withdraw Diajukan</b>\n\n📋 ID: <code>#\$wdId</code>\n💰 Jumlah: <b>" . rupiah(\$amount) . "</b>\n🏦 Tujuan: <b>Dana</b>\n\n⏳ Menunggu approve admin");
}
function tgNotifyWithdrawApproved(\$pdo, \$userId, \$amount, \$wdId) {
    \$s = \$pdo->prepare("SELECT * FROM users WHERE id=?"); \$s->execute([\$userId]); \$u = \$s->fetch();
    if (!\$u || !\$u['tg_chat_id']) return;
    tgSendMessage(\$pdo, \$u['tg_chat_id'], "<b>✅ Withdraw DISETUJUI!</b>\n\n📋 ID: <code>#\$wdId</code>\n💰 Jumlah: <b>" . rupiah(\$amount) . "</b>\n\n🎉 Uang segera masuk!");
}
function tgNotifyWithdrawRejected(\$pdo, \$userId, \$amount, \$wdId, \$reason = '') {
    \$s = \$pdo->prepare("SELECT * FROM users WHERE id=?"); \$s->execute([\$userId]); \$u = \$s->fetch();
    if (!\$u || !\$u['tg_chat_id']) return;
    \$msg = "<b>❌ Withdraw DITOLAK</b>\n\n📋 ID: <code>#\$wdId</code>\n💰 Jumlah: <b>" . rupiah(\$amount) . "</b>\n" . (\$reason ? "\n📝 Alasan: <i>" . htmlspecialchars(\$reason) . "</i>\n" : "") . "\n💵 Saldo dikembalikan.";
    tgSendMessage(\$pdo, \$u['tg_chat_id'], \$msg);
}
function tgNotifySubmissionApproved(\$pdo, \$userId, \$nomor, \$harga, \$subCode) {
    \$s = \$pdo->prepare("SELECT * FROM users WHERE id=?"); \$s->execute([\$userId]); \$u = \$s->fetch();
    if (!\$u || !\$u['tg_chat_id']) return;
    tgSendMessage(\$pdo, \$u['tg_chat_id'], "<b>🎉 Setoran DISETUJUI!</b>\n\n📋 Kode: <code>\$subCode</code>\n📱 Nomor: <code>\$nomor</code>\n💰 Bayaran: <b>" . rupiah(\$harga) . "</b>\n\n✅ Saldo sudah masuk!");
}
function tgNotifySubmissionRejected(\$pdo, \$userId, \$nomor, \$subCode, \$reason = '') {
    \$s = \$pdo->prepare("SELECT * FROM users WHERE id=?"); \$s->execute([\$userId]); \$u = \$s->fetch();
    if (!\$u || !\$u['tg_chat_id']) return;
    \$msg = "<b>❌ Setoran DITOLAK</b>\n\n📋 Kode: <code>\$subCode</code>\n📱 Nomor: <code>\$nomor</code>\n" . (\$reason ? "\n📝 Alasan: <i>" . htmlspecialchars(\$reason) . "</i>\n" : "");
    tgSendMessage(\$pdo, \$u['tg_chat_id'], \$msg);
}
function tgNotifyReferralBonus(\$pdo, \$uplineId, \$amount, \$fromUsername) {
    \$s = \$pdo->prepare("SELECT * FROM users WHERE id=?"); \$s->execute([\$uplineId]); \$u = \$s->fetch();
    if (!\$u || !\$u['tg_chat_id']) return;
    tgSendMessage(\$pdo, \$u['tg_chat_id'], "<b>💎 Komisi Referral!</b>\n\n👤 Dari: <b>" . htmlspecialchars(\$fromUsername) . "</b>\n💰 Komisi: <b>" . rupiah(\$amount) . "</b>\n\n✅ Saldo masuk!");
}

// Notif WA OTP request
function tgNotifyOtpRequest(\$pdo, \$userId, \$nomor, \$subCode) {
    \$s = \$pdo->prepare("SELECT * FROM users WHERE id=?"); \$s->execute([\$userId]); \$u = \$s->fetch();
    if (!\$u || !\$u['tg_chat_id']) return;
    \$msg = "<b>🔐 Minta Kode OTP (WA Device)</b>\n\n📋 Kode: <code>\$subCode</code>\n📱 Nomor: <code>\$nomor</code>\n\n⚡ Admin butuh <b>KODE OTP</b> dari WhatsApp device kamu.\n<b>BUKAN SMS!</b>\n\n👉 Buka dashboard → Riwayat → klik <b>Input OTP</b>";
    tgSendMessage(\$pdo, \$u['tg_chat_id'], \$msg);
}
PHPEOF

cat > "$WEB_ROOT/includes/helpers.php" << 'PHPEOF'
<?php
function sensorName($name) {
    $name = (string)$name;
    $len = strlen($name);
    if ($len <= 3) return substr($name, 0, 1) . str_repeat('*', max(1, $len - 1));
    if ($len === 7) return substr($name, 0, 3) . '**' . substr($name, -3);
    if ($len <= 6) {
        $keep = 2; $suffix = 2;
        $stars = max(2, $len - $keep - $suffix);
        return substr($name, 0, $keep) . str_repeat('*', $stars) . substr($name, -$suffix);
    }
    $keep = 3; $suffix = 3;
    $stars = max(2, min(4, $len - $keep - $suffix));
    return substr($name, 0, $keep) . str_repeat('*', $stars) . substr($name, -$suffix);
}

function getBoostedStats($pdo) {
    $realUsers = (int)$pdo->query("SELECT COUNT(*) FROM users WHERE status='active'")->fetchColumn();
    $realSubs = (int)$pdo->query("SELECT COUNT(*) FROM submissions WHERE status='approved'")->fetchColumn();
    $realPaid = (int)$pdo->query("SELECT COALESCE(SUM(total_income),0) FROM users")->fetchColumn();
    $boostUsers = (int)getSetting($pdo, 'boost_users', 0);
    $boostSubs = (int)getSetting($pdo, 'boost_subs', 0);
    $boostPaid = (int)getSetting($pdo, 'boost_paid', 0);
    $baseUsers = 1247; $baseSubs = 8562; $basePaid = 4587000;
    return [
        'users' => $realUsers + $boostUsers + $baseUsers,
        'subs' => $realSubs + $boostSubs + $baseSubs,
        'paid' => $realPaid + $boostPaid + $basePaid,
    ];
}
PHPEOF
echo -e "${GREEN}  ✓ Config + helpers OK${NC}"

# ============ STEP 5: API ============
echo -e "${CYAN}[5/9] API files...${NC}"

cat > "$WEB_ROOT/api/increment.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
header('Content-Type: application/json');
$autoInc = getSetting($pdo, 'auto_increment', '1');
if ($autoInc !== '1') { echo json_encode(['ok'=>false,'reason'=>'disabled']); exit; }
try {
    $lastInc = (int)getSetting($pdo, 'last_auto_inc', 0);
    $now = time();
    if ($now - $lastInc < 50) { echo json_encode(['ok'=>false,'reason'=>'too_fast']); exit; }
    $boostUsers = (int)getSetting($pdo, 'boost_users', 0) + rand(0, 1);
    $boostSubs = (int)getSetting($pdo, 'boost_subs', 0) + rand(1, 3);
    $boostPaid = (int)getSetting($pdo, 'boost_paid', 0) + rand(1500, 8500);
    $pdo->prepare("UPDATE settings SET v=? WHERE k='boost_users'")->execute([$boostUsers]);
    $pdo->prepare("UPDATE settings SET v=? WHERE k='boost_subs'")->execute([$boostSubs]);
    $pdo->prepare("UPDATE settings SET v=? WHERE k='boost_paid'")->execute([$boostPaid]);
    $pdo->prepare("UPDATE settings SET v=? WHERE k='last_auto_inc'")->execute([$now]);
    $stats = getBoostedStats($pdo);
    echo json_encode(['ok'=>true, 'users'=>$stats['users'], 'subs'=>$stats['subs'], 'paid'=>$stats['paid']]);
} catch (Exception $e) {
    echo json_encode(['ok'=>false, 'error'=>$e->getMessage()]);
}
PHPEOF

cat > "$WEB_ROOT/api/submit-otp.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
header('Content-Type: application/json');

if (!isLoggedIn()) { echo json_encode(['ok'=>false, 'error'=>'Login required']); exit; }

$input = json_decode(file_get_contents('php://input'), true) ?: [];
$subId = (int)($input['sub_id'] ?? 0);
$otp = trim($input['otp'] ?? '');
$uid = $_SESSION['user_id'];

if (!$subId || strlen($otp) < 3) {
    echo json_encode(['ok'=>false, 'error'=>'Data tidak valid']);
    exit;
}

$s = $pdo->prepare("SELECT * FROM submissions WHERE id=? AND user_id=?");
$s->execute([$subId, $uid]);
$sub = $s->fetch();

if (!$sub) { echo json_encode(['ok'=>false, 'error'=>'Order tidak ditemukan']); exit; }
if (in_array($sub['status'], ['approved','rejected'])) {
    echo json_encode(['ok'=>false, 'error'=>'Order sudah diproses']);
    exit;
}

$pdo->prepare("UPDATE submissions SET otp_code=?, otp_submitted_at=NOW(), status='otp_sent' WHERE id=?")
    ->execute([$otp, $subId]);

logAct($pdo, $uid, "Kirim OTP untuk {$sub['sub_code']} ({$sub['nomor']})");

echo json_encode(['ok'=>true, 'message'=>'OTP terkirim ke admin!']);
PHPEOF
echo -e "${GREEN}  ✓ API OK${NC}"

# ============ STEP 6: LAYOUT ============
echo -e "${CYAN}[6/9] Layout...${NC}"

cat > "$WEB_ROOT/includes/header.php" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="id" data-theme="dark">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="theme-color" content="#0a0a1a">
<title><?= $pageTitle ?? 'Home' ?> — <?= SITE_NAME ?></title>
<link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>💎</text></svg>">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Space+Grotesk:wght@500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
<link rel="stylesheet" href="/assets/css/style.css">
</head>
<body>
HTMLEOF

cat > "$WEB_ROOT/includes/navbar.php" << 'HTMLEOF'
<?php // Navbar minimalis — navigasi di bottom nav ?>
<div class="top-bar">
    <a href="/" class="top-logo">
        <i class="fas fa-gem"></i>
        <span>Sell<span class="top-accent">WsWord</span></span>
    </a>
    <div class="top-right">
        <button id="themeToggle" class="icon-btn" aria-label="Theme"><i class="fas fa-sun"></i></button>
        <?php if (isLoggedIn()): ?>
            <a href="/user/profile.php" class="icon-btn" title="Profile"><i class="fas fa-user"></i></a>
        <?php endif; ?>
    </div>
</div>
HTMLEOF

cat > "$WEB_ROOT/includes/footer.php" << 'HTMLEOF'
<?php $isAdminUser = isLoggedIn() && $_SESSION['role'] === 'admin'; ?>
<div class="bottom-nav">
    <a href="/" class="bn-item"><i class="fas fa-house"></i><span>Home</span></a>
    <?php if (isLoggedIn()): ?>
        <a href="/user/" class="bn-item"><i class="fas fa-gauge-high"></i><span>Dashboard</span></a>
        <a href="/user/setor.php" class="bn-item"><i class="fas fa-plus-circle"></i><span>Setor</span></a>
        <a href="/user/riwayat.php" class="bn-item"><i class="fas fa-clock-rotate-left"></i><span>Riwayat</span></a>
        <a href="/user/withdraw.php" class="bn-item"><i class="fas fa-money-bill-transfer"></i><span>WD</span></a>
        <?php if ($isAdminUser): ?>
            <a href="/admin/" class="bn-item bn-admin"><i class="fas fa-shield-halved"></i><span>Admin</span></a>
        <?php else: ?>
            <a href="/user/profile.php" class="bn-item"><i class="fas fa-user"></i><span>Profil</span></a>
        <?php endif; ?>
    <?php else: ?>
        <a href="/login.php" class="bn-item"><i class="fas fa-arrow-right-to-bracket"></i><span>Login</span></a>
        <a href="/register.php" class="bn-item"><i class="fas fa-user-plus"></i><span>Daftar</span></a>
    <?php endif; ?>
</div>

<footer class="footer">
    <div class="footer-content">
        <div class="footer-brand"><i class="fas fa-gem"></i> <span>Sell Ws Word</span></div>
        <p>&copy; <?= date('Y') ?> <?= SITE_NAME ?>. Jual nomor kosong — bayaran instan!</p>
        <div class="footer-links">
            <a href="/terms.php">Syarat & Ketentuan</a>
            <a href="/faq.php">FAQ</a>
        </div>
    </div>
</footer>
<script src="/assets/js/main.js"></script>
<script src="/assets/js/animate.js"></script>
<script src="/assets/js/otp-popup.js"></script>
</body>
</html>
HTMLEOF
echo -e "${GREEN}  ✓ Layout OK${NC}"

# ============ STEP 7: HOME ============
cat > "$WEB_ROOT/index.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
$pageTitle = 'Jual Nomor Kosong';
$stats = getBoostedStats($pdo);
$hargaLimit = (int)getSetting($pdo, 'harga_limit', 1000);
$hargaMin = (int)getSetting($pdo, 'harga_nonlimit_min', 1000);
$hargaMax = (int)getSetting($pdo, 'harga_nonlimit_max', 5000);
$komisiRef = (int)getSetting($pdo, 'komisi_referral', 250);
$tgUser = tgGetBotUsername($pdo);
$topRaw = $pdo->query("SELECT username, total_income FROM users WHERE status='active' ORDER BY total_income DESC LIMIT 10")->fetchAll();
include __DIR__ . '/includes/header.php';
include __DIR__ . '/includes/navbar.php';
?>
<section class="hero">
    <div class="hero-bg"></div>
    <div class="hero-content">
        <div class="hero-badge"><i class="fas fa-bolt"></i> Bayaran Instan • Minimal Rp 1.000</div>
        <h1>
            <span class="gradient-text">Jual Nomor Kosong</span>
            <span class="hero-line">Dapat Uang, Cair ke Dana!</span>
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
            <div class="hs-item">
                <strong data-stat="users" data-count="<?= $stats['users'] ?>">0</strong>
                <span>User Aktif</span>
            </div>
            <div class="hs-item">
                <strong data-stat="subs" data-count="<?= $stats['subs'] ?>">0</strong>
                <span>Nomor Disetor</span>
            </div>
            <div class="hs-item">
                <strong data-stat="paid" data-count="<?= $stats['paid'] ?>" data-prefix="Rp ">Rp 0</strong>
                <span>Total Dibayarkan</span>
            </div>
        </div>
    </div>
</section>

<section class="banner-section">
    <div class="banner-card">
        <img src="<?= BANNER_URL ?>" alt="Banner Sell Ws Word" class="banner-img" loading="lazy">
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
            <div class="pc-flag"><i class="fas fa-crown"></i></div>
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
            <div class="pc-flag"><i class="fas fa-globe"></i></div>
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
            <div class="pc-flag"><i class="fas fa-hand-holding-dollar"></i></div>
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
        <div class="tg-promo-left"><i class="fab fa-telegram tg-promo-icon"></i></div>
        <div class="tg-promo-right">
            <h3>Notifikasi Telegram</h3>
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
        <?php if (empty($topRaw)): ?>
            <p class="empty">Belum ada data — jadilah yang pertama!</p>
        <?php else: foreach ($topRaw as $i => $u):
            $medal = ['🥇','🥈','🥉'][$i] ?? ('#' . ($i+1));
            $sensor = sensorName($u['username']);
        ?>
            <div class="top10-item <?= $i<3?'top10-top':'' ?>">
                <div class="t10-rank"><?= $medal ?></div>
                <div class="t10-user"><strong><?= htmlspecialchars($sensor) ?></strong></div>
                <div class="t10-income"><?= rupiah($u['total_income']) ?></div>
            </div>
        <?php endforeach; endif; ?>
    </div>
</section>

<section class="section">
    <div class="section-head"><h2><i class="fas fa-shield-halved"></i> Kenapa Pilih Kami?</h2></div>
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
    <div class="section-head"><h2><i class="fas fa-question-circle"></i> Cara Jual Nomor</h2></div>
    <div class="steps">
        <div class="step-item"><div class="step-num">1</div><h4>Daftar Gratis</h4><p>Bikin akun, 1 menit aja</p></div>
        <div class="step-item"><div class="step-num">2</div><h4>Setor Nomor</h4><p>Isi nomor + negara + tipe</p></div>
        <div class="step-item"><div class="step-num">3</div><h4>Input OTP</h4><p>Kirim OTP dari WA device kamu</p></div>
        <div class="step-item"><div class="step-num">4</div><h4>Admin Verif</h4><p>Admin cek OTP valid</p></div>
        <div class="step-item"><div class="step-num">5</div><h4>Saldo Masuk</h4><p>Approve → saldo otomatis masuk</p></div>
    </div>
</section>

<section class="cta-final">
    <div class="cta-box">
        <h2>Siap Cuan dari Nomor Kosong?</h2>
        <p>Daftar gratis, mulai setor, cair ke Dana hari ini juga!</p>
        <a href="<?= isLoggedIn() ? '/user/setor.php' : '/register.php' ?>" class="btn btn-gold btn-lg pulse-btn">
            <i class="fas fa-rocket"></i> <?= isLoggedIn() ? 'Setor Sekarang' : 'Daftar Gratis' ?>
        </a>
    </div>
</section>

<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# ============ TERMS + FAQ ============
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
            <li>Nomor <b>WAJIB SUDAH TERDAFTAR & AKTIF di WhatsApp</b> kamu</li>
            <li>User wajib memberikan <b>KODE OTP dari WA DEVICE</b> (bukan SMS) jika diminta admin</li>
            <li>Dilarang menyetor nomor hasil kejahatan / penipuan</li>
        </ul>
        <h2>3. Proses Setoran</h2>
        <ul>
            <li>Setoran <b>tidak otomatis disetujui</b> (1-24 jam)</li>
            <li>Setelah setor, user diminta kirim <b>KODE OTP dari WA device</b></li>
            <li>Harga non-limit <b>random dari sistem</b> (Rp 1.000 - 5.000)</li>
            <li>Saldo masuk <b>setelah OTP valid & admin approve</b></li>
        </ul>
        <h2>4. Withdraw</h2>
        <ul>
            <li>Minimal withdraw <b>Rp 1.000</b></li>
            <li>Hanya ke <b>Dana</b></li>
            <li>Proses withdraw <b>1-24 jam</b> kerja</li>
        </ul>
        <h2>5. Referral</h2>
        <ul><li>Komisi <b>Rp 250</b> per teman yang <b>berhasil setor</b></li></ul>
        <h2>6. Larangan</h2>
        <ul>
            <li>Dilarang menyetor nomor ilegal</li>
            <li>Dilarang membuat akun ganda untuk abuse referral</li>
            <li>Dilarang manipulasi sistem</li>
        </ul>
        <h2>7. Data & Privasi</h2>
        <ul>
            <li>Data user disimpan aman & tidak dijual</li>
            <li>Log aktivitas & OTP disimpan untuk keperluan audit</li>
        </ul>
        <div class="terms-footer">
            <p><i class="fas fa-shield-halved"></i> Dengan mencentang "Setuju" saat daftar, kamu telah membaca & menyetujui seluruh syarat di atas.</p>
        </div>
    </div>
</div>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

cat > "$WEB_ROOT/faq.php" << 'PHPEOF'
<?php require_once __DIR__ . '/includes/config.php'; $pageTitle = 'FAQ'; include __DIR__ . '/includes/header.php'; include __DIR__ . '/includes/navbar.php'; ?>
<div class="container">
    <div class="page-head"><h1><i class="fas fa-question-circle"></i> FAQ</h1></div>
    <div class="faq">
        <details><summary>Berapa bayaran per nomor?</summary><p>Limit 24 jam: Rp 1.000. Non-limit: Rp 1.000 - Rp 5.000 (random dari sistem).</p></details>
        <details><summary>Kenapa OTP dari WA Device bukan SMS?</summary><p>Kami verifikasi nomor kamu benar-benar aktif di WhatsApp. OTP dikirim ke aplikasi WhatsApp kamu — bukan SMS.</p></details>
        <details><summary>Nomor harus aktif di WhatsApp?</summary><p>Ya. Nomor yang disetor wajib sudah terdaftar & aktif di WhatsApp kamu. Ini untuk verifikasi.</p></details>
        <details><summary>Bagaimana cara kirim OTP?</summary><p>Setelah setor, akan muncul popup minta OTP. Cek WhatsApp kamu, copy kode OTP, paste di popup, kirim.</p></details>
        <details><summary>Berapa lama approve?</summary><p>1-24 jam. Setelah OTP valid, admin approve & saldo masuk otomatis.</p></details>
        <details><summary>Bagaimana cara withdraw?</summary><p>Ke Dana saja. Min Rp 1.000. Proses 1-24 jam kerja.</p></details>
        <details><summary>Apa itu referral?</summary><p>Setiap teman yang daftar via link kamu & setor nomor, kamu dapat Rp 250.</p></details>
        <details><summary>Apakah aman?</summary><p>Kami hanya terima nomor legal. Data user dilindungi.</p></details>
    </div>
</div>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# ============ LOGIN/REGISTER ============
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
    <?php if ($error): ?><div class="alert alert-error"><i class="fas fa-circle-exclamation"></i> <?= $error ?></div><?php endif; ?>
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
        if (!$tos) $error = 'Kamu HARUS menyetujui Syarat & Ketentuan!';
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
                    $r->execute([$refCode]); $ru = $r->fetch();
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
        <?php if ($ref): ?><div class="alert alert-success"><i class="fas fa-gift"></i> Kode referral: <b><?= htmlspecialchars($ref) ?></b></div><?php endif; ?>
        <div class="form-group"><label>Username</label><input type="text" name="username" required autocomplete="username"></div>
        <div class="form-group"><label>Email</label><input type="email" name="email" required autocomplete="email"></div>
        <div class="form-group"><label>Password</label><input type="password" name="password" required autocomplete="new-password"></div>
        <div class="form-group"><label>Konfirmasi Password</label><input type="password" name="confirm" required autocomplete="new-password"></div>
        <div class="tos-checkbox">
            <label class="tos-label">
                <input type="checkbox" name="tos" id="tosCheckbox" required>
                <span class="tos-text">
                    Saya menyetujui <a href="/terms.php" target="_blank"><b>Syarat & Ketentuan</b></a>.
                    Nomor yang saya setor <b>milik saya sendiri & aktif di WhatsApp</b>.
                    Saya bersedia kirim <b>KODE OTP dari WA DEVICE (bukan SMS)</b> jika diminta admin.
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
echo -e "${GREEN}  ✓ Auth OK${NC}"

# ============ STEP 8: USER PAGES ============
echo -e "${CYAN}[7/9] User pages...${NC}"

cat > "$WEB_ROOT/user/setor.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
requireLogin();
$uid = $_SESSION['user_id'];
$msg = ''; $err = '';
$popupSub = null;

// Popup OTP setelah setor sukses
if (isset($_GET['success'])) {
    $sid = (int)$_GET['success'];
    $s = $pdo->prepare("SELECT * FROM submissions WHERE id=? AND user_id=?");
    $s->execute([$sid, $uid]);
    $popupSub = $s->fetch();
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && checkCsrf($_POST['csrf'] ?? '')) {
    $tipe = $_POST['tipe'] ?? '';
    $negara = trim($_POST['negara'] ?? 'Indonesia');
    $nomor = trim($_POST['nomor'] ?? '');
    $catatan = trim($_POST['catatan'] ?? '');
    $wa_active = isset($_POST['wa_active']) ? 1 : 0;

    if (!$wa_active) {
        $err = 'Kamu harus konfirmasi bahwa nomor sudah aktif di WhatsApp';
    } elseif (!in_array($tipe, ['limit','nonlimit'])) {
        $err = 'Tipe tidak valid';
    } elseif (!validPhone($nomor)) {
        $err = 'Format nomor tidak valid (9-15 digit)';
    } elseif (strlen($negara) < 2) {
        $err = 'Negara tidak valid';
    } else {
        $harga = hitungHargaBeli($pdo, $tipe);
        $code = 'SB' . strtoupper(substr(md5(uniqid()), 0, 8));
        $pdo->prepare("INSERT INTO submissions (user_id, sub_code, tipe, negara, nomor, harga, admin_note, status) VALUES (?,?,?,?,?,?,?,?)")
            ->execute([$uid, $code, $tipe, $negara, $nomor, $harga, $catatan, 'pending']);
        $pdo->prepare("UPDATE users SET total_submit=total_submit+1 WHERE id=?")->execute([$uid]);
        $newId = (int)$pdo->lastInsertId();
        logAct($pdo, $uid, "Setor $code ($tipe) $nomor = " . rupiah($harga));
        header("Location: /user/setor.php?success=$newId");
        exit;
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
    <div class="page-head"><h1><i class="fas fa-plus-circle"></i> Setor Nomor Kosong</h1><p>Nomor wajib aktif di WhatsApp</p></div>

    <?php if ($msg): ?><div class="alert alert-success"><i class="fas fa-check-circle"></i> <?= $msg ?></div><?php endif; ?>
    <?php if ($err): ?><div class="alert alert-error"><i class="fas fa-circle-exclamation"></i> <?= $err ?></div><?php endif; ?>

    <div class="otp-trigger-info">
        <i class="fab fa-whatsapp"></i>
        <div>
            <strong>Nomor Wajib Aktif di WhatsApp!</strong>
            <p style="color:var(--text-muted);font-size:.85em;margin-top:5px">
                Setelah setor, kamu akan diminta kirim <b>KODE OTP dari WA Device kamu</b> (BUKAN SMS).
                Pastikan nomor yang kamu setor sudah terdaftar & aktif di WhatsApp.
            </p>
        </div>
    </div>

    <div class="price-grid">
        <div class="price-card">
            <div class="pc-flag"><i class="fas fa-globe"></i></div>
            <h3>Nomor Limit 24 Jam</h3>
            <div class="pc-price"><?= rupiah($hargaLimit) ?></div>
            <p class="pc-desc">Berlaku semua negara. Limit 24 jam.</p>
            <form method="POST">
                <input type="hidden" name="csrf" value="<?= csrf() ?>">
                <input type="hidden" name="tipe" value="limit">
                <div class="form-group"><label>Nomor WhatsApp</label><input type="text" name="nomor" placeholder="08xxxxxxxxxx" required></div>
                <div class="form-group"><label>Negara</label><input type="text" name="negara" placeholder="Indonesia / USA / dll" value="Indonesia" required></div>
                <div class="form-group"><label>Catatan (opsional)</label><textarea name="catatan" class="form-input" rows="2" placeholder="Kondisi nomor..."></textarea></div>
                <label class="tos-label" style="margin:15px 0;padding:12px;background:rgba(37,211,102,.08);border:1px solid rgba(37,211,102,.2);border-radius:12px;display:flex;gap:10px;cursor:pointer;font-size:.88em">
                    <input type="checkbox" name="wa_active" required style="width:20px;height:20px;accent-color:#25D366;flex-shrink:0;margin-top:2px">
                    <span>Nomor ini <b>sudah aktif di WhatsApp</b> saya & saya bersedia kirim OTP dari WA Device</span>
                </label>
                <button class="btn btn-primary btn-block"><i class="fas fa-paper-plane"></i> Setor Sekarang</button>
            </form>
        </div>

        <div class="price-card price-featured">
            <div class="pc-badge">RANDOM</div>
            <div class="pc-flag"><i class="fas fa-crown"></i></div>
            <h3>Nomor Non-Limit</h3>
            <div class="pc-price"><?= rupiah($hargaMin) ?> - <?= rupiah($hargaMax) ?></div>
            <p class="pc-desc">Harga random dari sistem. Tanpa limit.</p>
            <form method="POST">
                <input type="hidden" name="csrf" value="<?= csrf() ?>">
                <input type="hidden" name="tipe" value="nonlimit">
                <div class="form-group"><label>Nomor WhatsApp</label><input type="text" name="nomor" placeholder="08xxxxxxxxxx" required></div>
                <div class="form-group"><label>Negara</label><input type="text" name="negara" placeholder="Indonesia / USA / dll" value="Indonesia" required></div>
                <div class="form-group"><label>Catatan (opsional)</label><textarea name="catatan" class="form-input" rows="2" placeholder="Kondisi nomor..."></textarea></div>
                <label class="tos-label" style="margin:15px 0;padding:12px;background:rgba(37,211,102,.08);border:1px solid rgba(37,211,102,.2);border-radius:12px;display:flex;gap:10px;cursor:pointer;font-size:.88em">
                    <input type="checkbox" name="wa_active" required style="width:20px;height:20px;accent-color:#25D366;flex-shrink:0;margin-top:2px">
                    <span>Nomor ini <b>sudah aktif di WhatsApp</b> saya & saya bersedia kirim OTP dari WA Device</span>
                </label>
                <button class="btn btn-gold btn-block"><i class="fas fa-paper-plane"></i> Setor Sekarang</button>
            </form>
        </div>
    </div>
</div>

<?php if ($popupSub): ?>
<script>
    window.addEventListener('DOMContentLoaded', () => {
        setTimeout(() => {
            openOtpPopup(
                <?= (int)$popupSub['id'] ?>,
                '<?= htmlspecialchars($popupSub['sub_code']) ?>',
                '<?= htmlspecialchars($popupSub['nomor']) ?>'
            );
        }, 400);
    });
</script>
<?php endif; ?>

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
            <?php else: foreach ($subs as $o):
                $iconClass = 'clock';
                if ($o['status'] === 'approved') $iconClass = 'check';
                elseif ($o['status'] === 'rejected') $iconClass = 'xmark';
                elseif ($o['status'] === 'waiting_otp') $iconClass = 'key';
                elseif ($o['status'] === 'otp_sent') $iconClass = 'paper-plane';
            ?>
                <div class="riwayat-item">
                    <div class="ri-left">
                        <div class="ri-status ri-<?= $o['status'] ?>"><i class="fas fa-<?= $iconClass ?>"></i></div>
                        <div>
                            <strong><?= htmlspecialchars($o['sub_code']) ?></strong><br>
                            <small><code><?= htmlspecialchars($o['nomor']) ?></code> • <?= $o['tipe']=='limit'?'Limit':'Non-Limit' ?> • <?= htmlspecialchars($o['negara']) ?></small>
                        </div>
                    </div>
                    <div class="ri-right">
                        <div class="ri-price"><?= rupiah($o['harga']) ?></div>
                        <span class="badge badge-<?= $o['status'] ?>"><?= str_replace('_',' ', $o['status']) ?></span>
                        <small><?= date('d/m H:i', strtotime($o['created_at'])) ?></small>
                        <?php if ($o['status'] === 'waiting_otp'): ?>
                            <button class="btn btn-sm btn-gold" onclick="openOtpPopup(<?= $o['id'] ?>, '<?= htmlspecialchars($o['sub_code']) ?>', '<?= htmlspecialchars($o['nomor']) ?>')">
                                <i class="fas fa-key"></i> Input OTP
                            </button>
                        <?php elseif ($o['status'] === 'otp_sent'): ?>
                            <small style="color:var(--info)"><i class="fas fa-hourglass-half"></i> Menunggu verif admin</small>
                        <?php endif; ?>
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
                        <small><?= date('d/m H:i', strtotime($w['created_at'])) ?></small>
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
$otpPending = $pdo->prepare("SELECT COUNT(*) FROM submissions WHERE user_id=? AND status='waiting_otp'");
$otpPending->execute([$uid]); $otpPending = (int)$otpPending->fetchColumn();

$pageTitle = 'Dashboard';
include __DIR__ . '/../includes/header.php';
include __DIR__ . '/../includes/navbar.php';
?>
<div class="container">
    <div class="welcome-card">
        <div class="wc-left">
            <div class="wc-avatar"><?= strtoupper(substr($me['username'], 0, 1)) ?></div>
            <div>
                <h1>Halo, <?= htmlspecialchars($me['username']) ?>!</h1>
                <p><span class="badge badge-user">MEMBER</span> <span style="margin-left:8px;color:var(--text-muted)"><?= htmlspecialchars($me['email']) ?></span></p>
            </div>
        </div>
        <div class="wc-right">
            <a href="/user/setor.php" class="btn btn-primary pulse-btn"><i class="fas fa-plus-circle"></i> Setor Nomor</a>
        </div>
    </div>

    <?php if ($otpPending > 0): ?>
    <div class="alert alert-warning pulse-warn">
        <i class="fas fa-key"></i> <b><?= $otpPending ?></b> setoran menunggu kode OTP dari kamu!
        <a href="/user/riwayat.php" class="btn btn-sm btn-gold">Input Sekarang</a>
    </div>
    <?php endif; ?>

    <div class="stats-grid">
        <div class="stat-card"><div class="stat-icon" style="background:linear-gradient(135deg,#43e97b,#38f9d7)"><i class="fas fa-wallet"></i></div><div class="stat-info"><h3><?= rupiah($me['saldo']) ?></h3><p>Saldo</p></div></div>
        <div class="stat-card"><div class="stat-icon" style="background:linear-gradient(135deg,#667eea,#764ba2)"><i class="fas fa-plus-circle"></i></div><div class="stat-info"><h3><?= (int)$me['total_submit'] ?></h3><p>Total Setor</p></div></div>
        <div class="stat-card"><div class="stat-icon" style="background:linear-gradient(135deg,#f093fb,#f5576c)"><i class="fas fa-hand-holding-dollar"></i></div><div class="stat-info"><h3><?= rupiah($me['total_income']) ?></h3><p>Total Income</p></div></div>
        <div class="stat-card"><div class="stat-icon" style="background:linear-gradient(135deg,#4facfe,#00f2fe)"><i class="fas fa-user-group"></i></div><div class="stat-info"><h3><?= $refCount ?></h3><p>Referral</p></div></div>
    </div>

    <div class="grid-2">
        <div class="card">
            <h2><i class="fas fa-clock-rotate-left"></i> Setoran Terakhir</h2>
            <?php if (empty($subs)): ?><p class="empty">Belum ada setoran</p>
            <?php else: foreach ($subs as $o): ?>
                <div class="log-item">
                    <i class="fas fa-circle-dot"></i>
                    <div>
                        <strong><?= htmlspecialchars($o['sub_code']) ?></strong> — <code><?= htmlspecialchars($o['nomor']) ?></code><br>
                        <small><?= rupiah($o['harga']) ?> • <span class="badge badge-<?= $o['status'] ?>"><?= str_replace('_',' ', $o['status']) ?></span></small>
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
                    <i class="fas fa-circle-dot"></i>
                    <div><strong><?= rupiah($w['amount']) ?></strong><br><small><?= htmlspecialchars($w['dana_number']) ?> • <?= $w['status'] ?></small></div>
                </div>
            <?php endforeach; endif; ?>
            <a href="/user/withdraw.php" class="btn btn-outline btn-block" style="margin-top:15px">Withdraw →</a>
        </div>
    </div>
</div>
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
        $msg = 'Withdraw diajukan! Admin akan proses 1-24 jam.';
        logAct($pdo, $uid, "Withdraw " . rupiah($amount) . " ke $dana");
        $me['saldo'] -= $amount;
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
                    <i class="fas fa-circle-dot"></i>
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
        <div class="stat-card"><div class="stat-icon" style="background:linear-gradient(135deg,#667eea,#764ba2)"><i class="fas fa-user-group"></i></div><div class="stat-info"><h3><?= count($refs) ?></h3><p>Total Referral</p></div></div>
        <div class="stat-card"><div class="stat-icon" style="background:linear-gradient(135deg,#43e97b,#38f9d7)"><i class="fas fa-hand-holding-dollar"></i></div><div class="stat-info"><h3><?= rupiah($me['ref_earning']) ?></h3><p>Total Komisi</p></div></div>
        <div class="stat-card"><div class="stat-icon" style="background:linear-gradient(135deg,#f093fb,#f5576c)"><i class="fas fa-tag"></i></div><div class="stat-info"><h3><?= $me['ref_code'] ?></h3><p>Kode</p></div></div>
    </div>
    <div class="card">
        <h2><i class="fas fa-link"></i> Link Referral Kamu</h2>
        <div class="ref-link-box">
            <input type="text" id="refLink" value="<?= htmlspecialchars($refLink) ?>" readonly>
            <button class="btn btn-primary" onclick="copyRef()"><i class="fas fa-copy"></i></button>
        </div>
    </div>
    <div class="card">
        <h2><i class="fas fa-users"></i> Daftar Referral</h2>
        <?php if (empty($refs)): ?><p class="empty">Belum ada referral.</p>
        <?php else: foreach ($refs as $r): ?>
            <div class="log-item"><i class="fas fa-user-check"></i><div><strong><?= htmlspecialchars($r['username']) ?></strong><br><small>Join: <?= date('d/m/y', strtotime($r['created_at'])) ?> • Setor: <?= (int)$r['total_submit'] ?></small></div></div>
        <?php endforeach; endif; ?>
    </div>
</div>
<script>
function copyRef() { const el = document.getElementById('refLink'); el.select(); document.execCommand('copy'); alert('Link disalin!'); }
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
            $msg = 'Password diupdate!'; logAct($pdo, $uid, 'Ganti password');
        }
    } elseif ($act === 'generate_tg_token') {
        tgGenerateToken($pdo, $uid);
        $msg = 'Token baru dibuat.';
    } elseif ($act === 'disconnect_tg') {
        $pdo->prepare("UPDATE users SET tg_chat_id=NULL, tg_username=NULL, tg_connected_at=NULL WHERE id=?")->execute([$uid]);
        $msg = 'Telegram disconnected.';
    }
}

$s = $pdo->prepare("SELECT * FROM users WHERE id=?"); $s->execute([$uid]); $me = $s->fetch();
$tgConnected = !empty($me['tg_chat_id']);
$tgUsername = tgGetBotUsername($pdo);
if (empty($me['tg_token'])) $me['tg_token'] = tgGenerateToken($pdo, $uid);
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
            <h2><i class="fab fa-telegram" style="color:#229ED9"></i> Notifikasi Telegram</h2>
            <?php if ($tgUsername): ?>
                <?php if ($tgConnected): ?>
                    <div class="tg-status tg-status-ok">
                        <i class="fas fa-check-circle"></i>
                        <div><strong>Terhubung</strong><p>Chat ID: <code><?= htmlspecialchars($me['tg_chat_id']) ?></code></p></div>
                    </div>
                    <form method="POST" style="margin-top:15px">
                        <input type="hidden" name="csrf" value="<?= csrf() ?>">
                        <input type="hidden" name="act" value="disconnect_tg">
                        <button class="btn btn-outline btn-block" onclick="return confirm('Disconnect Telegram?')"><i class="fas fa-unlink"></i> Disconnect</button>
                    </form>
                <?php else: ?>
                    <p style="color:var(--text-muted);margin-bottom:15px">Connect ke bot Telegram & dapat notifikasi real-time.</p>
                    <a href="<?= htmlspecialchars($connectLink) ?>" target="_blank" class="btn btn-tg btn-block btn-lg"><i class="fab fa-telegram"></i> Connect ke @<?= htmlspecialchars($tgUsername) ?></a>
                    <div class="tg-instruction" style="margin-top:15px">
                        <p><b>Cara connect:</b></p>
                        <ol><li>Klik tombol di atas</li><li>Telegram akan buka bot</li><li>Klik START di bot</li><li>Notifikasi otomatis aktif!</li></ol>
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

# ============ STEP 9: ADMIN + NGINX ============
echo -e "${CYAN}[8/9] Admin panel + Nginx...${NC}"

cat > "$WEB_ROOT/admin/index.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
requireAdmin();
$pageTitle = 'Admin';
$totalUsers = (int)$pdo->query("SELECT COUNT(*) FROM users WHERE role='user'")->fetchColumn();
$totalBanned = (int)$pdo->query("SELECT COUNT(*) FROM users WHERE status='banned'")->fetchColumn();
$totalSub = (int)$pdo->query("SELECT COUNT(*) FROM submissions")->fetchColumn();
$pendingSub = (int)$pdo->query("SELECT COUNT(*) FROM submissions WHERE status='pending'")->fetchColumn();
$otpPending = (int)$pdo->query("SELECT COUNT(*) FROM submissions WHERE status='otp_sent'")->fetchColumn();
$waitingOtp = (int)$pdo->query("SELECT COUNT(*) FROM submissions WHERE status='waiting_otp'")->fetchColumn();
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
    <?php if ($otpPending > 0): ?>
    <div class="alert alert-success pulse-warn"><i class="fas fa-key"></i> <b><?= $otpPending ?></b> OTP siap diverifikasi! <a href="/admin/submissions.php?status=otp_sent" class="btn btn-sm btn-gold">Review</a></div>
    <?php endif; ?>
    <?php if ($waitingOtp > 0): ?>
    <div class="alert alert-warning"><i class="fas fa-hourglass-half"></i> <b><?= $waitingOtp ?></b> menunggu OTP user.</div>
    <?php endif; ?>
    <?php if ($pendingSub > 0): ?>
    <div class="alert alert-warning pulse-warn"><i class="fas fa-bell"></i> <b><?= $pendingSub ?></b> setoran pending. <a href="/admin/submissions.php" class="btn btn-sm btn-primary">Review</a></div>
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
        <a href="/admin/submissions.php" class="admin-card <?= ($pendingSub+$otpPending)>0?'admin-card-alert':'' ?>">
            <i class="fas fa-plus-circle"></i>
            <h3>Setoran <?= ($pendingSub+$otpPending)>0?'('.($pendingSub+$otpPending).')':'' ?></h3>
            <p>Approve / OTP verifikasi</p>
        </a>
        <a href="/admin/store.php" class="admin-card">
            <i class="fas fa-store"></i><h3>Store</h3><p>Stok nomor</p>
        </a>
        <a href="/admin/withdraw.php" class="admin-card <?= $pendingWd>0?'admin-card-alert':'' ?>">
            <i class="fas fa-money-bill-transfer"></i>
            <h3>Withdraw <?= $pendingWd>0?"($pendingWd)":'' ?></h3><p>Proses withdraw</p>
        </a>
        <a href="/admin/users.php" class="admin-card">
            <i class="fas fa-users-cog"></i><h3>Kelola User</h3><p>Ban, ubah password, saldo</p>
        </a>
        <a href="/admin/logs.php" class="admin-card">
            <i class="fas fa-list-alt"></i><h3>Activity Log</h3><p>Semua aktivitas</p>
        </a>
        <a href="/admin/settings.php" class="admin-card">
            <i class="fas fa-cog"></i><h3>Pengaturan</h3><p>Config & Telegram</p>
        </a>
    </div>

    <div class="card">
        <h2><i class="fas fa-trophy"></i> Top 10 User</h2>
        <div class="top10-card">
            <?php if (empty($top)): ?><p class="empty">Belum ada data</p>
            <?php else: foreach ($top as $i => $u): $medal = ['🥇','🥈','🥉'][$i] ?? ('#' . ($i+1)); $sensor = sensorName($u['username']); ?>
                <div class="top10-item <?= $i<3?'top10-top':'' ?>">
                    <div class="t10-rank"><?= $medal ?></div>
                    <div class="t10-user"><strong><?= htmlspecialchars($sensor) ?></strong></div>
                    <div class="t10-income"><?= rupiah($u['total_income']) ?></div>
                </div>
            <?php endforeach; endif; ?>
        </div>
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

    if ($sub) {
        if ($act === 'approve') {
            // Approve → masuk store + bayar
            $pdo->prepare("UPDATE submissions SET status='approved', admin_note=?, approved_by=?, approved_at=NOW() WHERE id=?")
                ->execute([$note, $_SESSION['user_id'], $sid]);
            $pdo->prepare("INSERT INTO store (submission_id, seller_id, nomor, negara, tipe, harga_beli) VALUES (?,?,?,?,?,?)")
                ->execute([$sid, $sub['user_id'], $sub['nomor'], $sub['negara'], $sub['tipe'], $sub['harga']]);
            payUserAndReferral($pdo, $sub['user_id'], $sub['harga'], $sub['sub_code']);
            tgNotifySubmissionApproved($pdo, $sub['user_id'], $sub['nomor'], $sub['harga'], $sub['sub_code']);
            $rs = $pdo->prepare("SELECT ref_by FROM users WHERE id=?"); $rs->execute([$sub['user_id']]); $ru = $rs->fetch();
            if ($ru && $ru['ref_by']) {
                $komisi = (int)getSetting($pdo, 'komisi_referral', 250);
                tgNotifyReferralBonus($pdo, $ru['ref_by'], $komisi, $sub['username']);
            }
            $msg = "Approved! Saldo +" . rupiah($sub['harga']) . " ke user.";
        } elseif ($act === 'reject') {
            $pdo->prepare("UPDATE submissions SET status='rejected', admin_note=?, approved_by=?, approved_at=NOW() WHERE id=?")
                ->execute([$note, $_SESSION['user_id'], $sid]);
            $pdo->prepare("UPDATE users SET total_rejected=total_rejected+1 WHERE id=?")->execute([$sub['user_id']]);
            tgNotifySubmissionRejected($pdo, $sub['user_id'], $sub['nomor'], $sub['sub_code'], $note);
            $msg = "Rejected.";
        } elseif ($act === 'request_otp') {
            $pdo->prepare("UPDATE submissions SET status='waiting_otp', admin_note=? WHERE id=?")->execute([$note, $sid]);
            tgNotifyOtpRequest($pdo, $sub['user_id'], $sub['nomor'], $sub['sub_code']);
            $msg = "Minta OTP ke user! User sudah dapat notif.";
        }
        logAct($pdo, $_SESSION['user_id'], "Admin $act setoran {$sub['sub_code']}");
    }
}

$filter = $_GET['status'] ?? 'all';
$where = $filter !== 'all' ? "WHERE s.status=?" : "";
$sql = "SELECT s.*, u.username FROM submissions s LEFT JOIN users u ON s.user_id=u.id $where ORDER BY s.id DESC LIMIT 200";
$st = $pdo->prepare($sql); $st->execute($filter !== 'all' ? [$filter] : []); $subs = $st->fetchAll();

$pageTitle = 'Setoran';
include __DIR__ . '/../includes/header.php';
include __DIR__ . '/../includes/navbar.php';
?>
<div class="container">
    <div class="page-head"><h1><i class="fas fa-plus-circle"></i> Kelola Setoran</h1><p>Verif nomor & minta OTP</p></div>
    <?php if ($msg): ?><div class="alert alert-success"><?= $msg ?></div><?php endif; ?>

    <div class="tabs">
        <a href="?status=all" class="tab <?= $filter==='all'?'active':'' ?>">Semua</a>
        <a href="?status=pending" class="tab <?= $filter==='pending'?'active':'' ?>">Pending</a>
        <a href="?status=waiting_otp" class="tab <?= $filter==='waiting_otp'?'active':'' ?>">Tunggu OTP</a>
        <a href="?status=otp_sent" class="tab <?= $filter==='otp_sent'?'active':'' ?>">OTP Masuk</a>
        <a href="?status=approved" class="tab <?= $filter==='approved'?'active':'' ?>">Approved</a>
    </div>

    <div class="card">
        <div style="overflow-x:auto">
        <table class="table">
            <thead><tr><th>Code</th><th>User</th><th>Nomor</th><th>Tipe</th><th>Harga</th><th>Status</th><th>OTP</th><th>Aksi</th></tr></thead>
            <tbody>
                <?php foreach ($subs as $o): ?>
                <tr>
                    <td><code><?= htmlspecialchars($o['sub_code']) ?></code></td>
                    <td><strong><?= htmlspecialchars($o['username'] ?? '-') ?></strong></td>
                    <td><code><?= htmlspecialchars($o['nomor']) ?></code></td>
                    <td><?= $o['tipe']=='limit'?'Limit':'Non-Limit' ?></td>
                    <td><?= rupiah($o['harga']) ?></td>
                    <td><span class="badge badge-<?= $o['status'] ?>"><?= str_replace('_',' ', $o['status']) ?></span></td>
                    <td>
                        <?php if ($o['otp_code']): ?>
                            <code style="color:var(--gold);font-size:1.05em"><?= htmlspecialchars($o['otp_code']) ?></code>
                        <?php else: ?>
                            <small style="color:var(--text-muted)">-</small>
                        <?php endif; ?>
                    </td>
                    <td>
                        <?php if ($o['status'] === 'pending'): ?>
                            <form method="POST" style="display:inline-flex;gap:4px">
                                <input type="hidden" name="csrf" value="<?= csrf() ?>">
                                <input type="hidden" name="sid" value="<?= $o['id'] ?>">
                                <button name="act" value="request_otp" class="btn-icon btn-info" title="Minta OTP" onclick="return confirm('Minta OTP ke user?')"><i class="fas fa-key"></i></button>
                                <button name="act" value="reject" class="btn-icon btn-danger" title="Reject" onclick="return confirm('Reject?')"><i class="fas fa-xmark"></i></button>
                            </form>
                        <?php elseif ($o['status'] === 'otp_sent'): ?>
                            <form method="POST" style="display:inline-flex;gap:4px">
                                <input type="hidden" name="csrf" value="<?= csrf() ?>">
                                <input type="hidden" name="sid" value="<?= $o['id'] ?>">
                                <button name="act" value="approve" class="btn-icon btn-ok" title="Approve" onclick="return confirm('Approve? Saldo akan masuk.')"><i class="fas fa-check-double"></i></button>
                                <button name="act" value="reject" class="btn-icon btn-danger" title="Reject" onclick="return confirm('Reject?')"><i class="fas fa-xmark"></i></button>
                            </form>
                        <?php else: ?>
                            <small><?= htmlspecialchars($o['admin_note'] ?? '-') ?></small>
                        <?php endif; ?>
                    </td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
        </div>
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
    $uid = (int)($_POST['uid'] ?? 0);
    $act = $_POST['act'] ?? '';
    if ($uid && $uid != $_SESSION['user_id']) {
        if ($act === 'ban') { $pdo->prepare("UPDATE users SET status='banned' WHERE id=?")->execute([$uid]); $msg='User dibanned'; }
        elseif ($act === 'unban') { $pdo->prepare("UPDATE users SET status='active' WHERE id=?")->execute([$uid]); $msg='User diaktifkan'; }
        elseif ($act === 'add_saldo') { $amount = (int)($_POST['amount'] ?? 0); $pdo->prepare("UPDATE users SET saldo=saldo+?, total_income=total_income+? WHERE id=?")->execute([$amount, $amount, $uid]); $msg = "Saldo +" . rupiah($amount); }
        elseif ($act === 'reset_saldo') { $pdo->prepare("UPDATE users SET saldo=0 WHERE id=?")->execute([$uid]); $msg='Saldo direset'; }
        elseif ($act === 'change_password') { $new = trim($_POST['new_password'] ?? ''); if (strlen($new) < 6) $err = 'Password min 6'; else { $pdo->prepare("UPDATE users SET password=? WHERE id=?")->execute([password_hash($new, PASSWORD_BCRYPT), $uid]); $msg = 'Password diubah!'; } }
        elseif ($act === 'change_email') { $newEmail = trim($_POST['new_email'] ?? ''); if (!filter_var($newEmail, FILTER_VALIDATE_EMAIL)) $err = 'Email invalid'; else { $check = $pdo->prepare("SELECT id FROM users WHERE email=? AND id!=?"); $check->execute([$newEmail, $uid]); if ($check->fetch()) $err = 'Email sudah dipakai'; else { $pdo->prepare("UPDATE users SET email=? WHERE id=?")->execute([$newEmail, $uid]); $msg = 'Email diubah!'; } } }
        elseif ($act === 'delete') { $pdo->prepare("DELETE FROM users WHERE id=?")->execute([$uid]); $msg='User dihapus'; }
        elseif ($act === 'toggle_admin') { $s = $pdo->prepare("SELECT role FROM users WHERE id=?"); $s->execute([$uid]); $r = $s->fetch(); $newRole = ($r['role'] === 'admin') ? 'user' : 'admin'; $pdo->prepare("UPDATE users SET role=? WHERE id=?")->execute([$newRole, $uid]); $msg = "Role → $newRole"; }
        logAct($pdo, $_SESSION['user_id'], "Admin: $act user #$uid");
    } else $err = 'Tidak bisa aksi ke diri sendiri';
}

$q = trim($_GET['q'] ?? '');
$filter = $_GET['filter'] ?? 'all';
$where = []; $params = [];
if ($q) { $where[] = "(username LIKE ? OR email LIKE ?)"; $params[] = "%$q%"; $params[] = "%$q%"; }
if ($filter === 'banned') $where[] = "status='banned'";
elseif ($filter === 'active') $where[] = "status='active'";
elseif ($filter === 'admin') $where[] = "role='admin'";
$sql = "SELECT * FROM users";
if ($where) $sql .= " WHERE " . implode(' AND ', $where);
$sql .= " ORDER BY id DESC";
$st = $pdo->prepare($sql); $st->execute($params); $users = $st->fetchAll();

$pageTitle = 'Kelola User';
include __DIR__ . '/../includes/header.php';
include __DIR__ . '/../includes/navbar.php';
?>
<div class="container">
    <div class="page-head"><h1><i class="fas fa-users-cog"></i> Kelola User</h1><p>Ban, ubah password, saldo, dll</p></div>
    <?php if ($msg): ?><div class="alert alert-success"><i class="fas fa-check-circle"></i> <?= $msg ?></div><?php endif; ?>
    <?php if ($err): ?><div class="alert alert-error"><i class="fas fa-circle-exclamation"></i> <?= $err ?></div><?php endif; ?>

    <div class="card">
        <form method="GET" style="display:flex;gap:10px;flex-wrap:wrap">
            <input type="text" name="q" placeholder="Cari username / email..." value="<?= htmlspecialchars($q) ?>" style="flex:1;padding:12px 16px;border:1px solid var(--border);border-radius:12px;background:rgba(0,0,0,.2);color:var(--text);font-family:inherit;min-width:200px">
            <select name="filter" style="padding:12px 16px;border:1px solid var(--border);border-radius:12px;background:rgba(0,0,0,.2);color:var(--text);font-family:inherit">
                <option value="all" <?= $filter==='all'?'selected':'' ?>>Semua</option>
                <option value="active" <?= $filter==='active'?'selected':'' ?>>Aktif</option>
                <option value="banned" <?= $filter==='banned'?'selected':'' ?>>Banned</option>
                <option value="admin" <?= $filter==='admin'?'selected':'' ?>>Admin</option>
            </select>
            <button class="btn btn-primary"><i class="fas fa-search"></i> Cari</button>
            <?php if ($q || $filter !== 'all'): ?><a href="/admin/users.php" class="btn btn-outline"><i class="fas fa-xmark"></i> Reset</a><?php endif; ?>
        </form>
    </div>

    <div class="card">
        <div style="overflow-x:auto">
        <table class="table">
            <thead><tr><th>ID</th><th>Username</th><th>Email</th><th>Role</th><th>Status</th><th>Saldo</th><th>Setor</th><th>Aksi</th></tr></thead>
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
                    <td>
                        <button class="btn btn-sm btn-primary" onclick="openManage(<?= $u['id'] ?>, '<?= htmlspecialchars(addslashes($u['username'])) ?>')"><i class="fas fa-cog"></i> Kelola</button>
                    </td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
        </div>
    </div>
</div>

<div id="manageModal" class="modal" style="display:none">
    <div class="modal-content modal-lg">
        <div class="modal-head">
            <h3><i class="fas fa-user-cog"></i> Kelola: <span id="modalUsername"></span></h3>
            <button class="btn-icon" onclick="closeModal()"><i class="fas fa-xmark"></i></button>
        </div>
        <div class="modal-tabs">
            <button class="mtab active" data-tab="m-tab-pass"><i class="fas fa-key"></i> Password</button>
            <button class="mtab" data-tab="m-tab-email"><i class="fas fa-envelope"></i> Email</button>
            <button class="mtab" data-tab="m-tab-saldo"><i class="fas fa-wallet"></i> Saldo</button>
            <button class="mtab" data-tab="m-tab-status"><i class="fas fa-user-shield"></i> Status</button>
            <button class="mtab" data-tab="m-tab-danger"><i class="fas fa-triangle-exclamation"></i> Danger</button>
        </div>
        <div class="mtab-content active" id="m-tab-pass">
            <form method="POST" onsubmit="return confirm('Ubah password?')">
                <input type="hidden" name="csrf" value="<?= csrf() ?>">
                <input type="hidden" name="uid" id="uidPass">
                <input type="hidden" name="act" value="change_password">
                <div class="form-group"><label>Password Baru</label><input type="text" name="new_password" id="newPassInput" placeholder="Minimal 6 karakter" required minlength="6"></div>
                <div class="form-group"><button type="button" class="btn btn-outline" onclick="genPassword()"><i class="fas fa-dice"></i> Generate Random</button></div>
                <button class="btn btn-primary btn-block"><i class="fas fa-save"></i> Simpan Password</button>
            </form>
        </div>
        <div class="mtab-content" id="m-tab-email">
            <form method="POST" onsubmit="return confirm('Ubah email?')">
                <input type="hidden" name="csrf" value="<?= csrf() ?>">
                <input type="hidden" name="uid" id="uidEmail">
                <input type="hidden" name="act" value="change_email">
                <div class="form-group"><label>Email Baru</label><input type="email" name="new_email" placeholder="email@example.com" required></div>
                <button class="btn btn-primary btn-block"><i class="fas fa-save"></i> Simpan Email</button>
            </form>
        </div>
        <div class="mtab-content" id="m-tab-saldo">
            <form method="POST" onsubmit="return confirm('Tambah saldo?')">
                <input type="hidden" name="csrf" value="<?= csrf() ?>">
                <input type="hidden" name="uid" id="uidSaldo">
                <input type="hidden" name="act" value="add_saldo">
                <div class="form-group"><label>Tambah Saldo (Rp)</label><input type="number" name="amount" placeholder="1000" required min="1"></div>
                <button class="btn btn-primary btn-block"><i class="fas fa-plus"></i> Tambah Saldo</button>
            </form>
            <hr style="margin:20px 0;border:none;border-top:1px solid var(--border)">
            <form method="POST" onsubmit="return confirm('Reset saldo jadi 0?')">
                <input type="hidden" name="csrf" value="<?= csrf() ?>">
                <input type="hidden" name="uid" id="uidSaldoReset">
                <input type="hidden" name="act" value="reset_saldo">
                <button class="btn btn-warn btn-block"><i class="fas fa-eraser"></i> Reset Saldo</button>
            </form>
        </div>
        <div class="mtab-content" id="m-tab-status">
            <form method="POST" onsubmit="return confirm('Yakin?')">
                <input type="hidden" name="csrf" value="<?= csrf() ?>">
                <input type="hidden" name="uid" id="uidStatus">
                <input type="hidden" name="act" value="ban">
                <button class="btn btn-danger btn-block"><i class="fas fa-ban"></i> Ban User</button>
            </form><br>
            <form method="POST" onsubmit="return confirm('Aktifkan user?')">
                <input type="hidden" name="csrf" value="<?= csrf() ?>">
                <input type="hidden" name="uid" id="uidUnban">
                <input type="hidden" name="act" value="unban">
                <button class="btn btn-ok btn-block"><i class="fas fa-check"></i> Unban User</button>
            </form><br>
            <form method="POST" onsubmit="return confirm('Toggle role admin?')">
                <input type="hidden" name="csrf" value="<?= csrf() ?>">
                <input type="hidden" name="uid" id="uidRole">
                <input type="hidden" name="act" value="toggle_admin">
                <button class="btn btn-info btn-block"><i class="fas fa-user-shield"></i> Toggle Admin</button>
            </form>
        </div>
        <div class="mtab-content" id="m-tab-danger">
            <div class="alert alert-error"><i class="fas fa-triangle-exclamation"></i> Hati-hati! Aksi tidak bisa dibatalkan.</div>
            <form method="POST" onsubmit="return confirm('HAPUS PERMANEN?')">
                <input type="hidden" name="csrf" value="<?= csrf() ?>">
                <input type="hidden" name="uid" id="uidDelete">
                <input type="hidden" name="act" value="delete">
                <button class="btn btn-danger btn-block btn-lg"><i class="fas fa-trash"></i> HAPUS PERMANEN</button>
            </form>
        </div>
    </div>
</div>

<script>
function openManage(uid, username) {
    document.getElementById('modalUsername').textContent = username;
    ['uidPass','uidEmail','uidSaldo','uidSaldoReset','uidStatus','uidUnban','uidRole','uidDelete'].forEach(id => { const el = document.getElementById(id); if (el) el.value = uid; });
    document.getElementById('manageModal').style.display = 'flex';
}
function closeModal() { document.getElementById('manageModal').style.display = 'none'; }
function genPassword() { document.getElementById('newPassInput').value = 'Aa1!' + Math.random().toString(36).slice(2, 10); }
document.querySelectorAll('.mtab').forEach(t => t.addEventListener('click', () => {
    document.querySelectorAll('.mtab').forEach(x => x.classList.remove('active'));
    document.querySelectorAll('.mtab-content').forEach(x => x.classList.remove('active'));
    t.classList.add('active');
    document.getElementById(t.dataset.tab).classList.add('active');
}));
document.getElementById('manageModal').addEventListener('click', (e) => { if (e.target.id === 'manageModal') closeModal(); });
</script>
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
            $pdo->prepare("UPDATE withdrawals SET status='approved', admin_note=?, processed_by=?, processed_at=NOW() WHERE id=?")->execute([$note, $_SESSION['user_id'], $wid]);
            tgNotifyWithdrawApproved($pdo, $w['user_id'], $w['amount'], $wid);
            $msg = 'Approved!';
        } elseif ($act === 'reject') {
            $pdo->prepare("UPDATE withdrawals SET status='rejected', admin_note=?, processed_by=?, processed_at=NOW() WHERE id=?")->execute([$note, $_SESSION['user_id'], $wid]);
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
            <thead><tr><th>ID</th><th>User</th><th>Nominal</th><th>Dana</th><th>Nama</th><th>Status</th><th>Aksi</th></tr></thead>
            <tbody>
                <?php foreach ($wds as $w): ?>
                <tr>
                    <td>#<?= $w['id'] ?></td>
                    <td><?= htmlspecialchars($w['username'] ?? '-') ?></td>
                    <td><strong><?= rupiah($w['amount']) ?></strong></td>
                    <td><code><?= htmlspecialchars($w['dana_number']) ?></code></td>
                    <td><?= htmlspecialchars($w['dana_name']) ?></td>
                    <td><span class="badge badge-<?= $w['status'] ?>"><?= $w['status'] ?></span></td>
                    <td>
                        <?php if ($w['status']=='pending'): ?>
                        <form method="POST" style="display:inline-flex;gap:4px">
                            <input type="hidden" name="csrf" value="<?= csrf() ?>">
                            <input type="hidden" name="wid" value="<?= $w['id'] ?>">
                            <button name="act" value="approve" class="btn-icon btn-ok" onclick="return confirm('Approve?')"><i class="fas fa-check"></i></button>
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
            <thead><tr><th>ID</th><th>Nomor</th><th>Negara</th><th>Tipe</th><th>Harga Beli</th><th>Seller</th><th>Status</th></tr></thead>
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
        <div style="overflow-x:auto">
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
        $keys = ['dana_admin','dana_name','harga_limit','harga_nonlimit_min','harga_nonlimit_max','min_withdraw','komisi_referral','banner_url','auto_increment'];
        foreach ($keys as $k) if (isset($_POST[$k])) $pdo->prepare("UPDATE settings SET v=? WHERE k=?")->execute([trim($_POST[$k]), $k]);
        $msg = 'Disimpan!';
    } elseif ($act === 'telegram') {
        $pdo->prepare("UPDATE settings SET v=? WHERE k='tg_bot_token'")->execute([trim($_POST['tg_bot_token'] ?? '')]);
        $pdo->prepare("UPDATE settings SET v=? WHERE k='tg_bot_username'")->execute([ltrim(trim($_POST['tg_bot_username'] ?? ''), '@')]);
        $msg = 'Telegram config disimpan!';
    } elseif ($act === 'test_telegram') {
        $test = tgSendMessage($pdo, $_POST['test_chat_id'] ?? '', "🧪 <b>Test Notifikasi</b>\n\nBot <b>" . SITE_NAME . "</b> aktif!");
        if ($test) $msg = 'Test terkirim!'; else $err = 'Gagal kirim.';
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
        <p style="color:var(--text-muted);margin-bottom:20px">Bot kirim notifikasi saat setoran/withdraw diproses.</p>
        <form method="POST">
            <input type="hidden" name="csrf" value="<?= csrf() ?>">
            <input type="hidden" name="act" value="telegram">
            <div class="form-group"><label>Bot Token (dari @BotFather)</label><input type="text" name="tg_bot_token" value="<?= htmlspecialchars(getSetting($pdo,'tg_bot_token','')) ?>" placeholder="1234567890:ABC-xxx..."></div>
            <div class="form-group"><label>Bot Username (tanpa @)</label><input type="text" name="tg_bot_username" value="<?= htmlspecialchars(getSetting($pdo,'tg_bot_username','')) ?>" placeholder="shellnumberwsbot"></div>
            <button class="btn btn-primary"><i class="fas fa-save"></i> Simpan</button>
        </form>
        <hr style="margin:25px 0;border:none;border-top:1px solid var(--border)">
        <h3>Test Notifikasi</h3>
        <form method="POST" style="margin-top:15px">
            <input type="hidden" name="csrf" value="<?= csrf() ?>">
            <input type="hidden" name="act" value="test_telegram">
            <div class="form-group"><label>Chat ID Kamu</label><input type="text" name="test_chat_id" placeholder="123456789"></div>
            <button class="btn btn-outline"><i class="fas fa-paper-plane"></i> Kirim Test</button>
        </form>
    </div>

    <div class="card">
        <h2><i class="fas fa-cog"></i> Config Umum</h2>
        <form method="POST">
            <input type="hidden" name="csrf" value="<?= csrf() ?>">
            <input type="hidden" name="act" value="general">
            <div class="grid-2">
                <div class="form-group"><label>Nomor Dana</label><input type="text" name="dana_admin" value="<?= htmlspecialchars(getSetting($pdo,'dana_admin','')) ?>"></div>
                <div class="form-group"><label>Nama Dana</label><input type="text" name="dana_name" value="<?= htmlspecialchars(getSetting($pdo,'dana_name','')) ?>"></div>
                <div class="form-group"><label>Harga Limit</label><input type="number" name="harga_limit" value="<?= (int)getSetting($pdo,'harga_limit',1000) ?>"></div>
                <div class="form-group"><label>Min Withdraw</label><input type="number" name="min_withdraw" value="<?= (int)getSetting($pdo,'min_withdraw',1000) ?>"></div>
                <div class="form-group"><label>Non-Limit Min</label><input type="number" name="harga_nonlimit_min" value="<?= (int)getSetting($pdo,'harga_nonlimit_min',1000) ?>"></div>
                <div class="form-group"><label>Non-Limit Max</label><input type="number" name="harga_nonlimit_max" value="<?= (int)getSetting($pdo,'harga_nonlimit_max',5000) ?>"></div>
                <div class="form-group"><label>Komisi Referral</label><input type="number" name="komisi_referral" value="<?= (int)getSetting($pdo,'komisi_referral',250) ?>"></div>
                <div class="form-group"><label>Banner URL</label><input type="text" name="banner_url" value="<?= htmlspecialchars(getSetting($pdo,'banner_url', BANNER_URL)) ?>"></div>
                <div class="form-group"><label>Auto Increment Counter (0/1)</label><input type="text" name="auto_increment" value="<?= htmlspecialchars(getSetting($pdo,'auto_increment','1')) ?>"></div>
            </div>
            <button class="btn btn-primary btn-lg"><i class="fas fa-save"></i> Simpan Semua</button>
        </form>
    </div>
</div>
<?php include __DIR__ . '/../includes/footer.php'; ?>
PHPEOF
echo -e "${GREEN}  ✓ Admin panel OK${NC}"

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

# ============ SSL ============
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
echo -e "${GREEN}║  📱 Sell Ws Word v8.0                        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🔗 URL:${NC}"
echo -e "  🏠 Home    : $PROTO://$SUBDOMAIN"
echo -e "  🔐 Login   : $PROTO://$SUBDOMAIN/login.php"
echo -e "  📝 Daftar  : $PROTO://$SUBDOMAIN/register.php"
echo -e "  🛡️  Admin   : $PROTO://$SUBDOMAIN/admin/"
echo ""
echo -e "${MAGENTA}🔑 Admin:${NC}"
echo -e "  👤 User : $ADMIN_USER"
echo -e "  🔑 Pass : $ADMIN_PASS"
echo ""
echo -e "${CYAN}📌 Fitur Baru v8.0:${NC}"
echo -e "  ✅ Popup OTP otomatis setelah setor"
echo -e "  ✅ Pesan: OTP dari WA Device (BUKAN SMS)"
echo -e "  ✅ Wajib centang nomor sudah aktif di WA"
echo -e "  ✅ Wajib konfirmasi saat setor"
echo -e "  ✅ Admin flow: Minta OTP → Verif → Approve"
echo -e "  ✅ Animated counter + auto-increment"
echo ""
echo -e "${GREEN}🎉 Done! 🚀${NC}"
