// ===== 可拖曳雙頁角色裝備視窗 =====
(function () {
    const PAGE_NAMES = ['一般裝備', '席琳遺骸'];
    const PAGE_SLOTS = [
        [
            { k: 'helm',    n: '頭盔',     x: 50.0, y: 15.81, w: 19.67, h: 8.82 },
            { k: 'ear1',    n: '耳環 I',   x: 19.4, y: 18.01, w: 19.67, h: 8.82 },
            { k: 'ear2',    n: '耳環 II',  x: 80.1, y: 18.01, w: 19.67, h: 8.82 },
            { k: 'amulet',  n: '項鍊',     x: 50.0, y: 33.46, w: 19.67, h: 8.82 },
            { k: 'gloves',  n: '手套',     x: 19.4, y: 31.50, w: 19.67, h: 8.82 },
            { k: 'cloak',   n: '斗篷',     x: 80.1, y: 31.50, w: 19.67, h: 8.82 },
            { k: 'tshirt',  n: 'T恤',      x: 50.0, y: 42.77, w: 19.67, h: 8.82 },
            { k: 'wpn',     n: '武器',     x: 19.4, y: 44.98, w: 19.67, h: 8.82 },
            { k: 'shield', alt: 'offwpn', n: '副手', x: 80.1, y: 44.98, w: 19.67, h: 8.82 },
            { k: 'armor',   n: '盔甲',     x: 50.0, y: 52.08, w: 19.67, h: 8.82 },
            { k: 'ring1',   n: '戒指 I',   x: 19.4, y: 58.46, w: 19.67, h: 8.82 },
            { k: 'ring2',   n: '戒指 II',  x: 80.1, y: 58.46, w: 19.67, h: 8.82 },
            { k: 'belt',    n: '腰帶',     x: 50.0, y: 63.36, w: 19.67, h: 8.82 },
            { k: 'ring3',   n: '戒指 III', x: 19.4, y: 67.77, w: 19.67, h: 8.82 },
            { k: 'ring4',   n: '戒指 IV',  x: 80.1, y: 67.77, w: 19.67, h: 8.82 },
            { k: 'shin',    n: '脛甲',     x: 50.0, y: 72.67, w: 19.67, h: 8.82 },
            { k: 'boots',   n: '長靴',     x: 50.0, y: 81.99, w: 19.67, h: 8.82 },
            { k: 'doll',    n: '魔法娃娃', x: 19.4, y: 80.76, w: 19.67, h: 8.82 },
            { k: 'arrow',   n: '箭矢',     x: 80.1, y: 80.76, w: 19.67, h: 8.82 }
        ],
        [
            { k: 'sherine_eye',    n: '頭盔遺骸',    x: 50.0, y: 15.81, w: 19.67, h: 8.82 },
            { k: 'sherine_horn',   n: '耳環 I 遺骸', x: 19.4, y: 18.01, w: 19.67, h: 8.82 },
            { k: 'sherine_wing',   n: '耳環 II 遺骸',x: 80.1, y: 18.01, w: 19.67, h: 8.82 },
            { k: 'sherine_shell',  n: '項鍊遺骸',    x: 50.0, y: 33.46, w: 19.67, h: 8.82 },
            { k: 'sherine_heart',  n: '手套遺骸',    x: 19.4, y: 31.50, w: 19.67, h: 8.82 },
            { k: 'sherine_fang',   n: '斗篷遺骸',    x: 80.1, y: 31.50, w: 19.67, h: 8.82 },
            { k: 'sherine_flesh',  n: 'T恤遺骸',     x: 50.0, y: 42.77, w: 19.67, h: 8.82 },
            { k: 'sherine_claw',   n: '武器遺骸',    x: 19.4, y: 44.98, w: 19.67, h: 8.82 },
            { k: 'sherine_scale',  n: '副手遺骸',    x: 80.1, y: 44.98, w: 19.67, h: 8.82 },
            { k: 'sherine_blood',  n: '盔甲遺骸',    x: 50.0, y: 52.08, w: 19.67, h: 8.82 },
            { k: 'sherine_tail',   n: '戒指 I 遺骸', x: 19.4, y: 58.46, w: 19.67, h: 8.82 },
            { k: 'sherine_soul',   n: '戒指 II 遺骸',x: 80.1, y: 58.46, w: 19.67, h: 8.82 },
            { k: 'sherine_vein',   n: '腰帶遺骸',    x: 50.0, y: 63.36, w: 19.67, h: 8.82 },
            { k: 'sherine_hide',   n: '戒指 III 遺骸',x: 19.4, y: 67.77, w: 19.67, h: 8.82 },
            { k: 'sherine_marrow', n: '戒指 IV 遺骸', x: 80.1, y: 67.77, w: 19.67, h: 8.82 },
            { k: 'sherine_shin',   n: '脛甲遺骸',    x: 50.0, y: 72.67, w: 19.67, h: 8.82 },
            { k: 'sherine_bone',   n: '長靴遺骸',    x: 50.0, y: 81.99, w: 19.67, h: 8.82 }
        ]
    ];

    let page = 0;
    let drag = null;
    let sideMode = null;
    let clickTimer = null;

    const SHERINE_SLOT_ICON = {
        sherine_claw: 'claw',
        sherine_eye: 'eye',
        sherine_blood: 'blood',
        sherine_flesh: 'flesh',
        sherine_heart: 'heart',
        sherine_bone: 'bone',
        sherine_fang: 'fang',
        sherine_scale: 'scale',
        sherine_horn: 'horn',
        sherine_wing: 'wing',
        sherine_tail: 'tail',
        sherine_soul: 'soul',
        sherine_hide: 'hide',
        sherine_marrow: 'marrow',
        sherine_vein: 'vein',
        sherine_shell: 'shell',
        sherine_shin: 'shin'
    };

    function getSherineSlotIcon(slotKey) {
        const iconKey = SHERINE_SLOT_ICON[slotKey];
        return iconKey ? `assets/icons/sherine/sherine_remain_${iconKey}.png?v=20260716b` : '';
    }

    // 🎬 v3.0.44 變身立繪動畫（用戶提供 morph.spr）：這 15 個變身用 assets/morphanim/<名>/morph_N.png 逐幀循環（8fps），取代舊 assets/morph/<名>.jpg 靜態立繪。其餘變身維持 .jpg 退回鏈。
    // 🎬 v3.0.46 ①大小統一：以「炎魔」畫布高(191px)為基準像素比例——顯示高 = 帶高 × 本形態畫布高/191（炎魔=剛好填滿帶·其餘等比例縮·同一像素倍率）；
    //          ②三層疊放：morph_s(影子·multiply·墊底) + morph(本體) + morph_w(武器特效·screen·最上)——三者 --multi 共畫布→同 rect 疊放即像素級對齊。
    const MORPH_ANIM_PORTRAIT = new Set(['克特', '卡司特王', '思克巴女皇', '死亡騎士', '炎魔', '白金法師', '白金騎士', '艾莉絲', '銀光法師', '銀光騎士', '騎士范德', '黃金法師', '黃金騎士', '黑暗法師', '黑暗騎士',
        '亞力安', '人形殭屍', '侏儒', '哥布林', '地靈', '多羅', '妖魔', '妖魔弓箭手', '小惡魔', '巴列斯', '巴風特', '思克巴', '惡魔', '歐吉', '死亡', '狼人', '萊肯', '食人妖精王', '食屍鬼', '骷髏弓箭手', '骷髏斧手', '骷髏槍兵', '黑暗妖精刺客',   // 🧝 v3.0.50 +23 變身動態立繪
        '反王肯恩', '吸血鬼', '巨人', '白金巡守', '賽尼斯', '銀光巡守', '阿魯巴', '黃金巡守', '黑暗巡守', '黑暗精靈',   // 🧝 v3.0.52 +10 變身動態立繪
        '卡士柏', '史巴托', '妖魔巡守', '妖魔鬥士', '巨大牛人', '巴土瑟', '暴走兔', '果凍怪', '格利芬', '歐姆民兵', '獨眼巨人', '甘地妖魔', '石頭高崙', '紙人', '羅孚妖魔', '西瑪', '那魯加妖魔', '都達瑪拉妖魔', '重裝歐姆', '長老', '阿吐巴妖魔', '雪怪', '食人妖精', '馬庫爾', '骷髏', '黑暗妖精運送員', '黑長者', '黑騎士']);   // 🧝 v3.0.57 +28 變身動態立繪（合計 76＝POLY_TIERS 全形態·變身動畫全數到位）
    const MORPH_PORTRAIT_REF_H = 191;   // 炎魔 morph 畫布高＝基準（用戶：炎魔目前大小剛好）
    let _morphPortrait = { name: null, body: [], shadow: [], weapon: [], i: 0, timer: null, bandH: 0 };
    function _portraitLayers(image) {   // 影子/武器覆疊層（動態建立→index.html/test.html 免改）
        const box = image.parentElement;
        let sh = document.getElementById('equipment-morph-shadow');
        let wp = document.getElementById('equipment-morph-weapon');
        if (!sh) { sh = document.createElement('img'); sh.id = 'equipment-morph-shadow'; sh.alt = ''; sh.draggable = false; box.insertBefore(sh, image); }
        if (!wp) { wp = document.createElement('img'); wp.id = 'equipment-morph-weapon'; wp.alt = ''; wp.draggable = false; box.appendChild(wp); }
        // 🛡️ v3.0.51 關鍵定位樣式改 JS inline 設定（inline 優先於外部樣式表）：不依賴 floating-ui.css 是否為最新→根治「舊 CSS 快取使覆疊層 position:static→影子與本體垂直排開沒對到」。
        const baseCss = 'position:absolute;pointer-events:none;object-fit:contain;image-rendering:crisp-edges;image-rendering:pixelated;';
        if (sh.getAttribute('data-pmcss') !== '1') { sh.style.cssText = baseCss + 'mix-blend-mode:multiply;z-index:1;visibility:hidden;'; sh.setAttribute('data-pmcss', '1'); }
        if (wp.getAttribute('data-pmcss') !== '1') { wp.style.cssText = baseCss + 'mix-blend-mode:screen;z-index:3;visibility:hidden;'; wp.setAttribute('data-pmcss', '1'); }
        return { sh: sh, wp: wp };
    }
    function _syncPortraitLayerRect(image) {   // 覆疊層幾何 = 本體 img 的 offset box（共畫布→同 rect 即對齊）
        const sh = document.getElementById('equipment-morph-shadow');
        const wp = document.getElementById('equipment-morph-weapon');
        [sh, wp].forEach(l => { if (!l) return; l.style.left = image.offsetLeft + 'px'; l.style.top = image.offsetTop + 'px'; l.style.width = image.offsetWidth + 'px'; l.style.height = image.offsetHeight + 'px'; });
    }
    function _stopMorphPortrait() {
        if (_morphPortrait.timer) { clearInterval(_morphPortrait.timer); _morphPortrait.timer = null; }
        _morphPortrait.name = null; _morphPortrait.body = []; _morphPortrait.shadow = []; _morphPortrait.weapon = [];
        const sh = document.getElementById('equipment-morph-shadow'); if (sh) sh.style.visibility = 'hidden';
        const wp = document.getElementById('equipment-morph-weapon'); if (wp) wp.style.visibility = 'hidden';
    }
    function _startMorphPortrait(dir, image) {   // 逐號探測 morph_0..N（含 _s/_w）→ 8fps 三層同步循環
        _stopMorphPortrait();
        _morphPortrait.name = dir;
        image.classList.add('morph-anim-portrait');
        const base = 'assets/morphanim/' + encodeURIComponent(dir) + '/';
        let natH = 0, pending = 3;
        const seqs = { body: [], shadow: [], weapon: [] };
        const done = () => {
            if (--pending > 0 || _morphPortrait.name !== dir) return;
            _morphPortrait.body = seqs.body; _morphPortrait.shadow = seqs.shadow; _morphPortrait.weapon = seqs.weapon; _morphPortrait.i = 0;
            if (!seqs.body.length) { image.classList.remove('morph-anim-portrait'); image.classList.add('no-image'); return; }
            image.classList.remove('no-image');
            // 📏 大小統一：量測帶高（先還原 height 讀 flex 天然高·只量一次快取）→ 顯示高=帶高×natH/191（上限=帶高）
            if (!_morphPortrait.bandH) { image.style.height = ''; image.style.flex = ''; const bh = image.offsetHeight; if (bh > 20) _morphPortrait.bandH = bh; }
            if (_morphPortrait.bandH && natH > 0) {
                const targetH = Math.min(_morphPortrait.bandH, Math.round(_morphPortrait.bandH * natH / MORPH_PORTRAIT_REF_H));
                image.style.height = targetH + 'px'; image.style.flex = '0 0 auto'; image.style.margin = 'auto';
            }
            const L = _portraitLayers(image);
            image.src = seqs.body[0];
            const paint = () => {
                const i = _morphPortrait.i;
                image.src = seqs.body[i];
                if (seqs.shadow.length) { L.sh.style.visibility = 'visible'; L.sh.src = seqs.shadow[i < seqs.shadow.length ? i : i % seqs.shadow.length]; } else L.sh.style.visibility = 'hidden';
                if (seqs.weapon[i]) { L.wp.style.visibility = 'visible'; L.wp.src = seqs.weapon[i]; } else L.wp.style.visibility = 'hidden';   // 武器嚴格逐幀（本幀無→隱藏）
            };
            requestAnimationFrame(() => { _syncPortraitLayerRect(image); paint(); });
            _morphPortrait.timer = setInterval(() => {
                if (!_morphPortrait.body.length) return;
                _morphPortrait.i = (_morphPortrait.i + 1) % _morphPortrait.body.length;
                _syncPortraitLayerRect(image);   // 每幀順手同步幾何（視窗拖曳/縮放後仍對齊·讀 offset 便宜）
                paint();
            }, 125);
        };
        const probe = (pfx, arr, captureH) => {
            const step = (n) => {
                if (_morphPortrait.name !== dir) return;
                const im = new Image();
                im.onload = () => { if (captureH && n === 0) natH = im.naturalHeight; arr.push(base + pfx + n + '.png'); step(n + 1); };
                im.onerror = () => done();
                im.src = base + pfx + n + '.png';
            };
            step(0);
        };
        probe('morph_', seqs.body, true);
        probe('morph_s_', seqs.shadow, false);
        probe('morph_w_', seqs.weapon, false);
    }

    function el(id) { return document.getElementById(id); }
    function signed(n) { n = Number(n) || 0; return n > 0 ? '+' + n : String(n); }

    const EQUIPMENT_TEMPLATE_CLASS = {
        royal: '王族', knight: '騎士', mage: '法師', elf: '妖精',
        dark: '黑妖', illusion: '幻術', dragon: '龍騎', warrior: '戰士'
    };
    function equipmentTemplateUrl() {
        const cls = typeof player !== 'undefined' && player ? EQUIPMENT_TEMPLATE_CLASS[player.cls] : '';
        if (!cls) return 'assets/equipment-window-bg.png';
        const avatar = String(player.avatar || '');
        const female = avatar.startsWith('女') || (player.cls === 'royal' && player.bloodPledge === 'esti');
        return 'public/assets/login/EQ%20UI/' + encodeURIComponent((female ? '女' : '男') + cls + '.png') + '?v=20260715';
    }
    function syncEquipmentBackground() {
        const background = el('equipment-window-frame')?.querySelector('.equipment-window-bg');
        if (!background) return;
        const src = equipmentTemplateUrl();
        if (background.getAttribute('src') !== src) background.src = src;
    }

    function renderStats() {
        if (typeof player === 'undefined' || !player || !player.d) return;
        const d = player.d;
        const expReq = getExpReq(player.lv);
        const expPct = player.lv >= 100 ? 100 : (expReq > 0 && isFinite(expReq) ? (player.exp / expReq) * 100 : 0);
        const values = [
            ['level', player.lv], ['exp', expPct.toFixed(2) + '%'],
            ['hp', `${Math.floor(player.hp)}/${Math.floor(player.mhp)}`],
            ['mp', `${Math.floor(player.mp)}/${Math.floor(player.mmp)}`],
            ['ac', player.d.ac], ['elixir', player.panaceaUsed || 0], ['pk', player.pk || 0],
            ['str', d.str], ['dex', d.dex], ['con', d.con], ['int', d.int], ['wis', d.wis], ['cha', d.cha],
            ['earth', Math.abs(Number(d.resEarth) || 0)], ['water', Math.abs(Number(d.resWater) || 0)],
            ['fire', Math.abs(Number(d.resFire) || 0)], ['wind', Math.abs(Number(d.resWind) || 0)],
            ['er', Math.abs(Number(d.er) || 0)]
        ];
        el('equipment-window-stats').innerHTML = values.map(([key, value]) =>
            `<span class="equipment-stat equipment-stat-${key}">${value}</span>`
        ).join('');
        const weight = el('equipment-window-weight');
        if (weight) {
            const weightPct = Math.max(0, Math.round(Number(d.weightPct) || 0));
            const loadTier = Math.max(0, Math.min(3, Number(d.loadTier) || 0));
            weight.textContent = `負重 ${weightPct} %`;
            weight.dataset.loadTier = String(loadTier);
        }
    }

    function renderMorphSnapshot() {
        const box = el('equipment-morph-snapshot');
        if (!box || typeof player === 'undefined' || !player) return;
        const form = player._setPoly || ((player.buffs && player.buffs.poly > 0 && player.poly) ? player.poly : null);
        if (!form) { _stopMorphPortrait(); const _im = el('equipment-morph-image'); if (_im) _im.setAttribute('data-morph', ''); box.classList.add('hidden'); return; }
        box.classList.remove('hidden');
        el('equipment-morph-name').textContent = form.n || '變身';
        const aliases = {
            '真‧死亡騎士':'死亡騎士', '真死亡騎士':'死亡騎士',
            '真‧克特':'克特', '真克特':'克特',
            '高等黑暗精靈':'黑暗精靈', '真‧黑暗妖精':'黑暗精靈', '真黑暗妖精':'黑暗精靈',
            '真‧黑暗精靈':'黑暗精靈', '真黑暗精靈':'黑暗精靈',
            // 🆕 v3.0.33 借用同族立繪的別名：本尊動畫部署後即移除（v3.0.50 刪 惡魔→小惡魔/黑暗妖精刺客→黑暗刺客·v3.0.52 刪 反王肯恩→反王肯特·v3.0.57 刪 暴走兔→曼波兔/重裝歐姆→歐姆＝本尊動畫已部署）。
            // ⚠️v3.0.35 古代黑/白銀/黃金/白金 騎士/搜索隊/法師 已改名為 黑暗/銀光/黃金/白金 巡守/騎士/法師（潔尼斯→賽尼斯）＝直接對應同名立繪，故移除其別名。
        };
        const rawName = (form.n || '').replace(/[()（）·‧\s]/g, '');
        const imageName = (aliases[form.n] || form.n || '').replace(/[()（）·‧\s]/g, '');
        const image = el('equipment-morph-image');
        // 🖼️ v3.0.33 圖片退回鏈＋只在「變身名稱改變」時重載：專屬立繪(assets/morph/*.jpg) → 該怪戰鬥動畫首幀(assets/anim/<原名>/idle_0.png) → 隱藏。
        //   守衛避免 500ms 定時刷新每次都把 src 重設回可能 404 的立繪 → 退回鏈重跑造成閃爍。
        if (image.getAttribute('data-morph') !== (form.n || '')) {
            image.setAttribute('data-morph', form.n || '');
            image.classList.remove('no-image');
            image.alt = form.n || '變身快照';
            if (MORPH_ANIM_PORTRAIT.has(imageName)) {   // 🎬 v3.0.44 動態立繪（morph.spr 幀循環）
                image.onerror = null;
                _startMorphPortrait(imageName, image);
            } else {   // 其餘：舊 .jpg → 動畫首幀 → 隱藏 退回鏈
                _stopMorphPortrait();
                image.classList.remove('morph-anim-portrait');
                image.style.height = ''; image.style.flex = ''; image.style.margin = '';   // 還原動態立繪的統一尺寸覆寫
                image.setAttribute('data-morphfb', 'assets/anim/' + encodeURIComponent(rawName) + '/idle_0.png');
                image.src = 'assets/morph/' + encodeURIComponent(imageName) + '.jpg';
                image.onerror = function () {
                    const fb = (this.getAttribute('data-morphfb') || '').split('|').filter(Boolean);
                    if (fb.length) { this.setAttribute('data-morphfb', fb.slice(1).join('|')); this.src = fb[0]; }
                    else { this.onerror = null; this.classList.add('no-image'); }
                };
            }
        }
        // 🚫 v3.0.34 用戶要求：只顯示變身「名稱＋圖片」，隱藏下方能力說明文字（之後放對應動態圖）。
        //   用 inline display:none 而非 class，避免 .equipment-morph-bonus{display:flex} 與 .hidden 誰後載入的層疊順序不確定。
        const bonus = el('equipment-morph-bonus');
        bonus.textContent = '';
        bonus.style.display = 'none';
    }

    function renderSlots() {
        if (typeof player === 'undefined' || !player || !player.eq) return;
        const host = el('equipment-window-slots');
        const pageLabel = el('equipment-window-page-label');
        if (pageLabel) pageLabel.textContent = `${page + 1} / ${PAGE_SLOTS.length}　${PAGE_NAMES[page]}`;
        host.innerHTML = '';
        PAGE_SLOTS[page].forEach(pos => {
            const actualKey = pos.alt && player.eq[pos.alt] ? pos.alt : pos.k;
            const item = player.eq[actualKey];
            const data = item && typeof DB !== 'undefined' && DB.items[item.id];
            const slot = document.createElement('button');
            slot.type = 'button';
            slot.className = 'equipment-visual-slot' + (item ? ' is-filled' : ' is-empty');
            slot.style.cssText = `left:${pos.x}%;top:${pos.y}%;width:${pos.w}%;height:${pos.h}%;`;
            if (pos.visualFrame) {
                slot.style.background = 'linear-gradient(145deg,rgba(2,6,12,.94),rgba(12,18,27,.88))';
                slot.style.border = '1px solid rgba(112,128,148,.72)';
                slot.style.boxShadow = 'inset 0 0 8px #000,0 1px 2px #000';
                slot.style.borderRadius = '2px';
            }
            if (item && data) {
                const img = document.createElement('img');
                const sherineIcon = getSherineSlotIcon(pos.k);
                img.src = sherineIcon || getIconUrl(data);
                img.alt = data.n || pos.k;
                img.draggable = false;
                img.onerror = function () {
                    if (sherineIcon && this.src.indexOf('/public/') === -1) {
                        this.src = sherineIcon.replace('assets/', 'public/assets/');
                        return;
                    }
                    this.onerror = null;
                    this.style.display = 'none';
                };
                if (typeof getGlowClass === 'function') {
                    const glowClass = getGlowClass(item, data);
                    if (glowClass) img.classList.add(...glowClass.split(/\s+/).filter(Boolean));
                }
                slot.appendChild(img);
                if (item.en) {
                    const badge = document.createElement('span');
                    badge.className = 'equipment-slot-enhance';
                    badge.textContent = '+' + item.en;
                    slot.appendChild(badge);
                }
                const equippedBadge = document.createElement('span');
                equippedBadge.className = 'equipment-slot-equipped';
                equippedBadge.textContent = 'E';
                slot.appendChild(equippedBadge);
                const fullName = document.createElement('span');
                fullName.innerHTML = getItemFullName(item);
                slot.title = fullName.textContent || fullName.innerText || data.n || item.id;
                slot.onclick = function () {
                    clearTimeout(clickTimer);
                    clickTimer = setTimeout(function () {
                        openEquipmentSidePanel((data.type === 'wpn' || data.isArrow) ? 'weapons' : 'armors');
                    }, 230);
                };
                slot.ondblclick = function (event) {
                    clearTimeout(clickTimer);
                    event.preventDefault();
                    event.stopPropagation();
                    unequipItem(actualKey);
                };
            } else {
                slot.title = `${pos.n || pos.k}：尚未裝備`;
                const emptyLabel = document.createElement('span');
                emptyLabel.className = 'equipment-slot-empty-label';
                emptyLabel.textContent = pos.n || pos.k;
                slot.appendChild(emptyLabel);
                slot.onclick = function () {
                    if (page === 0) openEquipmentSidePanel((pos.k === 'wpn' || pos.k === 'offwpn' || pos.k === 'arrow') ? 'weapons' : 'armors');
                };
            }
            host.appendChild(slot);
        });
        const pageOne = el('equipment-window-prev'), pageTwo = el('equipment-window-next');
        pageOne.disabled = false;
        pageTwo.disabled = false;
        pageOne.classList.toggle('active', page === 0);
        pageTwo.classList.toggle('active', page === 1);
        pageOne.setAttribute('aria-pressed', page === 0 ? 'true' : 'false');
        pageTwo.setAttribute('aria-pressed', page === 1 ? 'true' : 'false');
    }

    function plainItemName(item) {
        const d = DB.items[item.id];
        const tmp = document.createElement('span');
        tmp.innerHTML = getItemFullName(item);
        return tmp.textContent || tmp.innerText || (d && d.n) || item.id;
    }

    function renderSidePanel() {
        const panel = el('equipment-side-panel');
        const list = el('equipment-side-list');
        if (!panel || panel.classList.contains('hidden') || !sideMode || typeof player === 'undefined') return;
        el('equipment-side-title').textContent = sideMode === 'weapons' ? '武器' : '防具與飾品';
        list.innerHTML = '';
        const items = player.inv.filter(function (item) {
            const d = DB.items[item.id];
            if (!d) return false;
            return sideMode === 'weapons' ? d.type === 'wpn' : (d.type === 'arm' || d.type === 'acc');
        });
        if (!items.length) {
            list.innerHTML = '<div class="equipment-side-empty">背包中沒有可顯示的裝備</div>';
            return;
        }
        items.forEach(function (item) {
            const d = DB.items[item.id];
            const row = document.createElement('button');
            row.type = 'button';
            row.className = 'equipment-side-item' + (checkCanEquip(item) ? '' : ' cannot-equip');
            row.title = plainItemName(item);
            const icon = document.createElement('img');
            icon.src = getIconUrl(d);
            icon.alt = '';
            icon.draggable = false;
            icon.onerror = function () { this.style.visibility = 'hidden'; };
            const name = document.createElement('span');
            name.className = 'equipment-side-name ' + getItemColor(item);
            name.innerHTML = getItemFullName(item);
            const count = document.createElement('small');
            count.textContent = (item.cnt || 1) > 1 ? '×' + (item.cnt || 1).toLocaleString() : '';
            row.append(icon, name, count);
            row.onclick = function () {
                clearTimeout(clickTimer);
                clickTimer = setTimeout(function () { openModal(item, false); }, 230);
            };
            row.ondblclick = function (event) {
                clearTimeout(clickTimer);
                event.preventDefault();
                event.stopPropagation();
                equipItem(item);
            };
            list.appendChild(row);
        });
    }

    window.openEquipmentSidePanel = function (mode) {
        sideMode = mode === 'armors' ? 'armors' : 'weapons';
        const panel = el('equipment-side-panel');
        if (!panel) return;
        panel.classList.remove('hidden');
        const frame = el('equipment-window-frame');
        if (frame) frame.classList.add('side-open');
        renderSidePanel();
        requestAnimationFrame(fitEquipmentWindowToViewport);
    };

    window.closeEquipmentSidePanel = function () {
        const panel = el('equipment-side-panel');
        if (panel) panel.classList.add('hidden');
        const frame = el('equipment-window-frame');
        if (frame) frame.classList.remove('side-open');
        sideMode = null;
        requestAnimationFrame(fitEquipmentWindowToViewport);
    };

    function fitEquipmentWindowToViewport() {
        const frame = el('equipment-window-frame');
        const win = el('equipment-window');
        if (!frame || !win || win.classList.contains('hidden')) return;
        if (win.classList.contains('equipment-window-embedded')) {
            const host = el('tab-content-panel');
            if (!host) return;
            let hostRect = host.getBoundingClientRect();
            const maxFrameWidth = 366;
            if (innerWidth <= 768) {
                const mobileFrameWidth = Math.min(hostRect.width, maxFrameWidth);
                host.style.setProperty('--equipment-panel-height', Math.ceil(mobileFrameWidth * 408 / 183) + 'px');
                hostRect = host.getBoundingClientRect();
            }
            const frameWidth = Math.max(0, Math.min(hostRect.width, maxFrameWidth, hostRect.height * 183 / 408));
            win.style.left = hostRect.left + 'px';
            win.style.top = hostRect.top + 'px';
            win.style.right = 'auto';
            win.style.bottom = 'auto';
            win.style.width = hostRect.width + 'px';
            win.style.height = hostRect.height + 'px';
            frame.style.left = '50%';
            frame.style.top = '0';
            frame.style.setProperty('width', frameWidth + 'px', 'important');
            frame.style.transform = 'translateX(-50%)';
            frame.classList.remove('side-open');
            return;
        }
        const rect = frame.getBoundingClientRect();
        const side = frame.classList.contains('side-open') ? el('equipment-side-panel') : null;
        const sideWidth = side && !side.classList.contains('hidden') ? side.getBoundingClientRect().width + 8 : 0;
        const totalWidth = rect.width + sideWidth;
        let left = rect.left, top = rect.top;
        left = Math.max(4, Math.min(left, innerWidth - totalWidth - 4));
        top = Math.max(4, Math.min(top, innerHeight - rect.height - 4));
        frame.style.left = left + 'px';
        frame.style.top = top + 'px';
        frame.style.transform = 'none';
    }

    window.refreshEquipmentWindow = function () {
        const win = el('equipment-window');
        if (!win || win.classList.contains('hidden')) return;
        syncEquipmentBackground();
        renderStats();
        renderMorphSnapshot();
        renderSlots();
        renderSidePanel();
    };

    window.setEquipmentPanelEmbedded = function (visible, targetPage) {
        const win = el('equipment-window');
        if (!win) return;
        if (Number.isInteger(targetPage)) page = Math.max(0, Math.min(PAGE_SLOTS.length - 1, targetPage));
        const host = el('tab-content-panel');
        if (host) {
            host.classList.toggle('equipment-panel-host', visible);
            if (!visible || innerWidth > 768) host.style.removeProperty('--equipment-panel-height');
        }
        win.classList.add('equipment-window-embedded');
        win.classList.toggle('hidden', !visible);
        win.setAttribute('aria-hidden', visible ? 'false' : 'true');
        if (!visible) return;
        closeEquipmentSidePanel();
        refreshEquipmentWindow();
        requestAnimationFrame(fitEquipmentWindowToViewport);
    };

    window.openEquipmentWindow = function (targetPage) {
        window._equipmentDisplayMode = 'grid';
        try { localStorage.setItem('equipmentDisplayMode', 'grid'); } catch (_) {}
        window.setEquipmentPanelEmbedded(true, targetPage);
    };

    window.toggleEquipmentWindow = function () {
        const win = el('equipment-window');
        if (!win) return;
        window.setEquipmentPanelEmbedded(win.classList.contains('hidden'));
    };

    window.closeEquipmentWindow = function () {
        const win = el('equipment-window');
        if (!win) return;
        win.classList.add('hidden');
        win.setAttribute('aria-hidden', 'true');
    };

    function init() {
        const frame = el('equipment-window-frame');
        const handle = el('equipment-window-drag');
        if (!frame || !handle) return;
        const win = el('equipment-window');
        if (win) win.classList.add('equipment-window-embedded');
        const background = frame.querySelector('.equipment-window-bg');
        if (background) {
            background.onerror = function () { this.onerror = null; this.src = 'assets/equipment-window-bg.png'; };
            syncEquipmentBackground();
        }
        el('equipment-window-close').onclick = closeEquipmentWindow;
        const textToggle = el('equipment-view-text');
        if (textToggle) textToggle.onclick = function () {
            if (typeof setEquipmentDisplayMode === 'function') setEquipmentDisplayMode('text');
        };
        el('equipment-side-close').onclick = closeEquipmentSidePanel;
        el('equipment-window-next').onclick = function () { page = 1; refreshEquipmentWindow(); };
        el('equipment-window-prev').onclick = function () { page = 0; refreshEquipmentWindow(); };

        handle.addEventListener('pointerdown', function (event) {
            const rect = frame.getBoundingClientRect();
            drag = { id: event.pointerId, dx: event.clientX - rect.left, dy: event.clientY - rect.top };
            handle.setPointerCapture(event.pointerId);
            frame.classList.add('is-dragging');
            event.preventDefault();
        });
        handle.addEventListener('pointermove', function (event) {
            if (!drag || drag.id !== event.pointerId) return;
            const side = frame.classList.contains('side-open') ? el('equipment-side-panel') : null;
            const sideWidth = side && !side.classList.contains('hidden') ? side.getBoundingClientRect().width + 8 : 0;
            const maxX = Math.max(0, innerWidth - frame.offsetWidth - sideWidth);
            const maxY = Math.max(0, innerHeight - frame.offsetHeight);
            frame.style.left = Math.max(0, Math.min(maxX, event.clientX - drag.dx)) + 'px';
            frame.style.top = Math.max(0, Math.min(maxY, event.clientY - drag.dy)) + 'px';
            frame.style.transform = 'none';
        });
        function stopDrag(event) {
            if (!drag || drag.id !== event.pointerId) return;
            drag = null;
            frame.classList.remove('is-dragging');
        }
        handle.addEventListener('pointerup', stopDrag);
        handle.addEventListener('pointercancel', stopDrag);
        window.addEventListener('resize', fitEquipmentWindowToViewport);
        // 純顯示更新：讓卷軸到期、重新變身或套裝切換能即時反映，不改動任何變身判定。
        window.setInterval(function () {
            const win = el('equipment-window');
            if (win && !win.classList.contains('hidden')) renderMorphSnapshot();
        }, 500);
    }

    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
    else init();
})();
