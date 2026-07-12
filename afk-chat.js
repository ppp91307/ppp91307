/* Supabase 全服／血盟／玩家 ID 私聊 */
(function(){
'use strict';
let client=null,user=null,channel='global',ready=false,busy=false,lastSig='',playerTag='',privateTarget='',lastPresenceAt=0;
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const el=id=>document.getElementById(id);
const cleanTag=s=>String(s||'').trim().replace(/^@/,'');
function setStatus(t,color='#94a3b8'){const x=el('chat-status');if(x){x.textContent=t;x.style.color=color;}}
function validTag(tag){return /^[\p{L}\p{N}_]{2,16}$/u.test(tag);}
function privateSeenKey(){return 'lineage_chat_private_seen_'+(user?.id||'guest');}
function loadPrivateSeen(){try{return new Set(JSON.parse(localStorage.getItem(privateSeenKey())||'[]').map(Number));}catch(e){return new Set();}}
function savePrivateSeen(seen){try{localStorage.setItem(privateSeenKey(),JSON.stringify(Array.from(seen).slice(-500)));}catch(e){}}
function showPrivateUnread(on){el('chat-private-unread')?.classList.toggle('hidden',!on);}
function markPrivateRowsSeen(rows){const seen=loadPrivateSeen();for(const m of rows||[])if(!m.mine)seen.add(Number(m.id));savePrivateSeen(seen);}
async function checkPrivateUnread(){
  if(!client||!user)return;
  try{const r=await client.rpc('chat_private_read',{p_target_tag:''});if(r.error)return;const seen=loadPrivateSeen();showPrivateUnread((r.data||[]).some(m=>!m.mine&&!seen.has(Number(m.id))));}catch(e){}
}
async function init(){
  if(ready)return true;
  if(!window.MARKET_CONFIG||!window.supabase?.createClient)return false;
  client=client||window.supabase.createClient(MARKET_CONFIG.url,MARKET_CONFIG.anonKey,{auth:{persistSession:true,autoRefreshToken:true}});
  let {data:{session}}=await client.auth.getSession();
  if(!session){const r=await client.auth.signInAnonymously();if(r.error)throw r.error;session=r.data.session;}
  user=session.user;
  const name=(window.player&&player.name)||'冒險者';
  const p=await client.rpc('market_ensure_profile',{p_name:name});if(p.error)throw p.error;
  const me=await client.rpc('player_my_identity');
  if(!me.error&&me.data){playerTag=me.data.player_tag||'';const b=el('chat-id-btn');if(b)b.textContent=playerTag?'@'+playerTag:'設定ID';}
  ready=true;setStatus(playerTag?`已連線｜@${playerTag}`:'已連線｜請設定玩家 ID',playerTag?'#86efac':'#fbbf24');return true;
}
function authorButton(name){
  const tag=cleanTag(name);
  if(name?.startsWith('@')&&validTag(tag)&&tag.toLowerCase()!==playerTag.toLowerCase())
    return `<button type="button" onclick="chatPrivate('${esc(tag)}')" title="私聊 ${esc(name)}" style="font-weight:700;color:#7dd3fc;text-decoration:underline;text-underline-offset:2px">${esc(name)}</button>`;
  return `<b style="color:#7dd3fc">${esc(name)}</b>`;
}
async function read(){
  if(document.hidden||!el('chat-panel')||el('game-screen')?.classList.contains('hidden'))return;
  try{
    if(!await init())return;
    if(Date.now()-lastPresenceAt>15000){lastPresenceAt=Date.now();const pr=await client.rpc('chat_presence');if(!pr.error&&el('chat-online-count'))el('chat-online-count').textContent=`（${Number(pr.data||0)}人）`;}
    const r=channel==='private'
      ? await client.rpc('chat_private_read',{p_target_tag:privateTarget})
      : await client.rpc('chat_read',{p_channel:channel});
    if(r.error)throw r.error;
    const rows=channel==='private'?(r.data||[]).slice().reverse():(r.data||[]);
    if(channel==='private')markPrivateRowsSeen(rows);
    await checkPrivateUnread();
    const sig=channel+'|'+privateTarget+'|'+rows.map(x=>x.id).join(',');if(sig===lastSig)return;lastSig=sig;
    const box=el('chat-messages'),wasBottom=box.scrollHeight-box.scrollTop-box.clientHeight<40;
    box.innerHTML=rows.map(m=>{
      const time=`<span style="color:#64748b">${new Date(m.created_at).toLocaleTimeString([],{hour:'2-digit',minute:'2-digit'})}</span>`;
      if(channel==='private'){
        const peer=m.mine?m.recipient:m.author;
        return `<div style="line-height:1.35;word-break:break-word">${time} <span style="color:#f9a8d4">[私聊]</span> ${authorButton(m.author)} <span style="color:#94a3b8">→</span> ${authorButton(m.recipient)}：<span style="color:#fce7f3">${esc(m.content)}</span></div>`;
      }
      return `<div style="line-height:1.35;word-break:break-word">${time} ${authorButton(m.author)}：<span style="color:#e2e8f0">${esc(m.content)}</span></div>`;
    }).join('')||`<div style="color:#64748b;text-align:center;padding:20px">${channel==='private'?'尚無私聊訊息。點玩家 ID 或按「私聊」選擇對象。':'目前沒有訊息'}</div>`;
    if(wasBottom||!box.dataset.seen){box.scrollTop=box.scrollHeight;box.dataset.seen='1';}
  }catch(e){setStatus(String(e.message||e).includes('chat_private')?'請先在 Supabase 執行 supabase-private-chat.sql':e.message,'#fca5a5');}
}
function updateTabs(){
  el('chat-tab-global')?.classList.toggle('active',channel==='global');
  el('chat-tab-clan')?.classList.toggle('active',channel==='clan');
  el('chat-tab-private')?.classList.toggle('active',channel==='private');
  const input=el('chat-input');if(input)input.placeholder=channel==='private'?(privateTarget?`私聊 @${privateTarget}…`:'先選擇私聊對象…'):'輸入訊息…';
}
window.chatSwitch=function(k){channel=k;lastSig='';updateTabs();setStatus(k==='global'?'全服聊天':'血盟聊天',k==='global'?'#7dd3fc':'#fdba74');read();};
window.chatPrivate=function(tag){
  let target=cleanTag(tag);
  if(!target){const v=prompt('輸入要私聊的玩家 ID（不用輸入 @）',privateTarget);if(v==null)return;target=cleanTag(v);}
  if(target&&!validTag(target))return alert('玩家 ID 必須為 2～16 位中文、英文、數字或底線。');
  if(target&&target.toLowerCase()===playerTag.toLowerCase())return alert('不能私聊自己。');
  privateTarget=target;channel='private';lastSig='';updateTabs();setStatus(target?`私聊對象：@${target}`:'私聊收件匣','#f9a8d4');read();
};
window.chatSend=async function(){
  const input=el('chat-input'),content=input?.value.trim();if(!content||busy)return;
  if(channel==='private'&&!privateTarget){window.chatPrivate();if(!privateTarget)return;}
  busy=true;try{if(!await init())throw new Error('連線尚未完成');const r=channel==='private'
    ?await client.rpc('chat_private_send',{p_target_tag:privateTarget,p_content:content})
    :await client.rpc('chat_send',{p_channel:channel,p_content:content});if(r.error)throw r.error;input.value='';lastSig='';await read();}
  catch(e){alert('訊息發送失敗：'+e.message);}finally{busy=false;}
};
window.chatSetId=async function(){
  try{await init();const v=prompt('設定唯一玩家 ID（2～16 位中文、英文、數字或底線）',playerTag||'');if(v==null)return;const tag=v.trim();if(!validTag(tag))return alert('ID 格式錯誤：只能使用 2～16 位中文、英文、數字或底線。');const r=await client.rpc('player_set_tag',{p_tag:tag});if(r.error)throw r.error;playerTag=tag;el('chat-id-btn').textContent='@'+tag;setStatus(`已連線｜@${tag}`,'#86efac');alert('玩家 ID 已設定：@'+tag);}catch(e){alert('設定失敗：'+e.message);}
};
function chatUpdateCollapseBtn(){const b=el('chat-collapse-btn'),p=el('chat-panel');if(b&&p)b.textContent=p.classList.contains('chat-collapsed')?'展開':'收合';}
function chatUpdateFocusBtn(){const b=el('chat-focus-btn'),p=el('chat-panel');if(b&&p)b.textContent=p.classList.contains('chat-focus-expanded')?'還原':'放大';}
function chatEnsureCollapse(){const p=el('chat-panel');if(!p||p.dataset.collapseReady)return;p.dataset.collapseReady='1';const h=p.querySelector('.panel-header'),tools=h&&h.querySelector('div.flex');if(!tools)return;const focus=document.createElement('button');focus.id='chat-focus-btn';focus.type='button';focus.className='btn px-2 py-1 text-sm';focus.onclick=()=>window.chatToggleFocus();tools.appendChild(focus);const b=document.createElement('button');b.id='chat-collapse-btn';b.type='button';b.className='btn px-2 py-1 text-sm';b.onclick=()=>window.chatToggleCollapse();tools.appendChild(b);try{p.classList.toggle('chat-collapsed',localStorage.getItem('lineage_chat_collapsed')==='1');}catch(e){}chatUpdateCollapseBtn();chatUpdateFocusBtn();}
window.chatToggleFocus=function(){const p=el('chat-panel'),col=el('col-left');if(!p||!col)return;const on=!p.classList.contains('chat-focus-expanded');p.classList.toggle('chat-focus-expanded',on);col.classList.toggle('chat-focus-mode',on);if(on)p.classList.remove('chat-collapsed');chatUpdateCollapseBtn();chatUpdateFocusBtn();setTimeout(()=>{const box=el('chat-messages');if(box)box.scrollTop=box.scrollHeight;},50);};
window.chatToggleCollapse=function(){const p=el('chat-panel'),col=el('col-left');if(!p)return;if(p.classList.contains('chat-focus-expanded')){p.classList.remove('chat-focus-expanded');col?.classList.remove('chat-focus-mode');}p.classList.toggle('chat-collapsed');try{localStorage.setItem('lineage_chat_collapsed',p.classList.contains('chat-collapsed')?'1':'0');}catch(e){}chatUpdateCollapseBtn();chatUpdateFocusBtn();};
setInterval(read,3000);if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>{chatEnsureCollapse();chatSwitch('global');read();});else{chatEnsureCollapse();chatSwitch('global');read();}
})();
