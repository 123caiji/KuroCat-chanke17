(function () {
  'use strict';

  var currentLang = /^en/i.test(document.documentElement.lang || '') ? 'en' : 'zh';

  var EN_COPY = {
    skip: 'Skip to main content',
    nav_hub: 'Hub',
    nav_features: 'Features',
    nav_skins: 'Skins',
    nav_compare: 'Compare',
    nav_download: 'Download',
    nav_faq: 'FAQ',
    nav_workshop: 'Workshop',
    nav_cta: 'Fast Mirror',
    drawer_cn: 'Fast Download Mirror',
    hero_badge: '· MIT Open Source · Zero Keystroke Upload',
    hero_h1: 'A native desktop cat<br />right on your keyboard',
    hero_sub: 'KuroCat is a lightweight open source desktop companion built natively for macOS, Windows, Linux, and UOS. Syncs with typing, gaming, graphics tablets, and OBS with zero keystrokes logged or uploaded.',
    hero_cta: 'Download KuroCat Free',
    hero_secondary: 'Explore Skin Workshop',
    proof_1: 'Native Swift / Win32 / GTK3',
    proof_2: 'Fast mirror & GitHub Releases',
    proof_3: 'Auditable MIT source, local only',
    pet_live_hint: 'Live Web Pet · Type or shake cursor',
    pet_float_on: 'Float on Page',
    ps_siamese: 'Siamese',
    ps_douni: 'Xiao Douni',
    ps_dazed: 'Palico',
    ps_orange: 'Orange White',
    ps_tabby: 'Brown Tabby',
    ps_black: 'Black Cat',
    pet_undocked_t: 'Your cat is floating in the corner',
    pet_undocked_d: 'Scroll, type on your keyboard, or drag it anywhere on screen',
    pet_dock_back: 'Dock Back',
    act_typing: 'Auto Type',
    act_pet: 'Pet Head',
    act_drag: 'Scruff Lift',
    act_sleep: 'Cat Ball Sleep',
    pet_controls_tip: 'Press any key to type · Shake mouse to hunt · Drag cat to lift',
    float_next_skin: 'Next Skin',
    stat_1: 'Windows single executable',
    stat_2: 'macOS / Win / Linux / UOS',
    stat_3: 'Built in & community skins',
    stat_4: 'Keystrokes uploaded',
    hub_eyebrow: 'Ecosystem Hub',
    hub_h2: 'Every KuroCat destination in one place',
    hub_sub: 'Jump straight to fast direct downloads, the online 2.5D skin editor, community skin & keyboard plaza, or MIT source docs.',
    hub_1_badge: 'Recommended Mirror',
    hub_1_title: 'Fast Direct Download Mirror',
    hub_1_desc: 'Direct high speed mirror for macOS, Windows, Linux, and UOS builds with verified SHA 256 checksums and community Q&A.',
    hub_1_qa: 'Top 10 Community Q&A',
    hub_open: 'Open',
    hub_2_badge: 'Editor & Community',
    hub_2_title: 'KuroCat Skin Workshop & Plaza',
    hub_2_desc: 'Turn your own cat into a 2.5D desktop pet right in the browser, or browse Xiao Douni, Monster Hunter Palico, Tabby, and custom keyboards.',
    hub_2_c1: 'Skin Editor',
    hub_2_c2: 'Skin Plaza',
    hub_2_c3: 'Accessories',
    hub_2_c4: 'Keyboards',
    hub_3_title: 'GitHub Repository & Releases',
    hub_3_desc: 'Fully open source native code across all three platforms, built transparently via GitHub Actions. Star, report issues, or contribute skins.',
    hub_3_c1: 'Latest Release',
    hub_3_c2: 'Report Issue',
    hub_3_c3: 'Submit Skin PR',
    hub_repo: 'View Source',
    hub_4_badge: 'Docs & Spec',
    hub_4_title: 'Open Format Spec & Creator Guide',
    hub_4_desc: 'Read the .kurocat v1 coordinate spec, bezier region schema, sticker anchors, and community submission workflow.',
    hub_4_c1: '.kurocat Spec',
    hub_4_c2: 'Submission Guide',
    hub_doc: 'Read Docs',
    feat_eyebrow: 'Why KuroCat',
    feat_h2: 'Not a static sticker, it reacts to everything you do',
    feat_sub: 'Built from native input APIs and real time 2.5D vector physics for coding, gaming, digital illustration, and livestreaming.',
    f1_t: 'Full state keyboard, mouse & 2.5D graphics tablet',
    f1_d: 'Uses IOHIDManager on macOS, Raw Input on Windows, and XInput2 + evdev on Linux. Tracks rapid typing, WASD holds, stylus strokes, 3 key hind foot kicks, and 4 key tail taps.',
    f2_t: '2.5D spherical head tracking & expressive physics',
    f2_d: 'Head, ears, whiskers, and eyes rotate smoothly toward your cursor. Shake fast for wide hunting eyes, pet for purrs, lift by the scruff with 2D inertia, and watch it curl up to sleep at low CPU.',
    f3_t: 'Built for OBS streaming & distraction free gaming',
    f3_d: 'One click OBS transparent window or chroma green (#00FF00) mode, automatic fullscreen hiding, always on top watchdog, ±180° snapped rotation, and full mouse click through.',
    f4_t: 'Open custom skin ecosystem in under 1 MB',
    f4_d: 'Zero Electron bloat: 802 KB single executable on Windows and under 1 MB Universal binary on macOS. Drag and drop .kurocat cat skins and .kurokb keyboard themes right onto your cat.',
    skins_eyebrow: 'Skins & Themes',
    skins_h2: 'Built in coats plus unlimited community creations',
    skins_sub: 'Toggleable soft white sticker outline stays sharp against dark desktops and IDEs. Drag any .kurocat file onto the cat to wear instantly.',
    sk_1: 'Classic Black Cat',
    sk_1_d: 'Neon chartreuse eyes · Soft white sticker outline',
    sk_2: 'Seal Point Siamese',
    sk_2_d: 'Sleek build · Caramel point gradient & sapphire eyes',
    sk_3: 'Silver Shorthair Tabby',
    sk_3_d: 'Silver mackerel stripes · Warm cream forelegs',
    sk_4: 'Orange & White',
    sk_4_d: 'Warm ginger back stripes · Cream belly & amber eyes',
    sk_5: 'Brown Mackerel Tabby',
    sk_5_d: 'Oat brown stripes · Feathered bib & olive gold eyes',
    sk_6_badge: 'Community Plaza',
    sk_6: 'Xiao Douni, Monster Hunter Palico & more',
    sk_6_d: 'Download community creations including comic style Xiao Douni, Monster Hunter Dazed Cat, Abyssinian, and custom keyboards for free.',
    sk_6_cta: 'Browse Skin Plaza',
    cmp_eyebrow: 'Side by Side',
    cmp_h2: 'How KuroCat compares to Bongo Cat & web pets',
    cmp_sub: 'A direct, factual comparison across architecture, platform support, streaming readiness, and privacy.',
    cmp_c0: 'Criteria',
    cmp_c2: 'Classic Bongo Cat',
    cmp_c3: 'Electron Desktop Pets',
    cmp_r1_0: 'Architecture & size',
    cmp_r1_1: 'Native Swift / Win32 C++ / GTK3, 802 KB single exe',
    cmp_r1_2: 'Fragmented community forks with uneven quality',
    cmp_r1_3: 'Bundled Chromium, often 100+ MB download',
    cmp_r2_0: 'Platforms',
    cmp_r2_1: 'macOS, Windows, Linux, UnionTech UOS & Kylin',
    cmp_r2_2: 'Mostly Windows only',
    cmp_r2_3: 'Cross platform with high RAM usage',
    cmp_r3_0: 'OBS & graphics tablet',
    cmp_r3_1: 'Built in transparent / green screen OBS & auto stylus',
    cmp_r3_2: 'Manual config files and third party plugins',
    cmp_r3_3: 'Usually basic keyboard & mouse only',
    cmp_r4_0: 'Custom skins',
    cmp_r4_1: 'Open .kurocat & .kurokb formats + browser Workshop',
    cmp_r4_2: 'Manual PNG sprite sheet swapping',
    cmp_r4_3: 'Often closed source or paid packs',
    cmp_r5_0: 'Gaming & idle efficiency',
    cmp_r5_1: 'Click through, fullscreen auto hide, low FPS sleep',
    cmp_r5_2: 'No fullscreen auto hide or sleep pacing',
    cmp_r5_3: 'Background browser process drains battery',
    cmp_r6_0: 'Privacy & license',
    cmp_r6_1: '100% MIT open source, zero keystroke logging, free',
    cmp_r6_2: 'Many repacks lack clear source code',
    cmp_r6_3: 'Frequently closed source telemetry',
    dl_eyebrow: 'Get Started in 3 Steps',
    dl_h2: 'Pick your OS and adopt your cat in seconds',
    dl_sub: 'Choose the fast direct mirror or official GitHub Releases. Every build is compiled automatically via GitHub Actions with matching SHA 256 hashes.',
    st_1_t: 'Download your build',
    st_1_d: 'Your OS is detected automatically. Download via the fast direct mirror or GitHub Releases.',
    st_2_t: 'Launch & interact',
    st_2_d: 'Run the single exe on Windows, drag to Applications on macOS, or install .deb / user tar.gz on Linux.',
    st_3_t: 'Drop skins to customize',
    st_3_d: 'Right click for native Settings, OBS mode, or drag any .kurocat or .kurokb file onto the cat.',
    mac_t: 'macOS Universal (Apple Silicon & Intel)',
    mac_d: 'Single zip supporting M series and Intel Macs on macOS 11+. Signed with a stable certificate so updates keep your Input Monitoring permission.',
    mac_dl_cn: 'Fast Mirror Download',
    dl_gh: 'GitHub Release',
    copy: 'Copy',
    mac_note: 'On first launch, enable KuroCat in System Settings → Privacy & Security → Input Monitoring, then restart from the menu bar.',
    win_t: 'Windows x64 Portable Single File',
    win_d: 'Zero external runtime dependencies for Windows 7 SP1 through Windows 11. Runs straight from the single executable with native in app auto update.',
    win_dl_cn: 'Fast Mirror Download',
    win_note: 'If SmartScreen warns about an unrecognized app, verify the SHA 256 hash above before running. Launch as Administrator for elevated games or WPS.',
    lin_t: 'Linux / UnionTech UOS / Kylin',
    lin_d: 'Built on Debian 10 (glibc 2.28) for Ubuntu, Debian, Deepin, UOS 20, Kylin V10, Arch, and Fedora in x86_64 and ARM64.',
    lin_note: 'Run bash install.sh inside the extracted tar.gz for password free user installation. On pure Wayland, run sudo usermod -aG input $USER once and re login.',
    dl_trust: 'Every package is built by GitHub Actions with identical SHA 256 checksums across mirrors.',
    dl_cn_page: 'Dedicated Mirror Page',
    faq_eyebrow: 'FAQ',
    faq_h2: 'Common questions answered clearly',
    faq_sub: 'Privacy, Bongo Cat comparison, OBS setup, and OS permissions. Need help with something else? Open a GitHub Issue.',
    faq_issue: 'Open GitHub Issue',
    faq_xhs: 'Community 10 Q&A',
    q1: 'Does KuroCat record or upload my keystrokes?',
    a1: 'No. Every keyboard and mouse event stays strictly in local memory to drive animations and counters. Nothing is logged to disk or uploaded. The entire codebase is MIT open source for public inspection.',
    q2: 'How is KuroCat different from classic Bongo Cat?',
    a2: 'KuroCat is natively built in Swift, Win32 C++, and GTK3 Cairo (802 KB on Windows) across macOS, Windows, Linux, and UOS, adding 2.5D head tracking, hunting eyes, graphics tablet support, OBS transparent/green modes, 2D scruff drag physics, and an online Skin Workshop.',
    q3: 'How do I add KuroCat to OBS Studio or streaming apps?',
    a3: 'Right click the cat or tray icon, open Settings, and enable OBS Transparent Window Capture or OBS Green Screen (#00FF00), then add a Window Capture source in OBS. Fullscreen auto hide pauses automatically during OBS capture.',
    q4: 'How do I open Settings after enabling full mouse click through?',
    a4: 'Click the KuroCat icon in the macOS menu bar or Windows / Linux system tray anytime. You can also hold Option on macOS or press Ctrl + Alt + Shift + P on Windows to toggle menu access.',
    q5: 'macOS says unverified developer or keyboard does not respond?',
    a5: 'Right click KuroCat.app and pick Open on first run. Then check KuroCat under System Settings → Privacy & Security → Input Monitoring and restart it from the menu bar.',
    q6: 'Is the Windows SmartScreen prompt normal?',
    a6: 'Yes. Open source indie apps without a paid commercial signing certificate can trigger SmartScreen on new releases. Compare the SHA 256 checksum with GitHub Releases, then click More info → Run anyway.',
    q7: 'Does it work on UnionTech UOS and Kylin Linux?',
    a7: 'Yes. Linux packages target glibc 2.28 (Debian 10) for both x86_64 and ARM64, supporting UOS 20 and Kylin V10 with both .deb and password free tar.gz installers.',
    q8: 'How do I turn my own cat into a custom skin?',
    a8: 'Open the KuroCat Skin Workshop in your browser to analyze a cat photo, draw bezier coat regions, add 2.5D sticker accessories, export .kurocat, and drag it right onto your desktop cat.',
    cta_h2: 'Bring your keyboard cat home today',
    cta_sub: 'Free, MIT open source, native speed, and zero keystrokes uploaded.',
    cta_btn: 'Open Fast Download Mirror',
    cta_ws: 'Open Skin Workshop',
    foot_desc: 'Native cross platform open source desktop cat. All keyboard and mouse signals stay strictly in local memory.',
    foot_c1: 'Destinations',
    foot_cn: 'Fast Download Mirror',
    foot_c2: 'Open Source & Docs',
    foot_c3: 'Privacy & Support',
    foot_privacy: 'Privacy Policy (Zero Data)',
    foot_license: 'MIT License Terms',
    foot_reward: 'Buy the Author a Coffee',
    foot_top: 'Back to top ↑',
    foot_note: 'Privacy promise: no keystroke logging, no ads, no personal telemetry.',
    rw_t: 'Buy the author a coffee',
    rw_d: 'If KuroCat brings joy to your coding, gaming, or drawing sessions, scan via WeChat to support ongoing updates.',
    rw_f: 'KuroCat is forever free and MIT open source. Thank you for every bit of support.'
  };

  // Capture original Chinese text once for clean ZH <-> EN switching
  var ZH_COPY = {};
  document.querySelectorAll('[data-i18n]').forEach(function (el) {
    ZH_COPY[el.getAttribute('data-i18n')] = el.textContent;
  });
  document.querySelectorAll('[data-i18n-html]').forEach(function (el) {
    ZH_COPY[el.getAttribute('data-i18n-html')] = el.innerHTML;
  });

  // Platform Detection & Download Tabs
  var detectedPlatform = 'mac';
  function detectPlatform() {
    var ua = (navigator.userAgent || '').toLowerCase();
    var p = '';
    try { p = ((navigator.userAgentData && navigator.userAgentData.platform) || '').toLowerCase(); } catch (e) {}
    var text = p + ' ' + ua + ' ' + (navigator.platform || '').toLowerCase();
    if (text.indexOf('win') !== -1) return 'windows';
    if (text.indexOf('mac') !== -1 || text.indexOf('iphone') !== -1 || text.indexOf('ipad') !== -1) return 'mac';
    if (text.indexOf('linux') !== -1 || text.indexOf('x11') !== -1) return 'linux';
    return 'mac';
  }

  function updateHeroCtaLabel() {
    var labelEl = document.getElementById('heroPrimaryLabel');
    if (!labelEl) return;
    if (currentLang === 'en') {
      var enMap = { mac: 'Download for macOS', windows: 'Download for Windows', linux: 'Download for Linux' };
      labelEl.textContent = enMap[detectedPlatform] || 'Download KuroCat Free';
    } else {
      var zhMap = { mac: '免费下载 macOS 版', windows: '免费下载 Windows 版', linux: '免费下载 Linux / UOS 版' };
      labelEl.textContent = zhMap[detectedPlatform] || '免费下载 KuroCat';
    }
  }

  function selectPlatform(key) {
    detectedPlatform = key;
    document.querySelectorAll('.platform-tab').forEach(function (tab) {
      var active = tab.getAttribute('data-platform') === key;
      tab.classList.toggle('active', active);
      tab.setAttribute('aria-selected', active ? 'true' : 'false');
    });
    document.querySelectorAll('.platform-panel').forEach(function (panel) {
      panel.classList.toggle('active', panel.getAttribute('data-panel') === key);
    });
    updateHeroCtaLabel();
  }

  document.querySelectorAll('.platform-tab').forEach(function (tab) {
    tab.addEventListener('click', function () {
      selectPlatform(tab.getAttribute('data-platform'));
    });
  });
  selectPlatform(detectPlatform());

  // Hero GIF Showcase Tabs
  var heroGif = document.getElementById('heroGif');
  var showcaseCaption = document.getElementById('showcaseCaption');
  document.querySelectorAll('.showcase-tab').forEach(function (tab) {
    tab.addEventListener('click', function () {
      document.querySelectorAll('.showcase-tab').forEach(function (el) {
        var active = el === tab;
        el.classList.toggle('active', active);
        el.setAttribute('aria-selected', active ? 'true' : 'false');
      });
      if (heroGif) {
        heroGif.src = tab.getAttribute('data-gif');
      }
      if (showcaseCaption) {
        showcaseCaption.textContent = tab.getAttribute(currentLang === 'en' ? 'data-cap-en' : 'data-cap-zh');
      }
    });
  });

  // Render Tagline Tokens for B11 Word-by-Word Scroll Reveal
  var taglineEl = document.getElementById('taglineReveal');
  var taglineTokens = [];
  function buildTaglineTokens(lang) {
    if (!taglineEl) return;
    var raw = taglineEl.getAttribute(lang === 'en' ? 'data-tagline-en' : 'data-tagline-zh') || '';
    var lines = raw.split('|');
    taglineEl.innerHTML = '';
    taglineTokens = [];
    lines.forEach(function (line, lineIdx) {
      var parts = lang === 'en' ? line.trim().split(/\s+/) : line.trim().split('');
      parts.forEach(function (piece, pIdx) {
        var span = document.createElement('span');
        span.className = 'tagline-token' + (lineIdx === lines.length - 1 ? ' tagline-token-accent' : '');
        span.textContent = lang === 'en' ? (piece + (pIdx < parts.length - 1 ? ' ' : '')) : piece;
        taglineEl.appendChild(span);
        taglineTokens.push(span);
      });
      if (lineIdx < lines.length - 1) {
        taglineEl.appendChild(document.createElement('br'));
      }
    });
    updateTaglineReveal();
  }

  var reducedMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  function updateTaglineReveal() {
    if (!taglineEl || !taglineTokens.length) return;
    if (reducedMotion) {
      taglineTokens.forEach(function (tok) { tok.classList.add('lit'); });
      return;
    }
    var rect = taglineEl.getBoundingClientRect();
    var vh = window.innerHeight || 800;
    var start = vh * 0.86;
    var end = vh * 0.28;
    var progress = (start - rect.top) / Math.max(1, start - end + rect.height * 0.35);
    progress = Math.max(0, Math.min(1, progress));
    var litCount = Math.floor(progress * (taglineTokens.length + 1));
    for (var i = 0; i < taglineTokens.length; i++) {
      taglineTokens[i].classList.toggle('lit', i < litCount);
    }
  }

  var rafPending = false;
  function onScrollThrottled() {
    if (rafPending) return;
    rafPending = true;
    window.requestAnimationFrame(function () {
      rafPending = false;
      updateTaglineReveal();
    });
  }
  if (!reducedMotion) {
    window.addEventListener('scroll', onScrollThrottled, { passive: true });
    window.addEventListener('resize', onScrollThrottled, { passive: true });
  }
  buildTaglineTokens(currentLang);

  // Language Switcher (only attaches in-place toggle when #langToggle is a button; link navigates directly)
  var langBtn = document.getElementById('langToggle');
  function setLanguage(lang) {
    currentLang = lang;
    document.documentElement.lang = lang === 'en' ? 'en' : 'zh-CN';
    var dict = lang === 'en' ? EN_COPY : ZH_COPY;
    document.querySelectorAll('[data-i18n]').forEach(function (el) {
      var k = el.getAttribute('data-i18n');
      if (dict[k] !== undefined) el.textContent = dict[k];
    });
    document.querySelectorAll('[data-i18n-html]').forEach(function (el) {
      var k = el.getAttribute('data-i18n-html');
      if (dict[k] !== undefined) el.innerHTML = dict[k];
    });
    if (langBtn && langBtn.tagName === 'BUTTON') langBtn.textContent = lang === 'en' ? '中文' : 'EN';
    var activeTab = document.querySelector('.showcase-tab.active');
    if (activeTab && showcaseCaption) {
      showcaseCaption.textContent = activeTab.getAttribute(lang === 'en' ? 'data-cap-en' : 'data-cap-zh');
    }
    buildTaglineTokens(lang);
    updateHeroCtaLabel();
  }
  if (langBtn && langBtn.tagName === 'BUTTON') {
    langBtn.addEventListener('click', function () {
      setLanguage(currentLang === 'zh' ? 'en' : 'zh');
    });
  }

  // IntersectionObserver Scroll Reveals (B7: reveal once only, progressive enhancement)
  var revealEls = document.querySelectorAll('.reveal');
  function revealVisibleNow() {
    var vh = window.innerHeight || 900;
    revealEls.forEach(function (el) {
      if (el.getBoundingClientRect().top < vh + 40) {
        el.classList.add('is-visible');
      }
    });
  }
  if ('IntersectionObserver' in window && !reducedMotion) {
    document.documentElement.classList.add('js-reveal');
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          io.unobserve(entry.target);
        }
      });
    }, { threshold: 0.01, rootMargin: '0px 0px -20px 0px' });
    revealEls.forEach(function (el) { io.observe(el); });
    revealVisibleNow();
    window.addEventListener('hashchange', function () { setTimeout(revealVisibleNow, 120); });
  } else {
    revealEls.forEach(function (el) { el.classList.add('is-visible'); });
  }

  // Active Navigation Section Tracking (B9)
  var navItems = document.querySelectorAll('.nav-item[data-nav]');
  var trackedSections = ['hub', 'features', 'skins', 'compare', 'download', 'faq']
    .map(function (id) { return document.getElementById(id); })
    .filter(Boolean);
  if ('IntersectionObserver' in window && trackedSections.length) {
    var navObserver = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          var id = entry.target.id;
          navItems.forEach(function (link) {
            link.classList.toggle('active', link.getAttribute('data-nav') === id);
          });
        }
      });
    }, { rootMargin: '-35% 0px -55% 0px', threshold: 0 });
    trackedSections.forEach(function (sec) { navObserver.observe(sec); });
  }

  // Mobile Full-Height Drawer Toggle (B7)
  var menuToggle = document.getElementById('menuToggle');
  var mobileDrawer = document.getElementById('mobileDrawer');
  function setDrawerOpen(open) {
    if (!menuToggle || !mobileDrawer) return;
    menuToggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    mobileDrawer.classList.toggle('open', open);
    mobileDrawer.setAttribute('aria-hidden', open ? 'false' : 'true');
    document.body.style.overflow = open ? 'hidden' : '';
  }
  if (menuToggle && mobileDrawer) {
    menuToggle.addEventListener('click', function () {
      setDrawerOpen(menuToggle.getAttribute('aria-expanded') !== 'true');
    });
    mobileDrawer.querySelectorAll('a').forEach(function (link) {
      link.addEventListener('click', function () { setDrawerOpen(false); });
    });
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') setDrawerOpen(false);
    });
  }

  // Copy SHA 256 Checksum with Inline Toast (B8 / B9)
  var toastEl = document.getElementById('toast');
  var toastTimer = null;
  function showToast(msg) {
    if (!toastEl) return;
    toastEl.textContent = msg;
    toastEl.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { toastEl.classList.remove('show'); }, 2000);
  }
  document.querySelectorAll('.copy-btn').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var val = btn.getAttribute('data-copy') || '';
      var okMsg = currentLang === 'en' ? 'SHA 256 copied to clipboard' : '已复制 SHA 256 校验值';
      if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(val).then(function () { showToast(okMsg); });
      } else {
        var ta = document.createElement('textarea');
        ta.value = val;
        ta.setAttribute('readonly', '');
        ta.style.position = 'fixed';
        ta.style.opacity = '0';
        document.body.appendChild(ta);
        ta.select();
        try { document.execCommand('copy'); showToast(okMsg); } catch (e) {}
        document.body.removeChild(ta);
      }
    });
  });

  // Reward Modal
  var rewardDialog = document.getElementById('rewardDialog');
  var openRewardBtn = document.getElementById('openRewardBtn');
  var closeRewardBtn = document.getElementById('closeRewardBtn');
  if (openRewardBtn && rewardDialog) {
    openRewardBtn.addEventListener('click', function () {
      if (typeof rewardDialog.showModal === 'function') rewardDialog.showModal();
      else rewardDialog.setAttribute('open', '');
    });
  }
  if (closeRewardBtn && rewardDialog) {
    closeRewardBtn.addEventListener('click', function () {
      if (typeof rewardDialog.close === 'function') rewardDialog.close();
      else rewardDialog.removeAttribute('open');
    });
  }
  if (rewardDialog) {
    rewardDialog.addEventListener('click', function (e) {
      if (e.target === rewardDialog && typeof rewardDialog.close === 'function') rewardDialog.close();
    });
  }
})();
