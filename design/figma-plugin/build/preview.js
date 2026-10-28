// Calcula un auto layout aproximado del árbol del simulador y exporta operaciones de dibujo (JSON)
// para revisar visualmente las páginas sin abrir Figma. Uso: node preview.js "Rol · Fan" out.json
"use strict";
const { figma } = require("./mock-figma.js");
global.__sizer = (n) => layout(n);
require(require("path").resolve(__dirname, "../rugby-app-figma-plugin/code.js"));
const P = (n) => n._props;
const isAL = (n) => P(n).layoutMode && P(n).layoutMode !== "NONE";
const charW = (n) => (P(n).fontSize || 13) * ((P(n).fontName || {}).family === "Barlow Condensed" ? 0.42 : 0.55);
const lineH = (n) => (P(n).lineHeight && P(n).lineHeight.value) || Math.round((P(n).fontSize || 13) * 1.25);

function textSize(n, w) {
  const chars = String(P(n).characters || ""); const cw = charW(n);
  if (P(n).textAutoResize === "HEIGHT" || w) {
    const width = w || n._w; const perLine = Math.max(1, Math.floor(width / cw)); let lines = 0;
    for (const para of chars.split("\n")) { let cur = 0; lines++; for (const word of para.split(" ")) { const l = word.length + (cur ? 1 : 0); if (cur + l > perLine && cur > 0) { lines++; cur = word.length; } else cur += l; } }
    return [width, lines * lineH(n)];
  }
  const longest = Math.max.apply(null, chars.split("\n").map((s) => s.length));
  return [Math.ceil(longest * cw), chars.split("\n").length * lineH(n)];
}
// Devuelve [w,h] y fija n._lw, n._lh; forcedW = ancho impuesto por FILL
function layout(n, forcedW) {
  if (P(n).visible === false) { n._lw = 0; n._lh = 0; return [0, 0]; }
  if (n._type === "TEXT") { const [w, h] = textSize(n, forcedW); n._lw = w; n._lh = h; return [w, h]; }
  if (!isAL(n)) {
    n._lw = forcedW || n._w; n._lh = n._h;
    for (const c of n._children) layout(c, P(c).layoutSizingHorizontal === "FILL" ? n._lw : undefined);
    return [n._lw, n._lh];
  }
  const horiz = P(n).layoutMode === "HORIZONTAL";
  const pl = P(n).paddingLeft || 0, pr = P(n).paddingRight || 0, pt = P(n).paddingTop || 0, pb = P(n).paddingBottom || 0, gap = P(n).itemSpacing || 0;
  const fixedW = forcedW || ((horiz ? P(n).primaryAxisSizingMode : P(n).counterAxisSizingMode) === "FIXED" ? n._w : null);
  const fixedH = (horiz ? P(n).counterAxisSizingMode : P(n).primaryAxisSizingMode) === "FIXED" ? n._h : null;
  const kids = n._children.filter((c) => P(c).visible !== false);
  const innerW = fixedW ? fixedW - pl - pr : null;
  if (!horiz) {
    let y = pt, maxW = 0;
    for (const c of kids) { const fill = P(c).layoutSizingHorizontal === "FILL" && innerW; const [w, h] = layout(c, fill ? innerW : undefined); c._lx = pl; c._ly = y; y += h + gap; maxW = Math.max(maxW, w); }
    const W = fixedW || maxW + pl + pr; const H = fixedH || (kids.length ? y - gap : y) + pb;
    const align = P(n).counterAxisAlignItems; for (const c of kids) { if (align === "CENTER") c._lx = (W - c._lw) / 2; if (align === "MAX") c._lx = W - pr - c._lw; }
    if (fixedH && P(n).primaryAxisAlignItems === "CENTER") { const used = y - gap - pt; const off = (H - pt - pb - used) / 2; kids.forEach((c) => (c._ly += off)); }
    n._lw = W; n._lh = H; return [W, H];
  }
  // horizontal
  const wrap = P(n).layoutWrap === "WRAP" && innerW;
  const sizes = kids.map((c) => (P(c).layoutSizingHorizontal === "FILL" ? null : layout(c)));
  const fillKids = kids.filter((c, i) => sizes[i] === null);
  const usedW = sizes.reduce((s, sz) => s + (sz ? sz[0] : 0), 0) + gap * Math.max(0, kids.length - 1);
  const share = fillKids.length && innerW ? Math.max(10, (innerW - usedW) / fillKids.length) : 60;
  kids.forEach((c, i) => { if (!sizes[i]) sizes[i] = layout(c, share); });
  let x = pl, y = pt, rowH = 0, maxW = 0;
  kids.forEach((c, i) => { const [w, h] = sizes[i]; if (wrap && x > pl && x + w > pl + innerW) { x = pl; y += rowH + (P(n).counterAxisSpacing || 0); rowH = 0; } c._lx = x; c._ly = y; x += w + gap; rowH = Math.max(rowH, h); maxW = Math.max(maxW, x - gap); });
  const W = fixedW || maxW + pr; const H = fixedH || y + rowH + pb;
  const al = P(n).counterAxisAlignItems; const just = P(n).primaryAxisAlignItems;
  if (!wrap) {
    const content = x - gap - pl; const free = W - pl - pr - content;
    if (just === "CENTER") kids.forEach((c) => (c._lx += free / 2));
    if (just === "MAX") kids.forEach((c) => (c._lx += free));
    if (just === "SPACE_BETWEEN" && kids.length > 1) kids.forEach((c, i) => (c._lx += (free / (kids.length - 1)) * i));
    kids.forEach((c) => { if (al === "CENTER") c._ly = (H - c._lh) / 2; if (al === "MAX") c._ly = H - pb - c._lh; });
  }
  n._lw = W; n._lh = H; return [W, H];
}
const hexOf = (p) => "#" + [p.color.r, p.color.g, p.color.b].map((v) => Math.round(v * 255).toString(16).padStart(2, "0")).join("");
function emit(n, ox, oy, ops, clip) {
  if (P(n).visible === false) return;
  const x = ox + (n._lx !== undefined ? n._lx : (P(n).x || 0)); const y = oy + (n._ly !== undefined ? n._ly : (P(n).y || 0));
  const w = n._lw || n._w, h = n._lh || n._h;
  if (n._type === "TEXT") { const f = (P(n).fills || [])[0]; ops.push({ t: "text", x, y, w, h, s: P(n).characters, size: P(n).fontSize, bold: /Bold|Semi|Medium/.test((P(n).fontName || {}).style || ""), color: f ? hexOf(f) : "#000", strike: P(n).textDecoration === "STRIKETHROUGH", wrap: P(n).textAutoResize === "HEIGHT" }); return; }
  const f = (P(n).fills || []).find((p) => p.type === "SOLID"); const s = (P(n).strokes || [])[0];
  if (n._type === "VECTOR") { ops.push({ t: "rect", x, y, w: Math.max(w, 2), h: Math.max(h, 2), stroke: s ? hexOf(s) : null }); return; }
  if (f || s) ops.push({ t: "rect", x, y, w, h, r: P(n).cornerRadius || P(n).topLeftRadius || 0, fill: f ? hexOf(f) : null, op: f ? (f.opacity === undefined ? 1 : f.opacity) : 1, stroke: s ? hexOf(s) : null, sw: P(n).strokeWeight || 1 });
  if (n._type === "FRAME" && !n._children.length && !f) ops.push({ t: "icon", x, y, w, h });
  for (const c of n._children) emit(c, x, y, ops);
}
(async () => {
  for (let i = 0; i < 400 && !global.__done; i++) await new Promise((r) => setTimeout(r, 50));
  const page = figma.root.children.find((p) => p.name === process.argv[2]);
  const ops = []; for (const c of page._children) { layout(c); emit(c, 0, 0, ops); }
  require("fs").writeFileSync(process.argv[3], JSON.stringify(ops));
  // Diagnóstico: contenido de cada teléfono que se sale de 852 px
  const phones = page.findAll((n) => n._type === "FRAME" && n._w === 393 && n._h === 852);
  const over = [];
  for (const ph of phones) for (const c of ph._children) if ((P(c).name === "Contenido" || P(c).name === "Hoja inferior") && (P(c).y || 0) + c._lh > 852 - 10) over.push(P(ph).name + " (" + Math.round((P(c).y || 0) + c._lh) + "px)");
  console.log(process.argv[2] + ": " + ops.length + " operaciones · " + phones.length + " pantallas · desbordadas: " + (over.length ? over.join(", ") : "ninguna"));
})();
