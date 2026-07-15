// 來源版介面／冒險地圖移植層。
// 僅改顯示：不碰背包資料、裝備資料、存檔格式或戰鬥計算。
(function () {
    'use strict';

    const TOWN_SCENES = {
        town_aden: '亞丁城鎮', town_giran: '奇岩城鎮', town_heine: '海音城鎮',
        town_oren: '歐瑞村莊', town_kent_castle: '肯特城', town_windwood_castle: '風木城',
        town_heine_castle: '海音城', town_elf: '妖精森林村莊', town_talking: '說話之島村莊',
        town_gludio: '燃柳村莊', town_witon: '威頓村莊', town_hyperia: '希培利亞',
        town_silver_knight: '銀騎士村莊', town_ivory_tower: '象牙塔（1~3樓）',
        town_sherine: '席琳神殿', town_silent: '沉默洞穴', town_behemoth: '貝希摩斯',
        town_flame_audience: '炎魔謁見所', town_pride: '傲慢之塔1樓',
        town_rift: '時空裂痕入口', town_pirate_village: '海賊島村莊',
        town_elder_council: '長老會議廳'
    };

    const NPC_FIXED = {
        npc_isba: '1045', npc_gilen: '237', npc_joel: '261', npc_elpin: '902', npc_narupa: '866',
        npc_ent: '847', npc_zeus_golem: '1762', npc_keluya: '1788', npc_imp: '2524', npc_basin: '118',
        npc_brabo: '31b', npc_mother: '2725', npc_ladal: '457', npc_falin: '460', npc_pan: '875',
        npc_pandora: '98', npc_linda: '949', npc_gunter: '100', npc_elf: '854', npc_robinson: '916',
        npc_elion: '920', npc_wh_elf: '918', npc_rekne: '864', npc_ryan: '727', npc_nalien: '914',
        npc_flame_shadow: '2538', npc_flame_aide: '2540', npc_flame_smith: '1768',
        npc_esti: '3227', npc_tros: '3225', npc_obel: '1049', npc_hert: '1049', npc_diren: '1049',
        npc_kupu: '1839', npc_rabiani: '1307', npc_runde: '2813', npc_kang: '2794',
        npc_brudica: '2829', npc_skvati: '2801', npc_saedia: '2820', npc_shenien: '6899',
        npc_bartel: '6757', npc_sphere: '6690', npc_dantes_lord: '5454'
    };
    const NPC_POOL = ['1256','1307','1314','1768','1305','1254','1278','1766','3858','1276','237','261','902','1045','457','460','727','914','916','918','920','949','100','118'];
    const NPC_FRAMES = { '31b': 3, '54': 3, '51': 4, '118': 4, '237': 6, '261': 4, '457': 6, '460': 6, '727': 6, '847': 6, '854': 16, '864': 6, '866': 6, '875': 12, '902': 6, '914': 6, '916': 6, '918': 6, '920': 7, '949': 6, '100': 6, '1045': 8, '1049': 6, '1222': 8, '1254': 6, '1256': 8, '1276': 21, '1278': 13, '1305': 8, '1307': 8, '1314': 6, '1762': 8, '1766': 13, '1768': 8, '1788': 6, '1839': 9, '2524': 8, '2538': 10, '2540': 10, '2725': 1, '2794': 9, '2801': 8, '2813': 9, '2820': 15, '2829': 11, '3225': 12, '3227': 12, '3858': 12, '5454': 1, '6690': 12, '6757': 12, '6804': 12, '6899': 12 };

    const POSITIONS = [
        [50,58],[35,43],[65,43],[22,64],[78,64],[38,76],[62,76],
        [18,39],[82,39],[50,30],[28,83],[72,83],[10,73],[90,73]
    ];
    const sceneProbe = new Map();
    let townSprites = [];
    let animTimer = 0;

    function ensureAbilityWindow() {
        const tab = document.getElementById('tab-stats');
        if (!tab || tab.classList.contains('ability-window-tab')) return;
        tab.className = 'ability-window-tab h-full';
        tab.innerHTML = `
            <div class="ability-window-shell">
                <div class="ability-primary-control ability-primary-str"><button class="alloc-minus hidden" onclick="adjAlloc('str',-1)">−</button><span id="dt-str">0</span><button class="alloc-plus hidden" onclick="adjAlloc('str',1)">＋</button></div>
                <div class="ability-primary-control ability-primary-dex"><button class="alloc-minus hidden" onclick="adjAlloc('dex',-1)">−</button><span id="dt-dex">0</span><button class="alloc-plus hidden" onclick="adjAlloc('dex',1)">＋</button></div>
                <div class="ability-primary-control ability-primary-con"><button class="alloc-minus hidden" onclick="adjAlloc('con',-1)">−</button><span id="dt-con">0</span><button class="alloc-plus hidden" onclick="adjAlloc('con',1)">＋</button></div>
                <div class="ability-primary-control ability-primary-int"><button class="alloc-minus hidden" onclick="adjAlloc('int',-1)">−</button><span id="dt-int">0</span><button class="alloc-plus hidden" onclick="adjAlloc('int',1)">＋</button></div>
                <div class="ability-primary-control ability-primary-wis"><button class="alloc-minus hidden" onclick="adjAlloc('wis',-1)">−</button><span id="dt-wis">0</span><button class="alloc-plus hidden" onclick="adjAlloc('wis',1)">＋</button></div>
                <div class="ability-primary-control ability-primary-cha"><button class="alloc-minus hidden" onclick="adjAlloc('cha',-1)">−</button><span id="dt-cha">0</span><button class="alloc-plus hidden" onclick="adjAlloc('cha',1)">＋</button></div>
                <div class="ability-detail-column ability-detail-left">
                    <div><span>近距離傷害</span><strong id="dt-mdmg">0</strong></div><div><span>近距離命中</span><strong id="dt-mhit">0</strong></div>
                    <div><span>近距離爆擊率</span><strong id="dt-mcrit-p">0%</strong></div><div><span>近距離爆擊傷害</span><strong id="dt-mcritdmg">0%</strong></div>
                    <div class="ability-detail-spacer"></div><div><span>遠距離傷害</span><strong id="dt-rdmg">0</strong></div><div><span>遠距離命中</span><strong id="dt-rhit">0</strong></div>
                    <div><span>遠距離爆擊率</span><strong id="dt-rcrit">0%</strong></div><div><span>遠距離爆擊傷害</span><strong id="dt-rcritdmg">0%</strong></div>
                    <div><span>迴避率</span><strong id="dt-er">0%</strong></div><div><span>HP恢復量</span><strong id="dt-hpr">0</strong></div>
                    <div><span>藥水恢復量</span><strong id="dt-potion">0%</strong></div><div><span>傷害減免</span><strong id="dt-dr">0</strong></div>
                    <div><span>移動速度</span><strong id="dt-movespeed">100%</strong></div><div><span>攻擊速度</span><strong id="dt-spd">1.0s</strong></div>
                </div>
                <div class="ability-detail-column ability-detail-right">
                    <div><span>魔法傷害</span><strong id="dt-mgdmg">0</strong></div><div><span>魔法命中</span><strong id="dt-mhit-mag">0</strong></div>
                    <div><span>額外魔法點數</span><strong id="dt-sp">0</strong></div><div><span>魔法爆擊率</span><strong id="dt-mcrit">0%</strong></div>
                    <div class="ability-magic-crit-dmg"><span>魔法爆擊傷害</span><strong id="dt-mgcritdmg">0%</strong></div><div><span>MP恢復量</span><strong id="dt-mpr">0</strong></div>
                    <div><span>MP消耗減免</span><strong id="dt-mpreduce">0%</strong></div><div><span>擊殺回魔</span><strong id="dt-mpkill">0</strong></div>
                    <div><span>魔法防禦</span><strong id="dt-mr">0</strong></div><div class="ability-detail-spacer"></div>
                    <div><span>無屬性抗性</span><strong id="dt-resnone">0</strong></div><div class="ability-res-fire"><span>火屬性抗性</span><strong id="dt-resfire">0</strong></div>
                    <div class="ability-res-water"><span>水屬性抗性</span><strong id="dt-reswater">0</strong></div><div class="ability-res-wind"><span>風屬性抗性</span><strong id="dt-reswind">0</strong></div>
                    <div class="ability-res-earth"><span>地屬性抗性</span><strong id="dt-researth">0</strong></div>
                </div>
                <div class="ability-hidden-values"><span id="dt-edmg">0</span><span id="dt-ehit">0</span></div><div id="dt-buffs" class="ability-buffs"></div>
                <div id="alloc-edit-bar" class="hidden ability-respec-overlay"><span id="alloc-bar-label" class="ability-respec-points">0</span><div class="ability-respec-actions"><span id="alloc-bar-hint">以上方 ＋／− 重新分配，確認後才會消耗回憶蠟燭</span><div><button id="alloc-confirm-btn" onclick="confirmRespec()" class="hidden">確認</button><button id="alloc-cancel-btn" onclick="cancelRespec()" class="hidden">取消</button></div></div></div>
            </div>`;
        const statsButton = document.querySelector('.tab-bar button');
        if (statsButton) statsButton.onclick = function () { if (typeof switchTab === 'function') switchTab('stats', statsButton); };
    }

    function syncAbilityExtras() {
        if (typeof player === 'undefined' || !player || !player.d) return;
        const d = player.d;
        const put = function (id, value) { const el = document.getElementById(id); if (el) el.textContent = value; };
        put('dt-mcritdmg', (d.meleeCritDmg || 0) + '%');
        put('dt-rcritdmg', (d.rangedCritDmg || 0) + '%');
        put('dt-mgcritdmg', (d.magicCritDmg || 0) + '%');
        let potion = 0;
        try { potion = (typeof getConPotionPct === 'function' ? getConPotionPct(d.con || 0) : 0) + (typeof dollFieldVal === 'function' ? dollFieldVal('potionBonus') : 0) + (player._miscPotionBonus || 0); } catch (e) {}
        put('dt-potion', Math.round(potion) + '%');
        put('dt-movespeed', (100 + (d.moveSpeedPct || 0)) + '%');
        put('dt-mpkill', typeof getWisMpOnKill === 'function' ? getWisMpOnKill(d.wis || 0) : 0);
        put('dt-mr', d.mr || 0);
        put('dt-resnone', Math.round(d.resNone || 0));
    }

    const BAG_PANEL_IDS = ['tab-weapons', 'tab-armors', 'tab-items'];

    function captureBagScrolls() {
        const saved = {};
        BAG_PANEL_IDS.forEach(function (id) {
            const panel = document.getElementById(id);
            if (!panel) return;
            const viewport = panel.querySelector(':scope > .classic-inventory-shell > .classic-inventory-viewport');
            saved[id] = {
                panelTop: panel.scrollTop || 0,
                gridTop: viewport ? (viewport.scrollTop || 0) : 0
            };
        });
        return saved;
    }

    function restoreBagScrolls(saved) {
        if (!saved) return;
        const apply = function () {
            BAG_PANEL_IDS.forEach(function (id) {
                const pos = saved[id];
                const panel = document.getElementById(id);
                if (!pos || !panel) return;
                panel.scrollTop = pos.panelTop || 0;
                const viewport = panel.querySelector(':scope > .classic-inventory-shell > .classic-inventory-viewport');
                if (viewport) viewport.scrollTop = pos.gridTop || 0;
            });
        };
        // 先立即恢復，再等瀏覽器完成格子高度計算後補套一次。
        apply();
        window.requestAnimationFrame(apply);
    }

    function bagMode() {
        try { return localStorage.getItem('lineage-bag-view') === 'text' ? 'text' : 'grid'; } catch (e) { return 'grid'; }
    }

    function setBagMode(mode) {
        try { localStorage.setItem('lineage-bag-view', mode); } catch (e) {}
        decorateBagPanels(true);
    }

    function decorateBagPanels(force, preservedScrolls) {
        const savedScrolls = preservedScrolls || captureBagScrolls();
        const mode = bagMode();
        BAG_PANEL_IDS.forEach(function (id) {
            const panel = document.getElementById(id);
            if (!panel) return;
            const hasShell = !!panel.querySelector(':scope > .classic-inventory-shell');
            const hasSwitch = !!panel.querySelector(':scope > .bag-mode-switch');
            const complete = mode === 'grid' ? (hasShell && hasSwitch) : (!hasShell && hasSwitch);
            if (!force && panel.dataset.bagDecorated === mode && complete) return;

            const oldShell = panel.querySelector(':scope > .classic-inventory-shell');
            if (oldShell) Array.from(oldShell.querySelectorAll(':scope > .classic-inventory-viewport > .list-item')).forEach(function (row) { panel.insertBefore(row, oldShell); });
            if (oldShell) oldShell.remove();
            const oldSwitch = panel.querySelector(':scope > .bag-mode-switch');
            if (oldSwitch) oldSwitch.remove();
            panel.classList.toggle('bag-grid-view', mode === 'grid');
            panel.classList.toggle('bag-text-view', mode === 'text');

            if (mode === 'grid') {
                const rows = Array.from(panel.querySelectorAll(':scope > .list-item'));
                const shell = document.createElement('div');
                shell.className = 'classic-inventory-shell';
                const viewport = document.createElement('div');
                viewport.className = 'classic-inventory-viewport';
                rows.forEach(function (row) {
                    row.classList.add('bag-grid-item');
                    const uid = row.dataset.invUid;
                    let item = null;
                    if (uid && typeof player !== 'undefined') item = (player.inv || []).find(function (x) { return String(x.uid) === String(uid); });
                    if (item && (item.cnt || 1) > 1 && !row.querySelector('.classic-icon-corner-value')) {
                        const badge = document.createElement('span');
                        badge.className = 'classic-icon-corner-value is-count';
                        badge.dataset.bagCount = '1';
                        badge.textContent = Number(item.cnt || 1).toLocaleString();
                        row.appendChild(badge);
                    }
                    viewport.appendChild(row);
                });
                for (let i = rows.length; i < Math.max(24, Math.ceil(rows.length / 4) * 4); i++) {
                    const empty = document.createElement('div'); empty.className = 'classic-grid-empty'; viewport.appendChild(empty);
                }
                shell.appendChild(viewport);
                panel.appendChild(shell);
            } else {
                panel.querySelectorAll('.bag-grid-item').forEach(function (row) { row.classList.remove('bag-grid-item'); });
                panel.querySelectorAll('[data-bag-count="1"]').forEach(function (badge) { badge.remove(); });
            }

            const toggle = document.createElement('button');
            toggle.type = 'button';
            toggle.className = 'bag-mode-switch';
            toggle.textContent = mode === 'grid' ? '切換文字背包' : '切換格子背包';
            toggle.onclick = function () { setBagMode(mode === 'grid' ? 'text' : 'grid'); };
            panel.appendChild(toggle);
            panel.dataset.bagDecorated = mode;
        });
        restoreBagScrolls(savedScrolls);
    }

    function sceneUrl(name) {
        return 'assets/area/1920x1080/' + encodeURIComponent(name) + '.jpg';
    }

    function ensureTownMap() {
        const view = document.getElementById('town-view');
        if (!view) return null;
        let map = document.getElementById('town-npc-map');
        if (!map) {
            map = document.createElement('div');
            map.id = 'town-npc-map';
            const oldList = document.getElementById('town-npc-container');
            view.insertBefore(map, oldList || view.firstChild);
        }
        return map;
    }

    function visibleNpcs(townId) {
        // DB 是原遊戲以 top-level const 宣告，並不會成為 window.DB。
        const town = (typeof DB !== 'undefined' && DB.towns) ? DB.towns[townId] : null;
        if (!town) return [];
        return (town.npcs || []).filter(function (npc) {
            if (npc.darkOnly && typeof player !== 'undefined' && player.cls !== 'dark') return false;
            if (npc.classicHide && typeof player !== 'undefined' && player.classicMode) return false;
            if (/_castle$/.test(townId) && typeof player !== 'undefined') {
                if (npc.id === 'npc_esti' && player.bloodPledge !== 'esti') return false;
                if (npc.id === 'npc_tros' && player.bloodPledge !== 'tros') return false;
            }
            return true;
        });
    }

    function spriteFor(npc, index, used) {
        let key = NPC_FIXED[npc.id];
        if (!key && npc.type === 'warehouse') key = '54';
        if (!key && npc.type === 'ally') key = '51';
        if (!key && npc.type === 'castleguard') key = '1222';
        if (!key) {
            let seed = 0;
            for (let i = 0; i < String(npc.id || '').length; i++) seed += String(npc.id).charCodeAt(i);
            for (let i = 0; i < NPC_POOL.length; i++) {
                const candidate = NPC_POOL[(seed + index + i) % NPC_POOL.length];
                if (!used.has(candidate)) { key = candidate; break; }
            }
        }
        key = key || '1256';
        used.add(key);
        return key;
    }

    function renderTownScene(townId) {
        const map = ensureTownMap();
        if (!map) return;
        const scene = TOWN_SCENES[townId] || '村莊周邊';
        map.style.backgroundImage = 'linear-gradient(rgba(10,12,18,.08),rgba(10,12,18,.23)),url("' + sceneUrl(scene) + '")';
        map.classList.toggle('show-labels', typeof window._showMobStatus === 'undefined' || !!window._showMobStatus);
        map.innerHTML = '';
        townSprites = [];
        const used = new Set();
        visibleNpcs(townId).forEach(function (npc, index) {
            const key = spriteFor(npc, index, used);
            const p = POSITIONS[index % POSITIONS.length];
            const wrap = Math.floor(index / POSITIONS.length);
            const node = document.createElement('button');
            node.type = 'button';
            node.className = 'town-npc';
            node.style.left = Math.min(93, p[0] + wrap * 2) + '%';
            node.style.top = Math.min(91, p[1] + wrap * 2) + '%';
            node.style.zIndex = String(Math.round(p[1] * 10));
            node.setAttribute('aria-label', (npc.n || 'NPC') + ' ' + (npc.title || ''));
            node.innerHTML = '<span class="tn-label"><span class="tn-name"></span><span class="tn-title"></span></span>' +
                '<img class="tn-shadow" alt="" src="assets/npc/' + key + '/idle_s_0.png">' +
                '<img class="tn-body" alt="" src="assets/npc/' + key + '/idle_0.png">';
            node.querySelector('.tn-name').textContent = npc.n || 'NPC';
            node.querySelector('.tn-title').textContent = npc.title || '';
            const shadow = node.querySelector('.tn-shadow');
            shadow.addEventListener('load', function () { node.classList.add('has-tn-shadow'); }, { once: true });
            shadow.addEventListener('error', function () { shadow.remove(); }, { once: true });
            node.addEventListener('click', function () {
                if (typeof interactNPC === 'function') interactNPC(npc.id, townId);
            });
            map.appendChild(node);
            townSprites.push({ img: node.querySelector('.tn-body'), key: key, count: NPC_FRAMES[key] || 1, phase: index * 2 });
        });
        const list = document.getElementById('town-npc-container');
        if (list) list.classList.add('hidden');
    }

    function tickTownSprites() {
        if (!townSprites.length) return;
        const map = document.getElementById('town-npc-map');
        if (!map || map.offsetParent === null) return;
        const frame = Math.floor(Date.now() / 140);
        townSprites.forEach(function (s) {
            const n = (frame + s.phase) % s.count;
            const src = 'assets/npc/' + s.key + '/idle_' + n + '.png';
            if (!s.img.src.endsWith('/idle_' + n + '.png')) s.img.src = src;
        });
    }

    function selectedMapName() {
        if (typeof mapState !== 'undefined' && typeof mapDisplayName === 'function') {
            const mapped = mapDisplayName(mapState.current);
            if (mapped) return mapped;
        }
        const select = document.getElementById('map-select');
        if (select && select.selectedIndex >= 0) return (select.options[select.selectedIndex].textContent || '').trim();
        return '';
    }

    function upgradeBattleScene() {
        if (typeof mapState === 'undefined' || !mapState.current || String(mapState.current).startsWith('town_')) return;
        const name = selectedMapName();
        if (!name) return;
        const key = String(mapState.current) + '|' + name;
        if (sceneProbe.get(key) === false) return;
        const apply = function () {
            const battle = document.getElementById('battle-view');
            if (!battle || typeof mapState === 'undefined' || String(mapState.current).startsWith('town_')) return;
            battle.style.backgroundImage = 'url("' + sceneUrl(name) + '")';
            battle.style.backgroundSize = 'cover';
            battle.style.backgroundPosition = 'center';
            battle.classList.add('has-bg', 'area-fit');
        };
        if (sceneProbe.get(key) === true) { apply(); return; }
        const img = new Image();
        img.onload = function () { sceneProbe.set(key, true); apply(); };
        img.onerror = function () { sceneProbe.set(key, false); };
        img.src = sceneUrl(name);
    }

    function installHooks() {
        ensureAbilityWindow();
        ensureTownMap();
        const originalTown = window.renderTownNPCs;
        if (typeof originalTown === 'function' && !originalTown.__visualTownPort) {
            const wrappedTown = function (townId) {
                originalTown.apply(this, arguments);
                renderTownScene(townId);
            };
            wrappedTown.__visualTownPort = true;
            window.renderTownNPCs = wrappedTown;
            try { renderTownNPCs = wrappedTown; } catch (e) {}
        }
        const originalBg = window.applyAreaBackground;
        if (typeof originalBg === 'function' && !originalBg.__visualTownPort) {
            const wrappedBg = function () {
                const out = originalBg.apply(this, arguments);
                const current = (typeof mapState !== 'undefined') ? mapState.current : null;
                if (current && String(current).startsWith('town_')) renderTownScene(current);
                else upgradeBattleScene();
                return out;
            };
            wrappedBg.__visualTownPort = true;
            window.applyAreaBackground = wrappedBg;
            try { applyAreaBackground = wrappedBg; } catch (e) {}
        }
        const originalTabs = window.renderTabs;
        if (typeof originalTabs === 'function' && !originalTabs.__bagViewPort) {
            const wrappedTabs = function () {
                const bagScrolls = captureBagScrolls();
                const out = originalTabs.apply(this, arguments);
                decorateBagPanels(false, bagScrolls);
                return out;
            };
            wrappedTabs.__bagViewPort = true;
            window.renderTabs = wrappedTabs;
            try { renderTabs = wrappedTabs; } catch (e) {}
        }
        if (!animTimer) animTimer = window.setInterval(tickTownSprites, 140);
        window.setInterval(syncAbilityExtras, 500);
        window.setTimeout(function () {
            try { if (typeof updateUI === 'function') updateUI(); } catch (e) {}
            decorateBagPanels(true);
            syncAbilityExtras();
        }, 0);
        const current = (typeof mapState !== 'undefined') ? mapState.current : null;
        if (current && String(current).startsWith('town_')) renderTownScene(current);
        else upgradeBattleScene();
    }

    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', installHooks, { once: true });
    else installHooks();
})();
