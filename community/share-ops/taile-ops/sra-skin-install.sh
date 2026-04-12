#!/bin/bash
# ================================================================
#   AESTHETICS STUDIO SITE INSTALLER v1.0
#   Deploy a premium skincare / aesthetics studio website
#   to any VPS running Docker + Nginx Proxy Manager.
#
#   Stack : nginx:alpine serving a single-file static HTML site
#   Design: Luxury aesthetics — dark/light mode, custom cursor,
#           before/after slider, testimonial carousel, animations
#
#   Prerequisites: NPM already installed + npm_default network exists
#   (Run vps-community-install.sh first if starting from scratch)
# ================================================================

# ── Colors + helpers ─────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()  { echo -e "${CYAN}  [INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}  [ OK ]${NC}  $*"; }
warn()  { echo -e "${YELLOW}  [WARN]${NC}  $*"; }
err()   { echo -e "${RED}  [ERR ]${NC}  $*"; exit 1; }
phase() {
  echo -e "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}${CYAN}  $*${NC}"
  echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}
ask()     { read -rp "  $1 " "$2"; }
askpass() { read -srp "  $1 " "$2"; echo; }
yesno()   {
  local reply
  read -rp "  $1 (y/n): " reply; reply="${reply,,}"
  while [[ "$reply" != "y" && "$reply" != "n" ]]; do
    read -rp "  Please enter y or n: " reply; reply="${reply,,}"
  done
  printf -v "$2" '%s' "$reply"
}

LOGFILE="$HOME/sra_install_$(date +%F_%H-%M-%S).log"
exec > >(tee -a "$LOGFILE") 2>&1

# ── Guard: do not run as root ────────────────────────────────────
if [ "$EUID" -eq 0 ]; then
  echo -e "${RED}${BOLD}"
  echo "  ╔══════════════════════════════════════════════════════════╗"
  echo "  ║   ⚠  YOU ARE LOGGED IN AS ROOT                         ║"
  echo "  ║      Run as a regular sudo user, not root.              ║"
  echo "  ╚══════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo "  Create a user first, then re-run:"
  echo -e "    ${CYAN}adduser YOUR_USERNAME && usermod -aG sudo,docker YOUR_USERNAME${NC}"
  echo -e "    ${CYAN}su - YOUR_USERNAME${NC}"
  exit 1
fi

# ================================================================
#   BANNER
# ================================================================
clear
echo -e "${BOLD}${CYAN}"
cat << 'BANNER'

   ██████╗  ██████╗ ██████╗ ███████╗
  ██╔════╝ ██╔════╝ ██╔══██╗██╔════╝  Aesthetics Studio
  ██║      ██║      ██████╔╝███████╗  Site Installer
  ██║      ██║      ██╔══██╗╚════██║  v1.0
  ╚██████╗ ╚██████╗ ██║  ██║███████║
   ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚══════╝

BANNER
echo -e "${NC}${BOLD}  Premium skincare / aesthetics studio website${NC}"
echo    "  Deploys in minutes — fully customized to your business"
echo
echo -e "${CYAN}  Prerequisites: NPM running with npm_default Docker network${NC}"
echo -e "${CYAN}  (run vps-community-install.sh first if not already done)${NC}"
echo

# ── Verify NPM network exists ────────────────────────────────────
NPM_NETWORK=""
for name in npm_default proxy nginx-proxy-manager_default; do
  if docker network inspect "$name" &>/dev/null; then
    NPM_NETWORK="$name"; break
  fi
done
if [ -z "$NPM_NETWORK" ]; then
  err "Could not find NPM Docker network. Is NPM running? Run vps-community-install.sh first."
fi
ok "NPM network detected: $NPM_NETWORK"

# ================================================================
#   WIZARD — Collect all business information upfront
# ================================================================
phase "SETUP WIZARD — Your Business Information"
echo
echo "  This information will be embedded directly into your website."
echo "  Press Enter to accept any default shown in [brackets]."
echo

# ── Subdomain & domain ────────────────────────────────────────────
ask "Your base domain (e.g. example.com):" BASE_DOMAIN
while [[ -z "$BASE_DOMAIN" ]]; do
  warn "Domain cannot be empty."
  ask "Base domain:" BASE_DOMAIN
done

ask "Subdomain for this site [skin.$BASE_DOMAIN]:" SITE_SUB
SITE_SUB="${SITE_SUB:-skin.$BASE_DOMAIN}"

ask "Folder name on server [skin]:" SITE_FOLDER
SITE_FOLDER="${SITE_FOLDER:-skin}"

ask "Docker container name [skin-site]:" CONTAINER_NAME
CONTAINER_NAME="${CONTAINER_NAME:-skin-site}"

# ── Business identity ─────────────────────────────────────────────
echo
echo -e "  ${BOLD}— Business Identity —${NC}"
ask "Full business name (e.g. Luxe Skin Studio):" BIZ_NAME
while [[ -z "$BIZ_NAME" ]]; do
  warn "Business name cannot be empty."
  ask "Full business name:" BIZ_NAME
done

ask "Short name for logo line 1 (e.g. Luxe Skin):" BIZ_SHORT
BIZ_SHORT="${BIZ_SHORT:-$BIZ_NAME}"

ask "City, State (e.g. San Jose, California):" BIZ_CITY
BIZ_CITY="${BIZ_CITY:-Your City, Your State}"

ask "City, ST short (e.g. San Jose, CA):" BIZ_CITY_SHORT
BIZ_CITY_SHORT="${BIZ_CITY_SHORT:-$BIZ_CITY}"

ask "Year established [$(date +%Y)]:" BIZ_EST
BIZ_EST="${BIZ_EST:-$(date +%Y)}"

# ── Contact info ──────────────────────────────────────────────────
echo
echo -e "  ${BOLD}— Contact & Location —${NC}"
ask "Business address (e.g. 123 Main St, Suite 101, City, ST 00000):" BIZ_ADDRESS
BIZ_ADDRESS="${BIZ_ADDRESS:-123 Main Street, Your City, ST 00000}"

ask "Phone number display (e.g. (408) 564-4479):" BIZ_PHONE
BIZ_PHONE="${BIZ_PHONE:-(000) 000-0000}"

BIZ_PHONE_RAW=$(echo "$BIZ_PHONE" | tr -d '() -')

ask "Business email:" BIZ_EMAIL
BIZ_EMAIL="${BIZ_EMAIL:-hello@yourbusiness.com}"

ask "Hours (e.g. Tue–Sat | 10AM–6PM):" BIZ_HOURS
BIZ_HOURS="${BIZ_HOURS:-Mon–Sat | 10AM–6PM}"

# ── Booking ───────────────────────────────────────────────────────
echo
echo -e "  ${BOLD}— Online Booking —${NC}"
yesno "Do you have an online booking URL (e.g. Mangomint, Vagaro, etc.)?" HAS_BOOKING
if [[ "$HAS_BOOKING" == "y" ]]; then
  ask "Booking URL (full URL including https://):" BOOKING_URL
  while [[ -z "$BOOKING_URL" ]]; do
    warn "Booking URL cannot be empty."
    ask "Booking URL:" BOOKING_URL
  done
  BOOK_TARGET="$BOOKING_URL"
  BOOK_ATTR='target="_blank"'
else
  BOOK_TARGET="#contact"
  BOOK_ATTR=""
  warn "No booking URL — all 'Book Now' buttons will scroll to the Contact section."
fi

# ── Copyright year ────────────────────────────────────────────────
ask "Copyright year [$(date +%Y)]:" COPYRIGHT_YEAR
COPYRIGHT_YEAR="${COPYRIGHT_YEAR:-$(date +%Y)}"

# ── Generate monogram (up to 3 initials from business name) ──────
BIZ_INITIALS=$(echo "$BIZ_NAME" | awk '{for(i=1;i<=NF&&i<=3;i++) printf substr($i,1,1)}' | tr '[:lower:]' '[:upper:]')
MAPS_URL="https://maps.google.com/?q=$(echo "$BIZ_ADDRESS" | sed 's/ /+/g')"

# ================================================================
#   CONFIRMATION
# ================================================================
clear
phase "CONFIRM YOUR SETTINGS"
echo
echo -e "  ${BOLD}Site${NC}"
echo "    Subdomain:     https://$SITE_SUB"
echo "    Folder:        ~/$SITE_FOLDER"
echo "    Container:     $CONTAINER_NAME"
echo
echo -e "  ${BOLD}Business${NC}"
echo "    Name:          $BIZ_NAME"
echo "    Monogram:      $BIZ_INITIALS"
echo "    City:          $BIZ_CITY"
echo "    Est:           $BIZ_EST"
echo "    Address:       $BIZ_ADDRESS"
echo "    Phone:         $BIZ_PHONE"
echo "    Email:         $BIZ_EMAIL"
echo "    Hours:         $BIZ_HOURS"
echo "    Booking URL:   ${BOOK_TARGET}"
echo "    Copyright:     © $COPYRIGHT_YEAR $BIZ_NAME"
echo
read -rp "  Everything correct? Type yes to begin (yes/no): " confirm
[[ "$confirm" != "yes" ]] && { echo "  Re-run the script to start over."; exit 0; }

# ================================================================
#   PHASE 1 — Create project directory + write HTML
# ================================================================
phase "PHASE 1 — Writing Website Files"

info "Removing old installation at ~/$SITE_FOLDER ..."
cd ~/ 2>/dev/null && docker compose -f ~/$SITE_FOLDER/docker-compose.yml down 2>/dev/null || true
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
rm -rf ~/$SITE_FOLDER
mkdir -p ~/$SITE_FOLDER/html
cd ~/$SITE_FOLDER

info "Writing index.html ..."

# ── Write HTML template with placeholders ────────────────────────
cat > html/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en" data-theme="light">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>__BIZ_NAME__ | __BIZ_CITY_SHORT__</title>
<meta name="description" content="__BIZ_NAME__ — Expert estheticians in __BIZ_CITY_SHORT__. Signature facials, chemical peels, microneedling, and personalized skincare."/>
<link href="https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,400;0,500;1,400;1,500&family=Inter:wght@300;400;500&display=swap" rel="stylesheet"/>
<style>
:root{
  --ivory:#faf8f5;--warm:#f5f2ed;--sage:#8a9e8c;--sage-l:#b8c9ba;--sage-d:#5c7a5e;
  --terra:#c4785a;--terra-l:#d4937a;--terra-d:#9a5540;
  --stone:#3d3530;--stone-m:#6b5d57;--stone-l:#a89990;--stone-xl:#d4cdc9;
  --gold:#b8956a;--gold-l:#d4b48a;
  --fs:'Playfair Display',serif;--fn:'Inter',sans-serif;
  --bg:var(--ivory);--surf:#fff;--txt:var(--stone);--txt2:var(--stone-m);
  --bdr:var(--stone-xl);--nav-bg:rgba(250,248,245,.95);
  --card-bg:#fff;--stat-bg:#3d3530;
}
[data-theme="dark"]{
  --bg:#13110f;--surf:#1c1815;--txt:#ede8e3;--txt2:#9c8f88;
  --bdr:#2e2820;--nav-bg:rgba(19,17,15,.95);
  --card-bg:#1c1815;--stat-bg:#0d0b09;
  --ivory:#13110f;--warm:#1c1815;--stone-xl:#2e2820;
}
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
html{scroll-behavior:smooth}
body{font-family:var(--fn);background:var(--bg);color:var(--txt);overflow-x:hidden;font-weight:300;transition:background .4s,color .4s}
/* ── CURSOR ── */
.cur{position:fixed;width:9px;height:9px;border-radius:50%;background:var(--terra);pointer-events:none;z-index:9999;transform:translate(-50%,-50%);transition:transform .1s;mix-blend-mode:multiply}
[data-theme="dark"] .cur{mix-blend-mode:screen}
.cur-ring{position:fixed;width:34px;height:34px;border-radius:50%;border:1.5px solid var(--terra);pointer-events:none;z-index:9998;transform:translate(-50%,-50%);transition:all .16s ease;opacity:.5}
.cur-ring.hov{width:52px;height:52px;opacity:.2}
/* ── NAV ── */
nav{position:fixed;top:0;left:0;right:0;z-index:900;padding:20px 60px;display:flex;align-items:center;justify-content:space-between;transition:all .4s}
nav.sc{background:var(--nav-bg);backdrop-filter:blur(14px);padding:13px 60px;box-shadow:0 1px 20px rgba(61,53,48,.08)}
.logo-wrap{display:flex;align-items:center;gap:11px;text-decoration:none;flex-shrink:0}
.logo-svg{width:48px;height:48px;flex-shrink:0}
.logo-txt-block{display:flex;flex-direction:column;line-height:1.15}
.logo-line1{font-family:var(--fs);font-size:1rem;font-weight:500;color:#fff;letter-spacing:.04em;transition:color .3s}
.logo-line2{font-size:.42rem;letter-spacing:.32em;text-transform:uppercase;color:rgba(255,255,255,.55);transition:color .3s}
nav.sc .logo-line1{color:var(--txt)}
nav.sc .logo-line2{color:var(--stone-l)}
.nav-links{display:flex;gap:30px;list-style:none;align-items:center}
.nav-links a{font-size:.7rem;letter-spacing:.15em;text-transform:uppercase;color:rgba(255,255,255,.75);text-decoration:none;transition:color .3s;position:relative}
.nav-links a::after{content:'';position:absolute;bottom:-2px;left:0;right:0;height:1px;background:var(--terra);transform:scaleX(0);transition:transform .3s;transform-origin:left}
.nav-links a:hover::after{transform:scaleX(1)}
nav.sc .nav-links a{color:var(--txt2)}
nav.sc .nav-links a:hover{color:var(--txt)}
.nav-r{display:flex;align-items:center;gap:12px}
.theme-btn{background:none;border:1px solid rgba(255,255,255,.28);color:rgba(255,255,255,.75);width:34px;height:34px;border-radius:50%;cursor:pointer;font-size:.75rem;transition:all .3s;display:flex;align-items:center;justify-content:center;flex-shrink:0}
nav.sc .theme-btn{border-color:var(--bdr);color:var(--txt2)}
.theme-btn:hover{border-color:var(--terra);color:var(--terra)}
.nav-book{background:var(--terra);color:#fff!important;padding:10px 22px;border-radius:40px;font-size:.7rem;font-weight:500;letter-spacing:.12em;text-transform:uppercase;text-decoration:none;transition:all .3s;white-space:nowrap}
.nav-book:hover{background:var(--terra-d);transform:translateY(-1px);box-shadow:0 6px 20px rgba(196,120,90,.35)}
/* ── HERO ── */
.hero{height:100vh;min-height:680px;position:relative;display:flex;align-items:center;overflow:hidden}
.hero-bg{position:absolute;inset:0;background-image:url('https://images.unsplash.com/photo-1515377905703-c4788e51af15?auto=format&fit=crop&w=1800&q=80');background-size:cover;background-position:center top;z-index:0;transition:transform 8s ease-out;transform:scale(1.06)}
.hero-bg.loaded{transform:scale(1)}
.hero-dim{position:absolute;inset:0;background:linear-gradient(110deg,rgba(25,17,13,.85) 0%,rgba(35,24,18,.68) 55%,rgba(45,30,22,.5) 100%);z-index:1}
.hero-content{position:relative;z-index:2;padding:0 60px;max-width:720px}
.h-pill{display:inline-flex;align-items:center;gap:8px;background:rgba(255,255,255,.09);border:1px solid rgba(255,255,255,.18);backdrop-filter:blur(8px);padding:6px 16px;border-radius:40px;margin-bottom:28px;opacity:0;animation:fadeUp .8s .3s forwards}
.h-pill span{font-size:.62rem;letter-spacing:.22em;text-transform:uppercase;color:rgba(255,255,255,.85)}
.h-pill::before{content:'';width:6px;height:6px;border-radius:50%;background:var(--sage-l);flex-shrink:0}
.h-title{font-family:var(--fs);font-size:clamp(2.8rem,6vw,5.4rem);font-weight:400;color:#fff;line-height:1.1;margin-bottom:24px;opacity:0;animation:fadeUp 1s .5s forwards}
.h-title em{font-style:italic;color:var(--terra-l)}
.h-sub{font-size:.9rem;color:rgba(255,255,255,.6);line-height:1.88;margin-bottom:44px;max-width:440px;opacity:0;animation:fadeUp .9s .7s forwards}
.h-ctas{display:flex;gap:12px;flex-wrap:wrap;opacity:0;animation:fadeUp .9s .9s forwards}
.btn-terra{background:var(--terra);color:#fff;padding:14px 34px;font-size:.72rem;font-weight:500;letter-spacing:.14em;text-transform:uppercase;text-decoration:none;border-radius:40px;transition:all .3s;display:inline-block;border:none;cursor:pointer;font-family:var(--fn)}
.btn-terra:hover{background:var(--terra-d);transform:translateY(-2px);box-shadow:0 10px 28px rgba(196,120,90,.4)}
.btn-wht{background:transparent;color:rgba(255,255,255,.82);padding:14px 34px;font-size:.72rem;letter-spacing:.14em;text-transform:uppercase;text-decoration:none;border:1px solid rgba(255,255,255,.28);border-radius:40px;transition:all .3s;display:inline-block}
.btn-wht:hover{border-color:rgba(255,255,255,.7);color:#fff;transform:translateY(-2px)}
.hero-scroll{position:absolute;bottom:36px;left:60px;z-index:2;display:flex;align-items:center;gap:12px;opacity:0;animation:fadeIn 1s 1.5s forwards;cursor:pointer}
.hs-line{width:36px;height:1px;background:rgba(255,255,255,.3)}
.hs-txt{font-size:.58rem;letter-spacing:.24em;text-transform:uppercase;color:rgba(255,255,255,.38)}
.hero-badges{position:absolute;right:60px;bottom:80px;z-index:2;display:flex;flex-direction:column;gap:10px;opacity:0;animation:fadeIn 1s 1.2s forwards}
.h-badge{background:rgba(255,255,255,.1);border:1px solid rgba(255,255,255,.18);backdrop-filter:blur(10px);padding:11px 16px;border-radius:10px;text-align:center}
.h-badge .bn{font-family:var(--fs);font-size:1.35rem;color:#fff;line-height:1}
.h-badge .bl{font-size:.55rem;letter-spacing:.15em;text-transform:uppercase;color:rgba(255,255,255,.55);margin-top:2px}
/* ── MARQUEE ── */
.mq{background:var(--terra);padding:12px 0;overflow:hidden}
.mq-track{display:flex;white-space:nowrap;animation:marquee 32s linear infinite}
.mq-track:hover{animation-play-state:paused}
.mq-track span{font-size:.58rem;letter-spacing:.26em;text-transform:uppercase;color:rgba(255,255,255,.9);font-weight:400;padding:0 32px}
.mq-track span::before{content:'◇';margin-right:32px;opacity:.5;font-size:.38rem;vertical-align:middle}
/* ── SHARED ── */
.sec{padding:100px 60px}
.inner{max-width:1160px;margin:0 auto}
.eyebrow{font-size:.6rem;letter-spacing:.3em;text-transform:uppercase;color:var(--terra);margin-bottom:14px;font-weight:400}
.sec-h{font-family:var(--fs);font-size:clamp(1.9rem,3.5vw,3rem);font-weight:400;line-height:1.2;color:var(--txt);margin-bottom:20px}
.sec-h em{font-style:italic;color:var(--sage-d)}
.body-txt{font-size:.88rem;line-height:1.92;color:var(--txt2)}
.divider{width:38px;height:2px;background:var(--terra);margin:18px 0;border-radius:2px}
/* ── INTRO ── */
.intro-grid{display:grid;grid-template-columns:1fr 1fr;gap:80px;align-items:center}
.img-wrap{position:relative}
.real-img{width:100%;aspect-ratio:3/4;object-fit:cover;border-radius:14px;display:block;transition:transform .6s}
.real-img:hover{transform:scale(1.02)}
.float-badge{position:absolute;bottom:-18px;right:-18px;background:var(--terra);color:#fff;width:92px;height:92px;border-radius:50%;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;border:3px solid var(--bg);z-index:2;box-shadow:0 8px 24px rgba(196,120,90,.3);transition:border-color .4s}
.float-badge .bn{font-family:var(--fs);font-size:1.65rem;line-height:1}
.float-badge .bl{font-size:.46rem;letter-spacing:.12em;text-transform:uppercase;opacity:.85;margin-top:2px}
.check-list{list-style:none;margin-top:22px;display:flex;flex-direction:column;gap:10px}
.check-list li{display:flex;align-items:center;gap:12px;font-size:.84rem;color:var(--txt2)}
.check-list li::before{content:'';width:15px;height:15px;min-width:15px;border-radius:50%;background:var(--sage);display:block}
/* ── STATS ── */
.stats-band{background:var(--stat-bg);padding:54px 60px}
.stats-inner{display:grid;grid-template-columns:repeat(4,1fr);max-width:1000px;margin:0 auto}
.stat-item{text-align:center;padding:0 28px;border-right:1px solid rgba(255,255,255,.1)}
.stat-item:last-child{border-right:none}
.stat-n{font-family:var(--fs);font-size:3rem;font-weight:400;color:var(--terra-l);line-height:1;transition:transform .3s}
.stat-item:hover .stat-n{transform:scale(1.08)}
.stat-l{font-size:.58rem;letter-spacing:.2em;text-transform:uppercase;color:rgba(255,255,255,.4);margin-top:8px}
/* ── SERVICES ── */
.svc-wrap{background:var(--warm)}
.svc-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:22px;margin-top:44px}
.svc-card{background:var(--card-bg);border-radius:14px;overflow:hidden;border:1px solid var(--bdr);transition:all .4s;cursor:pointer}
.svc-card:hover{transform:translateY(-6px);box-shadow:0 20px 56px rgba(61,53,48,.1);border-color:var(--terra-l)}
[data-theme="dark"] .svc-card:hover{box-shadow:0 20px 56px rgba(0,0,0,.4)}
.svc-img{width:100%;height:190px;object-fit:cover;display:block;transition:transform .6s}
.svc-card:hover .svc-img{transform:scale(1.05)}
.svc-body{padding:22px}
.svc-cat{font-size:.56rem;letter-spacing:.22em;text-transform:uppercase;color:var(--terra);margin-bottom:7px;font-weight:500}
.svc-name{font-family:var(--fs);font-size:1.2rem;color:var(--txt);margin-bottom:8px}
.svc-desc{font-size:.8rem;line-height:1.75;color:var(--txt2);margin-bottom:13px}
.svc-foot{display:flex;align-items:center;justify-content:space-between}
.svc-price{font-size:.86rem;color:var(--terra);font-weight:500}
.svc-link{font-size:.62rem;letter-spacing:.13em;text-transform:uppercase;color:var(--sage-d);text-decoration:none;transition:color .3s;display:flex;align-items:center;gap:4px}
.svc-link:hover{color:var(--terra)}
.svc-arrow{display:inline-block;transition:transform .3s}
.svc-card:hover .svc-arrow{transform:translateX(4px)}
/* ── BEFORE / AFTER ── */
.ba-sec{background:var(--stat-bg);padding:100px 60px}
.ba-inner{max-width:920px;margin:0 auto;text-align:center}
.ba-sec .eyebrow{color:var(--terra-l)}
.ba-sec .sec-h{color:#fff}
.ba-sec .body-txt{color:rgba(255,255,255,.5);margin:0 auto;max-width:420px}
.ba-wrap{position:relative;width:100%;aspect-ratio:4/3;border-radius:14px;overflow:hidden;cursor:ew-resize;margin-top:44px;user-select:none;-webkit-user-select:none;touch-action:none}
.ba-after{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;object-position:center top;display:block}
.ba-before-wrap{position:absolute;inset:0;width:50%;overflow:hidden;z-index:2}
.ba-before{position:absolute;top:0;left:0;width:100%;height:100%;object-fit:cover;object-position:center top;display:block;filter:saturate(.3) brightness(.75) contrast(1.15)}
.ba-divider{position:absolute;top:0;bottom:0;width:3px;background:#fff;left:50%;transform:translateX(-50%);z-index:4;pointer-events:none;box-shadow:0 0 12px rgba(0,0,0,.4)}
.ba-handle{position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);width:46px;height:46px;border-radius:50%;background:#fff;z-index:5;display:flex;align-items:center;justify-content:center;box-shadow:0 4px 20px rgba(0,0,0,.5);cursor:ew-resize;pointer-events:none}
.ba-handle svg{width:20px;height:20px}
.ba-lbl{position:absolute;bottom:18px;font-size:.6rem;letter-spacing:.2em;text-transform:uppercase;padding:6px 14px;background:rgba(0,0,0,.5);color:#fff;border-radius:40px;backdrop-filter:blur(6px);font-weight:500;z-index:3}
.ba-lbl.l{left:18px}.ba-lbl.r{right:18px}
.ba-hint{margin-top:16px;font-size:.7rem;color:rgba(255,255,255,.3);letter-spacing:.1em}
/* ── PHILOSOPHY ── */
.phil-grid{display:grid;grid-template-columns:1fr 1.2fr;gap:80px;align-items:center}
.phil-imgs{position:relative;padding-bottom:44px}
.phil-main{width:100%;aspect-ratio:4/5;object-fit:cover;object-position:top;border-radius:14px;display:block}
.phil-float{position:absolute;bottom:0;right:-20px;width:46%;aspect-ratio:1;object-fit:cover;border-radius:10px;border:4px solid var(--bg);box-shadow:0 14px 36px rgba(61,53,48,.15);transition:border-color .4s}
.phil-tag{position:absolute;top:22px;left:-16px;background:var(--terra);color:#fff;padding:14px 18px;border-radius:10px;max-width:195px;box-shadow:0 8px 24px rgba(196,120,90,.28)}
.phil-tag p{font-family:var(--fs);font-size:.88rem;font-style:italic;line-height:1.55}
.phil-tag span{font-size:.52rem;letter-spacing:.16em;text-transform:uppercase;opacity:.72;margin-top:6px;display:block}
.feat-list{display:flex;flex-direction:column;gap:14px;margin-top:26px}
.feat-item{display:flex;gap:13px;align-items:flex-start;padding:14px;border-radius:10px;border:1px solid transparent;transition:all .3s}
.feat-item:hover{border-color:var(--bdr);background:var(--warm)}
.feat-icon{width:34px;height:34px;min-width:34px;border-radius:8px;background:var(--warm);display:flex;align-items:center;justify-content:center;font-size:.85rem;transition:background .3s;color:var(--terra)}
.feat-item:hover .feat-icon{background:var(--terra);color:#fff}
.feat-title{font-size:.75rem;font-weight:500;letter-spacing:.06em;text-transform:uppercase;color:var(--txt);margin-bottom:3px}
.feat-desc{font-size:.8rem;line-height:1.72;color:var(--txt2)}
/* ── PROCESS ── */
.proc-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:2px;margin-top:46px}
.proc-step{background:var(--card-bg);padding:38px 22px;text-align:center;position:relative;transition:all .3s;border:1px solid var(--bdr)}
.proc-step:first-child{border-radius:14px 0 0 14px}
.proc-step:last-child{border-radius:0 14px 14px 0}
.proc-step:hover{background:var(--terra);border-color:var(--terra);transform:translateY(-4px);z-index:1}
.proc-num{width:46px;height:46px;border-radius:50%;border:1px solid var(--bdr);display:flex;align-items:center;justify-content:center;margin:0 auto 16px;font-family:var(--fs);font-size:1.2rem;color:var(--terra);transition:all .3s}
.proc-step:hover .proc-num{border-color:rgba(255,255,255,.5);color:#fff;background:rgba(255,255,255,.15)}
.proc-title{font-family:var(--fs);font-size:1.08rem;color:var(--txt);margin-bottom:8px;transition:color .3s}
.proc-step:hover .proc-title{color:#fff}
.proc-desc{font-size:.76rem;line-height:1.8;color:var(--txt2);transition:color .3s}
.proc-step:hover .proc-desc{color:rgba(255,255,255,.75)}
.proc-arrow{position:absolute;right:-13px;top:50%;transform:translateY(-50%);width:24px;height:24px;border-radius:50%;background:var(--bdr);display:flex;align-items:center;justify-content:center;font-size:.7rem;color:var(--stone-m);z-index:2}
.proc-step:last-child .proc-arrow{display:none}
/* ── TESTIMONIALS ── */
.testi-wrap{background:var(--warm)}
.testi-slider{overflow:hidden;margin-top:46px}
.testi-track{display:flex;gap:18px;transition:transform .5s cubic-bezier(.4,0,.2,1)}
.testi-card{background:var(--card-bg);padding:30px 26px;border-radius:14px;border:1px solid var(--bdr);min-width:calc(33.33% - 12px);flex-shrink:0;transition:all .3s;position:relative}
.testi-card::before{content:'"';font-family:var(--fs);font-size:5rem;color:var(--terra);opacity:.08;position:absolute;top:-10px;left:18px;line-height:1}
.testi-card:hover{border-color:var(--terra-l);transform:translateY(-4px);box-shadow:0 14px 42px rgba(61,53,48,.07)}
[data-theme="dark"] .testi-card:hover{box-shadow:0 14px 42px rgba(0,0,0,.35)}
.stars{color:var(--terra);font-size:.78rem;letter-spacing:2px;margin-bottom:13px}
.testi-txt{font-family:var(--fs);font-size:.98rem;font-style:italic;color:var(--txt);line-height:1.72;margin-bottom:16px}
.testi-auth{font-size:.62rem;letter-spacing:.16em;text-transform:uppercase;color:var(--stone-l)}
.testi-nav{display:flex;gap:10px;justify-content:center;margin-top:14px}
.testi-btn{width:36px;height:36px;border-radius:50%;border:1px solid var(--bdr);background:transparent;color:var(--txt2);cursor:pointer;display:flex;align-items:center;justify-content:center;transition:all .3s;font-size:.78rem}
.testi-btn:hover{border-color:var(--terra);color:var(--terra)}
.testi-dots{display:flex;gap:7px;justify-content:center;margin-top:10px}
.testi-dot{width:7px;height:7px;border-radius:50%;background:var(--bdr);border:none;cursor:pointer;transition:all .3s;padding:0}
.testi-dot.active{background:var(--terra);width:22px;border-radius:4px}
/* ── FOOTER ── */
footer{background:var(--stone);padding:62px 60px 32px}
[data-theme="dark"] footer{background:#0a0806}
.foot-grid{display:grid;grid-template-columns:2fr 1fr 1fr 1fr;gap:48px;margin-bottom:48px}
.f-logo-wrap{display:flex;align-items:center;gap:10px;margin-bottom:14px}
.f-logo-svg{width:40px;height:40px;flex-shrink:0}
.f-logo-line1{font-family:var(--fs);font-size:1rem;color:#fff;display:block;letter-spacing:.04em}
.f-logo-line2{font-size:.4rem;letter-spacing:.28em;text-transform:uppercase;color:rgba(255,255,255,.38)}
.f-p{font-size:.78rem;line-height:1.85;color:rgba(255,255,255,.38);max-width:250px}
.f-col h4{font-size:.56rem;letter-spacing:.26em;text-transform:uppercase;color:var(--terra-l);margin-bottom:16px;font-weight:500}
.f-col a{display:block;font-size:.78rem;color:rgba(255,255,255,.38);text-decoration:none;margin-bottom:8px;transition:color .3s}
.f-col a:hover{color:#fff}
.soc-row{display:flex;gap:9px;margin-top:18px}
.soc-btn{width:30px;height:30px;border:1px solid rgba(255,255,255,.14);border-radius:50%;display:flex;align-items:center;justify-content:center;color:rgba(255,255,255,.38);font-size:.62rem;text-decoration:none;transition:all .3s}
.soc-btn:hover{border-color:var(--terra);color:var(--terra)}
.foot-btm{border-top:1px solid rgba(255,255,255,.07);padding-top:22px;display:flex;justify-content:space-between;flex-wrap:wrap;gap:10px}
.foot-btm p{font-size:.66rem;color:rgba(255,255,255,.26);letter-spacing:.06em}
/* ── STICKY + FAB ── */
.sticky-bar{position:fixed;bottom:0;left:0;right:0;z-index:899;background:var(--stone);padding:13px 60px;display:flex;align-items:center;justify-content:space-between;transform:translateY(100%);transition:transform .4s;box-shadow:0 -4px 30px rgba(0,0,0,.22)}
[data-theme="dark"] .sticky-bar{background:#0a0806}
.sticky-bar.show{transform:translateY(0)}
.sticky-bar p{font-size:.74rem;color:rgba(255,255,255,.6)}
.sticky-bar strong{color:#fff}
.fab{position:fixed;bottom:76px;right:22px;z-index:898;background:var(--terra);color:#fff;width:50px;height:50px;border-radius:50%;display:flex;align-items:center;justify-content:center;text-decoration:none;box-shadow:0 6px 22px rgba(196,120,90,.45);opacity:0;transform:scale(0);transition:all .4s;font-size:.52rem;font-weight:500;text-align:center;letter-spacing:.04em;line-height:1.3;padding:8px}
.fab.show{opacity:1;transform:scale(1)}
.fab:hover{background:var(--terra-d);transform:scale(1.1)!important}
/* ── SCROLL REVEAL ── */
.sr{opacity:0;transform:translateY(30px);transition:opacity .82s cubic-bezier(.2,.6,.3,1),transform .82s cubic-bezier(.2,.6,.3,1)}
.sr.up{opacity:1;transform:none}
.sr-l{opacity:0;transform:translateX(-30px);transition:opacity .82s,transform .82s}
.sr-l.up{opacity:1;transform:none}
.sr-r{opacity:0;transform:translateX(30px);transition:opacity .82s,transform .82s}
.sr-r.up{opacity:1;transform:none}
.d1{transition-delay:.08s}.d2{transition-delay:.16s}.d3{transition-delay:.24s}.d4{transition-delay:.32s}
@keyframes fadeUp{from{opacity:0;transform:translateY(22px)}to{opacity:1;transform:translateY(0)}}
@keyframes fadeIn{from{opacity:0}to{opacity:1}}
@keyframes marquee{from{transform:translateX(0)}to{transform:translateX(-50%)}}
@media(max-width:960px){
  nav,nav.sc{padding:14px 22px}.nav-links{gap:14px}
  .sec{padding:70px 22px}
  .intro-grid,.phil-grid{grid-template-columns:1fr;gap:44px}
  .svc-grid{grid-template-columns:1fr}
  .proc-grid{grid-template-columns:1fr 1fr}.proc-arrow{display:none}
  .stats-inner{grid-template-columns:1fr 1fr}
  .stat-item{border-right:none;border-bottom:1px solid rgba(255,255,255,.08);padding:18px 0}
  .foot-grid{grid-template-columns:1fr 1fr;gap:26px}
  .sticky-bar,.fab{display:none}
  .ba-sec{padding:70px 22px}
  .testi-card{min-width:100%}
  .phil-float,.phil-tag{display:none}
  .hero-badges{display:none}
  .hero-content{padding:0 22px}
  .hero-scroll{left:22px}
}
</style>
</head>
<body>
<div class="cur" id="cur"></div>
<div class="cur-ring" id="curR"></div>
<!-- NAV -->
<nav id="nav">
  <a href="#" class="logo-wrap">
    <svg class="logo-svg" viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg">
      <circle cx="24" cy="24" r="22.5" fill="none" stroke="rgba(255,255,255,0.35)" stroke-width="1"/>
      <circle cx="24" cy="24" r="19" fill="none" stroke="rgba(196,120,90,0.4)" stroke-width="0.5"/>
      <text x="24" y="22" text-anchor="middle" dominant-baseline="middle"
            font-family="Playfair Display,Georgia,serif" font-size="12" font-weight="500"
            fill="#fff" letter-spacing="1.5">__BIZ_INITIALS__</text>
      <line x1="10" y1="26.5" x2="38" y2="26.5" stroke="rgba(196,120,90,0.55)" stroke-width="0.6"/>
      <text x="24" y="33" text-anchor="middle" dominant-baseline="middle"
            font-family="Inter,Arial,sans-serif" font-size="4.2" font-weight="400"
            fill="rgba(255,255,255,0.6)" letter-spacing="2.8">AESTHETICS</text>
    </svg>
    <div class="logo-txt-block">
      <span class="logo-line1">__BIZ_SHORT__</span>
      <span class="logo-line2">Aesthetics · __BIZ_CITY_SHORT__</span>
    </div>
  </a>
  <ul class="nav-links">
    <li><a href="#services">Services</a></li>
    <li><a href="#results">Results</a></li>
    <li><a href="#about">About</a></li>
    <li><a href="#contact">Contact</a></li>
  </ul>
  <div class="nav-r">
    <button class="theme-btn" id="themeBtn" title="Toggle dark/light mode">☾</button>
    <a href="__BOOK_TARGET__" __BOOK_ATTR__ class="nav-book">Book Now</a>
  </div>
</nav>
<!-- HERO -->
<section class="hero">
  <div class="hero-bg" id="heroBg"></div>
  <div class="hero-dim"></div>
  <div class="hero-content">
    <div class="h-pill"><span>__BIZ_CITY_SHORT__ · Est. __BIZ_EST__</span></div>
    <h1 class="h-title">Reveal Your Best Skin.<br><em>Restored &amp; Radiant.</em></h1>
    <p class="h-sub">Advanced facials, chemical peels, and customized skincare plans to support smoother, brighter, healthier-looking skin.</p>
    <div class="h-ctas">
      <a href="__BOOK_TARGET__" __BOOK_ATTR__ class="btn-terra">Book Consultation</a>
      <a href="#services" class="btn-wht">View Services</a>
    </div>
  </div>
  <div class="hero-badges">
    <div class="h-badge"><div class="bn">5★</div><div class="bl">Client care</div></div>
    <div class="h-badge"><div class="bn">Custom</div><div class="bl">Treatment plans</div></div>
    <div class="h-badge"><div class="bn">Expert</div><div class="bl">Estheticians</div></div>
  </div>
  <div class="hero-scroll" onclick="document.getElementById('intro').scrollIntoView({behavior:'smooth'})">
    <div class="hs-line"></div><span class="hs-txt">Scroll to explore</span>
  </div>
</section>
<!-- MARQUEE -->
<div class="mq"><div class="mq-track">
  <span>Signature Facials</span><span>Chemical Peels</span><span>Microneedling</span>
  <span>Anti-Aging</span><span>Skin Brightening</span><span>Hydration Therapy</span>
  <span>Acne Solutions</span><span>LED Light Therapy</span><span>Dermaplaning</span>
  <span>Signature Facials</span><span>Chemical Peels</span><span>Microneedling</span>
  <span>Anti-Aging</span><span>Skin Brightening</span><span>Hydration Therapy</span>
  <span>Acne Solutions</span><span>LED Light Therapy</span><span>Dermaplaning</span>
</div></div>
<!-- INTRO -->
<div style="background:var(--surf)" id="intro">
<div class="sec"><div class="inner">
  <div class="intro-grid">
    <div class="img-wrap sr-l">
      <img class="real-img" src="https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=800&q=80" alt="Client facial treatment" loading="lazy"/>
      <div class="float-badge"><span class="bn">5★</span><span class="bl">Rated<br>Studio</span></div>
    </div>
    <div class="sr-r" id="about">
      <p class="eyebrow">Our Philosophy</p>
      <h2 class="sec-h">Where <em>Science</em><br>Meets Skincare</h2>
      <div class="divider"></div>
      <p class="body-txt">We recognize the profound impact skin health has on confidence and well-being. Our team blends clinical expertise with personalized care — addressing everything from inflammation and aging to uneven tone and loss of radiance.</p>
      <ul class="check-list">
        <li>Personalized skin consultation for every client</li>
        <li>Premium medical-grade products and techniques</li>
        <li>Results-driven protocols backed by science</li>
        <li>Located in __BIZ_CITY_SHORT__</li>
      </ul>
      <a href="__BOOK_TARGET__" __BOOK_ATTR__ class="btn-terra" style="margin-top:30px">Begin Your Journey</a>
    </div>
  </div>
</div></div></div>
<!-- STATS -->
<div class="stats-band"><div class="stats-inner">
  <div class="stat-item sr d1"><div class="stat-n" data-target="500">0</div><div class="stat-l">Happy Clients</div></div>
  <div class="stat-item sr d2"><div class="stat-n" data-target="15">0</div><div class="stat-l">Treatments Offered</div></div>
  <div class="stat-item sr d3"><div class="stat-n" data-target="100">0</div><div class="stat-l">Custom Protocols %</div></div>
  <div class="stat-item sr d4"><div class="stat-n" data-target="5">0</div><div class="stat-l">Star Rating</div></div>
</div></div>
<!-- SERVICES -->
<div class="svc-wrap sec" id="services"><div class="inner" style="text-align:center">
  <p class="eyebrow sr">What We Offer</p>
  <h2 class="sec-h sr" style="margin:0 auto;max-width:500px">Treatments Tailored to <em>Your Skin Goals</em></h2>
  <div class="svc-grid sr">
    <div class="svc-card"><img class="svc-img" src="https://images.unsplash.com/photo-1552693673-1bf958298935?auto=format&fit=crop&w=800&q=80" alt="Facial" loading="lazy"/><div class="svc-body"><div class="svc-cat">Facial</div><h3 class="svc-name">Signature Facial</h3><p class="svc-desc">Personalized around your skin goals, hydration needs, and current concerns.</p><div class="svc-foot"><span class="svc-price">From $120</span><a href="__BOOK_TARGET__" __BOOK_ATTR__ class="svc-link">Book now <span class="svc-arrow">→</span></a></div></div></div>
    <div class="svc-card"><img class="svc-img" src="https://images.unsplash.com/photo-1519824145371-296894a0daa9?auto=format&fit=crop&w=800&q=80" alt="Chemical Peel" loading="lazy"/><div class="svc-body"><div class="svc-cat">Resurfacing</div><h3 class="svc-name">Chemical Peel</h3><p class="svc-desc">Refresh dull, uneven skin tone with a customized resurfacing treatment.</p><div class="svc-foot"><span class="svc-price">From $145</span><a href="__BOOK_TARGET__" __BOOK_ATTR__ class="svc-link">Book now <span class="svc-arrow">→</span></a></div></div></div>
    <div class="svc-card"><img class="svc-img" src="https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?auto=format&fit=crop&w=800&q=80" alt="Microneedling" loading="lazy"/><div class="svc-body"><div class="svc-cat">Collagen</div><h3 class="svc-name">Microneedling</h3><p class="svc-desc">Stimulate collagen, soften texture, and support smoother, firmer skin.</p><div class="svc-foot"><span class="svc-price">From $225</span><a href="__BOOK_TARGET__" __BOOK_ATTR__ class="svc-link">Book now <span class="svc-arrow">→</span></a></div></div></div>
    <div class="svc-card"><img class="svc-img" src="https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=800&q=80" alt="Acne" loading="lazy"/><div class="svc-body"><div class="svc-cat">Acne</div><h3 class="svc-name">Acne Treatment</h3><p class="svc-desc">Target congestion, inflammation, and breakouts with a tailored plan.</p><div class="svc-foot"><span class="svc-price">From $135</span><a href="__BOOK_TARGET__" __BOOK_ATTR__ class="svc-link">Book now <span class="svc-arrow">→</span></a></div></div></div>
    <div class="svc-card"><img class="svc-img" src="https://images.unsplash.com/photo-1515377905703-c4788e51af15?auto=format&fit=crop&w=800&q=80" alt="Anti-aging" loading="lazy"/><div class="svc-body"><div class="svc-cat">Anti-Aging</div><h3 class="svc-name">Anti-Aging Protocol</h3><p class="svc-desc">Visibly reduce fine lines, firm skin, and restore youthful luminosity.</p><div class="svc-foot"><span class="svc-price">From $165</span><a href="__BOOK_TARGET__" __BOOK_ATTR__ class="svc-link">Book now <span class="svc-arrow">→</span></a></div></div></div>
    <div class="svc-card"><img class="svc-img" src="https://images.unsplash.com/photo-1552693673-1bf958298935?auto=format&fit=crop&w=800&q=80" alt="LED" loading="lazy" style="filter:hue-rotate(20deg) brightness(.85)"/><div class="svc-body"><div class="svc-cat">Therapy</div><h3 class="svc-name">LED Light Therapy</h3><p class="svc-desc">Calms inflammation, accelerates healing, and stimulates cellular renewal.</p><div class="svc-foot"><span class="svc-price">From $95</span><a href="__BOOK_TARGET__" __BOOK_ATTR__ class="svc-link">Book now <span class="svc-arrow">→</span></a></div></div></div>
  </div>
  <div class="sr" style="margin-top:38px"><a href="__BOOK_TARGET__" __BOOK_ATTR__ class="btn-terra">View All &amp; Book Now</a></div>
</div></div>
<!-- BEFORE / AFTER -->
<div class="ba-sec" id="results">
<div class="ba-inner">
  <p class="eyebrow sr">Real Transformations</p>
  <h2 class="sec-h sr">See the <em>Difference</em> We Make</h2>
  <p class="body-txt sr">Drag the handle left and right to reveal the skin transformation.</p>
  <div class="ba-wrap sr" id="baWrap">
    <img class="ba-after" id="baAfterImg" src="https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=1400&q=80" alt="After treatment" draggable="false"/>
    <div class="ba-before-wrap" id="baBeforeWrap">
      <img class="ba-before" id="baBeforeImg" src="https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=1400&q=80" alt="Before treatment" draggable="false"/>
    </div>
    <div class="ba-lbl l">Before</div>
    <div class="ba-lbl r">After</div>
    <div class="ba-divider" id="baDivider"></div>
    <div class="ba-handle" id="baHandle">
      <svg viewBox="0 0 24 24" fill="none" stroke="#3d3530" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
        <path d="M9 18l-6-6 6-6"/><path d="M15 6l6 6-6 6"/>
      </svg>
    </div>
  </div>
  <p class="ba-hint">← Drag handle to compare before &amp; after →</p>
</div>
</div>
<!-- PHILOSOPHY -->
<div style="background:var(--surf)" class="sec">
<div class="inner">
  <div class="phil-grid">
    <div class="sr-l">
      <div class="phil-imgs">
        <img class="phil-main" src="https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=800&q=80" alt="Esthetician" loading="lazy"/>
        <img class="phil-float" src="https://images.unsplash.com/photo-1519824145371-296894a0daa9?auto=format&fit=crop&w=600&q=80" alt="Consultation" loading="lazy"/>
        <div class="phil-tag">
          <p>"Embrace a newfound confidence in your skin."</p>
          <span>— __BIZ_NAME__</span>
        </div>
      </div>
    </div>
    <div class="sr-r">
      <p class="eyebrow">Our Promise</p>
      <h2 class="sec-h">A Calm, Elevated Approach to <em>Skincare</em></h2>
      <div class="divider"></div>
      <p class="body-txt">__BIZ_NAME__ blends relaxation, education, and real skin support. Every appointment is personalized so your skin goals stay at the center of your care — from the first consultation forward.</p>
      <div class="feat-list">
        <div class="feat-item"><div class="feat-icon">✓</div><div><div class="feat-title">Customized Care</div><div class="feat-desc">Recommendations based on your unique skin condition, concerns, and goals.</div></div></div>
        <div class="feat-item"><div class="feat-icon">→</div><div><div class="feat-title">Simple Next Steps</div><div class="feat-desc">Clear homecare guidance so results continue between appointments.</div></div></div>
        <div class="feat-item"><div class="feat-icon">★</div><div><div class="feat-title">Premium Products</div><div class="feat-desc">Professional-grade formulations curated for maximum real-world results.</div></div></div>
      </div>
    </div>
  </div>
</div></div>
<!-- PROCESS -->
<div class="sec" style="background:var(--warm);text-align:center"><div class="inner">
  <p class="eyebrow sr">How It Works</p>
  <h2 class="sec-h sr" style="margin:0 auto;max-width:430px">Your Journey to <em>Radiant Skin</em></h2>
  <div class="proc-grid sr">
    <div class="proc-step"><div class="proc-num">1</div><h3 class="proc-title">Consultation</h3><p class="proc-desc">We assess your skin history and goals to craft the perfect plan.</p><div class="proc-arrow">→</div></div>
    <div class="proc-step"><div class="proc-num">2</div><h3 class="proc-title">Custom Protocol</h3><p class="proc-desc">Your treatment is designed using best-in-class techniques.</p><div class="proc-arrow">→</div></div>
    <div class="proc-step"><div class="proc-num">3</div><h3 class="proc-title">Treatment</h3><p class="proc-desc">Experience your session in a relaxing results-driven environment.</p><div class="proc-arrow">→</div></div>
    <div class="proc-step"><div class="proc-num">4</div><h3 class="proc-title">Aftercare</h3><p class="proc-desc">We provide a home-care plan to maintain your glow long-term.</p><div class="proc-arrow">→</div></div>
  </div>
</div></div>
<!-- TESTIMONIALS -->
<div class="testi-wrap sec"><div class="inner" style="text-align:center">
  <p class="eyebrow sr">Client Love</p>
  <h2 class="sec-h sr" style="margin:0 auto">Why Clients <em>Keep Coming Back</em></h2>
  <div class="testi-slider sr"><div class="testi-track" id="testiTrack">
    <div class="testi-card"><div class="stars">★★★★★</div><p class="testi-txt">"My skin looked brighter after my first visit, and the treatment plan made everything feel simple and personalized."</p><p class="testi-auth">— Maria T.</p></div>
    <div class="testi-card"><div class="stars">★★★★★</div><p class="testi-txt">"Clean, calming space and real results. I finally found treatments that feel both relaxing and effective."</p><p class="testi-auth">— Jennifer K.</p></div>
    <div class="testi-card"><div class="stars">★★★★★</div><p class="testi-txt">"The consultation was thorough, and I felt confident knowing exactly what my skin needed next."</p><p class="testi-auth">— Aisha R.</p></div>
    <div class="testi-card"><div class="stars">★★★★★</div><p class="testi-txt">"I've tried so many facials but nothing compares. They address the root cause, not just symptoms."</p><p class="testi-auth">— Diana M.</p></div>
    <div class="testi-card"><div class="stars">★★★★★</div><p class="testi-txt">"My skin texture improved dramatically. The estheticians explain every step. Love this place!"</p><p class="testi-auth">— Priya S.</p></div>
  </div></div>
  <div class="testi-nav"><button class="testi-btn" id="tPrev">←</button><button class="testi-btn" id="tNext">→</button></div>
  <div class="testi-dots" id="testiDots"></div>
</div></div>
<!-- FOOTER -->
<footer id="contact">
<div class="foot-grid">
  <div>
    <div class="f-logo-wrap">
      <svg class="f-logo-svg" viewBox="0 0 40 40" xmlns="http://www.w3.org/2000/svg">
        <circle cx="20" cy="20" r="18.5" fill="none" stroke="rgba(196,120,90,0.4)" stroke-width="1"/>
        <text x="20" y="19" text-anchor="middle" dominant-baseline="middle"
              font-family="Playfair Display,Georgia,serif" font-size="10" font-weight="500"
              fill="#fff" letter-spacing="1.2">__BIZ_INITIALS__</text>
        <line x1="9" y1="23" x2="31" y2="23" stroke="rgba(196,120,90,0.5)" stroke-width="0.6"/>
        <text x="20" y="29" text-anchor="middle" dominant-baseline="middle"
              font-family="Inter,Arial,sans-serif" font-size="3.5" font-weight="400"
              fill="rgba(255,255,255,0.45)" letter-spacing="2.4">AESTHETICS</text>
      </svg>
      <div><span class="f-logo-line1">__BIZ_SHORT__</span><span class="f-logo-line2">Aesthetics</span></div>
    </div>
    <p class="f-p">Your destination for expert skincare in __BIZ_CITY_SHORT__. Personalized treatments. Lasting results.</p>
    <div class="soc-row"><a href="#" class="soc-btn">ig</a><a href="#" class="soc-btn">fb</a><a href="#" class="soc-btn">tt</a></div>
  </div>
  <div class="f-col"><h4>Services</h4>
    <a href="__BOOK_TARGET__" __BOOK_ATTR__>Signature Facials</a>
    <a href="__BOOK_TARGET__" __BOOK_ATTR__>Chemical Peels</a>
    <a href="__BOOK_TARGET__" __BOOK_ATTR__>Microneedling</a>
    <a href="__BOOK_TARGET__" __BOOK_ATTR__>LED Therapy</a>
    <a href="__BOOK_TARGET__" __BOOK_ATTR__>Acne Treatments</a>
  </div>
  <div class="f-col"><h4>Studio</h4>
    <a href="#about">About Us</a>
    <a href="#services">Our Services</a>
    <a href="#results">Before &amp; After</a>
    <a href="#contact">Contact</a>
  </div>
  <div class="f-col"><h4>Visit Us</h4>
    <a href="__MAPS_URL__" target="_blank">__BIZ_ADDRESS__</a>
    <a href="tel:__BIZ_PHONE_RAW__">__BIZ_PHONE__</a>
    <a href="mailto:__BIZ_EMAIL__">__BIZ_EMAIL__</a>
    <a href="#">__BIZ_HOURS__</a>
  </div>
</div>
<div class="foot-btm">
  <p>© __COPYRIGHT_YEAR__ __BIZ_NAME__ · All rights reserved</p>
  <p>Privacy Policy · Terms of Service</p>
</div>
</footer>
<div class="sticky-bar" id="stickyBar">
  <p><strong>Ready to glow?</strong> — __BIZ_NAME__ · __BIZ_CITY_SHORT__</p>
  <a href="__BOOK_TARGET__" __BOOK_ATTR__ class="btn-terra" style="padding:9px 20px;font-size:.66rem">Book Now</a>
</div>
<a href="__BOOK_TARGET__" __BOOK_ATTR__ class="fab" id="fab">Book</a>
<script>
// DARK / LIGHT THEME
const html=document.documentElement,themeBtn=document.getElementById('themeBtn');
let isDark=false;
function setTheme(d){isDark=d;html.setAttribute('data-theme',d?'dark':'light');themeBtn.textContent=d?'☀':'☾';themeBtn.title=d?'Switch to light mode':'Switch to dark mode';}
themeBtn.onclick=()=>setTheme(!isDark);
// CURSOR
const cur=document.getElementById('cur'),curR=document.getElementById('curR');
let mx=0,my=0,rx=0,ry=0;
document.addEventListener('mousemove',e=>{mx=e.clientX;my=e.clientY;cur.style.left=mx+'px';cur.style.top=my+'px';});
(function animR(){rx+=(mx-rx)*.12;ry+=(my-ry)*.12;curR.style.left=rx+'px';curR.style.top=ry+'px';requestAnimationFrame(animR);})();
document.querySelectorAll('a,button,.svc-card,.testi-card,.feat-item,.proc-step').forEach(el=>{
  el.addEventListener('mouseenter',()=>curR.classList.add('hov'));
  el.addEventListener('mouseleave',()=>curR.classList.remove('hov'));
});
// HERO
window.addEventListener('load',()=>document.getElementById('heroBg').classList.add('loaded'));
// NAV + STICKY
const nav=document.getElementById('nav'),sticky=document.getElementById('stickyBar'),fab=document.getElementById('fab');
window.addEventListener('scroll',()=>{
  const y=scrollY;
  nav.classList.toggle('sc',y>60);
  sticky.classList.toggle('show',y>600);
  fab.style.opacity=y>600?'1':'0';
  fab.style.transform=y>600?'scale(1)':'scale(0)';
});
// SCROLL REVEAL
const io=new IntersectionObserver(e=>{e.forEach(x=>{if(x.isIntersecting){x.target.classList.add('up');io.unobserve(x.target);}});},{threshold:.1});
document.querySelectorAll('.sr,.sr-l,.sr-r').forEach(el=>io.observe(el));
// COUNTERS
const cio=new IntersectionObserver(e=>{
  e.forEach(x=>{
    if(x.isIntersecting){
      const el=x.target.querySelector('[data-target]');
      if(el){const t=+el.dataset.target,sfx=t===5?'★':t===100?'%':'+';let c=0;
        const ti=setInterval(()=>{c=Math.min(c+t/55,t);el.textContent=Math.floor(c)+(c>=t?sfx:'');if(c>=t)clearInterval(ti);},20);}
      cio.unobserve(x.target);
    }
  });
},{threshold:.3});
document.querySelectorAll('.stat-item').forEach(el=>cio.observe(el));
// BEFORE / AFTER SLIDER
(function(){
  const wrap=document.getElementById('baWrap'),bWrap=document.getElementById('baBeforeWrap'),
        bImg=document.getElementById('baBeforeImg'),div=document.getElementById('baDivider'),
        hdl=document.getElementById('baHandle');
  let pct=50,drag=false;
  function upd(p){pct=Math.max(2,Math.min(98,p));bWrap.style.width=pct+'%';bImg.style.width=wrap.offsetWidth+'px';div.style.left=pct+'%';hdl.style.left=pct+'%';}
  window.addEventListener('resize',()=>upd(pct));
  const img=document.getElementById('baAfterImg');
  if(img.complete)upd(50);else img.addEventListener('load',()=>upd(50));
  function gx(e){return e.touches?e.touches[0].clientX:e.clientX;}
  wrap.addEventListener('mousedown',e=>{drag=true;const r=wrap.getBoundingClientRect();upd((gx(e)-r.left)/r.width*100);e.preventDefault();});
  wrap.addEventListener('touchstart',e=>{drag=true;const r=wrap.getBoundingClientRect();upd((gx(e)-r.left)/r.width*100);},{passive:true});
  window.addEventListener('mousemove',e=>{if(!drag)return;const r=wrap.getBoundingClientRect();upd((gx(e)-r.left)/r.width*100);});
  window.addEventListener('touchmove',e=>{if(!drag)return;const r=wrap.getBoundingClientRect();upd((gx(e)-r.left)/r.width*100);},{passive:true});
  window.addEventListener('mouseup',()=>drag=false);
  window.addEventListener('touchend',()=>drag=false);
  wrap.setAttribute('tabindex','0');
  wrap.addEventListener('keydown',e=>{if(e.key==='ArrowLeft')upd(pct-3);if(e.key==='ArrowRight')upd(pct+3);});
})();
// TESTIMONIAL SLIDER
(function(){
  const track=document.getElementById('testiTrack'),dotsEl=document.getElementById('testiDots');
  const cards=track.querySelectorAll('.testi-card'),vis=window.innerWidth<960?1:3,maxI=cards.length-vis;
  let idx=0;
  cards.forEach((_,i)=>{if(i>maxI)return;const d=document.createElement('button');d.className='testi-dot'+(i===0?' active':'');d.onclick=()=>go(i);dotsEl.appendChild(d);});
  function go(i){idx=Math.max(0,Math.min(maxI,i));const w=cards[0].offsetWidth+18;track.style.transform=`translateX(-${idx*w}px)`;dotsEl.querySelectorAll('.testi-dot').forEach((d,j)=>d.classList.toggle('active',j===idx));}
  document.getElementById('tPrev').onclick=()=>go(idx-1);
  document.getElementById('tNext').onclick=()=>go(idx+1);
  let auto=setInterval(()=>go(idx>=maxI?0:idx+1),4800);
  track.addEventListener('mouseenter',()=>clearInterval(auto));
  track.addEventListener('mouseleave',()=>{auto=setInterval(()=>go(idx>=maxI?0:idx+1),4800);});
})();
</script>
</body>
</html>
HTMLEOF

# ── Replace all placeholders with actual values ───────────────────
info "Injecting business data into HTML..."

# Escape special characters for sed
_esc() { echo "$1" | sed 's/[&/\]/\\&/g'; }

sed -i \
  -e "s|__BIZ_NAME__|$(_esc "$BIZ_NAME")|g" \
  -e "s|__BIZ_SHORT__|$(_esc "$BIZ_SHORT")|g" \
  -e "s|__BIZ_INITIALS__|$(_esc "$BIZ_INITIALS")|g" \
  -e "s|__BIZ_CITY__|$(_esc "$BIZ_CITY")|g" \
  -e "s|__BIZ_CITY_SHORT__|$(_esc "$BIZ_CITY_SHORT")|g" \
  -e "s|__BIZ_EST__|$(_esc "$BIZ_EST")|g" \
  -e "s|__BIZ_ADDRESS__|$(_esc "$BIZ_ADDRESS")|g" \
  -e "s|__BIZ_PHONE__|$(_esc "$BIZ_PHONE")|g" \
  -e "s|__BIZ_PHONE_RAW__|$(_esc "$BIZ_PHONE_RAW")|g" \
  -e "s|__BIZ_EMAIL__|$(_esc "$BIZ_EMAIL")|g" \
  -e "s|__BIZ_HOURS__|$(_esc "$BIZ_HOURS")|g" \
  -e "s|__BOOK_TARGET__|$(_esc "$BOOK_TARGET")|g" \
  -e "s|__BOOK_ATTR__|$(_esc "$BOOK_ATTR")|g" \
  -e "s|__MAPS_URL__|$(_esc "$MAPS_URL")|g" \
  -e "s|__COPYRIGHT_YEAR__|$(_esc "$COPYRIGHT_YEAR")|g" \
  html/index.html

ok "index.html written — $(wc -c < html/index.html) bytes"

# ================================================================
#   PHASE 2 — nginx.conf
# ================================================================
phase "PHASE 2 — nginx.conf"

cat > nginx.conf << 'NGINXEOF'
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    gzip on;
    gzip_types text/html text/css application/javascript image/svg+xml;
    gzip_min_length 1024;

    location ~* \.(css|js|svg|png|jpg|jpeg|gif|ico|woff2?)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location / {
        try_files $uri $uri/ /index.html;
    }

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
    add_header Referrer-Policy "strict-origin-when-cross-origin";
}
NGINXEOF
ok "nginx.conf written"

# ================================================================
#   PHASE 3 — docker-compose.yml
# ================================================================
phase "PHASE 3 — docker-compose.yml"

cat > docker-compose.yml << EOF
services:
  ${CONTAINER_NAME}:
    image: nginx:alpine
    container_name: ${CONTAINER_NAME}
    restart: unless-stopped
    volumes:
      - ./html:/usr/share/nginx/html:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    expose:
      - "80"
    networks:
      - npm_net
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:80"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

networks:
  npm_net:
    external: true
    name: ${NPM_NETWORK}
EOF

docker compose config > /dev/null 2>&1 || err "docker-compose.yml validation failed."
ok "docker-compose.yml written and validated"

# ================================================================
#   PHASE 4 — Launch container
# ================================================================
phase "PHASE 4 — Starting Container"

docker compose up -d
ok "Container started"

info "Waiting for site to come up (up to 30s)..."
for i in $(seq 1 6); do
  sleep 5
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80 2>/dev/null)
  if [ "$STATUS" = "200" ]; then
    ok "Site is UP! (HTTP $STATUS)"
    break
  else
    echo "  ⏳ Still starting... ($((i*5))s)"
  fi
done

# ================================================================
#   FINAL SUMMARY
# ================================================================
clear
echo -e "${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║                                                        ║"
echo "  ║   SITE DEPLOYED SUCCESSFULLY!                          ║"
echo "  ║                                                        ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${BOLD}  Business:${NC}    $BIZ_NAME"
echo -e "${BOLD}  Location:${NC}    $BIZ_CITY_SHORT"
echo -e "${BOLD}  Container:${NC}   $CONTAINER_NAME  (nginx:alpine)"
echo -e "${BOLD}  Site folder:${NC} ~/$SITE_FOLDER"
echo -e "${BOLD}  Network:${NC}     $NPM_NETWORK"
echo
echo -e "${BOLD}${YELLOW}  NEXT STEP — Add this proxy host in NPM:${NC}"
echo
echo "  1. Open NPM admin panel"
echo "  2. Proxy Hosts → Add Proxy Host"
echo -e "     Domain:           ${CYAN}$SITE_SUB${NC}"
echo    "     Scheme:           http"
echo -e "     Forward Hostname: ${CYAN}$CONTAINER_NAME${NC}"
echo    "     Forward Port:     80"
echo    "     WebSocket:        ON"
echo    "     SSL Tab:          Request Let's Encrypt cert"
echo    "                       Force SSL ON · HTTP/2 ON · Block Exploits ON"
echo
echo -e "  3. Visit: ${GREEN}https://$SITE_SUB${NC}"
echo
echo -e "${BOLD}  Log file:${NC} $LOGFILE"
echo
