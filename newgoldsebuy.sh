#!/bin/bash
# ============================================
#   🪙 TREASURY GOLD — FINAL MASTER UPDATE
# ============================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

[[ $EUID -ne 0 ]] && { echo -e "${RED}❌ Harus root!${NC}"; exit 1; }

clear
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🪙 TREASURY GOLD — FINAL MASTER UPDATE    ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

read -p "👉 Subdomain (contoh: gold.voltxyz.my.id): " SUBDOMAIN
WEB_ROOT="/var/www/$SUBDOMAIN"

[[ ! -d "$WEB_ROOT" ]] && { echo -e "${RED}❌ Folder tidak ada: $WEB_ROOT${NC}"; exit 1; }

echo -e "${GREEN}📁 Web root: $WEB_ROOT${NC}"

# ============ 1. UPDATE DATABASE ============
echo -e "${CYAN}[1/5] Cek Database...${NC}"
DB_NAME=$(grep "DB_NAME" "$WEB_ROOT/includes/config.php" | grep -oP "'\K[^']+" | tail -1)

mysql "$DB_NAME" -e "SHOW COLUMNS FROM users LIKE 'last_claim_date';" 2>/dev/null | grep -q last_claim_date || \
    mysql "$DB_NAME" -e "ALTER TABLE users ADD COLUMN last_claim_date DATE DEFAULT NULL;"

mysql "$DB_NAME" -e "SHOW COLUMNS FROM users LIKE 'claim_streak';" 2>/dev/null | grep -q claim_streak || \
    mysql "$DB_NAME" -e "ALTER TABLE users ADD COLUMN claim_streak INT DEFAULT 0;"

echo -e "${GREEN}  ✓ Kolom Daily Reward siap${NC}"

# ============ 2. UPDATE HEADER (Security) ============
echo -e "${CYAN}[2/5] Update Header (Security)...${NC}"
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
            <a href="/profile.php" class="btn btn-sm btn-outline" style="border:none"><i class="fas fa-user"></i> Profil</a>
            <a href="/logout.php" class="btn btn-sm btn-outline" style="border:none;color:var(--danger)">Logout</a>
        <?php else: ?>
            <a href="/login.php" class="btn btn-sm btn-outline">Login</a>
        <?php endif; ?>
    </div>
</nav>
HTMLEOF

# ============ 3. UPDATE FOOTER (Tambah Menu Bonus) ============
echo -e "${CYAN}[3/5] Update Bottom Navigation...${NC}"
cat > "$WEB_ROOT/includes/footer.php" << 'HTMLEOF'
<div class="bottom-nav">
    <a href="/" class="nav-item <?= basename($_SERVER['PHP_SELF']) == 'index.php' ? 'active' : '' ?>"><i class="fas fa-home"></i> Home</a>
    <a href="/chart.php" class="nav-item <?= basename($_SERVER['PHP_SELF']) == 'chart.php' ? 'active' : '' ?>"><i class="fas fa-chart-line"></i> Market</a>
    <a href="/trade.php" class="nav-item <?= basename($_SERVER['PHP_SELF']) == 'trade.php' ? 'active' : '' ?>"><i class="fas fa-shopping-cart"></i> Trade</a>
    <a href="/daily.php" class="nav-item <?= basename($_SERVER['PHP_SELF']) == 'daily.php' ? 'active' : '' ?>"><i class="fas fa-gift"></i> Bonus</a>
    <a href="/profile.php" class="nav-item <?= basename($_SERVER['PHP_SELF']) == 'profile.php' ? 'active' : '' ?>"><i class="fas fa-user"></i> Profil</a>
</div>
</body>
</html>
HTMLEOF

# ============ 4. UPDATE HALAMAN USER & API ============
echo -e "${CYAN}[4/5] Update Halaman User...${NC}"

# DAILY REWARD
cat > "$WEB_ROOT/daily.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
requireLogin();
$uid = $_SESSION['user_id'];
$cekDep = $pdo->prepare("SELECT COUNT(*) FROM deposits WHERE user_id=? AND status='approved'");
$cekDep->execute([$uid]);
$pernahDeposit = ($cekDep->fetchColumn() > 0);

$s = $pdo->prepare("SELECT * FROM users WHERE id=?"); $s->execute([$uid]); $me = $s->fetch();
$today = date('Y-m-d');
$lastClaim = $me['last_claim_date'];
$streak = (int)$me['claim_streak'];

$msg = ''; $err = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['claim'])) {
    if (!$pernahDeposit) {
        $err = 'Kamu harus melakukan Deposit minimal 1x untuk klaim hadiah!';
    } elseif ($lastClaim === $today) {
        $err = 'Kamu sudah klaim hari ini. Kembali besok ya!';
    } else {
        if ($lastClaim === date('Y-m-d', strtotime('-1 day'))) { $streak++; } 
        else { $streak = 1; }
        if ($streak > 7) $streak = 1;

        $rewards = [1 => 1000, 2 => 2000, 3 => 3000, 4 => 4000, 5 => 5000, 6 => 6000, 7 => 10000];
        $hadiah = $rewards[$streak];

        $pdo->beginTransaction();
        try {
            $pdo->prepare("UPDATE users SET saldo_rp = saldo_rp + ?, last_claim_date = ?, claim_streak = ? WHERE id=?")->execute([$hadiah, $today, $streak, $uid]);
            $pdo->commit(); $msg = "Berhasil klaim Rp " . number_format($hadiah,0,',','.') . "! Streak hari ke-$streak.";
            $me['saldo_rp'] += $hadiah; $lastClaim = $today;
        } catch (Exception $e) { $pdo->rollBack(); $err = 'Gagal klaim.'; }
    }
}
$pageTitle = 'Daily Reward';
include __DIR__ . '/includes/header.php';
?>
<div class="container">
    <h2 style="margin-bottom:20px; text-align:center">Hadiah Harian</h2>
    <div class="card" style="text-align:center; background:linear-gradient(135deg, rgba(245,158,11,0.15), transparent); border-color:var(--primary)">
        <i class="fas fa-gift" style="font-size:3em; color:var(--primary); margin-bottom:15px"></i>
        <h3 style="margin-bottom:5px">Klaim Bonus Harianmu!</h3>
        <p style="color:var(--text-muted); margin-bottom:20px">Login setiap hari untuk dapat saldo gratis. Streak makin panjang, hadiah makin besar!</p>

        <?php if (!$pernahDeposit): ?>
            <div class="alert alert-error" style="text-align:left"><i class="fas fa-lock"></i> <b>Akses Terkunci.</b><br>Kamu wajib melakukan <b>Deposit minimal 1x</b> dan menunggu di-approve admin sebelum bisa klaim.</div>
            <a href="/deposit.php" class="btn btn-primary btn-block">Deposit Sekarang</a>
        <?php else: ?>
            <?php if ($msg): ?><div class="alert alert-success"><?= $msg ?></div><?php endif; ?>
            <?php if ($err): ?><div class="alert alert-error"><?= $err ?></div><?php endif; ?>
            <div style="background:rgba(0,0,0,0.2); padding:15px; border-radius:12px; margin-bottom:20px">
                <div style="font-size:0.85em; color:var(--text-muted)">Streak Saat Ini</div>
                <div style="font-size:2em; font-weight:800; color:var(--primary)">Hari ke-<?= $streak ?>/7</div>
            </div>
            <form method="POST">
                <?php if ($lastClaim === $today): ?>
                    <button type="button" class="btn btn-primary btn-block" disabled style="opacity:0.5; cursor:not-allowed"><i class="fas fa-check-circle"></i> Sudah Diklaim Hari Ini</button>
                <?php else: ?>
                    <button type="submit" name="claim" class="btn btn-primary btn-block pulse-btn"><i class="fas fa-gift"></i> Klaim Hadiah Hari Ini</button>
                <?php endif; ?>
            </form>
        <?php endif; ?>
    </div>
    <div class="card" style="margin-top:20px">
        <h3 style="margin-bottom:15px; font-size:1.1em"><i class="fas fa-list"></i> Daftar Hadiah (7 Hari)</h3>
        <div style="display:grid; grid-template-columns:repeat(2, 1fr); gap:10px;">
            <?php $rewards = [1 => 1000, 2 => 2000, 3 => 3000, 4 => 4000, 5 => 5000, 6 => 6000, 7 => 10000];
            foreach ($rewards as $day => $amount): $isClaimed = ($lastClaim === $today && $streak == $day); ?>
                <div style="background:<?= $isClaimed ? 'rgba(16,185,129,0.2)' : 'rgba(255,255,255,0.05)' ?>; border:1px solid <?= $isClaimed ? 'var(--success)' : 'var(--border)' ?>; padding:15px; border-radius:10px; text-align:center">
                    <div style="font-size:0.8em; color:var(--text-muted)">Hari <?= $day ?></div>
                    <div style="font-weight:800; color:<?= $isClaimed ? 'var(--success)' : 'var(--primary)' ?>">Rp <?= number_format($amount,0,',','.') ?></div>
                </div>
            <?php endforeach; ?>
        </div>
    </div>
</div>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# TRADE (Jual & Beli)
cat > "$WEB_ROOT/trade.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
requireLogin();
$uid = $_SESSION['user_id'];
$s = $pdo->prepare("SELECT * FROM users WHERE id=?"); $s->execute([$uid]); $me = $s->fetch();
$harga = (float)getSetting($pdo, 'harga_emas', 1350000);
$msg = ''; $err = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action'])) {
    $action = $_POST['action']; $gram = (float)$_POST['gram']; $total = $gram * $harga;
    if ($action === 'buy') {
        if ($gram < 0.01) $err = 'Minimal 0.01 Gram!';
        elseif ($total > $me['saldo_rp']) $err = 'Saldo Rupiah tidak cukup!';
        else {
            $pdo->beginTransaction();
            try {
                $pdo->prepare("UPDATE users SET saldo_rp = saldo_rp - ?, saldo_gram = saldo_gram + ? WHERE id=?")->execute([$total, $gram, $uid]);
                $pdo->prepare("INSERT INTO transactions (user_id, type, amount_gram, price_per_gram, total_rp) VALUES (?,?,?,?,?)")->execute([$uid, 'buy_gold', $gram, $harga, $total]);
                $pdo->commit(); $msg = "Berhasil beli " . number_format($gram, 4) . " Gram emas!";
            } catch (Exception $e) { $pdo->rollBack(); $err = 'Gagal transaksi.'; }
        }
    } elseif ($action === 'sell') {
        if ($gram < 0.01) $err = 'Minimal 0.01 Gram!';
        elseif ($gram > $me['saldo_gram']) $err = 'Saldo Emas tidak cukup!';
        else {
            $pdo->beginTransaction();
            try {
                $pdo->prepare("UPDATE users SET saldo_gram = saldo_gram - ?, saldo_rp = saldo_rp + ? WHERE id=?")->execute([$gram, $total, $uid]);
                $pdo->prepare("INSERT INTO transactions (user_id, type, amount_gram, price_per_gram, total_rp) VALUES (?,?,?,?,?)")->execute([$uid, 'sell_gold', $gram, $harga, $total]);
                $pdo->commit(); $msg = "Berhasil jual " . number_format($gram, 4) . " Gram emas!";
            } catch (Exception $e) { $pdo->rollBack(); $err = 'Gagal transaksi.'; }
        }
    }
}
$pageTitle = 'Jual / Beli Emas';
include __DIR__ . '/includes/header.php';
?>
<div class="container">
    <h2 style="margin-bottom:20px">Trading Emas</h2>
    <div class="card" style="background:linear-gradient(135deg, rgba(245,158,11,0.1), transparent)">
        <div class="grid-2">
            <div><div style="font-size:0.85em; color:var(--text-muted)">Saldo Rupiah</div><div style="font-size:1.3em; font-weight:700"><?= rupiah($me['saldo_rp']) ?></div></div>
            <div><div style="font-size:0.85em; color:var(--text-muted)">Saldo Emas</div><div style="font-size:1.3em; font-weight:700; color:var(--primary)"><?= gram($me['saldo_gram']) ?></div></div>
        </div>
        <div style="text-align:center; margin-top:15px; font-size:0.9em; color:var(--text-muted)">Harga Emas: <b style="color:var(--success)"><?= rupiah($harga) ?> / gram</b></div>
    </div>
    <?php if ($msg): ?><div class="alert alert-success"><?= $msg ?></div><?php endif; ?>
    <?php if ($err): ?><div class="alert alert-error"><?= $err ?></div><?php endif; ?>
    <div class="grid-2">
        <div class="card" style="border-top:4px solid var(--success)">
            <h3 style="color:var(--success);margin-bottom:15px">Beli Emas</h3>
            <form method="POST"><input type="hidden" name="action" value="buy">
                <div class="form-group"><label>Jumlah Gram (Min 0.01)</label><input type="number" name="gram" step="0.01" min="0.01" value="0.01" required></div>
                <button class="btn btn-primary btn-block" style="background:var(--success);color:#fff">Beli</button>
            </form>
        </div>
        <div class="card" style="border-top:4px solid var(--danger)">
            <h3 style="color:var(--danger);margin-bottom:15px">Jual Emas</h3>
            <form method="POST"><input type="hidden" name="action" value="sell">
                <div class="form-group"><label>Jumlah Gram (Min 0.01)</label><input type="number" name="gram" step="0.01" min="0.01" value="0.01" required></div>
                <button class="btn btn-primary btn-block" style="background:var(--danger);color:#fff">Jual</button>
            </form>
        </div>
    </div>
</div>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# ============ 5. UPDATE ADMIN PANEL (Harga Manual & Bonus) ============
echo -e "${CYAN}[5/5] Update Admin Panel...${NC}"
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
            $bonus = ($d['amount'] >= 10000) ? 5000 : 0;
            $total_masuk = $d['amount'] + $bonus;
            $pdo->prepare("UPDATE deposits SET status='approved' WHERE id=?")->execute([$id]);
            $pdo->prepare("UPDATE users SET saldo_rp = saldo_rp + ? WHERE id=?")->execute([$total_masuk, $d['user_id']]);
            $msg = 'Deposit disetujui! Saldo masuk: Rp ' . number_format($total_masuk,0,',','.') . ($bonus ? ' (Termasuk Bonus Rp 5.000)' : '');
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
        $newPrice = (float)$_POST['price']; $pdo->prepare("UPDATE settings SET v=? WHERE k='harga_emas'")->execute([$newPrice]); $msg = 'Harga emas berhasil diubah manual.';
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
    } elseif ($act === 'add_rp') { $uid = (int)$_POST['uid']; $amount = (float)$_POST['amount']; $pdo->prepare("UPDATE users SET saldo_rp = saldo_rp + ? WHERE id=?")->execute([$amount, $uid]); $msg = "Berhasil menambah Rp " . number_format($amount,0,',','.') . " ke user.";
    } elseif ($act === 'cut_rp') { $uid = (int)$_POST['uid']; $amount = (float)$_POST['amount']; $pdo->prepare("UPDATE users SET saldo_rp = GREATEST(0, saldo_rp - ?) WHERE id=?")->execute([$amount, $uid]); $msg = "Berhasil memotong Rp " . number_format($amount,0,',','.') . " dari user.";
    } elseif ($act === 'add_gram') { $uid = (int)$_POST['uid']; $amount = (float)$_POST['amount']; $pdo->prepare("UPDATE users SET saldo_gram = saldo_gram + ? WHERE id=?")->execute([$amount, $uid]); $msg = "Berhasil menambah " . number_format($amount,4) . " gr emas ke user.";
    } elseif ($act === 'cut_gram') { $uid = (int)$_POST['uid']; $amount = (float)$_POST['amount']; $pdo->prepare("UPDATE users SET saldo_gram = GREATEST(0, saldo_gram - ?) WHERE id=?")->execute([$amount, $uid]); $msg = "Berhasil memotong " . number_format($amount,4) . " gr emas dari user.";
    } elseif ($act === 'ban_user') { $uid = (int)$_POST['uid']; $pdo->prepare("UPDATE users SET status='banned' WHERE id=? AND role='user'")->execute([$uid]); $msg = 'User dibanned!';
    } elseif ($act === 'unban_user') { $uid = (int)$_POST['uid']; $pdo->prepare("UPDATE users SET status='active' WHERE id=? AND role='user'")->execute([$uid]); $msg = 'User diaktifkan!';
    } elseif ($act === 'delete_user') { $uid = (int)$_POST['uid']; $pdo->prepare("DELETE FROM users WHERE id=? AND role='user'")->execute([$uid]); $msg = 'User dihapus permanen!';
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
        <a href="/x-panel-core/" class="logo"><i class="fas fa-shield-alt"></i> MANAGEMENT</a>
        <div><a href="/" target="_blank" style="color:var(--text-muted); margin-right:15px">Lihat Web</a><a href="/logout.php" style="color:var(--danger);font-size:0.9em">Logout</a></div>
    </div>
</nav>
<div class="container" style="max-width:1000px">
    <?php if ($msg): ?><div class="alert alert-success"><?= $msg ?></div><?php endif; ?>
    <div class="grid-2" style="margin-bottom:20px">
        <div class="card" style="text-align:center"><h3 style="color:var(--text-muted)">Total User</h3><div style="font-size:2em;font-weight:800;color:var(--primary)"><?= $totalUsers ?></div></div>
        <div class="card" style="text-align:center"><h3 style="color:var(--text-muted)">Harga Emas (Manual)</h3><div style="font-size:1.5em;font-weight:800;color:var(--success)">Rp <?= number_format((float)$price,0,',','.') ?></div></div>
    </div>
    <div class="tabs">
        <button class="tab-btn active" onclick="showTab('tab-deps')">Deposit</button>
        <button class="tab-btn" onclick="showTab('tab-wds')">Penarikan</button>
        <button class="tab-btn" onclick="showTab('tab-users')">Kelola User</button>
        <button class="tab-btn" onclick="showTab('tab-settings')">Set Harga & QRIS</button>
        <button class="tab-btn" onclick="showTab('tab-bc')">Broadcast</button>
    </div>

    <div id="tab-deps" class="tab-content active card">
        <h3 style="color:var(--primary);margin-bottom:15px">Deposit Pending</h3>
        <p style="font-size:0.85em; color:var(--text-muted); margin-bottom:15px">*Otomatis menambahkan Bonus Rp 5.000 jika nominal deposit ≥ Rp 10.000.</p>
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
        <h3 style="color:var(--primary);margin-bottom:15px">Update Harga Emas (Manual)</h3>
        <form method="POST" style="display:flex;gap:10px;align-items:flex-end;margin-bottom:30px"><div class="form-group" style="flex:1;margin:0"><label>Harga / Gram</label><input type="number" name="price" value="<?= $price ?>" required></div><button name="action" value="update_price" class="btn btn-primary">Set Harga</button></form>
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

# FIX CSS & PERMISSIONS
cat >> "$WEB_ROOT/assets/css/style.css" << 'CSSEOF'

/* PULSE BUTTON */
.pulse-btn { position: relative; animation: pulseAnim 2s infinite; }
@keyframes pulseAnim {
    0% { box-shadow: 0 0 0 0 rgba(245, 158, 11, 0.7); }
    70% { box-shadow: 0 0 0 15px rgba(245, 158, 11, 0); }
    100% { box-shadow: 0 0 0 0 rgba(245, 158, 11, 0); }
}
CSSEOF

chown -R www-data:www-data "$WEB_ROOT"
chmod -R 775 "$WEB_ROOT/uploads"
systemctl restart php8.3-fpm

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ FINAL MASTER UPDATE SELESAI!           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
