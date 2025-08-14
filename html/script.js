// ===== Helpers / NUI =====
const RES = (typeof GetParentResourceName === "function") ? GetParentResourceName() : "bread_propplacer";
function nui(event, payload) {
  try {
    fetch(`https://${RES}/${event}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload || {})
    });
  } catch (e) {}
}
const $ = (id)=>document.getElementById(id);

// ===== DOM refs =====
const wrap        = $("wrap");
const search      = $("search");
const listEl      = $("item-list");
const reticle     = $("reticle");
const reticleHelp = $("reticle-help");

// details
const details       = $("details");
const dTitle        = $("d-title");
const dItem         = $("d-item");
const dModel        = $("d-model-code");
const dHash         = $("d-hash-code");
const dClose        = $("d-close");
const btnCopyModel  = $("btn-copy-model");
const btnCopyHash   = $("btn-copy-hash");
const btnPlace      = $("btn-place");

// top placement tooltip
const placeTip = document.getElementById("place-tip");
function setPlaceTip(show, htmlText){
  if (!placeTip) return;
  if (typeof htmlText === "string") placeTip.innerHTML = htmlText;
  // use a class so we get a smooth fade/slide animation
  placeTip.classList.toggle("active", !!show);
}


// ===== State =====
let allItems = [];
let filtered = [];
let searchTerm = "";
let currentDetail = null;

// ===== Render catalog =====
function tagPill(text){
  const s = document.createElement("span");
  s.textContent = text;
  s.style.cssText = "margin-left:6px;padding:2px 6px;border-radius:6px;background:rgba(255,255,255,0.06);font-size:11px;color:#cfcfcf;";
  return s;
}
function itemRow(it){
  const row = document.createElement("div"); row.className = "row";
  const left = document.createElement("div"); left.style.cssText = "flex:1;min-width:0;";
  const title = document.createElement("div"); title.className="title"; title.textContent = it.label || it.model;
  const sub = document.createElement("div"); sub.className="sub";
  const code = document.createElement("code"); code.textContent = it.model;
  sub.appendChild(code); (it.tags||[]).forEach(t=>sub.appendChild(tagPill(t)));
  left.append(title, sub);

  const btn = document.createElement("button");
  btn.className="place"; btn.textContent = "Details";
  btn.addEventListener("click", ()=>openDetails(it));

  row.append(left, btn);
  return row;
}
function render(){
  listEl.innerHTML = "";
  const src = filtered.length ? filtered : allItems;
  if (!src.length) {
    const empty = document.createElement("div");
    empty.textContent = "No props match your search.";
    empty.style.cssText = "opacity:.7;padding:18px;";
    listEl.appendChild(empty);
    return;
  }
  const frag = document.createDocumentFragment();
  src.forEach(it => frag.appendChild(itemRow(it)));
  listEl.appendChild(frag);
}

// ===== Search =====
function applyFilter(){
  const q = (searchTerm||"").trim().toLowerCase();
  if (!q) { filtered = []; render(); return; }
  filtered = allItems.filter(it=>{
    const label=(it.label||"").toLowerCase();
    const model=(it.model||"").toLowerCase();
    const tags =(it.tags||[]).join(" ").toLowerCase();
    return label.includes(q)||model.includes(q)||tags.includes(q);
  });
  render();
}
let searchTimer=null;
if (search){
  search.addEventListener("input",(e)=>{
    searchTerm = e.target.value || "";
    clearTimeout(searchTimer);
    searchTimer = setTimeout(applyFilter,80);
  });
}

// ===== Reticle overlay =====
function setReticle(show, hit, text){
  if (!reticle) return;
  reticle.style.display = show ? "block" : "none";
  reticle.classList.toggle("hit", !!hit);
  if (typeof text === "string" && reticleHelp) reticleHelp.textContent = text;
}

// ===== Details + preview =====
function hexHashFromModelName(name){
  return "0x" + (Array.from(name).reduce((a,c)=>((a<<5)-a)+c.charCodeAt(0)|0,0)>>>0)
    .toString(16).padStart(8,"0").toUpperCase();
}
function openDetails(it){
  currentDetail = it;
  details.style.display = "block";
  dTitle.textContent = it.label || it.model;
  dItem.textContent  = it.label || it.model;
  dModel.textContent = it.model;
  dHash.textContent  = hexHashFromModelName(it.model);
  nui("catalog_preview_start", { model: it.model });
}
function closeDetails(){
  details.style.display = "none";
  nui("catalog_preview_stop", {});
}
if (dClose) dClose.addEventListener("click", closeDetails);
if (btnCopyModel) btnCopyModel.addEventListener("click", ()=>navigator.clipboard.writeText(dModel.textContent));
if (btnCopyHash)  btnCopyHash.addEventListener("click", ()=>navigator.clipboard.writeText(dHash.textContent));
if (btnPlace)     btnPlace.addEventListener("click", ()=>{
  if (!currentDetail) return;
  nui("catalog_preview_stop", {});
  nui("catalog_pick", { model: currentDetail.model });
  closeDetails();
});

// ===== NUI message router =====
window.addEventListener("message", (e)=>{
  const d = e.data || {};
  switch (d.action) {
    case "open":
      wrap.style.display = "flex";
      allItems = Array.isArray(d.items) ? d.items : [];
      searchTerm = ""; if (search) search.value = "";
      filtered = []; render(); setTimeout(()=>search && search.focus(), 30);
      break;
    case "close": wrap.style.display = "none"; break;

    // placement tooltip mapping
    case "showHelp":
      setPlaceTip(true, '<b>G</b> Place • <b>H</b> Cancel • <b>Q/E</b> Rotate • <b>PgUp/PgDn</b> Raise/Lower • <b>Shift</b> Snap • <b>Delete</b> Grid');
      break;
    case "hideHelp":
      setPlaceTip(false);
      break;

    case "reticle": setReticle(!!d.show, !!d.hit, d.text); break;
    case "toast":   console.log("[bread_propplacer]", d.message); break;
  }
});

// close button + Esc
const closeBtn = document.getElementById("btn-close");
if (closeBtn) closeBtn.addEventListener("click", ()=>nui("catalog_close", {}));
window.addEventListener("keydown",(ev)=>{
  if (ev.key === "Escape" && wrap && wrap.style.display !== "none") {
    nui("catalog_close", {});
  }
});
