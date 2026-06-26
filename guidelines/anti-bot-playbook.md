# Anti‑Bot / Anti‑Scraping / Anti‑Automation Playbook

> **What this is.** A portable, self‑contained field guide for driving logged‑in,
> anti‑bot‑protected web platforms (especially Chinese subscription/data platforms
> like BOSS直聘, 飞瓜, 蝉妈妈) with browser automation **without getting detected or
> burning the account**. It is the distilled result of real mistakes and fixes.
>
> **How to use it.** Read **§0 Pre‑flight checklist** and **§1 Golden rules** BEFORE
> writing or running any automation against a protected site. When something breaks,
> go to **§4 Diagnostic methodology** before concluding "anti‑bot". **§6 Detection
> vectors** and **§7 Tooling** tell you what to fix.
>
> **This file is meant to be shared.** It is provider‑agnostic and project‑agnostic.
> Copy it into any project (or keep one global copy) — nothing here depends on a
> specific repo. See **§9 Adopt this in another project**.
>
> **This file is LIVING.** Every new mistake or win on any anti‑bot platform should
> be folded back in. See **§10 Maintenance** + Changelog.
>
> **Last updated:** 2026‑06‑27

---

## 0. Pre‑flight checklist — do this FIRST, before any risky action

Tick every box before you launch automation against a protected site:

1. **Cheaper/safer source?** Is there an `official_api` > `licensed_feed` you should
   use instead of scraping? Scrape only when higher‑trust sources are exhausted.
   (For *subscription data platforms* the house rule is the opposite for their data:
   **browser‑only, never their private API** — APIs there are rate‑limited and
   trigger anti‑scraping. Drive the rendered DOM like a human.)
2. **Read the platform's own rules / your project's golden rules** for that site.
3. **Pick the right tool for the threat level** (§7). For sophisticated anti‑bot,
   default to **DrissionPage**, not vanilla Playwright/Puppeteer/Selenium.
4. **Browser hygiene — the four that matter most (§6):**
   - Real installed Chrome, **not** bundled Chromium.
   - **No `--enable-automation`** (so `navigator.webdriver` is naturally false).
   - **No `--remote-allow-origins=*`** (keeps web pages from reaching the CDP port).
   - **No CDP `Runtime.enable` leak** (use DrissionPage, or `rebrowser`‑patched
     Playwright). Drop `puppeteer-extra-plugin-stealth` (it adds its own tells).
5. **Instrumentation ready** (§4): a "survival watch" + console/network/navigation
   traps, so the FIRST run is observable and you can tell a *bug* from a *block*.
6. **Human pace + safety rails:** randomized delays, a **cool‑down between runs**,
   one stable logged‑in profile, residential/local IP, **confirm before bulk**,
   **never commit secrets** (profile dir, `.env`, data).
7. **Know your stop condition** (§1.4) and have it coded to **halt, not retry**.

> If you can't tick 1–4, you are not ready to run. Stop and fix the setup first.

---

## 1. Golden rules (operating discipline)

1. **Browser‑only on subscription platforms.** Never call their private/JSON APIs;
   act through the visible DOM exactly like a human analyst.
2. **Human pace, always.** Randomized, varied pauses; natural scrolling; never fire
   actions back‑to‑back at machine speed. Enforce a **minimum gap between runs**
   (a cool‑down) in the one place every run launches through.
3. **Stop on a CONFIRMED hard signal — do not retry.** Captcha/slider, 验证/安全验证,
   "操作过于频繁/访问过于频繁", forced logout, repeated genuine blank/blocked pages,
   odd redirects to a logged‑out page. Halt, alert the human, screenshot, and let a
   person take over **by hand**. Retrying after a real block is the worst thing you
   can do.
4. **But verify it's real before you cry wolf (§4).** Most "logouts" and "blank
   pages" in early development are **your own timing/render bugs**, not the site.
   Distinguish before alarming or stopping.
5. **Confirm before bulk.** Outreach / replies / exports require explicit
   confirmation and should print the count first. Read‑only flows send nothing.
6. **Never commit secrets.** The logged‑in browser profile, cookies, `.env`,
   collected data, and real config are gitignored, always.
7. **Anti‑detection is ongoing engineering, not one‑time.** Sites evolve; keep
   learning and updating this file.

---

## 2. The single most important mental model

> **A protected page often renders FULLY first, then kills itself a few seconds
> later.** Don't trust "it loaded." Watch it for ~30s.

Two failure shapes you will see:

- **Kill‑switch (blank):** page renders, then at ~t+5s some script navigates it to
  `about:blank` (e.g. `window.open('','_self')`) → permanently empty.
- **Bounce (redirect):** page renders, then at ~t+13s it redirects to the
  logged‑out homepage / login wall.

Both are **delayed, detection‑triggered defenses** — the delay means an async
fingerprint check completed and the site reacted. The delay itself is a clue.

A third, totally different shape is **your own bug**:

- **Loading‑state false negative:** you check "am I logged in / is content here?"
  while the SPA still shows a loading placeholder (e.g. `加载中，请稍候`), get a false
  "no", and do something dumb (wait for a QR that isn't needed, capture a blank).

---

## 3. Mistakes we actually made — and the rule each one taught

> These are real. Each cost time. Don't repeat them.

| # | Mistake | What actually happened | Rule learned |
|---|---------|------------------------|--------------|
| M1 | **Cried "anti‑bot logout"** on a valid session | `isLoggedIn()` ran while the SPA showed `加载中，请稍候`; with no logged‑in marker *and* no login wall yet, it returned false → a spurious 10‑min QR wait | **Wait for a definitive ready signal** before judging login/render. Poll for *in / wall / still‑loading*, never decide during "loading". |
| M2 | **Captured/clicked before paint** | 39‑byte blank HTML dumps, all‑white screenshots | Gate every capture/click on a **known content selector being present**, not a fixed sleep or "body non‑empty". |
| M3 | **Redundant `page.goto()` to the same SPA URL** | "navigation interrupted by another navigation to about:blank" crash | If you're already on the target, **don't re‑navigate**. On interrupt, settle + retry once. |
| M4 | **No diagnostics on the failure path** | A 10‑min timeout produced zero evidence (no screenshot/URL/text) | **Instrument the failure moment**: screenshot + URL + body‑text snippet + console + failed requests, *the instant* something looks wrong. |
| M5 | **Reloaded repeatedly when blank** | Each reload just re‑armed the kill‑switch; looked like hammering | **Understand WHY it's blank before retrying.** Blind reload re‑triggers detection and risks a real block. |
| M6 | **Changed several variables, then guessed** | "Real Chrome will fix it" — it didn't, and we'd changed more than one thing | **Change ONE variable, test, attribute cause.** Use a repeatable survival watch as the test harness. |
| M7 | **Trusted a stealth plugin** | `puppeteer-extra-plugin-stealth` emitted a tell‑tale `chrome-extension://invalid/` request; with real Chrome it was also unnecessary | Stealth plugins can **add** fingerprints. Prefer a real browser + structural fixes over piling on evasions. |
| M8 | **Tried to hand‑patch a minified bundle** | `Runtime.enable` lived in `coreBundle.js` (minified) — not safely patchable | Use the **maintained patch/package** (e.g. `rebrowser`) or a tool without the leak; don't hack vendor bundles. |
| M9 | **Treated symptoms as the cause** | Aborted XHRs (`getBossFriendListV2`) looked like the problem; they were just in‑flight requests **aborted by** the page navigating away | Find the **first** cause. Trap the navigation primitive; ignore downstream abort noise. |

---

## 4. Diagnostic methodology — what to look for, in order

When a protected page misbehaves, **instrument before concluding.** Cheap, decisive.

### 4.1 The "survival watch" (always run this first)
Load the target and poll every ~2s for ~30s, logging:
`url`, `document.body.innerHTML.length`, count of a **known content selector**,
and a short `innerText` snippet. Classify the run:
- **SURVIVED** — content selector stays present, URL stays put. ✅
- **BLANKED** — `len → 0` and/or `url → about:blank`. (kill‑switch)
- **REDIRECTED** — URL leaves the app for the homepage/login. (bounce)
- **NEVER‑RENDERED** — stuck on the loading placeholder. (network/soft block, or bug)

### 4.2 Capture the side channels
Attach listeners and dump after the watch:
- `console` messages (esp. errors),
- `pageerror`,
- **failed requests** (`requestfailed`) with method + url + failure text,
- watch for **localhost probes** in failed requests: `127.0.0.1:9222` (CDP port),
  `/json/version`, health pings, etc. → the site is **scanning for an automation
  agent** (a real detection layer).

### 4.3 Trap the navigation primitive (find the kill‑switch trigger)
Before the page's own JS runs, wrap and log a stack for every way a script can
navigate the top frame:
`Location.prototype.assign` / `.replace`, the `Location.prototype.href` setter,
`window.open`, `HTMLFormElement.prototype.submit`. The one that fires (with its
JS stack → the vendor bundle + function) **is** the kill‑switch. By elimination you
learn the exact mechanism (e.g. `window.open('','_self')` from `564.js`).

### 4.4 Decide: bug vs benign vs block
- Recovers within a couple seconds of waiting → **your render‑timing bug** (M1/M2).
- Only an automated context blanks/bounces; a human's browser is fine →
  **detection‑triggered defense** (real anti‑bot).
- Captcha/验证/频繁 text visible → **hard block**; stop per §1.3.

---

## 5. Case study — BOSS直聘 (zhipin.com), recruiter side (2026‑06)

Concrete, because patterns generalize.

**Layer 0 — our own bugs (not the site):** the early "logged out / blank page"
scares were M1–M3 above. The session was fine the whole time.

**Layer 1 — CDP `Runtime.enable` kill‑switch.** With stock Playwright the 沟通 page
renders all conversations (~t+2s), then `js/564.js` calls `window.open('','_self')`
(~t+5s) → `about:blank`, permanently. Trigger: the **`Runtime.enable` fingerprint**
that Playwright/Puppeteer expose. **Real Chrome alone did NOT fix it.**
- **Fix:** `rebrowser-playwright` (Runtime‑fix mode `addBinding`), drop the stealth
  plugin, launch real Chrome (`channel:'chrome'`). → kill‑switch no longer fires;
  page survives ~12s with working APIs.

**Layer 2 — localhost automation‑port scan.** ~t+13s the page probes
`ws://127.0.0.1:9222` (CDP), plus agent endpoints/`/health` pings, then **redirects
to the logged‑out homepage**. Confirmed to be 直聘's anti‑bot.
- **Why DrissionPage beats it:** it launches Chrome with `--remote-debugging-port`
  **but WITHOUT `--remote-allow-origins=*`**. Chrome's built‑in origin check then
  **refuses the page's attempt to talk to the CDP port**, so the scan finds nothing.
  Playwright opens that door when it uses a TCP port; DrissionPage never does.

**Conclusion for hard, multi‑layer anti‑bot:** prefer **DrissionPage** (real Chrome,
no `Runtime.enable` leak, no `--remote-allow-origins`). It is what the proven working
script used. Playwright can be pushed (rebrowser) but it's an arms race per layer.

**Observed 直聘 signals to treat as hard stops:** 安全验证 / 请完成验证 / 滑动验证 /
拖动滑块 / 人机验证 / 操作过于频繁 / 访问过于频繁 / 账号异常 / 访问受限 / forced logout.

---

## 6. Detection vectors catalog (what they check → what to do)

| Vector | How they detect | Countermeasure |
|--------|-----------------|----------------|
| **CDP `Runtime.enable`** | Trap object whose getter fires when the DevTools console serializes it; timing tells. The #1 Playwright/Puppeteer giveaway. | Use **DrissionPage** (doesn't enable Runtime) or **`rebrowser`‑patched** Playwright/Puppeteer. |
| **Localhost debug‑port scan** | Page tries `127.0.0.1:9222` / `/json/version` / WS to the CDP endpoint; known‑agent health pings. | **Never** set `--remote-allow-origins=*`. Prefer pipe transport or rely on Chrome's origin check (DrissionPage default). |
| **`navigator.webdriver`** | `=== true` when launched with `--enable-automation`. | Launch real Chrome **without** `--enable-automation` (DrissionPage default). Don't over‑patch; patched getters are themselves detectable. |
| **Bundled Chromium vs real Chrome** | UA string, `navigator.userAgentData.brands` ("Chromium" vs "Google Chrome"), missing proprietary codecs (Widevine/H.264). | Drive **real installed Chrome** (`channel:'chrome'` / DrissionPage auto‑find). |
| **Stealth‑plugin artifacts** | e.g. a `chrome-extension://invalid/` request; inconsistent spoofed `navigator.plugins`. | With real Chrome, **don't** use `puppeteer-extra-plugin-stealth`; real Chrome already has genuine values. |
| **Behavioral** | Machine‑speed clicks, no mouse movement, metronomic timing, inhuman session length. | Real mouse paths, randomized varied delays, natural scroll, cool‑down between runs, sane session lengths. |
| **Network/identity** | Datacenter IP, mismatched timezone/locale/Accept‑Language vs IP region. | Residential/local IP for the target region; matching `locale`/`timezoneId`/`--lang`. |
| **SPA loading‑state confusion (self‑inflicted)** | n/a — this is *your* bug | Wait for a definitive content selector before judging (§4.1). |

---

## 7. Tooling guidance (pick by threat level)

- **DrissionPage (Python) — default for hard anti‑bot (China subscription platforms).**
  Drives real Chrome, no `Runtime.enable` leak, no `--remote-allow-origins`. Proven
  against 直聘. Minimal, AI‑maintainable.
  ```python
  from DrissionPage import ChromiumPage, ChromiumOptions
  co = ChromiumOptions()
  co.set_user_data_path('user-data-dp')   # persistent logged-in profile
  co.headless(False)                       # visible so a human can watch/take over
  co.set_argument('--lang=zh-CN')
  page = ChromiumPage(co)                  # launches real Chrome, no automation tells
  ```
- **Playwright/Puppeteer — only if you must stay in Node.** Make it look like
  DrissionPage:
  - use **`rebrowser-playwright`** (or `rebrowser-patches`) to kill the
    `Runtime.enable` leak; set `REBROWSER_PATCHES_RUNTIME_FIX_MODE=addBinding`;
  - launch **real Chrome** (`channel:'chrome'`);
  - **do NOT** add `--remote-allow-origins=*`; prefer pipe transport;
  - **drop** `puppeteer-extra-plugin-stealth`.
  - Caveat: `rebrowser` patches lag the newest Playwright (e.g. no 1.61 yet) — pin a
    supported version. Even patched, expect to fight each new detection **layer**.
- **Selenium — avoid for hard anti‑bot.** Similar CDP tells, more fingerprints.

> Rule of thumb: if a site has a *delayed kill‑switch or localhost port scan*, reach
> for DrissionPage rather than grinding Playwright through layer after layer.

---

## 8. Reusable diagnostic recipes

- **Survival watch** — load → poll `url`/`bodyLen`/content‑selector‑count/text every
  2s for ~30s → classify SURVIVED/BLANKED/REDIRECTED/NEVER‑RENDERED. (§4.1)
- **Side‑channel capture** — collect `console`, `pageerror`, `requestfailed`; flag any
  `127.0.0.1` / CDP / health probes. (§4.2)
- **Nav‑primitive trap** — `addInitScript` wrapping `location.assign/replace`, the
  `href` setter, `window.open`, `form.submit`, each logging `new Error().stack`. The
  one that fires is the kill‑switch; the stack names the vendor bundle. (§4.3)
- **Login‑verdict poll** — return `in` / `wall` / `loading`; only treat as logged‑out
  when a login wall is *visibly* present, never while a loading placeholder shows.
- **Run cool‑down** — persist a `last-run` timestamp; on launch, if elapsed < floor
  (e.g. 90s), sleep the remainder + jitter. One choke point for every run.

(Reference implementations from the 直聘 project: a `diag` survival/nav‑trap script
and a DrissionPage `survival` proof. Port the *shape*, not the literal code.)

---

## 9. Adopt this in another project (how to share)

1. Copy this file in (or symlink one global canonical copy). It depends on nothing
   external.
2. Start at **§0 Pre‑flight** and **§1 Golden rules**.
3. Bring the **§8 recipes** as small scripts before any real run.
4. Add a project‑local case‑study section as you learn that site's specifics (mirror
   **§5**).
5. Keep ONE canonical copy and update it everywhere (§10).

---

## 10. Maintenance — keep this file alive (REQUIRED)

- **When to update:** any new detection vector, kill‑switch shape, tool quirk, or
  mistake — on *any* project, not just the one where you found it.
- **How:** add/expand the relevant section, add a row to **§3** (mistake) or **§6**
  (vector) if novel, bump *Last updated*, and append a **Changelog** line.
- **Trigger to remember across sessions:** a `feedback` memory points here so future
  sessions update this file proactively. If you're reading this and just learned
  something anti‑bot‑related, **update this file before moving on.**

### Changelog
- **2026‑06‑27** — Created from the BOSS直聘 investigation. Captured M1–M9 mistakes,
  the render‑race vs real‑block distinction, the `Runtime.enable` and
  localhost‑port‑scan vectors, the `--remote-allow-origins=*` insight, DrissionPage
  vs rebrowser‑Playwright tooling guidance, and the survival‑watch / nav‑trap recipes.
