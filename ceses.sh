#!/bin/bash
# ============================================
#   🔧 FIX SEMUA ASSET — Sell Ws Word
# ============================================

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
[[ $EUID -ne 0 ]] && { echo -e "${RED}Harus root!${NC}"; exit 1; }

read -p "👉 Subdomain (contoh: sellws.voltxyz.my.id): " SUBDOMAIN
WEB_ROOT="/var/www/$SUBDOMAIN"

if [[ ! -d "$WEB_ROOT" ]]; then
    echo -e "${RED}❌ Folder tidak ada!${NC}"
    echo "Cek: ls /var/www/"
    exit 1
fi

mkdir -p "$WEB_ROOT/assets/css" "$WEB_ROOT/assets/js"

# ============ 1. CSS LENGKAP ============
echo -e "${CYAN}📝 Bikin CSS...${NC}"

cat > "$WEB_ROOT/assets/css/style.css" << 'CSSEOF'
:root{--bg:#0a0a1a;--bg-2:#12122a;--bg-card:rgba(30,30,60,.6);--bg-nav:rgba(15,15,35,.85);--text:#e8e8ff;--text-muted:#8888aa;--border:rgba(120,120,200,.15);--primary:#7c5cff;--primary-2:#b066ff;--gold:#ffb700;--gold-2:#ff8c00;--success:#00e676;--danger:#ff4757;--warning:#ffa726;--info:#29b6f6;--tg:#229ED9;--shadow:0 8px 40px rgba(0,0,0,.4);--glow:0 0 40px rgba(124,92,255,.4)}
[data-theme="light"]{--bg:#f0f2ff;--bg-2:#e8ebff;--bg-card:rgba(255,255,255,.8);--bg-nav:rgba(255,255,255,.9);--text:#1a1a2e;--text-muted:#666688;--border:rgba(100,100,180,.15);--shadow:0 8px 40px rgba(80,80,180,.12)}
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Plus Jakarta Sans',system-ui,sans-serif;background:var(--bg);color:var(--text);line-height:1.6;min-height:100vh;padding-bottom:100px;background-image:radial-gradient(circle at 20% 0%,rgba(124,92,255,.15),transparent 40%),radial-gradient(circle at 80% 100%,rgba(176,102,255,.1),transparent 40%)}
a{color:var(--primary);text-decoration:none;transition:.2s}
a:hover{color:var(--primary-2)}
img{max-width:100%}

/* TOP BAR */
.top-bar{display:flex;justify-content:space-between;align-items:center;padding:12px 18px;background:var(--bg-nav);backdrop-filter:blur(20px);border-bottom:1px solid var(--border);position:sticky;top:0;z-index:100}
.top-logo{display:flex;align-items:center;gap:8px;font-family:'Space Grotesk',sans-serif;font-weight:800;font-size:1.1em;color:var(--text)}
.top-logo i{color:var(--primary-2);font-size:1.3em}
.top-accent{background:linear-gradient(135deg,var(--primary),var(--primary-2));-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text}
.top-right{display:flex;gap:8px;align-items:center}

/* BUTTONS */
.btn{padding:10px 20px;border-radius:12px;border:none;cursor:pointer;font-weight:700;font-family:inherit;display:inline-flex;align-items:center;gap:8px;transition:.25s;font-size:.9em;text-decoration:none}
.btn-primary{background:linear-gradient(135deg,var(--primary),var(--primary-2));color:#fff;box-shadow:0 4px 20px rgba(124,92,255,.4)}
.btn-primary:hover{transform:translateY(-2px);box-shadow:0 8px 30px rgba(124,92,255,.6);color:#fff}
.btn-outline{background:transparent;border:2px solid var(--primary);color:var(--primary)}
.btn-outline:hover{background:var(--primary);color:#fff}
.btn-gold{background:linear-gradient(135deg,var(--gold),var(--gold-2));color:#000;box-shadow:0 4px 20px rgba(255,183,0,.4)}
.btn-gold:hover{transform:translateY(-2px);color:#000}
.btn-danger{background:var(--danger);color:#fff}
.btn-ok{background:var(--success);color:#000}
.btn-warn{background:var(--warning);color:#000}
.btn-info{background:var(--info);color:#fff}
.btn-tg{background:var(--tg);color:#fff;box-shadow:0 4px 20px rgba(34,158,217,.4)}
.btn-tg:hover{background:#1a8bc4;color:#fff}
.btn-block{width:100%;justify-content:center}
.btn-lg{padding:14px 32px;font-size:1.05em}
.btn-sm{padding:6px 12px;font-size:.8em}
.icon-btn{background:transparent;border:1px solid var(--border);color:var(--text);padding:8px 12px;border-radius:10px;cursor:pointer;display:inline-flex;align-items:center;justify-content:center}
.icon-btn:hover{border-color:var(--primary);background:rgba(124,92,255,.1)}
.btn-icon{background:rgba(255,255,255,.05);border:1px solid var(--border);padding:8px 12px;border-radius:8px;cursor:pointer;color:var(--text)}
.btn-icon:hover{color:#fff;transform:scale(1.05)}
.btn-icon.btn-ok:hover{background:var(--success);color:#000}
.btn-icon.btn-danger:hover{background:var(--danger);color:#fff}
.btn-icon.btn-warn:hover{background:var(--warning);color:#000}
.btn-icon.btn-info:hover{background:var(--info);color:#fff}

/* PULSE */
.pulse-btn{position:relative;overflow:hidden}
.pulse-btn::before{content:'';position:absolute;inset:0;background:radial-gradient(circle,rgba(255,255,255,.3),transparent 70%);animation:pulse 2s infinite}
@keyframes pulse{0%{transform:scale(.8);opacity:1}100%{transform:scale(1.5);opacity:0}}

/* FORMS */
.form-group{margin-bottom:18px}
.form-group label{display:block;margin-bottom:8px;font-weight:600;font-size:.9em}
.form-group input,.form-input,.form-group textarea,.form-group select{width:100%;padding:13px 16px;border:1px solid var(--border);border-radius:12px;background:rgba(0,0,0,.2);color:var(--text);font-size:.95em;font-family:inherit}
.form-group input:focus,.form-input:focus{outline:none;border-color:var(--primary);box-shadow:0 0 0 4px rgba(124,92,255,.15)}

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

/* CARDS */
.card{background:var(--bg-card);backdrop-filter:blur(20px);padding:28px;border-radius:20px;border:1px solid var(--border);margin-bottom:25px;box-shadow:var(--shadow)}
.card h2{font-family:'Space Grotesk',sans-serif;margin-bottom:20px;font-size:1.3em;display:flex;align-items:center;gap:10px}
.card h2 i{color:var(--primary)}

/* STATS */
.stats-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:18px;margin-bottom:25px}
.stat-card{background:var(--bg-card);backdrop-filter:blur(20px);padding:22px;border-radius:18px;border:1px solid var(--border);display:flex;align-items:center;gap:16px;transition:.25s}
.stat-card:hover{transform:translateY(-3px);border-color:var(--primary)}
.stat-icon{width:55px;height:55px;border-radius:14px;display:flex;align-items:center;justify-content:center;color:#fff;font-size:1.5em;flex-shrink:0}
.stat-info h3{font-size:1.4em;font-family:'Space Grotesk',sans-serif;margin:0}
.stat-info p{color:var(--text-muted);font-size:.85em;margin:0}

/* WELCOME */
.welcome-card{background:linear-gradient(135deg,rgba(124,92,255,.2),rgba(176,102,255,.1));border:1px solid rgba(124,92,255,.3);border-radius:22px;padding:28px;display:flex;justify-content:space-between;align-items:center;margin-bottom:25px;gap:20px;flex-wrap:wrap}
.wc-left{display:flex;align-items:center;gap:18px}
.wc-avatar{width:70px;height:70px;border-radius:20px;background:linear-gradient(135deg,var(--primary),var(--primary-2));display:flex;align-items:center;justify-content:center;font-size:1.8em;font-weight:800;color:#fff;box-shadow:0 8px 30px rgba(124,92,255,.5)}
.welcome-card h1{font-family:'Space Grotesk',sans-serif;font-size:1.5em;margin-bottom:5px}

/* GRID */
.grid-2{display:grid;grid-template-columns:1fr 1fr;gap:20px}
@media (max-width:800px){.grid-2{grid-template-columns:1fr}}

/* TABLE */
.table{width:100%;border-collapse:collapse}
.table th{text-align:left;padding:13px 12px;font-size:.78em;letter-spacing:.5px;text-transform:uppercase;color:var(--text-muted);border-bottom:2px solid var(--border);background:rgba(0,0,0,.2)}
.table td{padding:13px 12px;border-bottom:1px solid var(--border);font-size:.9em}
.table tr:hover td{background:rgba(124,92,255,.05)}
.table code{background:rgba(124,92,255,.15);padding:3px 8px;border-radius:6px;font-size:.85em;color:var(--primary-2)}

/* BADGES */
.badge{padding:4px 12px;border-radius:20px;font-size:.72em;font-weight:800;text-transform:uppercase;display:inline-flex;align-items:center;gap:5px}
.badge-admin{background:rgba(255,71,87,.15);color:var(--danger)}
.badge-user{background:rgba(41,182,246,.15);color:var(--info)}
.badge-active{background:rgba(0,230,118,.15);color:var(--success)}
.badge-banned{background:rgba(255,71,87,.15);color:var(--danger)}
.badge-pending{background:rgba(255,167,38,.15);color:var(--warning)}
.badge-approved{background:rgba(0,230,118,.15);color:var(--success)}
.badge-rejected{background:rgba(255,71,87,.15);color:var(--danger)}
.badge-waiting_otp{background:rgba(41,182,246,.15);color:var(--info)}
.badge-otp_sent{background:rgba(124,92,255,.15);color:var(--primary-2)}
.badge-sold{background:rgba(120,120,150,.15);color:var(--text-muted)}
.badge-info{background:rgba(124,92,255,.15);color:var(--primary-2)}

/* BOTTOM NAV */
.bottom-nav{position:fixed;bottom:12px;left:12px;right:12px;display:flex;justify-content:space-around;align-items:center;background:rgba(20,20,45,.95);backdrop-filter:blur(30px);-webkit-backdrop-filter:blur(30px);border:1px solid rgba(124,92,255,.2);border-radius:22px;padding:8px 6px;z-index:99;box-shadow:0 8px 40px rgba(0,0,0,.5);max-width:520px;margin:0 auto}
[data-theme="light"] .bottom-nav{background:rgba(255,255,255,.95);border-color:rgba(124,92,255,.2);box-shadow:0 8px 40px rgba(80,80,180,.15)}
.bn-item{display:flex;flex-direction:column;align-items:center;gap:3px;padding:8px 10px;color:var(--text-muted);font-size:.68em;font-weight:600;border-radius:14px;transition:all .25s;min-width:52px;text-decoration:none;position:relative}
.bn-item i{font-size:1.25em;transition:transform .2s}
.bn-item:hover,.bn-item.active{color:var(--primary-2);background:rgba(124,92,255,.12)}
.bn-item.active i{transform:scale(1.15);filter:drop-shadow(0 0 8px rgba(176,102,255,.8))}
.bn-item.active::before{content:'';position:absolute;top:-8px;left:50%;transform:translateX(-50%);width:24px;height:3px;background:linear-gradient(90deg,var(--primary),var(--primary-2));border-radius:2px;box-shadow:0 0 10px rgba(176,102,255,.8)}
.bn-item.bn-admin{color:var(--gold)}
.bn-item.bn-admin:hover,.bn-item.bn-admin.active{color:var(--gold-2);background:rgba(255,183,0,.12)}
.bn-item.bn-admin.active::before{background:linear-gradient(90deg,var(--gold),var(--gold-2));box-shadow:0 0 10px rgba(255,183,0,.8)}
@media(min-width:768px){.bottom-nav{bottom:20px;left:50%;right:auto;transform:translateX(-50%);min-width:480px;max-width:600px}}

/* FOOTER */
.footer{margin-top:60px;padding:40px 20px;border-top:1px solid var(--border);background:rgba(0,0,0,.2);text-align:center}
.footer-content{max-width:1200px;margin:0 auto}
.footer-brand{display:flex;align-items:center;justify-content:center;gap:10px;font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:1.1em;margin-bottom:15px}
.footer-brand i{color:var(--primary-2)}
.footer p{color:var(--text-muted);font-size:.9em;margin-bottom:15px}
.footer-links{display:flex;gap:20px;justify-content:center;flex-wrap:wrap}
.footer-links a{color:var(--text-muted);font-size:.9em}

/* ADMIN GRID */
.admin-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:16px;margin-bottom:25px}
.admin-card{background:var(--bg-card);backdrop-filter:blur(20px);padding:22px;border-radius:20px;border:1px solid var(--border);text-align:center;transition:.25s;color:var(--text);text-decoration:none;display:flex;flex-direction:column;align-items:center;gap:8px;position:relative;overflow:hidden}
.admin-card::before{content:'';position:absolute;top:0;left:0;right:0;height:3px;background:linear-gradient(90deg,var(--primary),var(--primary-2));opacity:0;transition:opacity .3s}
.admin-card:hover::before{opacity:1}
.admin-card:hover{transform:translateY(-4px);border-color:var(--primary);box-shadow:0 12px 40px rgba(124,92,255,.25);color:var(--text)}
.admin-card i{font-size:2.1em;color:var(--primary);margin-bottom:4px;display:block}
.admin-card h3{font-family:'Space Grotesk',sans-serif;margin:0;font-size:1.05em}
.admin-card p{color:var(--text-muted);font-size:.82em;margin:0}
.admin-card-alert{border-color:var(--warning);background:linear-gradient(135deg,rgba(255,167,38,.15),rgba(255,167,38,.05))}
.admin-card-alert i{color:var(--warning)}
.admin-card-alert::before{background:linear-gradient(90deg,var(--warning),var(--gold));opacity:1}

/* LOG ITEM */
.log-item{display:flex;gap:12px;padding:12px 0;border-bottom:1px solid var(--border);font-size:.9em;align-items:flex-start}
.log-item:last-child{border-bottom:none}
.log-item i{color:var(--primary);margin-top:4px;flex-shrink:0}
.log-item small{color:var(--text-muted);font-size:.8em}

/* RIWAYAT */
.riwayat-item{display:flex;justify-content:space-between;gap:15px;padding:15px 0;border-bottom:1px solid var(--border);flex-wrap:wrap}
.riwayat-item:last-child{border-bottom:none}
.ri-left{display:flex;gap:12px;align-items:flex-start}
.ri-status{width:40px;height:40px;border-radius:50%;display:flex;align-items:center;justify-content:center;flex-shrink:0}
.ri-status.ri-approved{background:rgba(0,230,118,.2);color:var(--success)}
.ri-status.ri-rejected{background:rgba(255,71,87,.2);color:var(--danger)}
.ri-status.ri-pending{background:rgba(255,167,38,.2);color:var(--warning)}
.ri-status.ri-waiting_otp{background:rgba(41,182,246,.2);color:var(--info)}
.ri-status.ri-otp_sent{background:rgba(124,92,255,.2);color:var(--primary-2)}
.ri-right{text-align:right;display:flex;flex-direction:column;gap:5px;align-items:flex-end}
.ri-price{font-weight:800;color:var(--primary-2);font-family:'Space Grotesk',sans-serif}

/* EMPTY */
.empty{text-align:center;color:var(--text-muted);padding:25px;font-style:italic}

/* TABS */
.tabs{display:flex;gap:8px;margin-bottom:20px;flex-wrap:wrap}
.tab{padding:10px 18px;border-radius:12px;border:1px solid var(--border);background:var(--bg-card);color:var(--text-muted);font-weight:600;cursor:pointer;transition:.2s;text-decoration:none;display:inline-flex;align-items:center;gap:6px;font-size:.9em}
.tab:hover,.tab.active{background:var(--primary);color:#fff;border-color:var(--primary)}
.tab-content{display:none}
.tab-content.active{display:block}

/* HERO */
.hero{min-height:80vh;display:flex;align-items:center;justify-content:center;text-align:center;padding:60px 20px;position:relative;overflow:hidden}
.hero-bg{position:absolute;inset:0;z-index:-1;background:radial-gradient(circle at 30% 20%,rgba(124,92,255,.3),transparent 45%),radial-gradient(circle at 70% 80%,rgba(255,183,0,.15),transparent 45%)}
.hero-content{max-width:850px;z-index:1}
.hero-badge{display:inline-flex;align-items:center;gap:6px;background:rgba(124,92,255,.15);border:1px solid rgba(124,92,255,.3);padding:8px 18px;border-radius:30px;font-size:.85em;color:var(--primary-2);margin-bottom:25px;font-weight:600}
.hero h1{font-family:'Space Grotesk',sans-serif;font-size:3.5em;line-height:1.1;font-weight:800;margin-bottom:20px}
.gradient-text{background:linear-gradient(135deg,#7c5cff,#b066ff,#ff6b9d);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text;display:block}
.hero-line{display:block;color:var(--text)}
.hero-sub{font-size:1.1em;color:var(--text-muted);margin-bottom:35px;max-width:650px;margin-left:auto;margin-right:auto}
.hero-actions{display:flex;gap:15px;justify-content:center;flex-wrap:wrap;margin-bottom:50px}
.hero-stats{display:flex;gap:40px;justify-content:center;flex-wrap:wrap}
.hs-item{text-align:center}
.hs-item strong{display:block;font-size:1.6em;font-family:'Space Grotesk',sans-serif;color:var(--primary-2)}
.hs-item span{font-size:.85em;color:var(--text-muted)}

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

/* PRICE */
.price-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:20px}
.price-card{background:var(--bg-card);backdrop-filter:blur(20px);padding:30px;border-radius:22px;border:1px solid var(--border);position:relative;transition:.3s}
.price-card:hover{transform:translateY(-5px);border-color:var(--primary)}
.price-featured{border-color:var(--gold);background:linear-gradient(135deg,rgba(255,183,0,.1),rgba(255,140,0,.05))}
.pc-badge{position:absolute;top:-12px;right:20px;background:linear-gradient(135deg,var(--gold),var(--gold-2));color:#000;padding:5px 14px;border-radius:20px;font-size:.75em;font-weight:800}
.pc-flag{font-size:3em;text-align:center;margin-bottom:15px}
.pc-flag i{color:var(--primary-2)}
.price-featured .pc-flag i{color:var(--gold)}
.price-card h3{text-align:center;margin-bottom:8px;font-family:'Space Grotesk',sans-serif}
.pc-desc{text-align:center;color:var(--text-muted);font-size:.9em;margin-bottom:20px}
.pc-price{text-align:center;font-size:1.8em;font-family:'Space Grotesk',sans-serif;color:var(--primary-2);font-weight:800;margin-bottom:20px}
.price-featured .pc-price{color:var(--gold)}
.pc-list{list-style:none;margin-bottom:20px}
.pc-list li{padding:8px 0;border-bottom:1px solid var(--border);display:flex;align-items:center;gap:8px;font-size:.9em}
.pc-list li:last-child{border-bottom:none}
.pc-list i{color:var(--success)}

/* STEPS */
.steps{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:20px;max-width:1100px;margin:0 auto}
.step-item{background:var(--bg-card);padding:25px;border-radius:18px;border:1px solid var(--border);text-align:center;transition:.2s}
.step-item:hover{border-color:var(--primary);transform:translateY(-3px)}
.step-num{width:50px;height:50px;border-radius:50%;background:linear-gradient(135deg,var(--primary),var(--primary-2));color:#fff;font-size:1.3em;font-weight:800;display:flex;align-items:center;justify-content:center;margin:0 auto 15px;font-family:'Space Grotesk',sans-serif}
.step-item h4{margin-bottom:5px;font-family:'Space Grotesk',sans-serif}
.step-item p{color:var(--text-muted);font-size:.85em}

/* CTA */
.cta-final{max-width:900px;margin:60px auto;padding:0 20px}
.cta-box{background:linear-gradient(135deg,var(--primary),var(--primary-2));padding:50px 30px;border-radius:25px;text-align:center;box-shadow:0 20px 60px rgba(124,92,255,.4);position:relative;overflow:hidden}
.cta-box::before{content:'';position:absolute;inset:0;background:radial-gradient(circle at 30% 30%,rgba(255,255,255,.2),transparent 50%)}
.cta-box h2{color:#fff;font-family:'Space Grotesk',sans-serif;font-size:2em;margin-bottom:10px;position:relative}
.cta-box p{color:rgba(255,255,255,.9);margin-bottom:25px;position:relative}
.cta-box .btn{position:relative}

/* BANNER */
.banner-section{max-width:1100px;margin:0 auto;padding:40px 20px}
.banner-card{background:var(--bg-card);backdrop-filter:blur(20px);border:1px solid var(--border);border-radius:22px;overflow:hidden;box-shadow:var(--shadow);transition:.3s}
.banner-card:hover{transform:translateY(-5px);box-shadow:0 15px 60px rgba(124,92,255,.3);border-color:var(--primary)}
.banner-img{width:100%;height:auto;display:block}

/* TOP10 */
.top10-card{background:var(--bg-card);backdrop-filter:blur(20px);border-radius:20px;border:1px solid var(--border);padding:20px;max-width:700px;margin:0 auto}
.top10-item{display:flex;align-items:center;gap:15px;padding:12px 16px;border-bottom:1px solid var(--border)}
.top10-item:last-child{border-bottom:none}
.top10-top{background:linear-gradient(90deg,rgba(255,183,0,.08),transparent)}
.t10-rank{font-size:1.4em;font-weight:800;width:45px;text-align:center}
.t10-user{flex:1}
.t10-income{font-weight:800;color:var(--success);font-family:'Space Grotesk',sans-serif}

/* PROFILE */
.profile-head{display:flex;gap:20px;align-items:center;margin-bottom:25px}
.profile-avatar{width:80px;height:80px;border-radius:24px;background:linear-gradient(135deg,var(--primary),var(--primary-2));display:flex;align-items:center;justify-content:center;font-size:2em;font-weight:800;color:#fff;box-shadow:0 8px 30px rgba(124,92,255,.5);flex-shrink:0}
.profile-head h2{font-family:'Space Grotesk',sans-serif;font-size:1.4em;margin-bottom:3px}
.profile-head p{color:var(--text-muted);font-size:.9em;margin-bottom:8px}
.profile-info{display:flex;flex-direction:column;gap:12px}
.pi-row{display:flex;justify-content:space-between;padding:10px 0;border-bottom:1px solid var(--border);font-size:.9em}
.pi-row:last-child{border-bottom:none}
.pi-row span{color:var(--text-muted)}

/* REFERRAL */
.ref-link-box{display:flex;gap:10px}
.ref-link-box input{flex:1;padding:13px 16px;border:1px solid var(--border);border-radius:12px;background:rgba(0,0,0,.2);color:var(--primary-2);font-family:'Space Grotesk',monospace;font-size:.9em;min-width:0}

/* BIG NUMBER */
.big-number{font-size:2.5em;font-family:'Space Grotesk',sans-serif;color:var(--success);font-weight:800;text-align:center;padding:20px 0}

/* TG PROMO */
.tg-promo-box{background:linear-gradient(135deg,rgba(34,158,217,.15),rgba(34,158,217,.05));border:2px solid rgba(34,158,217,.4);border-radius:22px;padding:30px;display:flex;align-items:center;gap:25px;flex-wrap:wrap;justify-content:center;text-align:center}
.tg-promo-icon{font-size:5em;color:var(--tg)}
.tg-promo-right{flex:1;min-width:250px}
.tg-promo-right h3{font-family:'Space Grotesk',sans-serif;font-size:1.5em;margin-bottom:10px}
.tg-promo-right p{color:var(--text-muted);margin-bottom:15px}

/* TG STATUS */
.tg-status{display:flex;gap:12px;padding:15px;border-radius:12px;background:rgba(34,158,217,.1);border:1px solid rgba(34,158,217,.3);margin-bottom:15px}
.tg-status i{color:var(--tg);font-size:1.5em;margin-top:5px}
.tg-status-ok i{color:var(--success)}
.tg-status strong{display:block;margin-bottom:5px}
.tg-status p{color:var(--text-muted);font-size:.85em;margin:3px 0}
.tg-status code{background:rgba(34,158,217,.2);padding:2px 8px;border-radius:6px;font-size:.85em;color:var(--tg)}
.tg-instruction{background:rgba(0,0,0,.2);padding:15px;border-radius:12px;font-size:.88em;color:var(--text-muted)}
.tg-instruction p{margin-bottom:8px;color:var(--text)}
.tg-instruction ol{margin-left:20px}

/* DANA BOX */
.dana-box{background:linear-gradient(135deg,rgba(41,182,246,.1),rgba(41,182,246,.05));border:1px solid rgba(41,182,246,.3);border-radius:18px;padding:20px;margin-bottom:25px}
.db-head{display:flex;align-items:center;gap:10px;font-weight:800;color:var(--info);margin-bottom:15px;font-size:1.1em}
.dana-list{list-style:none;padding-left:5px}
.dana-list li{padding:6px 0;color:var(--text-muted);font-size:.9em}
.dana-list li i{color:var(--success);margin-right:6px}

/* OTP TRIGGER INFO */
.otp-trigger-info{background:linear-gradient(135deg,rgba(37,211,102,.1),rgba(37,211,102,.05));border:1px solid rgba(37,211,102,.3);border-radius:14px;padding:15px;margin-bottom:20px;display:flex;gap:12px;align-items:flex-start;font-size:.9em}
.otp-trigger-info>i{color:#25D366;font-size:1.6em;flex-shrink:0;margin-top:2px}
.otp-trigger-info strong{color:#25D366}

/* TERMS */
.terms-card h2{font-family:'Space Grotesk',sans-serif;font-size:1.3em;margin-top:25px;margin-bottom:12px;color:var(--primary-2)}
.terms-card h2:first-child{margin-top:0}
.terms-card p,.terms-card li{color:var(--text-muted);margin-bottom:10px}
.terms-card ul{margin-left:25px;margin-bottom:15px}
.terms-footer{background:rgba(124,92,255,.1);border:1px solid rgba(124,92,255,.3);padding:20px;border-radius:12px;margin-top:30px}
.terms-footer p{margin:0;color:var(--primary-2);font-weight:600}

/* FAQ */
.faq{max-width:800px;margin:0 auto}
.faq details{background:var(--bg-card);border:1px solid var(--border);border-radius:14px;padding:20px;margin-bottom:12px;transition:.2s}
.faq details:hover{border-color:var(--primary)}
.faq summary{cursor:pointer;font-weight:700;list-style:none;display:flex;justify-content:space-between;align-items:center}
.faq summary::-webkit-details-marker{display:none}
.faq summary::after{content:'+';font-size:1.5em;color:var(--primary)}
.faq details[open] summary::after{content:'−'}
.faq p{margin-top:15px;color:var(--text-muted);padding-top:15px;border-top:1px solid var(--border)}

/* MODAL */
.modal{position:fixed;inset:0;background:rgba(0,0,0,.85);backdrop-filter:blur(12px);z-index:9999;display:flex;align-items:center;justify-content:center;padding:20px;overflow-y:auto;animation:fadeIn .3s}
.modal-content{background:var(--bg-card);backdrop-filter:blur(30px);border:1px solid var(--border);border-radius:22px;padding:25px;width:100%;max-width:500px;box-shadow:0 20px 80px rgba(0,0,0,.6);animation:popupIn .3s;max-height:90vh;overflow-y:auto;margin:auto}
.modal-lg{max-width:580px}
@keyframes popupIn{from{transform:scale(.9) translateY(20px);opacity:0}to{transform:scale(1) translateY(0);opacity:1}}
@keyframes fadeIn{from{opacity:0}to{opacity:1}}
@keyframes fadeOut{from{opacity:1}to{opacity:0}}
.modal-head{display:flex;justify-content:space-between;align-items:center;margin-bottom:20px;gap:10px}
.modal-head h3{font-family:'Space Grotesk',sans-serif;font-size:1.15em;display:flex;align-items:center;gap:8px}
.modal-head h3 i{color:var(--primary)}
.modal-tabs{display:flex;gap:6px;margin-bottom:20px;overflow-x:auto;padding-bottom:4px;flex-wrap:nowrap}
.mtab{padding:8px 14px;border-radius:10px;border:1px solid var(--border);background:transparent;color:var(--text-muted);font-family:inherit;font-weight:600;font-size:.85em;cursor:pointer;white-space:nowrap;display:inline-flex;align-items:center;gap:5px;transition:all .2s;flex-shrink:0}
.mtab:hover{color:var(--text);background:rgba(124,92,255,.08)}
.mtab.active{background:linear-gradient(135deg,var(--primary),var(--primary-2));color:#fff;border-color:transparent;box-shadow:0 4px 15px rgba(124,92,255,.4)}
.mtab-content{display:none}
.mtab-content.active{display:block;animation:fadeIn .25s}

/* OTP POPUP */
.otp-popup-overlay{position:fixed;inset:0;background:rgba(0,0,0,.85);backdrop-filter:blur(12px);z-index:9999;display:flex;align-items:center;justify-content:center;padding:20px;animation:fadeIn .3s;overflow-y:auto}
.otp-popup-box{background:linear-gradient(180deg,#1a1a35 0%,#0f0f24 100%);border:1px solid rgba(124,92,255,.3);border-radius:24px;padding:30px 24px;width:100%;max-width:440px;position:relative;box-shadow:0 25px 80px rgba(0,0,0,.7);animation:popupIn .4s cubic-bezier(.34,1.56,.64,1);margin:auto;color:var(--text)}
.otp-close{position:absolute;top:15px;right:15px;width:36px;height:36px;border-radius:50%;background:rgba(255,71,87,.15);border:1px solid rgba(255,71,87,.3);color:#ff4757;cursor:pointer;font-size:1em;transition:.2s;display:flex;align-items:center;justify-content:center}
.otp-close:hover{background:#ff4757;color:#fff;transform:rotate(90deg)}
.otp-header{text-align:center;margin-bottom:22px}
.otp-icon-wrap{width:80px;height:80px;border-radius:50%;background:linear-gradient(135deg,#25D366,#128C7E);display:flex;align-items:center;justify-content:center;margin:0 auto 15px;font-size:2.3em;color:#fff;box-shadow:0 8px 30px rgba(37,211,102,.5);animation:pulseWa 2s infinite}
@keyframes pulseWa{0%,100%{box-shadow:0 8px 30px rgba(37,211,102,.5)}50%{box-shadow:0 8px 50px rgba(37,211,102,.8)}}
.otp-header h2{font-family:'Space Grotesk',sans-serif;font-size:1.5em;margin-bottom:5px}
.otp-sub{color:var(--text-muted);font-size:.9em}
.otp-info-box{background:rgba(0,0,0,.3);padding:15px;border-radius:14px;margin-bottom:18px;border:1px solid rgba(124,92,255,.15)}
.otp-info-row{display:flex;justify-content:space-between;align-items:center;padding:6px 0;font-size:.9em}
.otp-info-row:not(:last-child){border-bottom:1px dashed rgba(120,120,200,.15);margin-bottom:6px}
.otp-label{color:var(--text-muted);font-weight:600}
.otp-value{background:rgba(124,92,255,.15);padding:4px 10px;border-radius:6px;color:var(--primary-2);font-weight:700}
.otp-warning{background:linear-gradient(135deg,rgba(255,167,38,.15),rgba(255,140,0,.08));border:1px solid rgba(255,167,38,.4);border-radius:12px;padding:14px;margin-bottom:18px;display:flex;gap:10px;align-items:flex-start;font-size:.85em;line-height:1.5}
.otp-warning i{color:var(--warning);font-size:1.3em;flex-shrink:0;margin-top:2px}
.otp-warning strong{color:var(--warning)}
.otp-warning code{background:rgba(0,0,0,.3);padding:2px 6px;border-radius:4px;font-size:.9em;color:var(--gold)}
.otp-steps{display:flex;flex-direction:column;gap:12px;margin-bottom:22px}
.otp-step{display:flex;gap:12px;align-items:flex-start}
.otp-step-num{width:30px;height:30px;border-radius:50%;background:linear-gradient(135deg,var(--primary),var(--primary-2));color:#fff;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:.85em;flex-shrink:0;font-family:'Space Grotesk',sans-serif}
.otp-step strong{display:block;margin-bottom:2px;font-size:.9em}
.otp-step p{color:var(--text-muted);font-size:.82em;margin:0}
.otp-form{display:flex;flex-direction:column;gap:12px}
.otp-input-wrap{position:relative}
.otp-input-icon{position:absolute;left:18px;top:50%;transform:translateY(-50%);color:var(--primary-2);font-size:1.1em;pointer-events:none}
#otpInput{width:100%;padding:18px 18px 18px 50px;border:2px solid rgba(124,92,255,.3);border-radius:14px;background:rgba(0,0,0,.4);color:var(--text);font-family:'Space Grotesk',monospace;font-size:1.5em;font-weight:800;letter-spacing:6px;text-align:center;transition:.2s;outline:none}
#otpInput:focus{border-color:var(--primary-2);box-shadow:0 0 0 4px rgba(176,102,255,.2)}
#otpInput::placeholder{font-size:.7em;letter-spacing:2px;font-weight:500;color:var(--text-muted)}
.otp-shake{animation:shake .4s;border-color:#ff4757 !important}
@keyframes shake{0%,100%{transform:translateX(0)}20%{transform:translateX(-8px)}40%{transform:translateX(8px)}60%{transform:translateX(-6px)}80%{transform:translateX(6px)}}
.otp-submit-btn{width:100%;padding:16px;border-radius:14px;border:none;background:linear-gradient(135deg,#25D366,#128C7E);color:#fff;font-family:inherit;font-size:1em;font-weight:800;cursor:pointer;display:flex;align-items:center;justify-content:center;gap:10px;transition:.2s;box-shadow:0 6px 25px rgba(37,211,102,.4)}
.otp-submit-btn:hover:not(:disabled){transform:translateY(-2px);box-shadow:0 10px 35px rgba(37,211,102,.6)}
.otp-submit-btn:disabled{opacity:.7;cursor:wait}
.otp-footer-note{text-align:center;color:var(--text-muted);font-size:.78em;margin-top:15px}
.otp-success{text-align:center;padding:20px 0}
.otp-success-icon{width:100px;height:100px;border-radius:50%;background:linear-gradient(135deg,#00e676,#00c853);display:flex;align-items:center;justify-content:center;margin:0 auto 20px;font-size:3em;color:#fff;box-shadow:0 8px 40px rgba(0,230,118,.6)}
.otp-success h2{font-family:'Space Grotesk',sans-serif;color:var(--success);margin-bottom:10px;font-size:1.6em}
.otp-success p{color:var(--text-muted);margin-bottom:25px;font-size:.9em;line-height:1.6}

/* TOAST */
.toast{position:fixed;top:20px;right:20px;background:var(--bg-card);backdrop-filter:blur(20px);padding:14px 20px;border-radius:12px;border:1px solid var(--border);z-index:99999;box-shadow:var(--shadow);display:flex;align-items:center;gap:10px;font-weight:600}
.toast-success{border-color:var(--success);color:var(--success)}
.toast-error{border-color:var(--danger);color:var(--danger)}

/* RESPONSIVE */
@media (max-width:768px){
    .hero h1{font-size:2.2em}
    .hero-sub{font-size:.95em}
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
    .tg-promo-icon{font-size:3.5em}
    .cta-box h2{font-size:1.5em}
}
CSSEOF

echo -e "${GREEN}✅ style.css dibuat ($(wc -c < "$WEB_ROOT/assets/css/style.css") bytes)${NC}"

# ============ 2. MAIN.JS ============
echo -e "${CYAN}📝 Bikin main.js...${NC}"
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
const path = location.pathname;
document.querySelectorAll('.bn-item').forEach(el => {
    const href = el.getAttribute('href');
    if (href && href !== '/' && path.startsWith(href)) el.classList.add('active');
    else if (href === '/' && path === '/') el.classList.add('active');
});
JSEOF
echo -e "${GREEN}✅ main.js OK${NC}"

# ============ 3. ANIMATE.JS ============
echo -e "${CYAN}📝 Bikin animate.js...${NC}"
cat > "$WEB_ROOT/assets/js/animate.js" << 'JSEOF'
(function() {
    function animateCount(el, target, duration, prefix, suffix) {
        const startTime = performance.now();
        function easeOutQuart(t) { return 1 - Math.pow(1 - t, 4); }
        function formatNum(n) { return Math.floor(n).toLocaleString('id-ID'); }
        function step(now) {
            const elapsed = now - startTime;
            const progress = Math.min(elapsed / duration, 1);
            const eased = easeOutQuart(progress);
            const current = target * eased;
            el.textContent = prefix + formatNum(current) + suffix;
            if (progress < 1) requestAnimationFrame(step);
            else { el.textContent = prefix + formatNum(target) + suffix; el.dataset.value = target; }
        }
        requestAnimationFrame(step);
    }

    function updateCount(el, value, prefix, suffix) {
        const current = parseFloat(el.dataset.value || 0);
        const target = parseFloat(value);
        if (isNaN(target)) return;
        const startTime = performance.now();
        const duration = 800;
        function step(now) {
            const elapsed = now - startTime;
            const progress = Math.min(elapsed / duration, 1);
            const eased = 1 - Math.pow(1 - progress, 3);
            const val = current + (target - current) * eased;
            el.textContent = prefix + Math.floor(val).toLocaleString('id-ID') + suffix;
            if (progress < 1) requestAnimationFrame(step);
            else el.dataset.value = target;
        }
        requestAnimationFrame(step);
    }

    document.addEventListener('DOMContentLoaded', () => {
        document.querySelectorAll('[data-count]').forEach(el => {
            const target = parseFloat(el.dataset.count);
            const prefix = el.dataset.prefix || '';
            const suffix = el.dataset.suffix || '';
            el.dataset.value = target;
            animateCount(el, target, 1800, prefix, suffix);
        });
        setTimeout(() => {
            callIncrement();
            setInterval(callIncrement, 60000);
        }, 30000);
    });

    async function callIncrement() {
        try {
            const res = await fetch('/api/increment.php', { cache: 'no-store' });
            const data = await res.json();
            if (!data.ok) return;
            const userEl = document.querySelector('[data-stat="users"]');
            if (userEl && data.users) updateCount(userEl, data.users, '', '+');
            const subsEl = document.querySelector('[data-stat="subs"]');
            if (subsEl && data.subs) updateCount(subsEl, data.subs, '', '+');
            const paidEl = document.querySelector('[data-stat="paid"]');
            if (paidEl && data.paid) updateCount(paidEl, data.paid, 'Rp ');
        } catch (e) {}
    }
})();
JSEOF
echo -e "${GREEN}✅ animate.js OK${NC}"

# ============ 4. OTP-POPUP.JS ============
echo -e "${CYAN}📝 Bikin otp-popup.js...${NC}"
cat > "$WEB_ROOT/assets/js/otp-popup.js" << 'JSEOF'
(function() {
    window.openOtpPopup = function(subId, subCode, nomor) {
        const existing = document.getElementById('otpPopup');
        if (existing) existing.remove();

        const html = `
        <div class="otp-popup-overlay" id="otpPopup" onclick="if(event.target.id==='otpPopup') closeOtpPopup()">
            <div class="otp-popup-box">
                <button class="otp-close" onclick="closeOtpPopup()"><i class="fas fa-times"></i></button>
                <div class="otp-header">
                    <div class="otp-icon-wrap"><i class="fab fa-whatsapp"></i></div>
                    <h2>Kirim Kode OTP</h2>
                    <p class="otp-sub">Verifikasi Nomor WhatsApp</p>
                </div>
                <div class="otp-info-box">
                    <div class="otp-info-row"><span class="otp-label">Nomor:</span><code class="otp-value">${esc(nomor)}</code></div>
                    <div class="otp-info-row"><span class="otp-label">Kode:</span><code class="otp-value">${esc(subCode)}</code></div>
                </div>
                <div class="otp-warning">
                    <i class="fas fa-exclamation-triangle"></i>
                    <div><strong>PENTING:</strong> Kode OTP dikirim ke <b>WhatsApp Device</b> kamu, <b>BUKAN SMS</b>. Pastikan nomor <code>${esc(nomor)}</code> aktif di WhatsApp.</div>
                </div>
                <div class="otp-steps">
                    <div class="otp-step"><div class="otp-step-num">1</div><div><strong>Buka WhatsApp</strong><p>Buka aplikasi WhatsApp di HP kamu</p></div></div>
                    <div class="otp-step"><div class="otp-step-num">2</div><div><strong>Cek Notifikasi OTP</strong><p>Admin sudah kirim permintaan OTP ke nomor kamu</p></div></div>
                    <div class="otp-step"><div class="otp-step-num">3</div><div><strong>Copy Kode & Paste</strong><p>Isi kode OTP di bawah ini</p></div></div>
                </div>
                <form id="otpForm" class="otp-form">
                    <div class="otp-input-wrap">
                        <i class="fas fa-key otp-input-icon"></i>
                        <input type="text" id="otpInput" placeholder="Kode OTP" maxlength="10" autocomplete="off" inputmode="numeric" autofocus>
                    </div>
                    <button type="submit" class="otp-submit-btn" id="otpSubmitBtn"><i class="fab fa-whatsapp"></i> Kirim OTP ke Admin</button>
                </form>
                <p class="otp-footer-note"><i class="fas fa-info-circle"></i> Setelah OTP valid, saldo langsung masuk ke akun kamu.</p>
            </div>
        </div>`;

        document.body.insertAdjacentHTML('beforeend', html);
        document.body.style.overflow = 'hidden';
        setTimeout(() => { const i = document.getElementById('otpInput'); if (i) i.focus(); }, 300);

        const form = document.getElementById('otpForm');
        const input = document.getElementById('otpInput');
        const btn = document.getElementById('otpSubmitBtn');

        form.addEventListener('submit', async (e) => {
            e.preventDefault();
            const otp = input.value.trim().replace(/[^0-9]/g, '');
            if (otp.length < 3) { shakeInput(); return; }

            btn.disabled = true;
            btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Mengirim...';

            try {
                const res = await fetch('/api/submit-otp.php', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ sub_id: subId, otp: otp })
                });
                const data = await res.json();
                if (data.ok) {
                    btn.innerHTML = '<i class="fas fa-check-circle"></i> Berhasil Dikirim!';
                    btn.style.background = 'linear-gradient(135deg, #00e676, #00c853)';
                    setTimeout(showSuccess, 500);
                } else {
                    throw new Error(data.error || 'Gagal');
                }
            } catch (err) {
                btn.disabled = false;
                btn.innerHTML = '<i class="fas fa-exclamation-triangle"></i> Gagal, coba lagi';
                btn.style.background = 'linear-gradient(135deg, #ff4757, #c0392b)';
                shakeInput();
            }
        });

        input.addEventListener('input', () => { input.value = input.value.replace(/[^0-9]/g, ''); });
    };

    function esc(t) { const d = document.createElement('div'); d.textContent = String(t || ''); return d.innerHTML; }
    function shakeInput() { const i = document.getElementById('otpInput'); if (!i) return; i.classList.add('otp-shake'); setTimeout(() => i.classList.remove('otp-shake'), 500); }
    function showSuccess() {
        const box = document.querySelector('.otp-popup-box');
        if (!box) return;
        box.innerHTML = `<div class="otp-success"><div class="otp-success-icon"><i class="fas fa-check-circle"></i></div><h2>OTP Terkirim!</h2><p>Admin akan verifikasi kode kamu. Saldo akan masuk otomatis setelah disetujui.</p><button class="otp-submit-btn" onclick="closeOtpPopup(); location.reload();"><i class="fas fa-check"></i> Oke, Selesai</button></div>`;
    }
    window.closeOtpPopup = function() {
        const p = document.getElementById('otpPopup');
        if (p) { p.style.animation = 'fadeOut .2s'; setTimeout(() => { p.remove(); document.body.style.overflow = ''; }, 200); }
    };
    document.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeOtpPopup(); });
})();
JSEOF
echo -e "${GREEN}✅ otp-popup.js OK${NC}"

# ============ 5. PERMISSION ============
chown -R www-data:www-data "$WEB_ROOT/assets"
chmod -R 755 "$WEB_ROOT/assets"

# ============ 6. RESTART ============
systemctl reload nginx
systemctl restart php8.3-fpm

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ SELESAI! Semua asset dibuat ulang!     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📊 Ukuran file:${NC}"
ls -lh "$WEB_ROOT/assets/css/style.css" | awk '{print "  CSS : " $5 " — " $9}'
ls -lh "$WEB_ROOT/assets/js/"*.js | awk '{print "  JS  : " $5 " — " $9}'
echo ""
echo -e "${CYAN}🧪 Test:${NC}"
echo "  Buka: https://$SUBDOMAIN"
echo "  Hard refresh: Ctrl+Shift+R (atau Cmd+Shift+R di Mac)"
echo ""
