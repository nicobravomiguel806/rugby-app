// Simulador mínimo y ESTRICTO del Plugin API de Figma para probar code.js en Node.
// Replica las reglas que más fallan: FILL/HUG solo en auto layout, fuentes cargadas antes de tocar texto,
// propiedades desconocidas lanzan error, hipervínculos y redes vectoriales.
"use strict";
let idSeq = 1;
const loaded = new Set();
const fkey = (f) => f.family + "|" + f.style;
const AVAILABLE = new Set(["Inter|Regular", "Inter|Semi Bold", "Inter|Bold", "Inter|Medium", "Inter|Extra Bold", "Roboto|Regular", "Roboto|Medium", "Roboto|Bold", "Barlow Condensed|Bold", "Barlow Condensed|ExtraBold"]);
const stats = { nodes: 0, texts: 0, instances: 0, components: 0, vectors: 0, links: 0, nodeLinks: 0, pages: 0 };

const COMMON = ["name", "x", "y", "visible", "opacity", "fills", "strokes", "strokeWeight", "strokeAlign", "cornerRadius", "layoutSizingHorizontal", "layoutSizingVertical", "strokeJoin", "dashPattern", "topLeftRadius", "topRightRadius", "strokeTopWeight", "strokeBottomWeight", "strokeLeftWeight", "strokeRightWeight", "clipsContent", "layoutGrow"];
const FRAME = COMMON.concat(["layoutMode", "primaryAxisSizingMode", "counterAxisSizingMode", "itemSpacing", "paddingLeft", "paddingRight", "paddingTop", "paddingBottom", "counterAxisAlignItems", "primaryAxisAlignItems", "layoutWrap", "counterAxisSpacing", "description"]);
const TEXT = COMMON.concat(["fontName", "fontSize", "characters", "lineHeight", "textAlignHorizontal", "textDecoration", "textAutoResize"]);
const PAGE = ["name", "backgrounds"];

class Node {
  constructor(type, allowed) { this._type = type; this._allowed = new Set(allowed.concat(["_parent", "_children", "_props", "_w", "_h", "_type", "_allowed", "id", "_links", "_self"])); this.id = (idSeq++) + ":" + (idSeq++); this._children = []; this._props = { name: type.charAt(0) + type.slice(1).toLowerCase(), visible: true, layoutMode: "NONE", fills: [], strokes: [] }; this._w = 100; this._h = 100; stats.nodes++; const px = new Proxy(this, handler); this._self = px; return px; }
}
const handler = {
  set(t, k, v) {
    if (typeof k === "string" && !k.startsWith("_l") && !t._allowed.has(k) && !(k in Object.getPrototypeOf(t))) throw new Error("Propiedad no soportada en " + t._type + ": " + k);
    if (k === "layoutSizingHorizontal" || k === "layoutSizingVertical") {
      const p = t._parent; const isAL = t._props.layoutMode && t._props.layoutMode !== "NONE";
      if (v === "FILL" && !(p && p._props.layoutMode && p._props.layoutMode !== "NONE")) throw new Error("FILL solo en hijos de auto layout (" + t._props.name + ")");
      if (v === "HUG" && !(isAL || t._type === "TEXT")) throw new Error("HUG solo en auto layout o texto");
    }
    if (t._type === "TEXT" && ["characters", "fontSize", "lineHeight", "textDecoration", "textAlignHorizontal", "textAutoResize"].indexOf(k) >= 0) {
      const f = t._props.fontName; if (!f || !loaded.has(fkey(f))) throw new Error("Fuente no cargada al cambiar " + k + ": " + (f ? fkey(f) : "sin fuente"));
    }
    if (k === "fontName" && !loaded.has(fkey(v))) throw new Error("fontName sin cargar: " + fkey(v));
    if ((k === "fills" || k === "strokes") && Array.isArray(v)) for (const p of v) { if (p.color && ("a" in p.color)) throw new Error("color con canal a"); if (p.color && [p.color.r, p.color.g, p.color.b].some((c) => c < 0 || c > 1 || isNaN(c))) throw new Error("color fuera de rango"); }
    if (k === "width" || k === "height") throw new Error("width/height son de solo lectura: usa resize()");
    if (typeof k === "string" && t._allowed.has(k) && !k.startsWith("_") && k !== "id") { t._props[k] = v; if (k === "characters") { t._w = Math.max(1, String(v).length * 7); stats.texts++; } return true; }
    t[k] = v; return true;
  },
  get(t, k) {
    if (k in t || typeof k === "symbol") return t[k];
    if (k === "width") return (global.__sizer && (t._type === "TEXT" || (t._props.layoutMode && t._props.layoutMode !== "NONE"))) ? global.__sizer(t._self)[0] : t._w; if (k === "height") return (global.__sizer && (t._type === "TEXT" || (t._props.layoutMode && t._props.layoutMode !== "NONE"))) ? global.__sizer(t._self)[1] : t._h;
    if (k === "type") return t._type; if (k === "parent") return t._parent; if (k === "children") return t._children.slice();
    if (k in t._props) return t._props[k];
    return undefined;
  },
};
Node.prototype.resize = function (w, h) { if (!(w > 0 && h > 0)) throw new Error("resize inválido " + w + "x" + h); this._w = w; this._h = h; if (this._props.layoutMode && this._props.layoutMode !== "NONE") { this._props.primaryAxisSizingMode = "FIXED"; this._props.counterAxisSizingMode = "FIXED"; } };
Node.prototype.appendChild = function (c) { if (c._parent) c._parent._children.splice(c._parent._children.indexOf(c), 1); c._parent = this; this._children.push(c); };
Node.prototype.insertChild = function (i, c) { if (c._parent) c._parent._children.splice(c._parent._children.indexOf(c), 1); c._parent = this; this._children.splice(i, 0, c); };
Node.prototype.remove = function () { if (this._parent) this._parent._children.splice(this._parent._children.indexOf(this), 1); this._parent = null; };
Node.prototype.findAll = function (fn) { const out = []; const walk = (n) => { for (const c of n._children) { if (!fn || fn(c)) out.push(c); walk(c); } }; walk(this); return out; };
Node.prototype.findOne = function (fn) { const all = this.findAll(fn); return all[0] || null; };
Node.prototype.setRangeHyperlink = function (s, e, l) { if (this._type !== "TEXT") throw new Error("hipervínculo en no-texto"); if (!loaded.has(fkey(this._props.fontName))) throw new Error("hipervínculo sin fuente"); if (!l || !l.value || ["URL", "NODE"].indexOf(l.type) < 0) throw new Error("hipervínculo inválido"); if (e > this._props.characters.length) throw new Error("rango fuera"); stats.links++; if (l.type === "NODE") stats.nodeLinks++; };
Node.prototype.createInstance = function () {
  if (this._type !== "COMPONENT") throw new Error("createInstance en " + this._type);
  const clone = (n, top) => { const c = new Node(top ? "INSTANCE" : n._type, n._type === "TEXT" ? TEXT : FRAME); Object.assign(c._props, JSON.parse(JSON.stringify(n._props))); c._w = n._w; c._h = n._h; for (const ch of n._children) { const cc = clone(ch, false); cc._parent = c; c._children.push(cc); } return c; };
  const i = clone(this, true); stats.instances++; figma.currentPage.appendChild(i); return i;
};
Node.prototype.setVectorNetworkAsync = async function (net) { if (!net.vertices.length || !net.segments.length) throw new Error("red vacía"); for (const s of net.segments) if (!net.vertices[s.start] || !net.vertices[s.end]) throw new Error("segmento inválido"); if (net.vertices.some((v) => v.x < 0 || v.y < 0)) throw new Error("vértice negativo (coordenadas no relativas)"); stats.vectors++; };
Node.prototype.loadAsync = async function () {};
Node.prototype.resizeWithoutConstraints = function (w, h) { if (this._type !== "SECTION") throw new Error("resizeWithoutConstraints solo en secciones aquí"); this._w = w; this._h = h; };

function make(type, allowed) { const n = new Node(type, allowed); if (figma.currentPage) figma.currentPage.appendChild(n); return n; }
const root = new Node("DOCUMENT", ["name"]);
const figma = {
  root, currentPage: null, fileKey: "TESTKEY1234567890123456", // gitleaks:allow (clave inventada para pruebas)
  showUI() {}, ui: { postMessage(m) { if (m.type === "log") console.log("  ·", m.msg); else if (m.type === "error") { console.error("ERROR:", m.msg); process.exitCode = 1; } else if (m.type === "done") { global.__done = m; } } },
  async loadFontAsync(f) { if (!AVAILABLE.has(fkey(f))) throw new Error("fuente no disponible " + fkey(f)); loaded.add(fkey(f)); },
  async setCurrentPageAsync(p) { if (p._type !== "PAGE") throw new Error("no es página"); figma.currentPage = p; },
  createPage() { if (process.env.MAX_PAGES && root._children.length >= +process.env.MAX_PAGES) throw new Error("The Starter plan only allows 3 pages"); const p = new Node("PAGE", PAGE); root.appendChild(p); stats.pages++; return p; },
  createSection() { stats.sections = (stats.sections || 0) + 1; return make("SECTION", ["name", "x", "y", "fills", "visible"]); },
  createFrame() { return make("FRAME", FRAME); },
  createComponent() { stats.components++; return make("COMPONENT", FRAME); },
  createText() { return make("TEXT", TEXT); },
  createRectangle() { return make("RECTANGLE", COMMON); },
  createVector() { return make("VECTOR", COMMON); },
  createNodeFromSvg(s) { if (!/^<svg[\s\S]*<\/svg>$/.test(s)) throw new Error("SVG inválido"); if (!/width="/.test(s) || !/viewBox=/.test(s)) throw new Error("SVG sin width o viewBox"); const n = make("FRAME", FRAME); return n; },
};
global.figma = figma; global.__html__ = "";
// El archivo de Figma del Sprint 2 tiene estas páginas
for (const n of ["Portada", "Tokens y componentes", "Pantallas MVP · iOS"]) { const p = figma.createPage(); p.name = n; }
stats.pages = 0;
figma.currentPage = root._children[0];
module.exports = { figma, stats };
