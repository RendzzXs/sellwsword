#!/bin/bash
# ============================================
#   🪙 TREASURY GOLD v7.0 — ELEGANT UI
#   UI Baru • Deposit Dana • Admin Elegant
# ============================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

[[ $EUID -ne 0 ]] && { echo -e "${RED}❌ Harus root!${NC}"; exit 1; }

clear
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🪙 TREASURY GOLD v7.0 — ELEGANT UPDATE    ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

read -p "👉 Subdomain (contoh: gold.voltxyz.my.id): " SUBDOMAIN
WEB_ROOT="/var/www/$SUBDOMAIN"

[[ ! -d "$WEB_ROOT" ]] && { echo -e "${RED}❌ Folder tidak ada: $WEB_ROOT${NC}"; exit 1; }

echo -e "${GREEN}📁 Web root: $WEB_ROOT${NC}"

# ============ 1. UPDATE DATABASE (DANA) ============
echo -e "${CYAN}[1/4] Setup Database...${NC}"
DB_NAME=$(grep "DB_NAME" "$WEB_ROOT/includes/config.php" | grep -oP "'\K[^']+" | tail -1)

# Tambah setting nomor Dana admin
mysql "$DB_NAME" -e "INSERT IGNORE INTO settings (k, v) VALUES ('dana_admin', '08123456789');" 2>/dev/null
mysql "$DB_NAME" -e "INSERT IGNORE INTO settings (k, v) VALUES ('dana_name', 'Admin Treasury');" 2>/dev/null

# Update tabel deposits untuk terima metode
mysql "$DB_NAME" -e "SHOW COLUMNS FROM deposits LIKE 'method';" 2>/dev/null | grep -q method || \
    mysql "$DB_NAME" -e "ALTER TABLE deposits ADD COLUMN method VARCHAR(20) DEFAULT 'QRIS';"

echo -e "${GREEN}  ✓ Database siap${NC}"

# ============ 2. UI CSS ELEGAN (GLOBAL) ============
echo -e "${CYAN}[2/4] Update CSS Elegan...${NC}"

cat > "$WEB_ROOT/assets/css/style.css" << 'CSSEOF'
:root {
    --bg: #09090b;
    --bg-card: #18181b;
    --bg-card-hover: #27272a;
    --text: #fafafa;
    --text-muted: #a1a1aa;
    --border: #27272a;
    --primary: #eab308;
    --primary-2: #ca8a04;
    --success: #10b981;
    --danger: #ef4444;
    --radius: 16px;
}
* { margin: 0; padding: 0; box-sizing: border-box; font-family: 'Inter', -apple-system, sans-serif; }
body { background: var(--bg); color: var(--text); line-height: 1.6; min-height: 100vh; padding-bottom: 80px; -webkit-font-smoothing: antialiased; }
a { color: inherit; text-decoration: none; }

/* TYPOGRAPHY */
h1, h2, h3 { letter-spacing: -0.02em; font-weight: 700; }
.text-muted { color: var(--text-muted); }

/* NAVBAR */
.navbar { position: sticky; top: 0; z-index: 100; background: rgba(9,9,11,0.8); backdrop-filter: blur(12px); border-bottom: 1px solid var(--border); padding: 16px 20px; display: flex; justify-content: space-between; align-items: center; }
.logo { font-size: 1.1em; font-weight: 800; display: flex; align-items: center; gap: 8px; color: var(--primary); }
.logo i { font-size: 1.2em; }

/* CONTAINER */
.container { max-width: 600px; margin: 0 auto; padding: 24px 20px; }

/* CARDS */
.card { background: var(--bg-card); border: 1px solid var(--border); border-radius: var(--radius); padding: 24px; margin-bottom: 20px; transition: all 0.3s ease; }
.card:hover { border-color: rgba(234, 179, 8, 0.3); }
.card-header { display: flex; align-items: center; gap: 12px; margin-bottom: 16px; }
.card-header i { color: var(--primary); font-size: 1.2em; }
.card-header h2 { font-size: 1.1em; margin: 0; }

/* GRID */
.grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
@media(max-width: 600px) { .grid-2 { grid-template-columns: 1fr; } }

/* BUTTONS */
.btn { padding: 12px 24px; border-radius: 12px; border: none; font-weight: 600; font-family: inherit; font-size: 0.95em; cursor: pointer; display: inline-flex; align-items: center; justify-content: center; gap: 8px; transition: all 0.2s; text-decoration: none; }
.btn-primary { background: var(--primary); color: #000; }
.btn-primary:hover { background: var(--primary-2); transform: translateY(-1px); }
.btn-outline { background: transparent; border: 1px solid var(--border); color: var(--text); }
.btn-outline:hover { background: var(--bg-card-hover); border-color: var(--text-muted); }
.btn-block { width: 100%; }
.btn-sm { padding: 8px 16px; font-size: 0.85em; border-radius: 8px; }
.btn-success { background: rgba(16, 185, 129, 0.15); color: var(--success); border: 1px solid rgba(16, 185, 129, 0.3); }
.btn-success:hover { background: var(--success); color: #000; }
.btn-danger { background: rgba(239, 68, 68, 0.15); color: var(--danger); border: 1px solid rgba(239, 68, 68, 0.3); }
.btn-danger:hover { background: var(--danger); color: #fff; }

/* FORMS */
.form-group { margin-bottom: 16px; }
.form-group label { display: block; margin-bottom: 8px; font-size: 0.85em; color: var(--text-muted); font-weight: 500; }
.form-group input, .form-group select { width: 100%; padding: 14px 16px; border: 1px solid var(--border); border-radius: 12px; background: var(--bg); color: var(--text); font-family: inherit; font-size: 0.95em; outline: none; transition: 0.2s; }
.form-group input:focus, .form-group select:focus { border-color: var(--primary); box-shadow: 0 0 0 3px rgba(234, 179, 8, 0.1); }

/* BOTTOM NAV */
.bottom-nav { position: fixed; bottom: 0; left: 0; right: 0; background: rgba(9,9,11,0.95); backdrop-filter: blur(20px); border-top: 1px solid var(--border); display: flex; justify-content: space-around; padding: 12px 0; z-index: 100; }
.nav-item { display: flex; flex-direction: column; align-items: center; gap: 4px; font-size: 0.65em; font-weight: 600; color: var(--text-muted); transition: 0.2s; padding: 0 10px; }
.nav-item i { font-size: 1.4em; margin-bottom: 2px; }
.nav-item.active, .nav-item:hover { color: var(--primary); }

/* ALERTS */
.alert { padding: 14px 16px; border-radius: 12px; margin-bottom: 16px; font-size: 0.85em; display: flex; align-items: center; gap: 10px; }
.alert-error { background: rgba(239, 68, 68, 0.1); color: var(--danger); border: 1px solid rgba(239, 68, 68, 0.2); }
.alert-success { background: rgba(16, 185, 129, 0.1); color: var(--success); border: 1px solid rgba(16, 185, 129, 0.2); }

/* BADGES */
.badge { padding: 4px 10px; border-radius: 6px; font-size: 0.7em; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; }
.badge-success { background: rgba(16, 185, 129, 0.15); color: var(--success); }
.badge-danger { background: rgba(239, 68, 68, 0.15); color: var(--danger); }
.badge-warning { background: rgba(234, 179, 8, 0.15); color: var(--primary); }

/* TABLES */
.table { width: 100%; border-collapse: collapse; font-size: 0.9em; }
.table th { text-align: left; padding: 12px 8px; color: var(--text-muted); font-size: 0.75em; text-transform: uppercase; border-bottom: 1px solid var(--border); font-weight: 600; }
.table td { padding: 14px 8px; border-bottom: 1px solid var(--border); }
.table tr:last-child td { border-bottom: none; }

/* ADMIN SPECIFIC */
.admin-header { background: #000; border-bottom: 1px solid var(--border); padding: 16px 24px; display: flex; justify-content: space-between; align-items: center; position: sticky; top: 0; z-index: 100; }
.admin-logo { font-weight: 800; font-size: 1.1em; color: var(--primary); display: flex; align-items: center; gap: 8px; }
.admin-tabs { display: flex; gap: 8px; margin-bottom: 24px; overflow-x: auto; padding-bottom: 8px; }
.admin-tab { padding: 10px 20px; border-radius: 10px; border: 1px solid var(--border); background: var(--bg-card); color: var(--text-muted); cursor: pointer; font-weight: 600; font-size: 0.85em; white-space: nowrap; transition: 0.2s; }
.admin-tab.active { background: var(--primary); color: #000; border-color: var(--primary); }
.admin-tab:hover:not(.active) { border-color: var(--text-muted); color: var(--text); }
.tab-pane { display: none; animation: fadeIn 0.3s; }
.tab-pane.active { display: block; }
@keyframes fadeIn { from { opacity: 0; transform: translateY(5px); } to { opacity: 1; transform: translateY(0); } }

/* MINI FORMS (ADMIN) */
.mini-form { display: flex; gap: 6px; align-items: center; background: rgba(0,0,0,0.2); padding: 6px; border-radius: 8px; }
.mini-form input { width: 90px; padding: 8px; border-radius: 6px; border: 1px solid var(--border); background: var(--bg); color: var(--text); font-size: 0.85em; }
.mini-form button { padding: 8px 12px; border-radius: 6px; border: none; cursor: pointer; font-size: 0.8em; font-weight: 700; }

/* CHART */
.chart-wrap { background: var(--bg); padding: 16px; border-radius: 12px; border: 1px solid var(--border); height: 250px; position: relative; }
CSSEOF

# ============ 3. UPDATE HALAMAN DEPOSIT (DANA & QRIS) ============
echo -e "${CYAN}[3/4] Update Deposit & Admin...${NC}"

cat > "$WEB_ROOT/deposit.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
requireLogin();
$uid = $_SESSION['user_id'];
$qris = getSetting($pdo, 'qris_url');
$danaAdmin = getSetting($pdo, 'dana_admin', '08123456789');
$danaName = getSetting($pdo, 'dana_name', 'Admin Treasury');
$msg = ''; $err = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $amount = (float)$_POST['amount'];
    $method = $_POST['method'];
    
    if ($amount < 5000) $err = 'Minimal deposit Rp 5.000!';
    elseif (!isset($_FILES['proof']) || $_FILES['proof']['error'] !== 0) $err = 'Bukti transfer wajib diupload!';
    else {
        $ext = pathinfo($_FILES['proof']['name'], PATHINFO_EXTENSION);
        if (!in_array(strtolower($ext), ['jpg','jpeg','png'])) $err = 'Format bukti harus JPG/PNG!';
        else {
            $fname = 'proof_' . $uid . '_' . time() . '.' . $ext;
            move_uploaded_file($_FILES['proof']['tmp_name'], __DIR__ . '/uploads/' . $fname);
            $pdo->prepare("INSERT INTO deposits (user_id, amount, proof, method) VALUES (?,?,?,?)")->execute([$uid, $amount, $fname, $method]);
            $msg = 'Deposit diajukan! Tunggu verifikasi admin.';
        }
    }
}
$pageTitle = 'Deposit';
include __DIR__ . '/includes/header.php';
?>
<div class="container">
    <h2 style="margin-bottom:20px">Deposit Saldo</h2>
    <?php if ($msg): ?><div class="alert alert-success"><i class="fas fa-check-circle"></i> <?= $msg ?></div><?php endif; ?>
    <?php if ($err): ?><div class="alert alert-error"><i class="fas fa-exclamation-circle"></i> <?= $err ?></div><?php endif; ?>

    <div class="card" style="background: rgba(234, 179, 8, 0.05); border-color: rgba(234, 179, 8, 0.2); padding:15px; margin-bottom:20px">
        <div style="display:flex; gap:10px; align-items:flex-start">
            <i class="fas fa-gift" style="color:var(--primary); font-size:1.2em; margin-top:2px"></i>
            <div>
                <h4 style="margin:0; color:var(--primary); font-size:0.95em">Bonus Deposit!</h4>
                <p style="margin:0; font-size:0.85em; color:var(--text-muted)">Dapatkan bonus Rp 5.000 setiap deposit minimal Rp 10.000.</p>
            </div>
        </div>
    </div>

    <div class="card">
        <div class="card-header"><i class="fas fa-wallet"></i><h2>Pilih Metode Pembayaran</h2></div>
        <form method="POST" enctype="multipart/form-data">
            <div class="form-group">
                <label>Nominal Deposit (Min Rp 5.000)</label>
                <input type="number" name="amount" min="5000" placeholder="10000" required>
            </div>
            <div class="form-group">
                <label>Metode Transfer</label>
                <select name="method" id="payMethod" onchange="togglePay()" required>
                    <option value="QRIS">QRIS (Semua E-Wallet/Bank)</option>
                    <option value="DANA">DANA</option>
                </select>
            </div>

            <!-- QRIS BOX -->
            <div id="box-qris" style="margin-bottom:15px; text-align:center">
                <p style="font-size:0.85em; color:var(--text-muted); margin-bottom:10px">Scan QRIS dibawah ini:</p>
                <img src="<?= htmlspecialchars($qris) ?>" style="max-width:250px; border-radius:12px; background:#fff; padding:8px;">
            </div>

            <!-- DANA BOX -->
            <div id="box-dana" style="display:none; margin-bottom:15px; background:rgba(0,0,0,0.2); padding:15px; border-radius:12px; border:1px solid var(--border)">
                <p style="font-size:0.85em; color:var(--text-muted); margin-bottom:10px">Transfer ke nomor DANA:</p>
                <div style="display:flex; justify-content:space-between; align-items:center; background:var(--bg); padding:10px 15px; border-radius:8px; margin-bottom:10px">
                    <div>
                        <div style="font-size:0.75em; color:var(--text-muted)">Nomor DANA</div>
                        <div style="font-weight:700; font-size:1.1em; color:var(--primary)"><?= htmlspecialchars($danaAdmin) ?></div>
                    </div>
                    <button type="button" class="btn btn-sm btn-outline" onclick="copyDana('<?= htmlspecialchars($danaAdmin) ?>')"><i class="fas fa-copy"></i></button>
                </div>
                <div style="font-size:0.85em">Atas Nama: <b><?= htmlspecialchars($danaName) ?></b></div>
            </div>

            <div class="form-group">
                <label>Upload Bukti Transfer</label>
                <input type="file" name="proof" accept="image/*" required style="padding:10px">
            </div>
            <button class="btn btn-primary btn-block">Kirim Konfirmasi</button>
        </form>
    </div>
</div>

<script>
function togglePay() {
    const m = document.getElementById('payMethod').value;
    document.getElementById('box-qris').style.display = (m === 'QRIS') ? 'block' : 'none';
    document.getElementById('box-dana').style.display = (m === 'DANA') ? 'block' : 'none';
}
function copyDana(text) {
    navigator.clipboard.writeText(text).then(() => alert('Nomor DANA dicopy!'));
}
</script>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# ============ 4. UPDATE ADMIN PANEL (ELEGAN) ============
cat > "$WEB_ROOT/x-panel-core/index.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
requireAdmin();

$msg = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action'])) {
    $act = $_POST['action'];
    
    if ($act === 'approve_dep') {
        $id = (int)$_POST['id']; 
        $s = $pdo->prepare("SELECT * FROM deposits WHERE id=?"); $s->execute([$id]); $d = $s->fetch();
        if ($d && $d['status'] == 'pending') {
            $bonus = ($d['amount'] >= 10000) ? 5000 : 0;
            $total_masuk = $d['amount'] + $bonus;
            $pdo->prepare("UPDATE deposits SET status='approved' WHERE id=?")->execute([$id]);
            $pdo->prepare("UPDATE users SET saldo_rp = saldo_rp + ? WHERE id=?")->execute([$total_masuk, $d['user_id']]);
            $msg = 'Deposit disetujui! Saldo masuk: Rp ' . number_format($total_masuk,0,',','.') . ($bonus ? ' (Bonus Rp 5.000)' : '');
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
        $newPrice = (float)$_POST['price']; $pdo->prepare("UPDATE settings SET v=? WHERE k='harga_emas'")->execute([$newPrice]); $msg = 'Harga emas diupdate.';
    } elseif ($act === 'update_qris') {
        $newQris = trim($_POST['qris_url']);
        if (filter_var($newQris, FILTER_VALIDATE_URL)) { $pdo->prepare("UPDATE settings SET v=? WHERE k='qris_url'")->execute([$newQris]); $msg = 'URL QRIS diupdate!'; } else { $msg = 'URL QRIS tidak valid!'; }
    } elseif ($act === 'update_dana') {
        $dana = trim($_POST['dana_admin']); $danaName = trim($_POST['dana_name']);
        $pdo->prepare("UPDATE settings SET v=? WHERE k='dana_admin'")->execute([$dana]);
        $pdo->prepare("UPDATE settings SET v=? WHERE k='dana_name'")->execute([$danaName]);
        $msg = 'Info DANA diupdate!';
    } elseif ($act === 'add_rp') { $uid = (int)$_POST['uid']; $amount = (float)$_POST['amount']; $pdo->prepare("UPDATE users SET saldo_rp = saldo_rp + ? WHERE id=?")->execute([$amount, $uid]); $msg = "Saldo +Rp " . number_format($amount,0,',','.'); }
    elseif ($act === 'cut_rp') { $uid = (int)$_POST['uid']; $amount = (float)$_POST['amount']; $pdo->prepare("UPDATE users SET saldo_rp = GREATEST(0, saldo_rp - ?) WHERE id=?")->execute([$amount, $uid]); $msg = "Saldo -Rp " . number_format($amount,0,',','.'); }
    elseif ($act === 'ban_user') { $uid = (int)$_POST['uid']; $pdo->prepare("UPDATE users SET status='banned' WHERE id=? AND role='user'")->execute([$uid]); $msg = 'User dibanned!';
    } elseif ($act === 'unban_user') { $uid = (int)$_POST['uid']; $pdo->prepare("UPDATE users SET status='active' WHERE id=? AND role='user'")->execute([$uid]); $msg = 'User diaktifkan!';
    } elseif ($act === 'delete_user') { $uid = (int)$_POST['uid']; $pdo->prepare("DELETE FROM users WHERE id=? AND role='user'")->execute([$uid]); $msg = 'User dihapus!';
    }
}

$deps = $pdo->query("SELECT d.*, u.username FROM deposits d JOIN users u ON d.user_id=u.id WHERE d.status='pending' ORDER BY d.id DESC")->fetchAll();
$wds = $pdo->query("SELECT w.*, u.username FROM withdrawals w JOIN users u ON w.user_id=u.id WHERE w.status='pending' ORDER BY w.id DESC")->fetchAll();
$users = $pdo->query("SELECT * FROM users WHERE role='user' ORDER BY id DESC")->fetchAll();
$price = getSetting($pdo, 'harga_emas', 1350000);
$qris = getSetting($pdo, 'qris_url');
$danaAdmin = getSetting($pdo, 'dana_admin');
$danaName = getSetting($pdo, 'dana_name');
?>
<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8"><title>Admin Management</title>
<link rel="stylesheet" href="/assets/css/style.css">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
</head>
<body style="padding-bottom:40px; background:#09090b">
<header class="admin-header">
    <div class="admin-logo"><i class="fas fa-shield-halved"></i> Admin Panel</div>
    <div>
        <a href="/" target="_blank" style="color:var(--text-muted); font-size:0.85em; margin-right:15px; font-weight:600">Lihat Web</a>
        <a href="/logout.php" style="color:var(--danger); font-size:0.85em; font-weight:600">Logout</a>
    </div>
</header>

<div class="container" style="max-width:1000px; margin-top:24px">
    <?php if ($msg): ?><div class="alert alert-success"><i class="fas fa-check"></i> <?= $msg ?></div><?php endif; ?>

    <div class="grid-2" style="margin-bottom:24px">
        <div class="card" style="text-align:center; margin-bottom:0">
            <div style="font-size:0.85em; color:var(--text-muted); margin-bottom:8px">Total User</div>
            <div style="font-size:1.8em; font-weight:800; color:var(--primary)"><?= count($users) ?></div>
        </div>
        <div class="card" style="text-align:center; margin-bottom:0">
            <div style="font-size:0.85em; color:var(--text-muted); margin-bottom:8px">Harga Emas</div>
            <div style="font-size:1.4em; font-weight:800; color:var(--success)">Rp <?= number_format((float)$price,0,',','.') ?></div>
        </div>
    </div>

    <div class="admin-tabs">
        <button class="admin-tab active" onclick="openTab('deps')">Deposit (<?= count($deps) ?>)</button>
        <button class="admin-tab" onclick="openTab('wds')">Penarikan (<?= count($wds) ?>)</button>
        <button class="admin-tab" onclick="openTab('users')">Kelola User</button>
        <button class="admin-tab" onclick="openTab('settings')">Pengaturan</button>
    </div>

    <!-- TAB DEPOSIT -->
    <div id="pane-deps" class="tab-pane active">
        <?php if (empty($deps)): ?><div class="card" style="text-align:center; color:var(--text-muted)">Tidak ada deposit pending.</div><?php else: foreach ($deps as $d): ?>
            <div class="card" style="padding:16px">
                <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:12px">
                    <div>
                        <div style="font-size:1.1em; font-weight:800; color:var(--success)">Rp <?= number_format($d['amount'],0,',','.') ?></div>
                        <div style="font-size:0.85em; color:var(--text-muted); margin-top:4px">User: <b>@<?= $d['username'] ?></b></div>
                        <div style="font-size:0.75em; color:var(--text-muted); margin-top:2px">Metode: <?= $d['method'] ?? 'QRIS' ?> • <?= date('d/m H:i', strtotime($d['created_at'])) ?></div>
                    </div>
                    <div style="display:flex; gap:8px">
                        <a href="/uploads/<?= $d['proof'] ?>" target="_blank" class="btn btn-sm btn-outline"><i class="fas fa-image"></i> Bukti</a>
                        <form method="POST"><input type="hidden" name="id" value="<?= $d['id'] ?>"><button name="action" value="approve_dep" class="btn btn-sm btn-success">Approve</button></form>
                        <form method="POST"><input type="hidden" name="id" value="<?= $d['id'] ?>"><button name="action" value="reject_dep" class="btn btn-sm btn-danger">Reject</button></form>
                    </div>
                </div>
            </div>
        <?php endforeach; endif; ?>
    </div>

    <!-- TAB PENARIKAN -->
    <div id="pane-wds" class="tab-pane">
        <?php if (empty($wds)): ?><div class="card" style="text-align:center; color:var(--text-muted)">Tidak ada penarikan pending.</div><?php else: foreach ($wds as $w): ?>
            <div class="card" style="padding:16px">
                <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:12px">
                    <div>
                        <div style="font-size:1.1em; font-weight:800; color:var(--danger)">Rp <?= number_format($w['amount'],0,',','.') ?></div>
                        <div style="font-size:0.85em; color:var(--text-muted); margin-top:4px">User: <b>@<?= $w['username'] ?></b></div>
                        <div style="font-size:0.75em; color:var(--text-muted); margin-top:2px"><?= $w['method'] ?> - <?= $w['account_no'] ?> (<?= $w['account_name'] ?>)</div>
                    </div>
                    <div style="display:flex; gap:8px">
                        <form method="POST"><input type="hidden" name="id" value="<?= $w['id'] ?>"><button name="action" value="approve_wd" class="btn btn-sm btn-success">Approve</button></form>
                        <form method="POST"><input type="hidden" name="id" value="<?= $w['id'] ?>"><button name="action" value="reject_wd" class="btn btn-sm btn-danger">Reject</button></form>
                    </div>
                </div>
            </div>
        <?php endforeach; endif; ?>
    </div>

    <!-- TAB KELOLA USER -->
    <div id="pane-users" class="tab-pane">
        <?php foreach ($users as $u): ?>
            <div class="card" style="padding:16px">
                <div style="display:flex; justify-content:space-between; align-items:flex-start; flex-wrap:wrap; gap:10px">
                    <div>
                        <div style="font-weight:700">@<?= htmlspecialchars($u['username']) ?></div>
                        <div style="font-size:0.8em; color:var(--text-muted)"><?= htmlspecialchars($u['email']) ?></div>
                        <div style="margin-top:8px; font-size:0.9em">Saldo: <b style="color:var(--success)">Rp <?= number_format($u['saldo_rp'],0,',','.') ?></b></div>
                        <span class="badge <?= $u['status']=='active'?'badge-success':'badge-danger' ?>" style="margin-top:6px; display:inline-block"><?= $u['status'] ?></span>
                    </div>
                    <div style="display:flex; gap:6px; flex-wrap:wrap">
                        <form method="POST" style="margin:0"><input type="hidden" name="uid" value="<?= $u['id'] ?>">
                            <?php if($u['status']=='active'): ?><button name="action" value="ban_user" class="btn btn-sm btn-danger" onclick="return confirm('Ban?')">Ban</button>
                            <?php else: ?><button name="action" value="unban_user" class="btn btn-sm btn-success">Unban</button><?php endif; ?>
                        </form>
                        <form method="POST" style="margin:0"><input type="hidden" name="uid" value="<?= $u['id'] ?>"><button name="action" value="delete_user" class="btn btn-sm btn-outline" onclick="return confirm('Hapus?')"><i class="fas fa-trash"></i></button></form>
                    </div>
                </div>
                <div style="margin-top:12px; display:flex; gap:8px">
                    <form method="POST" class="mini-form" style="flex:1"><input type="hidden" name="uid" value="<?= $u['id'] ?>"><input type="number" name="amount" placeholder="Rp" required style="width:100%"><button name="action" value="add_rp" style="background:var(--success);color:#000">+Rp</button></form>
                    <form method="POST" class="mini-form" style="flex:1"><input type="hidden" name="uid" value="<?= $u['id'] ?>"><input type="number" name="amount" placeholder="Rp" required style="width:100%"><button name="action" value="cut_rp" style="background:var(--danger);color:#fff">-Rp</button></form>
                </div>
            </div>
        <?php endforeach; ?>
    </div>

    <!-- TAB SETTINGS -->
    <div id="pane-settings" class="tab-pane">
        <div class="card">
            <div class="card-header"><i class="fas fa-chart-line"></i><h2>Harga Emas</h2></div>
            <form method="POST" style="display:flex; gap:10px">
                <input type="number" name="price" value="<?= $price ?>" required style="flex:1; padding:12px; border-radius:10px; border:1px solid var(--border); background:var(--bg); color:var(--text)">
                <button name="action" value="update_price" class="btn btn-primary">Set</button>
            </form>
        </div>

        <div class="card">
            <div class="card-header"><i class="fas fa-qrcode"></i><h2>QRIS</h2></div>
            <div style="display:flex; gap:20px; flex-wrap:wrap; align-items:flex-start">
                <img src="<?= htmlspecialchars($qris) ?>" style="width:120px; border-radius:10px; background:#fff; padding:5px">
                <form method="POST" style="flex:1; min-width:250px">
                    <input type="url" name="qris_url" placeholder="https://..." required style="width:100%; padding:12px; border-radius:10px; border:1px solid var(--border); background:var(--bg); color:var(--text); margin-bottom:10px">
                    <button name="action" value="update_qris" class="btn btn-primary btn-block">Update QRIS</button>
                </form>
            </div>
        </div>

        <div class="card">
            <div class="card-header"><i class="fas fa-wallet"></i><h2>Info DANA</h2></div>
            <form method="POST">
                <div class="form-group"><label>Nomor DANA</label><input type="text" name="dana_admin" value="<?= htmlspecialchars($danaAdmin) ?>" required></div>
                <div class="form-group"><label>Atas Nama DANA</label><input type="text" name="dana_name" value="<?= htmlspecialchars($danaName) ?>" required></div>
                <button name="action" value="update_dana" class="btn btn-primary btn-block">Update Info DANA</button>
            </form>
        </div>
    </div>
</div>

<script>
function openTab(id) {
    document.querySelectorAll('.tab-pane').forEach(el => el.classList.remove('active'));
    document.querySelectorAll('.admin-tab').forEach(el => el.classList.remove('active'));
    document.getElementById('pane-' + id).classList.add('active');
    event.target.classList.add('active');
}
</script>
</body>
</html>
PHPEOF

chown -R www-data:www-data "$WEB_ROOT"
systemctl restart php8.3-fpm

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ UPDATE ELEGAN SELESAI!                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
