#!/bin/bash
# ============================================
#   📱 SELL WS WORD v10.0 — BAN SYSTEM UPDATE
#   Lock: Setor, WD, OTP, Referral
# ============================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

[[ $EUID -ne 0 ]] && { echo -e "${RED}❌ Harus root!${NC}"; exit 1; }

clear
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  📱 SELL WS WORD v10.0 — BAN SYSTEM        ║${NC}"
echo -e "${CYAN}║  Lock Setor/Withdraw/OTP/Referral          ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

read -p "👉 Subdomain: " SUBDOMAIN
[[ -z "$SUBDOMAIN" ]] && { echo -e "${RED}❌ Kosong!${NC}"; exit 1; }

WEB_ROOT="/var/www/$SUBDOMAIN"
[[ ! -d "$WEB_ROOT" ]] && { echo -e "${RED}❌ Folder tidak ada: $WEB_ROOT${NC}"; exit 1; }

# ============ BACKUP ============
BACKUP="${WEB_ROOT}_backup_$(date +%Y%m%d_%H%M%S)"
echo -e "${CYAN}[1/8] Backup ke $BACKUP${NC}"
cp -r "$WEB_ROOT" "$BACKUP"
echo -e "${GREEN}  ✓ Backup OK${NC}"

# ============ DB: TAMBAH KOLOM BAN ============
echo -e "${CYAN}[2/8] Update database...${NC}"
DB_NAME=$(grep "DB_NAME" "$WEB_ROOT/includes/config.php" | grep -oP "'\K[^']+" | tail -1)
DB_USER=$(grep "DB_USER" "$WEB_ROOT/includes/config.php" | grep -oP "'\K[^']+" | tail -1)
echo "  DB: $DB_NAME / User: $DB_USER"

mysql "$DB_NAME" -e "SHOW COLUMNS FROM users LIKE 'banned_reason';" 2>/dev/null | grep -q banned_reason || \
    mysql "$DB_NAME" -e "ALTER TABLE users ADD COLUMN banned_reason TEXT DEFAULT NULL;"

mysql "$DB_NAME" -e "SHOW COLUMNS FROM users LIKE 'banned_at';" 2>/dev/null | grep -q banned_at || \
    mysql "$DB_NAME" -e "ALTER TABLE users ADD COLUMN banned_at DATETIME DEFAULT NULL;"

mysql "$DB_NAME" -e "SHOW COLUMNS FROM users LIKE 'banned_by';" 2>/dev/null | grep -q banned_by || \
    mysql "$DB_NAME" -e "ALTER TABLE users ADD COLUMN banned_by INT DEFAULT NULL;"

echo -e "${GREEN}  ✓ Kolom ban OK${NC}"

# ============ HELPER FILE ============
echo -e "${CYAN}[3/8] Bikin helpers...${NC}"

# Tulis ke config.php kalau belum ada
if ! grep -q "apiCheckBanned" "$WEB_ROOT/includes/config.php"; then
    # Insert helper sebelum penutup PHP
    HELPERS='
// ============ BAN HELPERS ============
function isBanned() {
    return isLoggedIn() && ($_SESSION['"'"'status'"'"'] ?? '"'"'active'"'"') === '"'"'banned'"'"';
}

function getBanInfo($pdo, $userId) {
    try {
        $s = $pdo->prepare("SELECT status, banned_reason, banned_at FROM users WHERE id=?");
        $s->execute([$userId]);
        return $s->fetch() ?: ["status" => "active"];
    } catch (Exception $e) {
        return ["status" => "active"];
    }
}

function apiCheckBanned($pdo) {
    if (!isLoggedIn()) {
        header("Content-Type: application/json");
        echo json_encode(["ok" => false, "error" => "Login required"]);
        exit;
    }
    $s = $pdo->prepare("SELECT status FROM users WHERE id=?");
    $s->execute([$_SESSION["user_id"]]);
    $u = $s->fetch();
    if (($u["status"] ?? "active") === "banned") {
        header("Content-Type: application/json");
        echo json_encode(["ok" => false, "error" => "Akun kamu DIBANNED. Tidak bisa akses fitur ini."]);
        exit;
    }
}

function pageCheckBanned($pdo, $feature = "Fitur ini") {
    $s = $pdo->prepare("SELECT status FROM users WHERE id=?");
    $s->execute([$_SESSION["user_id"]]);
    $u = $s->fetch();
    if (($u["status"] ?? "active") === "banned") {
        $_SESSION["flash_error"] = "Akun kamu DIBANNED. $feature tidak bisa diakses.";
        header("Location: /user/?banned=1");
        exit;
    }
}

function refreshSessionStatus($pdo) {
    if (!isLoggedIn()) return;
    $s = $pdo->prepare("SELECT status FROM users WHERE id=?");
    $s->execute([$_SESSION["user_id"]]);
    $u = $s->fetch();
    if ($u) $_SESSION["status"] = $u["status"];
}
'
    # Remove closing ?> if exists, append helper, close PHP
    sed -i '$ d' "$WEB_ROOT/includes/config.php" 2>/dev/null
    echo "$HELPERS" >> "$WEB_ROOT/includes/config.php"
    echo "?>" >> "$WEB_ROOT/includes/config.php"
    echo -e "${GREEN}  ✓ Helper ditambah ke config.php${NC}"
else
    echo -e "${GREEN}  ✓ Helper sudah ada${NC}"
fi

# ============ UPDATE login.php ============
echo -e "${CYAN}[4/8] Update login.php...${NC}"

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
            $_SESSION['user_id'] = $user['id'];
            $_SESSION['username'] = $user['username'];
            $_SESSION['role'] = $user['role'];
            $_SESSION['status'] = $user['status'];
            $pdo->prepare("UPDATE users SET last_login=NOW() WHERE id=?")->execute([$user['id']]);
            logAct($pdo, $user['id'], 'Login' . ($user['status'] === 'banned' ? ' (BANNED)' : ''));
            header('Location: /user/'); exit;
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
echo -e "${GREEN}  ✓ login.php OK${NC}"

# ============ UPDATE user/index.php ============
echo -e "${CYAN}[5/8] Update user/index.php...${NC}"

cat > "$WEB_ROOT/user/index.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
requireLogin();
$uid = $_SESSION['user_id'];

// Refresh status banned
refreshSessionStatus($pdo);

$s = $pdo->prepare("SELECT * FROM users WHERE id=?"); $s->execute([$uid]); $me = $s->fetch();
$isBanned = ($me['status'] ?? 'active') === 'banned';

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
    <?php if (!empty($_SESSION['flash_error'])): ?>
    <div class="alert alert-error" style="font-size:.95em">
        <i class="fas fa-triangle-exclamation"></i>
        <div><?= $_SESSION['flash_error'] ?></div>
    </div>
    <?php unset($_SESSION['flash_error']); endif; ?>

    <?php if ($isBanned): ?>
    <div class="ban-banner">
        <div class="ban-icon"><i class="fas fa-ban"></i></div>
        <div class="ban-content">
            <h3>🚫 Akun Kamu DIBANNED</h3>
            <p>Fitur <b>Setor Nomor</b>, <b>Withdraw</b>, dan <b>Referral</b> dikunci sementara.</p>
            <?php if (!empty($me['banned_reason'])): ?>
                <p class="ban-reason"><strong>Alasan:</strong> <?= htmlspecialchars($me['banned_reason']) ?></p>
            <?php endif; ?>
            <?php if (!empty($me['banned_at'])): ?>
                <p class="ban-date"><i class="fas fa-clock"></i> Diban pada: <?= date('d M Y H:i', strtotime($me['banned_at'])) ?></p>
            <?php endif; ?>
            <p style="margin-top:10px;font-size:.85em;color:var(--text-muted)">
                <i class="fas fa-info-circle"></i> Hubungi admin jika kamu merasa ini kesalahan.
            </p>
        </div>
    </div>
    <?php endif; ?>

    <div class="welcome-card">
        <div class="wc-left">
            <div class="wc-avatar"><?= strtoupper(substr($me['username'], 0, 1)) ?></div>
            <div>
                <h1>Halo, <?= htmlspecialchars($me['username']) ?>!</h1>
                <p>
                    <?php if ($isBanned): ?>
                        <span class="badge badge-banned"><i class="fas fa-ban"></i> BANNED</span>
                    <?php else: ?>
                        <span class="badge badge-user">MEMBER</span>
                    <?php endif; ?>
                    <span style="margin-left:8px;color:var(--text-muted)"><?= htmlspecialchars($me['email']) ?></span>
                </p>
            </div>
        </div>
        <div class="wc-right">
            <?php if ($isBanned): ?>
                <button class="btn btn-outline" onclick="alert('Akun kamu dibanned. Hubungi admin.')"><i class="fas fa-lock"></i> Terkunci</button>
            <?php else: ?>
                <a href="/user/setor.php" class="btn btn-primary pulse-btn"><i class="fas fa-plus-circle"></i> Setor Nomor</a>
            <?php endif; ?>
        </div>
    </div>

    <?php if ($otpPending > 0 && !$isBanned): ?>
    <div class="alert alert-warning pulse-warn">
        <i class="fas fa-key"></i> <b><?= $otpPending ?></b> setoran menunggu kode OTP dari kamu!
        <a href="/user/riwayat.php" class="btn btn-sm btn-gold">Input Sekarang</a>
    </div>
    <?php endif; ?>

    <div class="stats-grid">
        <div class="stat-card">
            <div class="stat-icon" style="background:linear-gradient(135deg,#43e97b,#38f9d7)"><i class="fas fa-wallet"></i></div>
            <div class="stat-info"><h3><?= rupiah($me['saldo']) ?></h3><p>Saldo<?= $isBanned ? ' (LOCKED)' : '' ?></p></div>
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
            <?php if ($isBanned): ?>
                <button class="btn btn-outline btn-block" style="margin-top:15px" onclick="alert('Withdraw terkunci.')"><i class="fas fa-lock"></i> Terkunci</button>
            <?php else: ?>
                <a href="/user/withdraw.php" class="btn btn-outline btn-block" style="margin-top:15px">Withdraw →</a>
            <?php endif; ?>
        </div>
    </div>
</div>
<?php include __DIR__ . '/../includes/footer.php'; ?>
PHPEOF
echo -e "${GREEN}  ✓ user/index.php OK${NC}"

# ============ UPDATE user/setor.php ============
echo -e "${CYAN}[6/8] Update user/setor.php...${NC}"

cat > "$WEB_ROOT/user/setor.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
requireLogin();
pageCheckBanned($pdo, 'Setor nomor');

$uid = $_SESSION['user_id'];
$msg = ''; $err = '';
$popupSub = null;

if (isset($_GET['success'])) {
    $sid = (int)$_GET['success'];
    $s = $pdo->prepare("SELECT * FROM submissions WHERE id=? AND user_id=?");
    $s->execute([$sid, $uid]);
    $popupSub = $s->fetch();
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && checkCsrf($_POST['csrf'] ?? '')) {
    // Double check banned
    $s = $pdo->prepare("SELECT status FROM users WHERE id=?"); $s->execute([$uid]);
    if (($s->fetch()['status'] ?? 'active') === 'banned') {
        $err = '🚫 Akun kamu DIBANNED. Tidak bisa setor nomor.';
    } else {
        $tipe = $_POST['tipe'] ?? '';
        $negara = trim($_POST['negara'] ?? 'Indonesia');
        $nomor = trim($_POST['nomor'] ?? '');
        $catatan = trim($_POST['catatan'] ?? '');
        $wa_active = isset($_POST['wa_active']) ? 1 : 0;

        if (!$wa_active) $err = 'Kamu harus konfirmasi nomor aktif di WhatsApp';
        elseif (!in_array($tipe, ['limit','nonlimit'])) $err = 'Tipe tidak valid';
        elseif (!validPhone($nomor)) $err = 'Format nomor tidak valid (9-15 digit)';
        elseif (strlen($negara) < 2) $err = 'Negara tidak valid';
        else {
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
echo -e "${GREEN}  ✓ user/setor.php OK${NC}"

# ============ UPDATE user/withdraw.php ============
cat > "$WEB_ROOT/user/withdraw.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
requireLogin();
pageCheckBanned($pdo, 'Withdraw');

$uid = $_SESSION['user_id'];
$s = $pdo->prepare("SELECT * FROM users WHERE id=?"); $s->execute([$uid]); $me = $s->fetch();
$msg = ''; $err = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && checkCsrf($_POST['csrf'] ?? '')) {
    // Double check banned
    $s = $pdo->prepare("SELECT status FROM users WHERE id=?"); $s->execute([$uid]);
    if (($s->fetch()['status'] ?? 'active') === 'banned') {
        $err = '🚫 Akun kamu DIBANNED. Saldo terkunci.';
    } else {
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
echo -e "${GREEN}  ✓ user/withdraw.php OK${NC}"

# ============ UPDATE user/referral.php ============
cat > "$WEB_ROOT/user/referral.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
requireLogin();
$uid = $_SESSION['user_id'];
$s = $pdo->prepare("SELECT * FROM users WHERE id=?"); $s->execute([$uid]); $me = $s->fetch();
$isBanned = ($me['status'] ?? 'active') === 'banned';
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

    <?php if ($isBanned): ?>
    <div class="ban-banner">
        <div class="ban-icon"><i class="fas fa-ban"></i></div>
        <div class="ban-content">
            <h3>🚫 Referral Terkunci</h3>
            <p>Akun kamu dibanned. <b>Komisi referral baru tidak akan masuk</b> sampai akun diaktifkan kembali.</p>
            <?php if (!empty($me['banned_reason'])): ?>
                <p class="ban-reason"><strong>Alasan:</strong> <?= htmlspecialchars($me['banned_reason']) ?></p>
            <?php endif; ?>
        </div>
    </div>
    <?php endif; ?>

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
echo -e "${GREEN}  ✓ user/referral.php OK${NC}"

# ============ UPDATE api/submit-otp.php ============
cat > "$WEB_ROOT/api/submit-otp.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
header('Content-Type: application/json');

if (!isLoggedIn()) { echo json_encode(['ok'=>false, 'error'=>'Login required']); exit; }

// Cek banned
$uCheck = $pdo->prepare("SELECT status FROM users WHERE id=?");
$uCheck->execute([$_SESSION['user_id']]);
$uStatus = $uCheck->fetch();
if (($uStatus['status'] ?? 'active') === 'banned') {
    echo json_encode(['ok'=>false, 'error'=>'🚫 Akun kamu DIBANNED. Tidak bisa submit OTP.']);
    exit;
}

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
echo -e "${GREEN}  ✓ api/submit-otp.php OK${NC}"

# ============ TAMBAH CSS BAN BANNER ============
echo -e "${CYAN}[7/8] Tambah CSS...${NC}"

if ! grep -q "ban-banner" "$WEB_ROOT/assets/css/style.css"; then
    cat >> "$WEB_ROOT/assets/css/style.css" << 'CSSEOF'

/* ============================================
   BAN BANNER
   ============================================ */
.ban-banner {
    background: linear-gradient(135deg, rgba(255,71,87,.2), rgba(200,40,60,.1));
    border: 2px solid rgba(255,71,87,.5);
    border-radius: 18px;
    padding: 22px;
    margin-bottom: 25px;
    display: flex;
    gap: 18px;
    align-items: flex-start;
    animation: banPulse 2s infinite;
}
@keyframes banPulse {
    0%, 100% { box-shadow: 0 0 0 0 rgba(255,71,87,.4); }
    50% { box-shadow: 0 0 0 12px rgba(255,71,87,0); }
}
.ban-icon {
    width: 60px;
    height: 60px;
    border-radius: 50%;
    background: linear-gradient(135deg, #ff4757, #c0392b);
    display: flex;
    align-items: center;
    justify-content: center;
    color: #fff;
    font-size: 1.8em;
    flex-shrink: 0;
    box-shadow: 0 6px 25px rgba(255,71,87,.5);
}
.ban-content { flex: 1; }
.ban-content h3 {
    font-family: 'Space Grotesk', sans-serif;
    color: #ff4757;
    margin-bottom: 8px;
    font-size: 1.3em;
}
.ban-content p {
    color: var(--text);
    font-size: .92em;
    margin-bottom: 6px;
}
.ban-reason {
    background: rgba(0,0,0,.2);
    padding: 10px 14px;
    border-radius: 10px;
    border-left: 4px solid #ff4757;
    margin: 10px 0 !important;
}
.ban-date {
    color: var(--text-muted) !important;
    font-size: .82em !important;
}

@media (max-width: 600px) {
    .ban-banner { flex-direction: column; padding: 18px; }
    .ban-icon { width: 50px; height: 50px; font-size: 1.5em; }
}
CSSEOF
    echo -e "${GREEN}  ✓ CSS ban banner ditambah${NC}"
else
    echo -e "${GREEN}  ✓ CSS sudah ada${NC}"
fi

# ============ FIX PERMISSION ============
echo -e "${CYAN}[8/8] Fix permission & restart...${NC}"
chown -R www-data:www-data "$WEB_ROOT"
chmod -R 755 "$WEB_ROOT"
systemctl reload nginx
systemctl restart php8.3-fpm
echo -e "${GREEN}  ✓ Selesai${NC}"

# ============ SUMMARY ============
clear
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ BAN SYSTEM v10.0 — INSTALLED!          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🔒 Yang Terkunci Saat Banned:${NC}"
echo "  🚫 Setor Nomor"
echo "  🚫 Withdraw (saldo dikunci)"
echo "  🚫 Submit OTP"
echo "  🚫 Referral komisi"
echo ""
echo -e "${CYAN}✅ Yang Tetap Bisa:${NC}"
echo "  ✅ Login (lihat alasan)"
echo "  ✅ Dashboard (read-only)"
echo "  ✅ Riwayat transaksi"
echo "  ✅ Ganti password"
echo ""
echo -e "${CYAN}📌 Cara Pakai:${NC}"
echo "  1. Login admin: /admin/users.php"
echo "  2. Klik 'Kelola' user → Tab Status"
echo "  3. Isi alasan ban → Klik Ban"
echo "  4. User langsung terkunci fiturnya"
echo ""
echo -e "${CYAN}📁 Backup:${NC} $BACKUP"
echo ""
echo -e "${GREEN}🧪 Test:${NC}"
echo "  1. Hard refresh: Ctrl+Shift+R"
echo "  2. Login user → cek banner (kalau banned)"
echo "  3. Coba akses /user/setor.php → redirect"
echo ""
