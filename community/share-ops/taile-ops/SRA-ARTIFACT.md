# SRA Site — Artifact
## The Complete Technical Blueprint

> This is the full record of how the Aesthetics Studio site was built —
> every design decision, every technical choice, every file, every config.
> Use this as the source of truth when modifying or re-deploying the site.

---

## Origin Story

The Skin Restoration Aesthetics (SRA) site started as a hardcoded static HTML file (`sra_v2_enhanced4.html`) built for `skin.ulyhome.cloud`. It was a 811-line single-file HTML site with a luxury aesthetics design.

When a co-worker wanted to deploy the same site for their own aesthetics business, we:

1. Extracted all hardcoded business data into `__PLACEHOLDER__` tokens
2. Wrote a generalized bash installer (`sra-skin-install.sh`) that prompts for all business information
3. Auto-generates the monogram from the business name
4. Builds the nginx config and docker-compose.yml
5. Launches the container and connects to the existing NPM stack

The installer is designed to run **after** `vps-community-install.sh` has already set up NPM and the `npm_default` Docker network.

---

## Infrastructure

### Server Path

```
~/skin/
├── html/
│   └── index.html          ← complete website (single HTML file)
├── nginx.conf              ← nginx configuration
└── docker-compose.yml      ← Docker stack definition
```

### Container

```yaml
services:
  skin-site:
    image: nginx:alpine
    container_name: skin-site      # customizable via installer prompt
    restart: unless-stopped
    expose:
      - "80"
    volumes:
      - ./html:/usr/share/nginx/html:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    networks:
      - npm_net

networks:
  npm_net:
    external: true
    name: npm_default
```

**Why nginx:alpine?** Smallest possible footprint for a static file server. No PHP, no Node, no database. The entire site is pre-rendered HTML+CSS+JS.

**Why `expose:` not `ports:`?** Security. The container is only reachable through NPM. No direct internet access.

### NPM Proxy Host Settings

| Field | Value |
|-------|-------|
| Domain Names | `skin.yourdomain.com` |
| Scheme | `http` |
| Forward Hostname/IP | `skin-site` (container name) |
| Forward Port | `80` |
| Cache Assets | Off |
| Block Common Exploits | On |
| Websockets Support | Off |
| SSL Certificate | Let's Encrypt — new cert for `skin.yourdomain.com` |
| Force SSL | On |
| HTTP/2 Support | On |

### nginx.conf (Complete)

```nginx
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # Compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript
               application/x-javascript application/xml application/json
               application/javascript image/svg+xml;

    # Cache static assets 30 days
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2|ttf|svg|eot)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # SPA fallback
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

---

## Installer: sra-skin-install.sh

### What It Does

1. Verifies running as non-root
2. Detects NPM Docker network (`npm_default`, `proxy`, or `nginx-proxy-manager_default`)
3. Wizard: collects 14+ business inputs with defaults
4. Auto-generates monogram from business name (up to 3 initials)
5. Builds Google Maps URL from address
6. Strips phone number to raw digits for `tel:` links
7. Writes full HTML with `__PLACEHOLDER__` tokens (quoted heredoc, no bash expansion)
8. Runs `sed -i` to replace all placeholders (values escaped first via `_esc()`)
9. Writes `nginx.conf` and `docker-compose.yml`
10. Runs `docker compose up -d`
11. Health checks: `curl -s -o /dev/null -w "%{http_code}"` → expects `200`
12. Prints NPM setup instructions with exact values

### Escape Function

All user input is escaped before passing to `sed -i`:

```bash
_esc() { echo "$1" | sed 's/[&/\]/\\&/g'; }
```

Covers `/`, `&`, and `\` which would break `sed` substitution.

### Monogram Generation

```bash
BIZ_INITIALS=$(echo "$BIZ_NAME" | awk '{for(i=1;i<=NF&&i<=3;i++) printf substr($i,1,1)}' | tr '[:lower:]' '[:upper:]')
```

- Takes first letter of each word (up to 3 words)
- Uppercases the result
- Examples: "Luxe Skin Studio" → `LSS`, "Glow Med Spa" → `GMS`, "SkinBar" → `S`

### Maps URL

```bash
MAPS_URL="https://maps.google.com/?q=$(echo "$BIZ_ADDRESS" | sed 's/ /+/g')"
```

Replaces spaces with `+` for URL encoding (basic — works for standard addresses).

### Booking URL Logic

```bash
if [[ "$HAS_BOOKING" == "y" ]]; then
  BOOK_TARGET="$BOOKING_URL"
  BOOK_ATTR='target="_blank"'
else
  BOOK_TARGET="#contact"
  BOOK_ATTR=""
fi
```

Both `__BOOK_TARGET__` and `__BOOK_ATTR__` are injected. When no booking URL is provided, all "Book Now" buttons scroll to `#contact` instead of opening an external tab.

### Deploy Command (One-liner)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/OWNER/REPO/main/PATH/sra-skin-install.sh)
```

---

## HTML Architecture

### Document Structure

```html
<!DOCTYPE html>
<html lang="en" data-theme="light">
<head>
  <!-- Google Fonts: Playfair Display + Inter -->
  <!-- All CSS in <style> block -->
</head>
<body>
  <div id="cursor"></div>
  <div id="cursor-ring"></div>

  <nav id="navbar">...</nav>
  <div id="mobile-menu">...</div>

  <section id="hero">...</section>
  <div class="marquee-strip">...</div>
  <section id="intro">...</section>
  <section id="services">...</section>
  <section id="before-after">...</section>
  <section id="philosophy">...</section>
  <section id="about">...</section>         <!-- process steps -->
  <section id="testimonials">...</section>
  <section id="contact">...</section>
  <footer>...</footer>

  <div id="sticky-bar">...</div>            <!-- mobile sticky -->
  <a id="fab" href="tel:__PHONE_RAW__">...</a>  <!-- desktop FAB -->

  <!-- All JS in <script> block at end of body -->
</body>
</html>
```

### CSS Variable System

All design tokens are defined on `:root` and overridden on `[data-theme="dark"]`:

```css
:root {
  --bg: #faf9f7;
  --surface: #ffffff;
  --text: #1a1a1a;
  --accent: #b8860b;
  --accent2: #8b6914;
  --muted: #6b6560;
  --border: rgba(0,0,0,0.08);
  --nav-bg: rgba(250,249,247,0.85);
  --card-shadow: 0 4px 24px rgba(0,0,0,0.08);
}

[data-theme="dark"] {
  --bg: #0e0e0e;
  --surface: #1a1a1a;
  --text: #f0ede8;
  --accent: #d4a017;
  --accent2: #c49010;
  --muted: #9a948e;
  --border: rgba(255,255,255,0.08);
  --nav-bg: rgba(14,14,14,0.85);
  --card-shadow: 0 4px 24px rgba(0,0,0,0.4);
}
```

---

## Detailed Section Reference

### Custom Cursor

**HTML:**
```html
<div id="cursor"></div>
<div id="cursor-ring"></div>
```

**CSS:**
```css
#cursor {
  position: fixed; width: 8px; height: 8px;
  background: var(--accent); border-radius: 50%;
  pointer-events: none; z-index: 9999;
  transform: translate(-50%, -50%);
  transition: transform 0.1s ease, opacity 0.1s ease;
}
#cursor-ring {
  position: fixed; width: 32px; height: 32px;
  border: 1.5px solid var(--accent); border-radius: 50%;
  pointer-events: none; z-index: 9998;
  transform: translate(-50%, -50%);
  transition: width 0.2s, height 0.2s;
}
@media (pointer: coarse) {
  #cursor, #cursor-ring { display: none; }
}
```

**JS (rAF lerp):**
```javascript
let mx = 0, my = 0, rx = 0, ry = 0;
document.addEventListener('mousemove', e => { mx = e.clientX; my = e.clientY; });
(function loop() {
  rx += (mx - rx) * 0.12;
  ry += (my - ry) * 0.12;
  cursor.style.left = mx + 'px';
  cursor.style.top  = my + 'px';
  ring.style.left   = rx + 'px';
  ring.style.top    = ry + 'px';
  requestAnimationFrame(loop);
})();
```

### Dark/Light Theme Toggle

**HTML:** Button `#theme-toggle` with inline SVG moon + sun icons.

**JS:**
```javascript
const savedTheme = localStorage.getItem('theme') ||
  (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
document.documentElement.setAttribute('data-theme', savedTheme);

themeToggle.addEventListener('click', () => {
  const t = document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
  document.documentElement.setAttribute('data-theme', t);
  localStorage.setItem('theme', t);
});
```

### SVG Monogram Logo

The logo is an inline SVG with two concentric circles and centered initials text:

```html
<svg width="44" height="44" viewBox="0 0 44 44" class="logo-svg">
  <circle cx="22" cy="22" r="20" fill="none" stroke="currentColor" stroke-width="1.5"/>
  <circle cx="22" cy="22" r="16" fill="var(--accent)" opacity="0.15"/>
  <text x="22" y="27" text-anchor="middle"
        font-family="Playfair Display, serif"
        font-size="13" font-weight="700"
        fill="var(--accent)">__BIZ_INITIALS__</text>
</svg>
```

### Hero Section

```html
<section id="hero">
  <div class="hero-bg" style="background-image:url('https://images.unsplash.com/...')"></div>
  <div class="hero-overlay"></div>
  <div class="hero-content reveal">
    <p class="hero-eyebrow">__BIZ_CITY_SHORT__ · Est. __BIZ_EST__</p>
    <h1>Your Skin,<br><em>Reimagined.</em></h1>
    <p class="hero-sub">Science-backed treatments...</p>
    <div class="hero-btns">
      <a href="__BOOK_TARGET__" __BOOK_ATTR__ class="btn-primary">Book a Consultation</a>
      <a href="#services" class="btn-secondary">Our Services</a>
    </div>
  </div>
</section>
```

**Hero zoom JS:**
```javascript
window.addEventListener('load', () => {
  document.querySelector('.hero-bg').classList.add('loaded');
});
```

**CSS:**
```css
.hero-bg {
  position: absolute; inset: 0;
  background-size: cover; background-position: center;
  transform: scale(1.03);
  transition: transform 1.5s ease;
}
.hero-bg.loaded { transform: scale(1); }
```

### Marquee Strip

```html
<div class="marquee-strip">
  <div class="marquee-track">
    <!-- Repeated 3× for seamless loop -->
    <span>FACIALS · PEELS · MICRONEEDLING · LASER · BODY CONTOURING · DERMAPLANING · </span>
    ...
  </div>
</div>
```

```css
@keyframes marquee {
  from { transform: translateX(0); }
  to   { transform: translateX(-33.33%); }
}
.marquee-track {
  display: flex; white-space: nowrap;
  animation: marquee 20s linear infinite;
}
```

### Animated Stat Counters

```html
<div class="stat-num" data-target="10">0</div>
<div class="stat-label">Years Experience</div>
```

```javascript
function animateCounter(el) {
  const target = +el.dataset.target;
  let current = 0;
  const step = target / 60;
  const timer = setInterval(() => {
    current = Math.min(current + step, target);
    el.textContent = Math.floor(current) + (target >= 100 ? '+' : '');
    if (current >= target) clearInterval(timer);
  }, 30);
}

const counterObs = new IntersectionObserver((entries) => {
  entries.forEach(e => { if (e.isIntersecting) animateCounter(e.target); });
}, { threshold: 0.5 });
document.querySelectorAll('.stat-num').forEach(el => counterObs.observe(el));
```

### Services Grid (6 Cards)

```html
<section id="services">
  <div class="services-grid">
    <div class="service-card reveal" style="--bg-img:url('https://images.unsplash.com/...')">
      <div class="service-overlay"></div>
      <div class="service-content">
        <div class="service-icon"><!-- SVG --></div>
        <h3>Signature Facials</h3>
        <p>Customized treatments...</p>
        <a href="#contact" class="service-link">Learn More →</a>
      </div>
    </div>
    <!-- × 6 cards -->
  </div>
</section>
```

```css
.service-card {
  background-image: var(--bg-img);
  background-size: cover; background-position: center;
  border-radius: 16px; overflow: hidden;
  position: relative; min-height: 380px;
  transition: transform 0.3s ease;
}
.service-card:hover { transform: translateY(-8px); }
.service-overlay {
  position: absolute; inset: 0;
  background: linear-gradient(to top, rgba(0,0,0,0.85) 0%, rgba(0,0,0,0.3) 60%, transparent 100%);
}
```

Services: Signature Facials, Chemical Peels, Microneedling, Laser Treatments, Body Contouring, Dermaplaning.

### Before/After Slider

**HTML:**
```html
<div id="ba-container">
  <img id="after-img"  src="https://images.unsplash.com/..." alt="After">
  <div id="before-wrap">
    <img id="before-img" src="https://images.unsplash.com/..." alt="Before">
  </div>
  <div id="ba-handle">
    <div class="ba-arrows">◀ ▶</div>
  </div>
</div>
```

**CSS:**
```css
#ba-container {
  position: relative; width: 100%; max-width: 700px;
  aspect-ratio: 4/3; overflow: hidden; border-radius: 16px;
  user-select: none;
}
#after-img {
  position: absolute; inset: 0;
  width: 100%; height: 100%; object-fit: cover;
}
#before-wrap {
  position: absolute; top: 0; left: 0; height: 100%;
  width: 50%; overflow: hidden;    /* <-- CLIP CONTAINER */
}
#before-img {
  position: absolute; top: 0; left: 0;
  height: 100%; object-fit: cover;
  /* width set dynamically via JS */
}
#ba-handle {
  position: absolute; top: 0; bottom: 0;
  left: 50%; width: 3px; background: white;
  cursor: ew-resize; transform: translateX(-50%);
}
```

**JS (critical clip pattern):**
```javascript
let dragging = false;
const wrap = document.getElementById('ba-container');
const beforeWrap = document.getElementById('before-wrap');
const beforeImg = document.getElementById('before-img');
const handle = document.getElementById('ba-handle');

function setSlider(x) {
  const rect = wrap.getBoundingClientRect();
  let pct = ((x - rect.left) / rect.width) * 100;
  pct = Math.min(Math.max(pct, 2), 98);
  beforeWrap.style.width = pct + '%';
  beforeImg.style.width = wrap.offsetWidth + 'px';  // KEY: prevents squish
  handle.style.left = pct + '%';
}

handle.addEventListener('mousedown', () => dragging = true);
document.addEventListener('mouseup', () => dragging = false);
document.addEventListener('mousemove', e => { if (dragging) setSlider(e.clientX); });
handle.addEventListener('touchstart', e => { dragging = true; });
document.addEventListener('touchend', () => dragging = false);
document.addEventListener('touchmove', e => {
  if (dragging) setSlider(e.touches[0].clientX);
});
window.addEventListener('resize', () => {
  beforeImg.style.width = wrap.offsetWidth + 'px';
});
```

### Process Steps (Hover Color Change)

```html
<div class="process-step reveal">
  <div class="step-num">01</div>
  <h3>Consultation</h3>
  <p>We begin with a thorough skin analysis...</p>
</div>
```

```css
.process-step {
  background: var(--surface); border-radius: 16px; padding: 40px 32px;
  transition: background 0.3s ease, transform 0.3s ease;
}
.process-step:hover {
  background: var(--accent);
  transform: translateY(-4px);
}
.process-step:hover .step-num,
.process-step:hover h3,
.process-step:hover p { color: #fff !important; }
```

### Testimonial Carousel

```html
<div class="testimonials-track">
  <div class="testimonial active">
    <div class="stars">★★★★★</div>
    <blockquote>"The microneedling treatment completely transformed..."</blockquote>
    <div class="client-name">Sarah M.</div>
    <div class="client-role">Long-time Client</div>
  </div>
  <!-- × 3 testimonials -->
</div>
<div class="carousel-nav">
  <button class="carousel-prev">←</button>
  <div class="carousel-dots">
    <button class="dot active" data-index="0"></button>
    <button class="dot" data-index="1"></button>
    <button class="dot" data-index="2"></button>
  </div>
  <button class="carousel-next">→</button>
</div>
```

**JS:**
```javascript
let carouselIdx = 0;
let carouselTimer;

function showTestimonial(idx) {
  items.forEach((t, i) => t.classList.toggle('active', i === idx));
  dots.forEach((d, i) => d.classList.toggle('active', i === idx));
  carouselIdx = idx;
}
function nextTestimonial() { showTestimonial((carouselIdx + 1) % items.length); }
function prevTestimonial() { showTestimonial((carouselIdx - 1 + items.length) % items.length); }

function startTimer() { carouselTimer = setInterval(nextTestimonial, 5000); }
function resetTimer() { clearInterval(carouselTimer); startTimer(); }

prevBtn.addEventListener('click', () => { prevTestimonial(); resetTimer(); });
nextBtn.addEventListener('click', () => { nextTestimonial(); resetTimer(); });
dots.forEach((d, i) => d.addEventListener('click', () => { showTestimonial(i); resetTimer(); }));

track.addEventListener('mouseenter', () => clearInterval(carouselTimer));
track.addEventListener('mouseleave', startTimer);

startTimer();
```

**CSS (fade transition):**
```css
.testimonial {
  display: none;
  opacity: 0; transform: translateY(10px);
  transition: opacity 0.4s ease, transform 0.4s ease;
}
.testimonial.active {
  display: block;
  opacity: 1; transform: translateY(0);
}
```

### Scroll Reveal

```css
.reveal {
  opacity: 0;
  transform: translateY(30px);
  transition: opacity 0.7s ease, transform 0.7s ease;
}
.reveal.visible {
  opacity: 1;
  transform: translateY(0);
}
```

```javascript
const revealObs = new IntersectionObserver((entries) => {
  entries.forEach(e => {
    if (e.isIntersecting) {
      e.target.classList.add('visible');
      revealObs.unobserve(e.target);
    }
  });
}, { threshold: 0.1 });
document.querySelectorAll('.reveal').forEach(el => revealObs.observe(el));
```

### FAB (Floating Action Button)

```html
<a id="fab" href="tel:__BIZ_PHONE_RAW__" title="Call Us">
  <!-- Phone SVG icon -->
</a>
```

```css
#fab {
  position: fixed; bottom: 32px; right: 32px;
  width: 56px; height: 56px;
  background: var(--accent); color: white;
  border-radius: 50%; display: flex; align-items: center; justify-content: center;
  box-shadow: 0 4px 20px rgba(0,0,0,0.3);
  z-index: 900; transition: transform 0.2s ease;
}
#fab::after {
  content: ''; position: absolute;
  width: 100%; height: 100%; border-radius: 50%;
  border: 2px solid var(--accent);
  animation: pulse-ring 2s ease-out infinite;
}
@keyframes pulse-ring {
  0%   { transform: scale(1); opacity: 0.8; }
  100% { transform: scale(1.6); opacity: 0; }
}
/* Hide FAB on mobile (sticky bar takes over) */
@media (max-width: 768px) { #fab { display: none; } }
```

### Sticky Bottom Bar (Mobile)

```html
<div id="sticky-bar">
  <a href="tel:__BIZ_PHONE_RAW__" class="sticky-call">📞 Call Us</a>
  <a href="__BOOK_TARGET__" __BOOK_ATTR__ class="sticky-book">Book Now</a>
</div>
```

```css
#sticky-bar {
  position: fixed; bottom: 0; left: 0; right: 0;
  display: none;  /* shown via JS */
  background: var(--surface);
  border-top: 1px solid var(--border);
  padding: 12px 20px; gap: 12px;
  z-index: 800;
}
@media (min-width: 769px) { #sticky-bar { display: none !important; } }
```

```javascript
window.addEventListener('scroll', () => {
  const past = window.scrollY > window.innerHeight * 0.6;
  stickyBar.style.display = past ? 'flex' : 'none';
});
```

---

## Customization Cheat Sheet

### Change Hero Background Image

Find `hero-bg` style attribute in `index.html`. Replace the Unsplash URL:
```html
<div class="hero-bg" style="background-image:url('YOUR_IMAGE_URL_HERE')">
```

### Change Service Card Images

Find each `.service-card` with `--bg-img:url(...)` in the style attribute:
```html
<div class="service-card" style="--bg-img:url('YOUR_IMAGE_URL')">
```

### Add a New Service Card

Copy an existing `.service-card` block and change the title, description, and image. If adding a 7th card, update the grid CSS:
```css
.services-grid { grid-template-columns: repeat(3, 1fr); }
/* becomes: */
.services-grid { grid-template-columns: repeat(4, 1fr); }
```

### Change Accent Color

Edit `:root { --accent: #YOUR_COLOR; }` and `[data-theme="dark"] { --accent: #YOUR_LIGHTER_COLOR; }`.

### Add a New Testimonial

Copy a `.testimonial` block, add a `.dot` button, update the JS `items.length` references.

### Disable Custom Cursor

Remove `#cursor`, `#cursor-ring` HTML and their CSS. Remove the `mousemove` listener and `loop()` function.

---

## Deployment Commands

```bash
# Install (first time)
bash sra-skin-install.sh

# Restart container
cd ~/skin && docker compose restart skin-site

# View logs
cd ~/skin && docker compose logs -f skin-site

# Edit the site
nano ~/skin/html/index.html
# nginx serves files directly from disk — changes take effect immediately (no restart needed)

# Update nginx config (requires restart)
nano ~/skin/nginx.conf
cd ~/skin && docker compose restart skin-site

# Check container network
docker network inspect npm_default --format '{{range .Containers}}{{.Name}}{{"\n"}}{{end}}'

# Fix 502 Bad Gateway
docker network connect npm_default skin-site
```

---

## Quick Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| 502 Bad Gateway | Container not on npm_default | `docker network connect npm_default skin-site` |
| Site not loading after edit | Browser cache | Hard refresh: Ctrl+Shift+R / Cmd+Shift+R |
| Cursor visible on mobile | Missing `@media (pointer: coarse)` CSS | Add `#cursor, #cursor-ring { display: none; }` in media query |
| Before/After slider squishes image | Setting width on `#before-img` directly | Set width on `#before-wrap` (clip container); set `#before-img` width to `wrap.offsetWidth + 'px'` |
| Dark mode sections look broken | New section added without dark mode CSS | Add `[data-theme="dark"] #new-section { ... }` styles |
| SSL cert fails | DNS not propagated | Wait 15–30 min; verify with `dig skin.yourdomain.com` |
| Booking URL opens in same tab | `target="_blank"` missing | Installer only adds this attribute when booking URL is provided |

---

## Changelog

| Date | Change |
|------|--------|
| April 2026 | Initial build — hardcoded HTML for skin.ulyhome.cloud (v2 enhanced4, 811 lines) |
| April 2026 | Generalized into reusable installer — all business data replaced with `__PLACEHOLDER__` tokens; bash wizard collects all inputs; auto-generates monogram |
| April 2026 | Added optional booking URL — if none provided, all CTAs scroll to `#contact` |
| April 2026 | Root guard added — installer exits with guidance if run as root |
| April 2026 | v4 design features — custom cursor, dark mode toggle, animated stat counters, before/after drag slider, testimonial carousel, FAB + sticky mobile bar, scroll reveal, marquee strip |
