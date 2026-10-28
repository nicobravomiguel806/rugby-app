// ═══════════════════════════════════════════════════════════════════════════
// Rugby App · Constructor de flujos para Figma
// Crea: Atomic Design iOS, Atomic Design Android y una página por rol con
// cada historia de usuario, su flujo completo de pantallas, sus dependencias
// y los enlaces a Notion.
// ═══════════════════════════════════════════════════════════════════════════

figma.showUI(__html__, { width: 460, height: 420 });
const log = (msg) => figma.ui.postMessage({ type: "log", msg });

// ── Paleta ─────────────────────────────────────────────────────────────────
const hex = (h) => { const n = parseInt(h.replace("#", ""), 16); return { r: ((n >> 16) & 255) / 255, g: ((n >> 8) & 255) / 255, b: (n & 255) / 255 }; };
const solid = (h, opacity) => [{ type: "SOLID", color: hex(h), opacity: opacity === undefined ? 1 : opacity }];
const LIGHT = { bg: "#F5F3EE", surface: "#FFFFFF", surface2: "#EDEAE2", text: "#14171A", muted: "#5E6670", border: "#E3DFD6", primary: "#0F4D32", onPrimary: "#FFFFFF", accent: "#F2B705" };
const DARK = { bg: "#0B0F0D", surface: "#18201C", surface2: "#232D28", text: "#FFFFFF", muted: "#A9B4AE", border: "#2E3A34", primary: "#2FBF71", onPrimary: "#0B0F0D", accent: "#FFD23F" };
const STATE = { yellow: "#F5C518", red: "#D7263D", ok: "#1E8E4E", warn: "#B26A00", warnBg: "#FFF4DB", info: "#2D5BA8", tap: "#F2B705" };
const BOARD = { page: "#1E1E1E", header: "#D9D9D9", headerText: "#000000", story: "#E6E6E6", muted: "#A0A0A0", link: "#8AB4F8" };

// ── Tipografías ────────────────────────────────────────────────────────────
const FONTS = {};
async function pick(cands) {
  for (const f of cands) { try { await figma.loadFontAsync(f); return f; } catch (e) { /* siguiente */ } }
  throw new Error("No se pudo cargar ninguna fuente de: " + cands.map((f) => f.family + " " + f.style).join(", "));
}
async function loadFonts() {
  const inter = (s) => ({ family: "Inter", style: s });
  FONTS.ios = {
    r: await pick([{ family: "SF Pro Text", style: "Regular" }, { family: "SF Pro", style: "Regular" }, inter("Regular")]),
    m: await pick([{ family: "SF Pro Text", style: "Semibold" }, { family: "SF Pro", style: "Semibold" }, inter("Semi Bold")]),
    b: await pick([{ family: "SF Pro Display", style: "Bold" }, { family: "SF Pro", style: "Bold" }, inter("Bold")]),
  };
  FONTS.android = {
    r: await pick([{ family: "Roboto", style: "Regular" }, inter("Regular")]),
    m: await pick([{ family: "Roboto", style: "Medium" }, inter("Medium")]),
    b: await pick([{ family: "Roboto", style: "Bold" }, inter("Bold")]),
  };
  FONTS.cond = await pick([{ family: "Barlow Condensed", style: "Bold" }, { family: "Roboto Condensed", style: "Bold" }, inter("Bold")]);
  FONTS.condX = await pick([{ family: "Barlow Condensed", style: "ExtraBold" }, { family: "Barlow Condensed", style: "Bold" }, inter("Extra Bold"), inter("Bold")]);
  FONTS.board = { r: inter("Regular"), m: inter("Semi Bold"), b: inter("Bold") };
  await figma.loadFontAsync(inter("Regular")); await figma.loadFontAsync(inter("Semi Bold")); await figma.loadFontAsync(inter("Bold"));
}

// ── Utilidades de nodos ────────────────────────────────────────────────────
function T(chars, size, font, color, opts) {
  opts = opts || {};
  const t = figma.createText();
  t.fontName = font;
  t.fontSize = size;
  t.characters = String(chars);
  t.fills = solid(color);
  if (opts.lh) t.lineHeight = { unit: "PIXELS", value: opts.lh };
  if (opts.align) t.textAlignHorizontal = opts.align;
  if (opts.strike) t.textDecoration = "STRIKETHROUGH";
  if (opts.name) t.name = opts.name;
  if (opts.w) { t.textAutoResize = "HEIGHT"; t.resize(opts.w, t.height); } else t.textAutoResize = "WIDTH_AND_HEIGHT";
  return t;
}
function AL(dir, o) {
  o = o || {};
  const f = o.component ? figma.createComponent() : figma.createFrame();
  f.layoutMode = dir;
  f.primaryAxisSizingMode = "AUTO";
  f.counterAxisSizingMode = "AUTO";
  f.fills = o.fill ? solid(o.fill, o.opacity) : [];
  f.itemSpacing = o.gap || 0;
  const p = o.pad === undefined ? 0 : o.pad;
  f.paddingLeft = o.pl !== undefined ? o.pl : (o.px !== undefined ? o.px : p);
  f.paddingRight = o.pr !== undefined ? o.pr : (o.px !== undefined ? o.px : p);
  f.paddingTop = o.pt !== undefined ? o.pt : (o.py !== undefined ? o.py : p);
  f.paddingBottom = o.pb !== undefined ? o.pb : (o.py !== undefined ? o.py : p);
  if (o.r) f.cornerRadius = o.r;
  if (o.stroke) { f.strokes = solid(o.stroke); f.strokeWeight = o.sw || 1; f.strokeAlign = "INSIDE"; }
  if (o.align) f.counterAxisAlignItems = o.align;       // MIN | CENTER | MAX
  if (o.justify) f.primaryAxisAlignItems = o.justify;   // MIN | CENTER | MAX | SPACE_BETWEEN
  // resize() deja ambos ejes en FIXED: primero se redimensiona y después se devuelve AUTO al eje que debe abrazar su contenido
  if (o.w || o.h) {
    f.resize(o.w || Math.max(1, f.width), o.h || Math.max(1, f.height));
    const wAxisPrimary = dir === "HORIZONTAL";
    f.primaryAxisSizingMode = (wAxisPrimary ? o.w : o.h) ? "FIXED" : "AUTO";
    f.counterAxisSizingMode = (wAxisPrimary ? o.h : o.w) ? "FIXED" : "AUTO";
  }
  if (o.name) f.name = o.name;
  if (o.clip !== undefined) f.clipsContent = o.clip;
  if (o.wrap) { f.layoutWrap = "WRAP"; f.counterAxisSpacing = o.gap || 0; }
  return f;
}
function add(parent, child, fill) { parent.appendChild(child); if (fill) child.layoutSizingHorizontal = "FILL"; return child; }
function svg(markup, size, name) { const n = figma.createNodeFromSvg(markup); n.resize(size, size); n.name = name || "Icono"; return n; }
function setText(node, name, value) {
  const t = node.findOne((n) => n.type === "TEXT" && n.name === name);
  if (t && value !== undefined && value !== null) t.characters = String(value);
  return t;
}
function highlight(node) { node.strokes = solid(STATE.tap); node.strokeWeight = 3; node.strokeAlign = "OUTSIDE"; }
function link(textNode, value, type) {
  try { textNode.setRangeHyperlink(0, textNode.characters.length, { type: type || "URL", value: value }); } catch (e) { /* hipervínculo opcional */ }
  return textNode;
}

// ── Iconos (trazo 2 px, 24×24) ─────────────────────────────────────────────
const ICONS = {
  Inicio: '<path d="M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/>',
  Torneos: '<path d="M8 21h8M12 17v4M7 4h10v5a5 5 0 0 1-10 0zM7 6H4a3 3 0 0 0 3 4M17 6h3a3 3 0 0 1-3 4"/>',
  Partido: '<circle cx="12" cy="13" r="8"/><path d="M12 9v4l2.5 2.5M10 2h4"/>',
  Equipos: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/><circle cx="9" cy="7" r="4"/>',
  Perfil: '<circle cx="12" cy="8" r="4"/><path d="M4 21v-1a6 6 0 0 1 6-6h4a6 6 0 0 1 6 6v1"/>',
  Atras: '<path d="m15 18-6-6 6-6"/>',
  Buscar: '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
  Check: '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
  Candado: '<rect x="4" y="10.5" width="16" height="10.5" rx="2.5"/><path d="M8 10.5V7.5a4 4 0 0 1 8 0v3"/>',
  SinRed: '<path d="M2 2l20 20M8.5 16.5a5 5 0 0 1 7 0M5 13a10 10 0 0 1 5.2-2.8M19 13a10 10 0 0 0-2-1.5M2 8.8a15 15 0 0 1 4.2-2.6M22 8.8A15 15 0 0 0 11 5"/>',
  Pausa: '<path d="M9 5v14M15 5v14"/>',
  Mas: '<path d="M12 5v14M5 12h14"/>',
  Documento: '<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5M9 13h6M9 17h6"/>',
  Campana: '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9M10.3 21a1.94 1.94 0 0 0 3.4 0"/>',
};
function icon(name, size, color) {
  return svg('<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><g stroke="' + color + '" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none">' + ICONS[name] + "</g></svg>", size, "Icono/" + name);
}
const LOGO = '<svg width="28" height="28" viewBox="0 0 28 28" fill="none" xmlns="http://www.w3.org/2000/svg"><rect width="28" height="28" rx="8" fill="#0F4D32"/><ellipse cx="14" cy="14" rx="10" ry="6" transform="rotate(-35 14 14)" fill="#F2B705"/><path d="M10.5 17.5 17.5 10.5M11.8 12.6l1.3 1.3M13.4 11l1.3 1.3M14.9 15.9l1.3 1.3" stroke="#0F4D32" stroke-width="1.4" stroke-linecap="round"/></svg>';

// ═══════════════════════════════════════════════════════════════════════════
// ATOMIC DESIGN — componentes por plataforma
// ═══════════════════════════════════════════════════════════════════════════
const PLAT = {
  ios: { key: "ios", label: "iOS", btnR: 12, btnH: 50, chipR: 100, fieldR: 12, cardR: 16, navTitleAlign: "CENTER", tabH: 83, statusH: 54 },
  android: { key: "android", label: "Android", btnR: 20, btnH: 48, chipR: 8, fieldR: 4, cardR: 12, navTitleAlign: "MIN", tabH: 80, statusH: 40 },
};
const C = { ios: {}, android: {} };

function comp(name, dir, o) { const c = AL(dir, Object.assign({ component: true }, o || {})); c.name = name; return c; }

function buildComponents(pl, place) {
  const Fn = FONTS[pl.key]; const L = LIGHT; const K = C[pl.key];

  // Barra de estado (claro / oscuro)
  for (const mode of ["Claro", "Oscuro"]) {
    const pal = mode === "Claro" ? LIGHT : DARK;
    const c = comp("Barra de estado/" + mode, "HORIZONTAL", { w: 393, h: pl.statusH, px: pl.key === "ios" ? 32 : 20, justify: "SPACE_BETWEEN", align: "CENTER", fill: pal.bg });
    add(c, T("9:41", pl.key === "ios" ? 16 : 14, Fn.m, pal.text, { name: "Hora" }));
    add(c, svg('<svg width="66" height="12" viewBox="0 0 66 12" xmlns="http://www.w3.org/2000/svg"><rect x="0" y="6" width="3" height="5" rx="1" fill="' + pal.text + '"/><rect x="5" y="4" width="3" height="7" rx="1" fill="' + pal.text + '"/><rect x="10" y="2" width="3" height="9" rx="1" fill="' + pal.text + '"/><rect x="15" y="0" width="3" height="11" rx="1" fill="' + pal.text + '"/><rect x="40" y="0.5" width="22" height="11" rx="3" stroke="' + pal.text + '" fill="none" opacity="0.4"/><rect x="42" y="2.5" width="18" height="7" rx="1.5" fill="' + pal.text + '"/></svg>', 66, "Indicadores"));
    c.children[1].resize(66, 12);
    K["status" + mode] = c; place(c, "Organismos");
  }
  // Botones
  const kinds = { Primario: [L.primary, L.onPrimary, null], Secundario: [L.surface, L.primary, L.primary], Texto: [null, L.primary, null], Destructivo: [STATE.red, "#FFFFFF", null], Apple: ["#000000", "#FFFFFF", null] };
  for (const k in kinds) {
    const [bg, fg, st] = kinds[k];
    const c = comp("Botón/" + k, "HORIZONTAL", { w: 361, h: pl.btnH, r: pl.btnR, justify: "CENTER", align: "CENTER", fill: bg || undefined, stroke: st || undefined, sw: 1.5 });
    add(c, T(pl.key === "android" ? "Continuar" : "Continuar", pl.key === "ios" ? 17 : 15, Fn.m, fg, { name: "Etiqueta" }));
    K["btn" + k] = c; place(c, "Moléculas");
  }
  // Chips
  for (const k of ["Activo", "Inactivo"]) {
    const on = k === "Activo";
    const c = comp("Chip/" + k, "HORIZONTAL", { px: 14, py: 8, r: pl.chipR, fill: on ? L.primary : L.surface, stroke: on ? undefined : L.border, align: "CENTER", gap: 6 });
    if (on && pl.key === "android") add(c, icon("Check", 16, L.onPrimary));
    add(c, T("Jugador", 15, Fn.r, on ? L.onPrimary : L.text, { name: "Etiqueta" }));
    K["chip" + k] = c; place(c, "Moléculas");
  }
  // Campo de texto
  {
    const c = comp("Campo de texto", "VERTICAL", { w: 361, gap: 6 });
    add(c, T("Etiqueta", 12, Fn.m, L.muted, { name: "Etiqueta" }));
    const box = AL("HORIZONTAL", { name: "Caja", px: 14, py: 13, r: pl.fieldR, fill: pl.key === "android" ? L.surface2 : L.surface, stroke: pl.key === "ios" ? L.border : undefined, align: "CENTER" });
    if (pl.key === "android") { box.strokes = solid(L.muted); box.strokeBottomWeight = 1; box.strokeTopWeight = 0; box.strokeLeftWeight = 0; box.strokeRightWeight = 0; }
    add(c, box, true); add(box, T("Valor", 17, Fn.r, L.text, { name: "Valor" }));
    K.field = c; place(c, "Moléculas");
  }
  // Buscador
  {
    const c = comp("Buscador", "HORIZONTAL", { w: 361, px: 12, py: 10, gap: 8, r: pl.key === "ios" ? 10 : 28, fill: L.surface2, align: "CENTER" });
    add(c, icon("Buscar", 18, L.muted)); add(c, T("Buscar", 17, Fn.r, L.muted, { name: "Texto" }));
    K.search = c; place(c, "Moléculas");
  }
  // Insignias
  const badges = { Exito: [STATE.ok, "#FFFFFF"], Aviso: [STATE.warnBg, STATE.warn], Neutro: [L.surface2, L.muted], EnVivo: [STATE.red, "#FFFFFF"], Peligro: [STATE.red, "#FFFFFF"] };
  for (const k in badges) {
    const c = comp("Insignia/" + k, "HORIZONTAL", { px: 8, py: 3, r: 6, fill: badges[k][0] });
    add(c, T(k.toUpperCase(), 11, Fn.m, badges[k][1], { name: "Texto" }));
    K["badge" + k] = c; place(c, "Moléculas");
  }
  // Casilla
  for (const k of ["Marcada", "Vacía"]) {
    const on = k === "Marcada";
    const c = comp("Casilla/" + k, "HORIZONTAL", { w: 361, gap: 12, align: "CENTER", py: 6 });
    const box = AL("HORIZONTAL", { name: "Caja", w: 22, h: 22, r: pl.key === "ios" ? 11 : 4, justify: "CENTER", align: "CENTER", fill: on ? L.primary : L.surface, stroke: on ? undefined : L.muted, sw: 2 });
    if (on) add(box, icon("Check", 16, "#FFFFFF"));
    add(c, box); const t = add(c, T("Opción", 15, Fn.r, L.text, { name: "Texto", w: 320 })); t.layoutSizingHorizontal = "FILL";
    K["check" + k] = c; place(c, "Moléculas");
  }
  // Fila de lista
  {
    const c = comp("Fila", "HORIZONTAL", { w: 361, gap: 12, px: 16, py: 12, align: "CENTER", fill: L.surface });
    const av = AL("HORIZONTAL", { name: "Avatar", w: 40, h: 40, r: 20, fill: L.surface2, justify: "CENTER", align: "CENTER" });
    add(av, T("LB", 13, Fn.m, L.primary, { name: "Iniciales" })); add(c, av);
    const col = add(c, AL("VERTICAL", { name: "Textos", gap: 2 })); col.layoutSizingHorizontal = "FILL";
    add(col, T("Título", 17, Fn.m, L.text, { name: "Título" })); add(col, T("Subtítulo", 13, Fn.r, L.muted, { name: "Subtítulo" }));
    add(c, T("›", 17, Fn.m, L.muted, { name: "Final" }));
    K.row = c; place(c, "Moléculas");
  }
  // Tarjeta de partido / torneo
  {
    const c = comp("Tarjeta", "VERTICAL", { w: 361, gap: 4, pad: 16, r: pl.cardR, fill: L.surface });
    const top = add(c, AL("HORIZONTAL", { name: "Arriba", justify: "SPACE_BETWEEN", align: "CENTER" }), true);
    add(top, T("Meta", 12, Fn.m, L.muted, { name: "Meta" }));
    const b = AL("HORIZONTAL", { name: "Insignia", px: 8, py: 3, r: 6, fill: L.surface2 }); add(b, T("ESTADO", 11, Fn.m, L.muted, { name: "Estado" })); add(top, b);
    add(c, T("Título", 20, Fn.b, L.text, { name: "Título" })); add(c, T("Subtítulo", 15, Fn.r, L.muted, { name: "Subtítulo" }));
    K.card = c; place(c, "Organismos");
  }
  // Barra de navegación
  {
    const c = comp("Barra de navegación", "HORIZONTAL", { w: 393, h: pl.key === "ios" ? 44 : 64, px: 8, gap: pl.key === "ios" ? 2 : 24, align: "CENTER", fill: pl.key === "ios" ? undefined : L.bg });
    add(c, icon("Atras", 24, L.primary));
    add(c, T(pl.key === "ios" ? "Atrás" : "Título", pl.key === "ios" ? 17 : 22, pl.key === "ios" ? Fn.r : Fn.r, pl.key === "ios" ? L.primary : L.text, { name: "Etiqueta" }));
    K.nav = c; place(c, "Organismos");
  }
  // Barra de pestañas (una variante por pestaña activa)
  for (const active of ["Inicio", "Torneos", "Partido", "Equipos", "Perfil"]) {
    const c = comp("Barra de pestañas/" + active, "HORIZONTAL", { w: 393, h: pl.tabH, px: 12, pt: 8, justify: "SPACE_BETWEEN", align: "MIN", fill: pl.key === "ios" ? L.surface : L.surface2 });
    if (pl.key === "ios") { c.strokes = solid(L.border); c.strokeTopWeight = 1; c.strokeBottomWeight = 0; c.strokeLeftWeight = 0; c.strokeRightWeight = 0; }
    for (const tab of ["Inicio", "Torneos", "Partido", "Equipos", "Perfil"]) {
      const on = tab === active;
      const it = add(c, AL("VERTICAL", { name: tab, w: 68, gap: 4, align: "CENTER" }));
      const ic = icon(tab, 24, on ? (pl.key === "ios" ? L.primary : L.text) : "#8A929B");
      if (pl.key === "android") { const pill = AL("HORIZONTAL", { name: "Indicador", w: 64, h: 32, r: 16, justify: "CENTER", align: "CENTER", fill: on ? "#CFE8D9" : undefined }); add(pill, ic); add(it, pill); }
      else add(it, ic);
      add(it, T(tab, 12, on ? Fn.m : Fn.r, on ? (pl.key === "ios" ? L.primary : L.text) : L.muted, { name: "Etiqueta" }));
    }
    K["tab" + active] = c; place(c, "Organismos");
  }
  // Marcador (siempre oscuro, se usa en el modo cancha)
  {
    const D = DARK;
    const c = comp("Marcador", "HORIZONTAL", { w: 361, px: 20, py: 16, r: 20, justify: "SPACE_BETWEEN", align: "CENTER", fill: D.surface });
    const side = (name, tName, pName) => { const v = AL("VERTICAL", { name: name, align: "CENTER" }); add(v, T("LOBOS", 12, Fn.m, D.muted, { name: tName })); add(v, T("21", 64, FONTS.condX, D.text, { name: pName })); return v; };
    add(c, side("Local", "Local", "PuntosLocal"));
    const mid = add(c, AL("VERTICAL", { name: "Reloj", align: "CENTER", gap: 4 }));
    add(mid, T("2T", 12, Fn.m, D.accent, { name: "Periodo" })); add(mid, T("54:12", 32, FONTS.cond, D.text, { name: "Tiempo" }));
    add(c, side("Visita", "Visita", "PuntosVisita"));
    K.score = c; place(c, "Organismos");
  }
  // Botón de cancha
  {
    const D = DARK;
    const c = comp("Botón de cancha", "VERTICAL", { w: 175, h: 88, r: 16, justify: "CENTER", align: "CENTER", gap: 2, fill: D.surface2, stroke: D.border });
    add(c, T("ENSAYO", 24, FONTS.cond, D.text, { name: "Acción" })); add(c, T("+5", 16, Fn.m, D.primary, { name: "Puntos" }));
    K.fieldBtn = c; place(c, "Organismos");
  }
  // Aviso sin conexión
  {
    const c = comp("Aviso", "HORIZONTAL", { w: 361, px: 14, py: 10, gap: 8, r: 12, align: "CENTER", fill: STATE.warnBg });
    add(c, icon("SinRed", 18, STATE.warn)); add(c, T("Sin conexión · 3 eventos por enviar", 15, Fn.r, STATE.warn, { name: "Texto" }));
    K.banner = c; place(c, "Organismos");
  }
  // Toast / snackbar
  {
    const c = comp(pl.key === "ios" ? "Toast" : "Snackbar", "HORIZONTAL", { w: 361, px: 16, py: 12, gap: 10, r: pl.key === "ios" ? 14 : 4, align: "CENTER", fill: "#2B2F2D" });
    add(c, icon("Check", 18, "#7BE0A6")); const t = add(c, T("Guardado", 15, Fn.r, "#FFFFFF", { name: "Texto", w: 300 })); t.layoutSizingHorizontal = "FILL";
    K.toast = c; place(c, "Organismos");
  }
  // Botón flotante (solo Android, Material FAB)
  if (pl.key === "android") {
    const c = comp("FAB", "HORIZONTAL", { w: 56, h: 56, r: 16, justify: "CENTER", align: "CENTER", fill: "#CFE8D9" });
    add(c, icon("Mas", 24, L.primary)); K.fab = c; place(c, "Moléculas");
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PANTALLAS — intérprete de la especificación de flows.py
// ═══════════════════════════════════════════════════════════════════════════
function inst(c) { return c.createInstance(); }

function el(pl, e, P, dark) {
  const Fn = FONTS[pl.key]; const K = C[pl.key];
  const type = e[0]; const a = e.slice(1);
  const hl = (n, flag) => { if (flag === 1) highlight(n); return n; };
  switch (type) {
    case "brand": { const r = AL("HORIZONTAL", { name: "Marca", gap: 10, align: "CENTER" }); add(r, svg(LOGO, 32, "Logo")); add(r, T("Rugby App", 17, Fn.m, P.primary)); return r; }
    case "h1": return T(a[0], 28, Fn.b, P.text, { w: 361, name: "Título" });
    case "p": return T(a[0], 15, Fn.r, P.muted, { w: 361, name: "Texto" });
    case "note": return T(a[0], 13, Fn.r, P.muted, { w: 361, name: "Nota" });
    case "section": return T(String(a[0]).toUpperCase(), 12, Fn.m, P.muted, { name: "Sección" });
    case "btn": {
      const map = { pri: "btnPrimario", sec: "btnSecundario", txt: "btnTexto", danger: "btnDestructivo", apple: "btnApple" };
      const i = inst(K[map[a[1]] || "btnPrimario"]); setText(i, "Etiqueta", a[0]); return hl(i, a[2]);
    }
    case "field": { const i = inst(K.field); setText(i, "Etiqueta", a[0]); setText(i, "Valor", a[1]); if (a[2] === 1) highlight(i.findOne((n) => n.name === "Caja")); return i; }
    case "search": { const i = inst(K.search); setText(i, "Texto", a[0]); return hl(i, a[1]); }
    case "chips": {
      const w = AL("HORIZONTAL", { name: "Chips", gap: 8, wrap: true, w: 361 });
      a[0].forEach((label, idx) => { const i = inst(a[1].indexOf(idx) >= 0 ? K.chipActivo : K.chipInactivo); setText(i, "Etiqueta", label); if (a[2] === idx) highlight(i); add(w, i); });
      return w;
    }
    case "lock": {
      const r = AL("HORIZONTAL", { name: "Bloqueado", gap: 10, px: 12, py: 10, r: 12, align: "CENTER", fill: P.surface2 });
      add(r, icon("Candado", 18, P.muted)); const c = add(r, AL("VERTICAL", { gap: 2 })); add(c, T(a[0], 15, Fn.m, P.text)); add(c, T(a[1], 13, Fn.r, P.muted, { w: 300 })); return r;
    }
    case "row": {
      if (!dark) { const i = inst(K.row); setText(i, "Iniciales", a[0]); setText(i, "Título", a[1]); setText(i, "Subtítulo", a[2] || " "); setText(i, "Final", a[3] || " "); return hl(i, a[4]); }
      const r = AL("HORIZONTAL", { name: "Fila", gap: 12, px: 16, py: 12, align: "CENTER", fill: P.surface, w: 361 });
      const av = AL("HORIZONTAL", { w: 40, h: 40, r: 20, fill: P.surface2, justify: "CENTER", align: "CENTER" }); add(av, T(a[0], 15, Fn.m, P.primary)); add(r, av);
      const c = add(r, AL("VERTICAL", { gap: 2 })); c.layoutSizingHorizontal = "FILL"; add(c, T(a[1], 17, Fn.m, P.text)); if (a[2]) add(c, T(a[2], 13, Fn.r, P.muted));
      if (a[3]) add(r, T(a[3], 15, Fn.m, P.muted));
      return hl(r, a[4]);
    }
    case "card": {
      const i = inst(K.card); setText(i, "Título", a[0]); setText(i, "Subtítulo", a[1]); setText(i, "Meta", a[2] || " ");
      const st = i.findOne((n) => n.name === "Insignia");
      if (a[3]) { setText(i, "Estado", a[3]); if (a[3] === "EN VIVO") { st.fills = solid(STATE.red); st.findOne((n) => n.type === "TEXT").fills = solid("#FFFFFF"); } } else st.visible = false;
      return hl(i, a[4]);
    }
    case "kv": {
      const c = AL("VERTICAL", { name: "Datos", r: pl.cardR, fill: P.surface, w: 361, clip: true });
      a[0].forEach((pair, idx) => {
        if (idx) { const d = figma.createRectangle(); d.resize(361, 1); d.fills = solid(P.border); d.name = "Divisor"; add(c, d, true); }
        const r = add(c, AL("HORIZONTAL", { name: pair[0], px: 16, py: 12, justify: "SPACE_BETWEEN", align: "CENTER" }), true);
        add(r, T(pair[0], 17, Fn.r, P.text)); add(r, T(pair[1], 17, Fn.m, P.text));
      });
      return c;
    }
    case "seg": {
      const s = AL("HORIZONTAL", { name: "Segmentado", gap: 2, pad: 3, r: pl.key === "ios" ? 10 : 20, fill: P.surface2, w: 361 });
      a[0].forEach((o) => { const on = o === a[1]; const it = add(s, AL("HORIZONTAL", { name: o, justify: "CENTER", py: 8, r: pl.key === "ios" ? 8 : 18, fill: on ? (dark ? P.primary : P.surface) : undefined })); it.layoutSizingHorizontal = "FILL"; add(it, T(o, 15, on ? Fn.m : Fn.r, on ? (dark ? P.onPrimary : P.text) : P.muted)); if (on && a[2] === 1) highlight(it); });
      return s;
    }
    case "banner": { const i = inst(K.banner); setText(i, "Texto", a[0]); return i; }
    case "toast": { const i = inst(K.toast); setText(i, "Texto", a[0]); return hl(i, a[1]); }
    case "check": { const i = inst(a[1] === 1 ? K.checkMarcada : K.checkVacía); setText(i, "Texto", a[0]); if (dark) i.findOne((n) => n.name === "Texto").fills = solid(P.text); return i; }
    case "badge": {
      const kind = { live: "badgeEnVivo", warn: "badgeAviso", ok: "badgeExito", danger: "badgePeligro" }[a[1]] || "badgeNeutro";
      const i = inst(K[kind]); setText(i, "Texto", a[0]); return i;
    }
    case "done": {
      const c = AL("VERTICAL", { name: "Confirmación", gap: 12, align: "CENTER", pt: 80, pb: 24, w: 361 });
      const circ = AL("HORIZONTAL", { w: 88, h: 88, r: 44, fill: STATE.ok, justify: "CENTER", align: "CENTER" }); add(circ, icon("Check", 44, "#FFFFFF")); add(c, circ);
      add(c, T(a[0], 24, Fn.b, P.text, { align: "CENTER", w: 361 })); add(c, T(a[1], 15, Fn.r, P.muted, { align: "CENTER", w: 320 }));
      return c;
    }
    case "avatar": {
      const r = AL("HORIZONTAL", { name: "Perfil", gap: 14, align: "CENTER", pad: 16, r: pl.cardR, fill: P.surface, w: 361 });
      const av = AL("HORIZONTAL", { w: 64, h: 64, r: 32, fill: P.primary, justify: "CENTER", align: "CENTER" }); add(av, T(a[0], 22, Fn.b, P.onPrimary)); add(r, av);
      const c = add(r, AL("VERTICAL", { gap: 2 })); add(c, T(a[1], 20, Fn.b, P.text)); if (a[2]) add(c, T(a[2], 15, Fn.r, P.muted));
      return r;
    }
    case "stat": {
      const r = AL("HORIZONTAL", { name: "Estadísticas", gap: 8, w: 361 });
      a[0].forEach((s) => { const c = add(r, AL("VERTICAL", { gap: 2, px: 12, py: 10, r: 12, fill: P.surface })); c.layoutSizingHorizontal = "FILL"; add(c, T(s[0], 22, Fn.b, P.primary)); add(c, T(s[1], 12, Fn.r, P.muted)); });
      return r;
    }
    case "actions": {
      const g = AL("HORIZONTAL", { name: "Accesos", gap: 10, wrap: true, w: 361 });
      a[0].forEach((label, idx) => {
        const t = add(g, AL("VERTICAL", { name: label, w: 175, h: 76, pad: 12, r: 16, gap: 6, fill: P.surface, justify: "SPACE_BETWEEN" }));
        const ico = { Torneos: "Torneos", "Mi equipo": "Equipos", Partidos: "Partido", Perfil: "Perfil", Feed: "Documento", Siguiendo: "Campana", Tabla: "Torneos" }[label] || "Inicio";
        add(t, icon(ico, 22, P.primary)); add(t, T(label, 15, Fn.m, P.text));
        if (a[1] === idx) highlight(t);
      });
      return g;
    }
    case "score": {
      const i = inst(K.score);
      setText(i, "Local", a[0]); setText(i, "PuntosLocal", a[1]); setText(i, "Visita", a[2]); setText(i, "PuntosVisita", a[3]); setText(i, "Tiempo", a[4]); setText(i, "Periodo", a[5]);
      return i;
    }
    case "grid": {
      const g = AL("HORIZONTAL", { name: "Anotaciones", gap: 10, wrap: true, w: 361 });
      a[0].forEach((b, idx) => { const i = inst(K.fieldBtn); setText(i, "Acción", b[0]); setText(i, "Puntos", b[1]); if (a[1] === idx) highlight(i); add(g, i); });
      return g;
    }
    case "cards": {
      const r = AL("HORIZONTAL", { name: "Sanciones", gap: 10, w: 361 });
      const col = { AMARILLA: [STATE.yellow, "#0B0F0D"], ROJA: [STATE.red, "#FFFFFF"], CAMBIO: [DARK.surface2, "#FFFFFF"] };
      a[0].forEach((label, idx) => { const b = add(r, AL("VERTICAL", { name: label, h: 64, r: 16, justify: "CENTER", align: "CENTER", fill: col[label][0] })); b.layoutSizingHorizontal = "FILL"; add(b, T(label, 22, FONTS.cond, col[label][1])); if (a[1] === idx) highlight(b); });
      return r;
    }
    case "event": {
      const kinds = { ok: P.primary, yellow: STATE.yellow, red: STATE.red, void: P.muted };
      const r = AL("HORIZONTAL", { name: "Evento " + a[0], gap: 12, px: 16, py: 12, align: "CENTER", r: 12, fill: P.surface, w: 361 });
      const bar = figma.createRectangle(); bar.resize(4, 40); bar.cornerRadius = 2; bar.fills = solid(kinds[a[3]] || P.primary); add(r, bar);
      add(r, T(a[0], 17, Fn.m, P.muted));
      const c = add(r, AL("VERTICAL", { gap: 2 })); c.layoutSizingHorizontal = "FILL";
      add(c, T(a[1], 17, Fn.m, a[3] === "void" ? P.muted : P.text, { strike: a[3] === "void" }));
      add(c, T(a[2], 13, Fn.r, a[3] === "void" ? STATE.red : P.muted));
      return hl(r, a[4]);
    }
    case "table": {
      const c = AL("VERTICAL", { name: "Tabla", r: pl.cardR, fill: P.surface, w: 361, clip: true });
      const widths = a[0].length === 5 ? [28, 145, 40, 60, 48] : [28, 125, 120, 48];
      const mk = (vals, head) => {
        const r = add(c, AL("HORIZONTAL", { px: 12, py: head ? 8 : 11, gap: 4, align: "CENTER", fill: head ? P.surface2 : undefined }), true);
        vals.forEach((v, j) => { const cell = add(r, AL("HORIZONTAL", { w: widths[j], justify: j > 1 ? "CENTER" : "MIN" })); add(cell, T(v, head ? 12 : 15, head || j === vals.length - 1 ? Fn.m : Fn.r, head ? P.muted : (j === vals.length - 1 ? P.primary : P.text))); });
      };
      mk(a[0], true); a[1].forEach((row) => mk(row, false));
      return c;
    }
    case "sig": {
      const c = AL("VERTICAL", { name: "Firma", pad: 16, r: 16, gap: 8, fill: P.surface, stroke: P.border, w: 361 });
      c.dashPattern = [6, 4];
      add(c, svg('<svg width="180" height="40" viewBox="0 0 180 40" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M4 30c14-22 22-24 24-14s-6 18 2 10 14-26 20-18-4 20 6 14 16-14 24-10 6 12 16 6 24-12 34-8 14 6 22 2" stroke="' + P.text + '" stroke-width="2.2" stroke-linecap="round"/></svg>', 180, "Trazo"));
      c.children[0].resize(180, 40); add(c, T("Firma del árbitro", 13, Fn.r, P.muted));
      return c;
    }
    case "pdf": {
      const c = AL("VERTICAL", { name: "Vista previa PDF", pad: 20, r: 8, gap: 8, fill: "#FFFFFF", stroke: P.border, w: 361 });
      add(c, T("ACTA DE PARTIDO · LIGA BAJÍO 2027", 11, Fn.m, "#5E6670"));
      add(c, T("Lobos 28 – 17 Toros", 20, Fn.b, "#14171A"));
      ["Ensayos: Lobos 4 · Toros 3", "Tarjetas: 1 amarilla (52') · 0 rojas", "Oficiales: R. Díaz · E. Cruz", "Hash de eventos: 7f3a…c91e"].forEach((s) => add(c, T(s, 13, Fn.r, "#14171A")));
      return c;
    }
    case "notif": {
      const c = AL("VERTICAL", { name: "Notificación", pad: 14, r: 18, gap: 4, fill: "#FFFFFF", opacity: 0.92, w: 361 });
      const top = add(c, AL("HORIZONTAL", { gap: 8, align: "CENTER" })); add(top, svg(LOGO, 20, "Logo")); add(top, T(a[0], 13, Fn.m, "#5E6670"));
      add(c, T(a[1], 15, Fn.m, "#14171A", { w: 330 }));
      return c;
    }
    default: return T("[" + type + "]", 13, Fn.r, STATE.red);
  }
}

// Construye un teléfono completo a partir de una pantalla de flows.py
function phone(pl, s) {
  const dark = !!s.dark; const P = dark ? DARK : LIGHT; const K = C[pl.key];
  const f = figma.createFrame(); f.name = s.n; f.resize(393, 852); f.cornerRadius = 44; f.clipsContent = true; f.fills = solid(P.bg);
  const sb = inst(dark ? K.statusOscuro : K.statusClaro); f.appendChild(sb); sb.x = 0; sb.y = 0;
  let y = pl.statusH;
  if (s.back) { const nv = inst(K.nav); setText(nv, "Etiqueta", s.back); f.appendChild(nv); nv.x = 0; nv.y = y; y += nv.height; }
  const body = AL("VERTICAL", { name: "Contenido", gap: 12, px: 16, pt: 8, pb: 24, w: 393 });
  f.appendChild(body); body.x = 0; body.y = y;
  if (s.tab) { const tb = inst(K["tab" + s.tab]); f.appendChild(tb); tb.x = 0; tb.y = 852 - pl.tabH; }
  let target = body; let sheetStarted = false;
  for (const e of s.els) {
    if (e[0] === "sheet") {
      const dim = figma.createRectangle(); dim.name = "Fondo atenuado"; dim.resize(393, 852); dim.fills = solid("#000000", 0.45); f.appendChild(dim); dim.x = 0; dim.y = 0;
      const sh = AL("VERTICAL", { name: "Hoja inferior", gap: 12, px: 16, pt: 12, pb: 40, w: 393, fill: dark ? DARK.surface : LIGHT.surface });
      sh.topLeftRadius = 20; sh.topRightRadius = 20;
      const grab = figma.createRectangle(); grab.resize(36, 5); grab.cornerRadius = 3; grab.fills = solid(P.muted, 0.5); grab.name = "Asa";
      const gw = add(sh, AL("HORIZONTAL", { justify: "CENTER" }), true); add(gw, grab);
      add(sh, T(e[1], 20, FONTS[pl.key].b, P.text, { w: 361 }));
      f.appendChild(sh); target = sh; sheetStarted = true;
      continue;
    }
    const node = el(pl, e, P, dark);
    target.appendChild(node);
    if (node.type !== "TEXT" && node.layoutSizingHorizontal !== undefined) { try { node.layoutSizingHorizontal = "FILL"; } catch (err) { /* nodo de ancho fijo */ } }
  }
  if (sheetStarted) { target.x = 0; target.y = 852 - target.height; }
  return f;
}

// ═══════════════════════════════════════════════════════════════════════════
// PÁGINAS
// ═══════════════════════════════════════════════════════════════════════════
// Modo "pages": una página por rol. Modo "sections": si el plan del archivo no permite tantas páginas
// (Figma Starter permite 3), todo va en una sola página con una sección por rol.
let MODE = "pages"; let SINGLE = null; let pending = null; let curY = 0;
const SINGLE_NAME = "Rugby App · Flujos por rol";

async function chooseMode(needed) {
  const probes = [];
  try { for (let i = 0; i < needed; i++) { const p = figma.createPage(); p.name = "_prueba"; probes.push(p); } }
  catch (e) { MODE = "sections"; }
  for (const p of probes) p.remove();
  if (MODE === "sections") log("Este archivo no permite " + needed + " páginas (plan Starter: 3). Todo irá en la página «" + SINGLE_NAME + "», con una sección por rol.");
}
function containers() {
  if (MODE === "pages") return figma.root.children.map((p) => ({ name: p.name, node: p }));
  return SINGLE.children.filter((n) => n.type === "SECTION").map((s) => ({ name: s.name, node: s }));
}
function closeSection() {
  if (MODE !== "sections" || !pending) return;
  const nodes = SINGLE.children.filter((n) => !pending.before.has(n.id) && n.type !== "SECTION");
  if (!nodes.length) { pending = null; return; }
  const minX = Math.min.apply(null, nodes.map((n) => n.x)); const minY = Math.min.apply(null, nodes.map((n) => n.y));
  const maxX = Math.max.apply(null, nodes.map((n) => n.x + n.width)); const maxY = Math.max.apply(null, nodes.map((n) => n.y + n.height));
  const sec = figma.createSection(); sec.name = pending.name; SINGLE.appendChild(sec);
  sec.x = 0; sec.y = curY; sec.resizeWithoutConstraints(maxX - minX + 400, maxY - minY + 400);
  sec.fills = solid(BOARD.page);
  for (const n of nodes) { const rx = n.x - minX + 200, ry = n.y - minY + 200; sec.appendChild(n); n.x = rx; n.y = ry; }
  curY += sec.height + 800; pending = null;
}
async function newPage(name) {
  if (MODE === "pages") {
    const old = figma.root.children.find((p) => p.name === name);
    const page = figma.createPage(); page.name = name;
    if (old) { await figma.setCurrentPageAsync(page); old.remove(); }
    await figma.setCurrentPageAsync(page);
    page.backgrounds = solid(BOARD.page);
    return page;
  }
  closeSection();
  if (!SINGLE) {
    SINGLE = figma.root.children.find((p) => p.name === SINGLE_NAME) || figma.root.children.find((p) => p.name === "Portada") || figma.root.children[0];
    SINGLE.name = SINGLE_NAME;
    await figma.setCurrentPageAsync(SINGLE);
    SINGLE.backgrounds = solid("#141414");
    for (const n of SINGLE.children.slice()) n.remove(); // se reconstruye completo en cada corrida
  }
  pending = { name: name, before: new Set(SINGLE.children.map((n) => n.id)) };
  return SINGLE;
}
function boardText(chars, size, weight, color, w) { return T(chars, size, FONTS.board[weight || "r"], color || "#FFFFFF", w ? { w: w } : {}); }

async function atomicPage(pl) {
  const page = await newPage("Atomic Design " + pl.label);
  const L = LIGHT; const Fb = FONTS.board;
  const head = boardText("Atomic Design · " + pl.label, 40, "b"); head.x = 0; head.y = 0;
  const sub = boardText(pl.key === "ios" ? "Human Interface Guidelines: SF Pro, barra de pestañas inferior, títulos grandes, botones de 50 pt." : "Material 3: Roboto, barra de navegación con indicador, campos rellenos, botones píldora y FAB.", 18, "r", BOARD.muted, 900);
  sub.x = 0; sub.y = 56;
  const cols = { "Átomos": 0, "Moléculas": 520, "Organismos": 1040, "Plantillas": 1560 };
  const cursor = {};
  for (const k in cols) {
    const bar = AL("HORIZONTAL", { name: k, w: 460, h: 56, r: 4, justify: "CENTER", align: "CENTER", fill: BOARD.header });
    add(bar, T(k, 24, Fb.b, BOARD.headerText)); bar.x = cols[k]; bar.y = 120; cursor[k] = 200;
  }
  const place = (node, col) => { node.x = cols[col]; node.y = cursor[col]; cursor[col] += node.height + 32; };

  // Átomos: color, tipografía, iconos, espaciado
  const sw = AL("VERTICAL", { name: "Color", gap: 8, pad: 16, r: 8, fill: "#FFFFFF", w: 460 });
  add(sw, T("Color", 20, Fb.b, L.text));
  for (const [n, v] of [["Primario · verde cancha", L.primary], ["Acento · ámbar", L.accent], ["Fondo", L.bg], ["Superficie", L.surface], ["Texto", L.text], ["Texto suave", L.muted], ["Cancha · fondo", DARK.bg], ["Cancha · primario", DARK.primary], ["Tarjeta amarilla", STATE.yellow], ["Tarjeta roja", STATE.red], ["Éxito", STATE.ok], ["Aviso", STATE.warn]]) {
    const r = add(sw, AL("HORIZONTAL", { gap: 12, align: "CENTER" }), true);
    const chip = figma.createRectangle(); chip.resize(40, 40); chip.cornerRadius = 8; chip.fills = solid(v); chip.strokes = solid(L.border); add(r, chip);
    add(r, T(n, 15, Fb.m, L.text)); add(r, T(v, 13, Fb.r, L.muted));
  }
  place(sw, "Átomos");
  const ty = AL("VERTICAL", { name: "Tipografía", gap: 10, pad: 16, r: 8, fill: "#FFFFFF", w: 460 });
  add(ty, T("Tipografía · " + FONTS[pl.key].r.family, 20, Fb.b, L.text));
  for (const [n, size, f] of [["Título grande", 34, FONTS[pl.key].b], ["Título", 28, FONTS[pl.key].b], ["Encabezado", 17, FONTS[pl.key].m], ["Cuerpo", 17, FONTS[pl.key].r], ["Secundario", 15, FONTS[pl.key].r], ["Nota", 13, FONTS[pl.key].r], ["Marcador 21", 64, FONTS.condX]]) add(ty, T(n, size, f, L.text));
  place(ty, "Átomos");
  const ic = AL("HORIZONTAL", { name: "Iconos", gap: 16, pad: 16, r: 8, fill: "#FFFFFF", w: 460, wrap: true });
  for (const k in ICONS) { const c = add(ic, AL("VERTICAL", { gap: 4, align: "CENTER", w: 64 })); add(c, icon(k, 24, L.text)); add(c, T(k, 11, Fb.r, L.muted)); }
  place(ic, "Átomos");
  const sp = AL("VERTICAL", { name: "Espaciado y radios", gap: 8, pad: 16, r: 8, fill: "#FFFFFF", w: 460 });
  add(sp, T("Espaciado y radios", 20, Fb.b, L.text));
  for (const v of [4, 8, 12, 16, 24, 32]) { const r = add(sp, AL("HORIZONTAL", { gap: 12, align: "CENTER" })); const b = figma.createRectangle(); b.resize(v, 16); b.fills = solid(L.primary); add(r, b); add(r, T(v + " px", 13, Fb.r, L.muted)); }
  add(sp, T("Radios: botón " + pl.btnR + " · tarjeta " + pl.cardR + " · campo " + pl.fieldR + " · objetivo táctil mínimo 44 pt (RNF-08)", 13, Fb.r, L.muted, { w: 420 }));
  place(sp, "Átomos");

  // Moléculas y organismos
  buildComponents(pl, place);

  // Plantillas: tres pantallas de ejemplo construidas con los componentes de esta plataforma
  const samples = [
    ["Plantilla · Lista", DATA.stories["E-03"].flow[1]],
    ["Plantilla · Formulario", DATA.stories["O-01"].flow[1]],
    ["Plantilla · Partido en vivo", DATA.stories["V-02"].flow[0]],
  ];
  for (const [name, spec] of samples) {
    const lbl = boardText(name, 18, "m"); place(lbl, "Plantillas");
    const ph = phone(pl, spec); ph.name = name; place(ph, "Plantillas");
  }
  return page;
}

// Flecha entre dos puntos (con codos opcionales); punta solo al final
async function arrow(points, color, parent) {
  const v = figma.createVector();
  const minX = Math.min.apply(null, points.map((p) => p[0])); const minY = Math.min.apply(null, points.map((p) => p[1]));
  points = points.map((p) => [p[0] - minX, p[1] - minY]);
  const vertices = points.map((p, i) => (i === points.length - 1 ? { x: p[0], y: p[1], strokeCap: "ARROW_LINES" } : { x: p[0], y: p[1] }));
  const segments = points.slice(1).map((_, i) => ({ start: i, end: i + 1 }));
  await v.setVectorNetworkAsync({ vertices: vertices, segments: segments, regions: [] });
  v.strokes = solid(color); v.strokeWeight = 2; v.strokeJoin = "ROUND"; v.name = "Flecha";
  if (parent) parent.appendChild(v);
  v.x = minX; v.y = minY;
  return v;
}

const COLW = 420, COLGAP = 140;
const roleOf = {}; // historia → primer rol donde aparece (para enlazar dependencias)
const columnId = {}; // `${rol}|${historia}` → id del nodo de la columna

function storyColumn(hu, roleName) {
  const st = DATA.stories[hu]; const Fb = FONTS.board;
  const col = AL("VERTICAL", { name: hu + " · " + st.quiero, gap: 14, w: COLW });
  // Encabezado con el ID, enlazado a Notion
  const head = add(col, AL("HORIZONTAL", { name: "Encabezado", h: 48, justify: "CENTER", align: "CENTER", fill: BOARD.header }), true);
  link(add(head, T(hu, 22, Fb.b, BOARD.headerText)), st.notion);
  add(col, boardText("Yo como " + st.como + " quiero " + st.quiero + ", para " + st.para + ".", 16, "r", BOARD.story, COLW));
  add(col, boardText(st.sprint + " · " + st.prio + " · " + st.pts + " pts · " + st.ver, 13, "m", BOARD.muted));
  const links = add(col, AL("HORIZONTAL", { name: "Enlaces", gap: 16 }));
  link(add(links, boardText("Notion iOS ↗", 13, "m", BOARD.link)), st.notion);
  if (st.android) link(add(links, boardText("Notion Android (AN-" + hu + ") ↗", 13, "m", BOARD.link)), st.android);
  const deps = add(col, AL("HORIZONTAL", { name: "Depende de", gap: 6, wrap: true, w: COLW }));
  add(deps, boardText(st.deps.length ? "Depende de:" : "Sin dependencias: es un punto de entrada.", 13, "m", BOARD.muted));
  for (const d of st.deps) {
    const chip = add(deps, AL("HORIZONTAL", { name: "dep:" + d, px: 8, py: 3, r: 10, stroke: "#6B6B6B" }));
    add(chip, boardText(d, 12, "m", "#FFFFFF"));
  }
  // Flujo de pantallas
  st.flow.forEach((s, i) => {
    add(col, boardText("Paso " + (i + 1) + " · " + s.n, 15, "m", "#FFFFFF"));
    add(col, phone(PLAT.ios, s));
    if (s.go && i < st.flow.length - 1) {
      const step = add(col, AL("HORIZONTAL", { name: "Acción", gap: 10, align: "CENTER", pl: 180 }));
      add(step, svg('<svg width="24" height="40" viewBox="0 0 24 40" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M12 2v34M5 29l7 8 7-8" stroke="#F2B705" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>', 24, "Flecha"));
      step.children[0].resize(24, 40);
      add(step, boardText(s.go, 14, "m", STATE.tap));
    } else if (s.go) {
      add(col, boardText("→ " + s.go, 14, "m", STATE.tap));
    }
  });
  add(col, boardText("✓ Objetivo cumplido: " + st.para + ".", 14, "m", "#7BE0A6", COLW));
  return col;
}

function topoOrder(hus) {
  const order = []; const seen = {};
  const visit = (h) => { if (seen[h]) return; seen[h] = true; for (const d of DATA.stories[h].deps) if (hus.indexOf(d) >= 0) visit(d); order.push(h); };
  hus.forEach(visit);
  return order;
}

async function rolePage(role, idx) {
  const page = await newPage("Rol · " + role.name);
  const Fb = FONTS.board;
  // Cabecera de la página
  const head = boardText(role.name, 44, "b"); head.x = 0; head.y = 0;
  const desc = boardText(role.desc, 18, "r", BOARD.muted, 1200); desc.x = 0; desc.y = 60;
  const legend = boardText("Cómo leer esta página: cada columna es una historia de usuario (el ID abre Notion). Debajo está la ruta completa, paso a paso, hasta cumplir el objetivo. El borde ámbar marca el toque que lleva a la siguiente pantalla. Las flechas grises de arriba son dependencias: la historia de origen debe estar terminada antes.", 14, "r", BOARD.story, 1200);
  legend.x = 0; legend.y = 96;

  const ordered = topoOrder(role.hus);
  // Agrupar por actividad conservando el orden
  const groups = []; ordered.forEach((h) => { const act = DATA.stories[h].act; let g = groups.find((x) => x.act === act); if (!g) { g = { act: act, hus: [] }; groups.push(g); } g.hus.push(h); });
  // Las actividades siguen el orden del story map
  const ACT_ORDER = ["Unirme a la comunidad", "Formar equipo", "Administrar la competencia", "Organizar el torneo", "Preparar el partido", "Jugar el partido", "Cerrar y reportar", "Consultar resultados", "Seguir y enterarme"];
  groups.sort((a, b) => ACT_ORDER.indexOf(a.act) - ACT_ORDER.indexOf(b.act));

  const intraDeps = []; ordered.forEach((h) => DATA.stories[h].deps.forEach((d) => { if (role.hus.indexOf(d) >= 0) intraDeps.push([d, h]); }));
  const laneTop = 200; const laneH = Math.max(1, intraDeps.length) * 16 + 40;
  const barY = laneTop + laneH; const colY = barY + 80;
  let x = 0; const pos = {};
  for (const g of groups) {
    const w = g.hus.length * COLW + (g.hus.length - 1) * COLGAP;
    const bar = AL("HORIZONTAL", { name: "Actividad · " + g.act, w: w, h: 52, r: 4, justify: "CENTER", align: "CENTER", fill: BOARD.header });
    add(bar, T(g.act, 24, Fb.b, BOARD.headerText)); bar.x = x; bar.y = barY;
    for (const h of g.hus) {
      const col = storyColumn(h, role.name); col.x = x; col.y = colY; pos[h] = x;
      columnId[role.name + "|" + h] = col.id;
      if (!roleOf[h]) roleOf[h] = { role: role.name, id: col.id };
      x += COLW + COLGAP;
    }
    x += 80;
  }
  // Dependencias dentro de la página: flechas con codo por encima de las columnas
  const colors = ["#8AB4F8", "#F28B82", "#FDD663", "#81C995", "#C58AF9", "#78D9EC", "#FCAD70", "#FF8BCB"];
  for (let i = 0; i < intraDeps.length; i++) {
    const [from, to] = intraDeps[i];
    const y = laneTop + 20 + i * 16; const color = colors[i % colors.length];
    const x1 = pos[from] + COLW / 2 - 40 + (i % 5) * 8; const x2 = pos[to] + COLW / 2 + 40 - (i % 5) * 8;
    await arrow([[x1, barY - 6], [x1, y], [x2, y], [x2, barY - 6]], color);
  }
  const depNote = boardText(intraDeps.length ? "Dependencias en esta página: " + intraDeps.map((p) => p[0] + " → " + p[1]).join(" · ") : "Las historias de este rol dependen de historias de otros roles (ver «Depende de» en cada columna).", 13, "r", BOARD.muted, 1400);
  depNote.x = 0; depNote.y = laneTop - 32;
  return page;
}

// Une las etiquetas "Depende de" con la columna de la historia correspondiente
async function linkDependencies() {
  let n = 0;
  for (const c of containers()) {
    if (c.name.indexOf("Rol · ") !== 0) continue;
    if (c.node.type === "PAGE") await c.node.loadAsync();
    const chips = c.node.findAll((node) => node.type === "FRAME" && node.name.indexOf("dep:") === 0);
    const roleName = c.name.slice(6);
    for (const chip of chips) {
      const hu = chip.name.slice(4);
      const local = columnId[roleName + "|" + hu];
      const target = local || (roleOf[hu] && roleOf[hu].id);
      const t = chip.findOne((x) => x.type === "TEXT");
      if (!target || !t) continue;
      t.characters = hu + (local ? "" : " · " + roleOf[hu].role) + " ↗";
      link(t, target, "NODE"); n++;
    }
  }
  return n;
}

const coverRows = {};
async function coverPage() {
  await newPage("Portada");
  const t = boardText("Rugby App · Flujos por rol", 56, "b"); t.x = 0; t.y = 0;
  const s = boardText("Atomic Design para iOS y Android, y " + (MODE === "pages" ? "una página" : "una sección") + " por rol con cada historia de usuario, su ruta completa y sus dependencias. Cada ID abre la historia en Notion; cada rol de esta lista lleva a su " + (MODE === "pages" ? "página" : "sección") + ".", 20, "r", BOARD.muted, 1100); s.x = 0; s.y = 80;
  let y = 200;
  for (const r of DATA.roles) {
    const row = AL("HORIZONTAL", { gap: 16, align: "CENTER", name: r.name });
    coverRows[r.name] = add(row, boardText(r.name + " ↗", 22, "b")); add(row, boardText(r.hus.join(" · "), 16, "r", BOARD.muted));
    row.x = 0; row.y = y; y += 44;
  }
}
function linkCover() {
  for (const r of DATA.roles) {
    const target = containers().find((c) => c.name === "Rol · " + r.name);
    if (target && coverRows[r.name]) link(coverRows[r.name], target.node.id, "NODE");
  }
}

// ═══════════════════════════════════════════════════════════════════════════
async function main() {
  log("Cargando fuentes…");
  await loadFonts();
  log("iOS: " + FONTS.ios.r.family + " · Android: " + FONTS.android.r.family + " · Marcador: " + FONTS.cond.family);

  // Quita las páginas del Sprint 2 que este archivo reemplaza
  for (const name of ["Tokens y componentes", "Pantallas MVP · iOS"]) {
    const p = figma.root.children.find((x) => x.name === name);
    if (p && figma.root.children.length > 1) { if (figma.currentPage === p) await figma.setCurrentPageAsync(figma.root.children.find((x) => x !== p)); p.remove(); log("Página anterior eliminada: " + name); }
  }
  const pageNames = ["Portada", "Atomic Design iOS", "Atomic Design Android"].concat(DATA.roles.map((r) => "Rol · " + r.name));
  await chooseMode(pageNames.filter((n) => !figma.root.children.find((p) => p.name === n)).length + 1);

  await coverPage();
  log("Atomic Design iOS…"); await atomicPage(PLAT.ios);
  log("Atomic Design Android…"); await atomicPage(PLAT.android);
  for (let i = 0; i < DATA.roles.length; i++) { log("Rol · " + DATA.roles[i].name + "…"); await rolePage(DATA.roles[i], i); }
  closeSection();
  log("Enlazando dependencias…"); const n = await linkDependencies(); log(n + " dependencias enlazadas.");
  linkCover();

  if (MODE === "pages") pageNames.forEach((name, i) => { const p = figma.root.children.find((x) => x.name === name); if (p) figma.root.insertChild(i, p); });
  await figma.setCurrentPageAsync(MODE === "pages" ? figma.root.children[0] : SINGLE);

  // Enlaces profundos para pegarlos en Notion
  const key = figma.fileKey;
  const links = {};
  for (const h in roleOf) links[h] = key ? "https://www.figma.com/design/" + key + "/?node-id=" + roleOf[h].id.replace(":", "-") : roleOf[h].id;
  figma.ui.postMessage({ type: "done", links: JSON.stringify(links, null, 1), hasKey: !!key });
  log("Listo · modo: " + (MODE === "pages" ? "una página por rol" : "una sección por rol"));
}

main().catch((e) => { figma.ui.postMessage({ type: "error", msg: String(e && e.stack ? e.stack : e) }); });
