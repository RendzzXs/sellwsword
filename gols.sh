#!/bin/bash
# ============================================
#   🪙 TREASURY GOLD — v2.0 FULL UPDATE
# ============================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

[[ $EUID -ne 0 ]] && { echo -e "${RED}❌ Harus root!${NC}"; exit 1; }

clear
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🪙 TREASURY GOLD v2.0 — UPDATE            ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

read -p "👉 Subdomain (contoh: gold.voltxyz.my.id): " SUBDOMAIN
WEB_ROOT="/var/www/$SUBDOMAIN"

[[ ! -d "$WEB_ROOT" ]] && { echo -e "${RED}❌ Folder tidak ada: $WEB_ROOT${NC}"; exit 1; }

echo -e "${GREEN}📁 Web root: $WEB_ROOT${NC}"

# ============ UPDATE ADMIN DASHBOARD ============
echo -e "${CYAN}📝 Update Admin Dashboard (Full Control)...${NC}"

cat > "$WEB_ROOT/x-panel-core/index.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
requireAdmin();

$msg = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action'])) {
    $act = $_POST['action'];
    
    // === KELOLA DEPOSIT ===
    if ($act === 'approve_dep') {
        $id = (int)$_POST['id'];
        $s = $pdo->prepare("SELECT * FROM deposits WHERE id=?"); $s->execute([$id]); $d = $s->fetch();
        if ($d && $d['status'] == 'pending') {
            $pdo->prepare("UPDATE deposits SET status='approved' WHERE id=?")->execute([$id]);
            $pdo->prepare("UPDATE users SET saldo_rp = saldo_rp + ? WHERE id=?")->execute([$d['amount'], $d['user_id']]);
            $msg = 'Deposit disetujui & saldo ditambahkan.';
        }
    } elseif ($act === 'reject_dep') {
        $id = (int)$_POST['id'];
        $pdo->prepare("UPDATE deposits SET status='rejected' WHERE id=?")->execute([$id]);
        $msg = 'Deposit ditolak.';
    
    // === KELOLA WITHDRAW ===
    } elseif ($act === 'approve_wd') {
        $id = (int)$_POST['id'];
        $pdo->prepare("UPDATE withdrawals SET status='approved' WHERE id=?")->execute([$id]);
        $msg = 'Penarikan disetujui.';
    } elseif ($act === 'reject_wd') {
        $id = (int)$_POST['id'];
        $s = $pdo->prepare("SELECT * FROM withdrawals WHERE id=?"); $s->execute([$id]); $w = $s->fetch();
        if ($w && $w['status'] == 'pending') {
            $pdo->prepare("UPDATE withdrawals SET status='rejected' WHERE id=?")->execute([$id]);
            $pdo->prepare("UPDATE users SET saldo_rp = saldo_rp + ? WHERE id=?")->execute([$w['amount'], $w['user_id']]);
            $msg = 'Penarikan ditolak, saldo dikembalikan.';
        }
    
    // === SETTINGS ===
    } elseif ($act === 'update_price') {
        $newPrice = (float)$_POST['price'];
        $pdo->prepare("UPDATE settings SET v=? WHERE k='harga_emas'")->execute([$newPrice]);
        $msg = 'Harga emas diupdate!';
    } elseif ($act === 'update_qris') {
        $newQris = trim($_POST['qris_url']);
        if (filter_var($newQris, FILTER_VALIDATE_URL)) {
            $pdo->prepare("UPDATE settings SET v=? WHERE k='qris_url'")->execute([$newQris]);
            $msg = 'URL QRIS berhasil diupdate!';
        } else {
            $msg = 'URL QRIS tidak valid!';
        }
    
    // === BROADCAST ===
    } elseif ($act === 'broadcast') {
        $title = trim($_POST['title']); $content = trim($_POST['content']); $image = null;
        if (isset($_FILES['image']) && $_FILES['image']['error'] === 0) {
            $ext = pathinfo($_FILES['image']['name'], PATHINFO_EXTENSION);
            $fname = 'bc_' . time() . '.' . $ext;
            move_uploaded_file($_FILES['image']['tmp_name'], __DIR__ . '/../uploads/' . $fname);
            $image = '/uploads/' . $fname;
        }
        $pdo->prepare("INSERT INTO broadcasts (title, content, image_url) VALUES (?,?,?)")->execute([$title, $content, $image]);
        $msg = 'Broadcast terkirim!';
    
    // === KELOLA USER ===
    } elseif ($act === 'add_rp') {
        $uid = (int)$_POST['uid']; $amount = (float)$_POST['amount'];
        $pdo->prepare("UPDATE users SET saldo_rp = saldo_rp + ? WHERE id=?")->execute([$amount, $uid]);
        $msg = "Berhasil menambah Rp " . number_format($amount,0,',','.') . " ke user.";
    } elseif ($act === 'cut_rp') {
        $uid = (int)$_POST['uid']; $amount = (float)$_POST['amount'];
        $pdo->prepare("UPDATE users SET saldo_rp = GREATEST(0, saldo_rp - ?) WHERE id=?")->execute([$amount, $uid]);
        $msg = "Berhasil memotong Rp " . number_format($amount,0,',','.') . " dari user.";
    } elseif ($act === 'add_gram') {
        $uid = (int)$_POST['uid']; $amount = (float)$_POST['amount'];
        $pdo->prepare("UPDATE users SET saldo_gram = saldo_gram + ? WHERE id=?")->execute([$amount, $uid]);
        $msg = "Berhasil menambah " . number_format($amount,4) . " gr emas ke user.";
    } elseif ($act === 'cut_gram') {
        $uid = (int)$_POST['uid']; $amount = (float)$_POST['amount'];
        $pdo->prepare("UPDATE users SET saldo_gram = GREATEST(0, saldo_gram - ?) WHERE id=?")->execute([$amount, $uid]);
        $msg = "Berhasil memotong " . number_format($amount,4) . " gr emas dari user.";
    } elseif ($act === 'ban_user') {
        $uid = (int)$_POST['uid'];
        $pdo->prepare("UPDATE users SET status='banned' WHERE id=? AND role='user'")->execute([$uid]);
        $msg = 'User dibanned!';
    } elseif ($act === 'unban_user') {
        $uid = (int)$_POST['uid'];
        $pdo->prepare("UPDATE users SET status='active' WHERE id=? AND role='user'")->execute([$uid]);
        $msg = 'User diaktifkan!';
    } elseif ($act === 'delete_user') {
        $uid = (int)$_POST['uid'];
        $pdo->prepare("DELETE FROM users WHERE id=? AND role='user'")->execute([$uid]);
        $msg = 'User dihapus permanen!';
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
<style>
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
</style>
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
        <div class="card" style="text-align:center">
            <h3 style="color:var(--text-muted)">Total User</h3>
            <div style="font-size:2em;font-weight:800;color:var(--primary)"><?= $totalUsers ?></div>
        </div>
        <div class="card" style="text-align:center">
            <h3 style="color:var(--text-muted)">Harga Emas Saat Ini</h3>
            <div style="font-size:1.5em;font-weight:800;color:var(--success)">Rp <?= number_format((float)$price,0,',','.') ?></div>
        </div>
    </div>

    <div class="tabs">
        <button class="tab-btn active" onclick="showTab('tab-deps')">Deposit</button>
        <button class="tab-btn" onclick="showTab('tab-wds')">Penarikan</button>
        <button class="tab-btn" onclick="showTab('tab-users')">Kelola User</button>
        <button class="tab-btn" onclick="showTab('tab-settings')">Pengaturan</button>
        <button class="tab-btn" onclick="showTab('tab-bc')">Broadcast</button>
    </div>

    <!-- TAB DEPOSIT -->
    <div id="tab-deps" class="tab-content active card">
        <h3 style="color:var(--primary);margin-bottom:15px">Deposit Pending</h3>
        <?php if (empty($deps)): ?><p style="color:var(--text-muted)">Tidak ada deposit pending.</p><?php else: ?>
            <?php foreach ($deps as $d): ?>
                <div class="user-card" style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px">
                    <div>
                        <b>@<?= $d['username'] ?></b><br>
                        <span style="color:var(--success);font-size:1.1em;font-weight:800">Rp <?= number_format($d['amount'],0,',','.') ?></span><br>
                        <small><?= date('d/m H:i', strtotime($d['created_at'])) ?></small><br>
                        <a href="/uploads/<?= $d['proof'] ?>" target="_blank" class="btn btn-sm btn-outline" style="margin-top:5px"><i class="fas fa-image"></i> Lihat Bukti</a>
                    </div>
                    <form method="POST" style="display:flex;gap:5px">
                        <input type="hidden" name="id" value="<?= $d['id'] ?>">
                        <button name="action" value="approve_dep" class="btn btn-sm" style="background:var(--success);color:#fff">Approve</button>
                        <button name="action" value="reject_dep" class="btn btn-sm" style="background:var(--danger);color:#fff">Reject</button>
                    </form>
                </div>
            <?php endforeach; ?>
        <?php endif; ?>
    </div>

    <!-- TAB PENARIKAN -->
    <div id="tab-wds" class="tab-content card">
        <h3 style="color:var(--primary);margin-bottom:15px">Penarikan Pending</h3>
        <?php if (empty($wds)): ?><p style="color:var(--text-muted)">Tidak ada penarikan pending.</p><?php else: ?>
            <?php foreach ($wds as $w): ?>
                <div class="user-card" style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px">
                    <div>
                        <b>@<?= $w['username'] ?></b><br>
                        <span style="color:var(--danger);font-size:1.1em;font-weight:800">Rp <?= number_format($w['amount'],0,',','.') ?></span><br>
                        <small><b><?= $w['method'] ?></b> - <?= $w['account_no'] ?> (<?= $w['account_name'] ?>)</small>
                    </div>
                    <form method="POST" style="display:flex;gap:5px">
                        <input type="hidden" name="id" value="<?= $w['id'] ?>">
                        <button name="action" value="approve_wd" class="btn btn-sm" style="background:var(--success);color:#fff">Approve</button>
                        <button name="action" value="reject_wd" class="btn btn-sm" style="background:var(--danger);color:#fff">Reject</button>
                    </form>
                </div>
            <?php endforeach; ?>
        <?php endif; ?>
    </div>

    <!-- TAB KELOLA USER -->
    <div id="tab-users" class="tab-content card">
        <h3 style="color:var(--primary);margin-bottom:15px">Kelola User</h3>
        <?php foreach ($users as $u): ?>
            <div class="user-card">
                <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap">
                    <div>
                        <b>@<?= htmlspecialchars($u['username']) ?></b> 
                        <span style="color:var(--text-muted);font-size:0.85em">(<?= htmlspecialchars($u['email']) ?>)</span>
                        <span class="badge" style="background:<?= $u['status']=='banned'?'rgba(239,68,68,0.2)':'rgba(16,185,129,0.2)' ?>;color:<?= $u['status']=='banned'?'var(--danger)':'var(--success)' ?>;margin-left:5px"><?= $u['status'] ?></span>
                    </div>
                    <form method="POST" style="margin:0">
                        <input type="hidden" name="uid" value="<?= $u['id'] ?>">
                        <?php if($u['status']=='active'): ?>
                            <button name="action" value="ban_user" class="btn btn-sm" style="background:var(--danger);color:#fff;border-radius:8px" onclick="return confirm('Ban user ini?')">Ban</button>
                        <?php else: ?>
                            <button name="action" value="unban_user" class="btn btn-sm" style="background:var(--success);color:#fff;border-radius:8px">Unban</button>
                        <?php endif; ?>
                        <button name="action" value="delete_user" class="btn btn-sm" style="background:#333;color:#fff;border-radius:8px" onclick="return confirm('Hapus permanen?')"><i class="fas fa-trash"></i></button>
                    </form>
                </div>
                <div style="margin-top:8px;font-size:0.9em">
                    Saldo Rp: <b style="color:var(--success)"><?= number_format($u['saldo_rp'],0,',','.') ?></b> | 
                    Saldo Emas: <b style="color:var(--primary)"><?= number_format($u['saldo_gram'],4) ?> gr</b>
                </div>
                
                <div class="action-forms">
                    <!-- Add RP -->
                    <form method="POST" class="mini-form">
                        <input type="hidden" name="uid" value="<?= $u['id'] ?>">
                        <input type="number" name="amount" placeholder="Rp" required>
                        <button name="action" value="add_rp" style="background:var(--success);color:#fff">+Rp</button>
                    </form>
                    <!-- Cut RP -->
                    <form method="POST" class="mini-form">
                        <input type="hidden" name="uid" value="<?= $u['id'] ?>">
                        <input type="number" name="amount" placeholder="Rp" required>
                        <button name="action" value="cut_rp" style="background:var(--danger);color:#fff">-Rp</button>
                    </form>
                    <!-- Add Gram -->
                    <form method="POST" class="mini-form">
                        <input type="hidden" name="uid" value="<?= $u['id'] ?>">
                        <input type="number" name="amount" step="0.01" placeholder="Gr" required>
                        <button name="action" value="add_gram" style="background:var(--primary);color:#000">+Gr</button>
                    </form>
                    <!-- Cut Gram -->
                    <form method="POST" class="mini-form">
                        <input type="hidden" name="uid" value="<?= $u['id'] ?>">
                        <input type="number" name="amount" step="0.01" placeholder="Gr" required>
                        <button name="action" value="cut_gram" style="background:#d97706;color:#fff">-Gr</button>
                    </form>
                </div>
            </div>
        <?php endforeach; ?>
    </div>

    <!-- TAB PENGATURAN -->
    <div id="tab-settings" class="tab-content card">
        <h3 style="color:var(--primary);margin-bottom:15px">Update Harga Emas</h3>
        <form method="POST" style="display:flex;gap:10px;align-items:flex-end;margin-bottom:30px">
            <div class="form-group" style="flex:1;margin:0"><label>Harga / Gram</label><input type="number" name="price" value="<?= $price ?>" required></div>
            <button name="action" value="update_price" class="btn btn-primary">Simpan Harga</button>
        </form>

        <h3 style="color:var(--primary);margin-bottom:15px">Update Gambar QRIS</h3>
        <div style="display:flex;gap:20px;flex-wrap:wrap">
            <div style="flex:1;min-width:200px">
                <img src="<?= htmlspecialchars($qris) ?>" style="width:100%;max-width:200px;border-radius:10px;background:#fff;padding:5px">
                <p style="font-size:0.8em;color:var(--text-muted);margin-top:5px">Preview QRIS saat ini</p>
            </div>
            <div style="flex:2;min-width:250px">
                <form method="POST">
                    <div class="form-group">
                        <label>URL Gambar QRIS Baru</label>
                        <input type="url" name="qris_url" placeholder="https://files.catbox.moe/xxx.jpg" required>
                    </div>
                    <button name="action" value="update_qris" class="btn btn-primary">Update QRIS</button>
                </form>
            </div>
        </div>
    </div>

    <!-- TAB BROADCAST -->
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

# ============ UPDATE USER PROFILE (Dashboard User) ============
echo -e "${CYAN}📝 Update User Dashboard...${NC}"

cat > "$WEB_ROOT/profile.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
requireLogin();
$uid = $_SESSION['user_id'];
$s = $pdo->prepare("SELECT * FROM users WHERE id=?"); $s->execute([$uid]); $me = $s->fetch();

// Riwayat transaksi (beli emas)
$trx = $pdo->prepare("SELECT * FROM transactions WHERE user_id=? ORDER BY id DESC LIMIT 10");
$trx->execute([$uid]); $trx = $trx->fetchAll();

$pageTitle = 'Profil Saya';
include __DIR__ . '/includes/header.php';
?>
<div class="container">
    <div class="card" style="background:linear-gradient(135deg, rgba(245,158,11,0.1), transparent); margin-bottom:20px">
        <div style="display:flex; align-items:center; gap:15px; margin-bottom:20px">
            <div style="width:60px;height:60px;border-radius:50%;background:var(--primary);display:flex;align-items:center;justify-content:center;font-size:1.5em;font-weight:800;color:#000">
                <?= strtoupper(substr($me['username'],0,1)) ?>
            </div>
            <div>
                <h2 style="margin:0">@<?= htmlspecialchars($me['username']) ?></h2>
                <p style="color:var(--text-muted);font-size:0.9em;margin:0"><?= htmlspecialchars($me['email']) ?></p>
            </div>
        </div>
        
        <div class="grid-2">
            <div style="background:rgba(0,0,0,0.2); padding:15px; border-radius:12px">
                <div style="font-size:0.85em; color:var(--text-muted)">Saldo Rupiah</div>
                <div style="font-size:1.4em; font-weight:800; color:var(--success); margin-bottom:10px"><?= rupiah($me['saldo_rp']) ?></div>
                <div style="display:flex;gap:5px">
                    <a href="/deposit.php" class="btn btn-sm btn-primary" style="flex:1">Deposit</a>
                    <a href="/withdraw.php" class="btn btn-sm btn-outline" style="flex:1">Tarik</a>
                </div>
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
        <?php if (empty($trx)): ?>
            <p style="color:var(--text-muted); text-align:center">Belum ada riwayat transaksi.</p>
        <?php else: ?>
            <div style="overflow-x:auto">
                <table class="table">
                    <tr><th>Tanggal</th><th>Gram</th><th>Total Bayar</th></tr>
                    <?php foreach($trx as $t): ?>
                    <tr>
                        <td><?= date('d/m/y H:i', strtotime($t['created_at'])) ?></td>
                        <td style="color:var(--primary)"><b><?= number_format($t['amount_gram'],4) ?> gr</b></td>
                        <td><?= rupiah($t['total_rp']) ?></td>
                    </tr>
                    <?php endforeach; ?>
                </table>
            </div>
        <?php endif; ?>
    </div>
    
    <a href="/logout.php" class="btn btn-outline" style="width:100%; border-color:var(--danger); color:var(--danger)">Logout Akun</a>
</div>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# ============ FIX PERMISSIONS ============
chown -R www-data:www-data "$WEB_ROOT"
chmod -R 775 "$WEB_ROOT/uploads"
systemctl restart php8.3-fpm

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ UPDATE SELESAI!                        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo "Fitur Admin Baru:"
echo "  - Tab Kelola User (+/- Saldo Rp & Gram, Ban, Hapus)"
echo "  - Tab Pengaturan (Update Harga Emas & Ganti URL QRIS)"
echo ""
echo "Fitur User Baru:"
echo "  - Dashboard profil & riwayat pembelian emas"
echo ""
echo "Refresh browser (Ctrl+Shift+R) dan coba!"
