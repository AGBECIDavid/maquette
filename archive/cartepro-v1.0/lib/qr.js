/* ============================================================================
   Encodeur QR (ISO/IEC 18004) — mode octet, niveau de correction M,
   versions 1 à 4.

   Écrit ici plutôt qu'importé : le cahier des charges impose que le QR de
   paiement fonctionne en connectivité dégradée (§2.2). Une dépendance
   distante contredirait cette exigence. Sortie vérifiée par décodage
   (OpenCV) à pleine résolution, à la taille d'affichage et floutée.
   ========================================================================= */

/* -- Corps de Galois GF(256), polynôme primitif 0x11d -------------------- */
const EXP = new Array(512), LOG = new Array(256);
(function () {
  let x = 1;
  for (let i = 0; i < 255; i++) { EXP[i] = x; LOG[x] = i; x <<= 1; if (x & 0x100) x ^= 0x11d; }
  for (let i = 255; i < 512; i++) EXP[i] = EXP[i - 255];
})();
const gmul = (a, b) => (a === 0 || b === 0) ? 0 : EXP[LOG[a] + LOG[b]];

function genPoly(n) {
  let p = [1];
  for (let i = 0; i < n; i++) {
    const r = new Array(p.length + 1).fill(0);
    for (let j = 0; j < p.length; j++) { r[j] ^= p[j]; r[j + 1] ^= gmul(p[j], EXP[i]); }
    p = r;
  }
  return p;
}
function eccOf(data, n) {
  const gen = genPoly(n);
  const res = data.slice().concat(new Array(n).fill(0));
  for (let i = 0; i < data.length; i++) {
    const f = res[i];
    if (f === 0) continue;
    for (let j = 0; j < gen.length; j++) res[i + j] ^= gmul(gen[j], f);
  }
  return res.slice(data.length);
}

/* -- Tables de version, niveau M ---------------------------------------- */
// ecPerBlock = mots de correction par bloc ; blocks = [nb de blocs, mots de données par bloc]
const VERSIONS = {
  1: { size: 21, ecPerBlock: 10, blocks: [[1, 16]], align: [],       remainder: 0 },
  2: { size: 25, ecPerBlock: 16, blocks: [[1, 28]], align: [6, 18],  remainder: 7 },
  3: { size: 29, ecPerBlock: 26, blocks: [[1, 44]], align: [6, 22],  remainder: 7 },
  4: { size: 33, ecPerBlock: 18, blocks: [[2, 32]], align: [6, 26],  remainder: 7 }
};
const dataCodewords = v =>
  VERSIONS[v].blocks.reduce((s, b) => s + b[0] * b[1], 0);
// 4 bits de mode + 8 bits de longueur (versions 1 à 9) en tête du flux
export const capacity = v => Math.floor((dataCodewords(v) * 8 - 12) / 8);

const G15 = 0x537, G15_MASK = 0x5412;
function bchDigit(d) { let n = 0; while (d !== 0) { n++; d >>>= 1; } return n; }
function formatBits(mask) {
  const data = (0 /* niveau M */ << 3) | mask;   // niveau M = 0b00
  let d = data << 10;
  while (bchDigit(d) - bchDigit(G15) >= 0) d ^= (G15 << (bchDigit(d) - bchDigit(G15)));
  return ((data << 10) | d) ^ G15_MASK;
}

const MASKS = [
  (i, j) => (i + j) % 2 === 0,
  (i, j) => i % 2 === 0,
  (i, j) => j % 3 === 0,
  (i, j) => (i + j) % 3 === 0,
  (i, j) => (Math.floor(i / 2) + Math.floor(j / 3)) % 2 === 0,
  (i, j) => (i * j) % 2 + (i * j) % 3 === 0,
  (i, j) => ((i * j) % 2 + (i * j) % 3) % 2 === 0,
  (i, j) => ((i * j) % 3 + (i + j) % 2) % 2 === 0
];

/* -- Construction de la matrice ----------------------------------------- */
function blank(size) {
  return { m: Array.from({ length: size }, () => new Array(size).fill(null)),
           fn: Array.from({ length: size }, () => new Array(size).fill(false)), size: size };
}
function put(g, r, c, v) { g.m[r][c] = v; g.fn[r][c] = true; }

function finder(g, r0, c0) {
  for (let r = -1; r <= 7; r++) for (let c = -1; c <= 7; c++) {
    const r1 = r0 + r, c1 = c0 + c;
    if (r1 < 0 || c1 < 0 || r1 >= g.size || c1 >= g.size) continue;
    const on = (r >= 0 && r <= 6 && (c === 0 || c === 6))
            || (c >= 0 && c <= 6 && (r === 0 || r === 6))
            || (r >= 2 && r <= 4 && c >= 2 && c <= 4);
    put(g, r1, c1, on ? 1 : 0);
  }
}

function functionPatterns(g, ver) {
  const size = g.size, cfg = VERSIONS[ver];
  finder(g, 0, 0); finder(g, 0, size - 7); finder(g, size - 7, 0);

  for (let i = 8; i < size - 8; i++) {          // rythme
    const v = i % 2 === 0 ? 1 : 0;
    put(g, 6, i, v); put(g, i, 6, v);
  }
  const A = cfg.align;                           // motifs d'alignement
  for (let a = 0; a < A.length; a++) for (let b = 0; b < A.length; b++) {
    const r = A[a], c = A[b];
    if ((r <= 8 && c <= 8) || (r <= 8 && c >= size - 9) || (r >= size - 9 && c <= 8)) continue;
    for (let dr = -2; dr <= 2; dr++) for (let dc = -2; dc <= 2; dc++)
      put(g, r + dr, c + dc, (Math.abs(dr) === 2 || Math.abs(dc) === 2 || (dr === 0 && dc === 0)) ? 1 : 0);
  }
  for (let i = 0; i < 9; i++) {                  // zones réservées au format
    if (g.m[8][i] === null) put(g, 8, i, 0);
    if (g.m[i][8] === null) put(g, i, 8, 0);
  }
  for (let i = 0; i < 8; i++) {
    if (g.m[8][size - 1 - i] === null) put(g, 8, size - 1 - i, 0);
    if (g.m[size - 1 - i][8] === null) put(g, size - 1 - i, 8, 0);
  }
  put(g, size - 8, 8, 1);                        // module toujours noir
}

function placeData(g, bytes) {
  const size = g.size;
  let inc = -1, row = size - 1, bit = 7, byte = 0;
  for (let col = size - 1; col > 0; col -= 2) {
    if (col === 6) col--;
    for (;;) {
      for (let c = 0; c < 2; c++) {
        const cc = col - c;
        if (g.m[row][cc] === null) {
          let dark = 0;
          if (byte < bytes.length) dark = (bytes[byte] >>> bit) & 1;
          g.m[row][cc] = dark;
          if (--bit === -1) { byte++; bit = 7; }
        }
      }
      row += inc;
      if (row < 0 || row >= size) { row -= inc; inc = -inc; break; }
    }
  }
}

function applied(g, mask) {
  const size = g.size, out = g.m.map(r => r.slice());
  for (let r = 0; r < size; r++) for (let c = 0; c < size; c++)
    if (!g.fn[r][c] && MASKS[mask](r, c)) out[r][c] ^= 1;
  const bits = formatBits(mask);
  for (let i = 0; i < 15; i++) {
    const v = (bits >> i) & 1;
    if (i < 6) out[i][8] = v; else if (i < 8) out[i + 1][8] = v; else out[size - 15 + i][8] = v;
    if (i < 8) out[8][size - 1 - i] = v; else if (i < 9) out[8][15 - i] = v; else out[8][14 - i] = v;
  }
  out[size - 8][8] = 1;
  return out;
}

/* Pénalités normatives : plus le score est bas, meilleur est le masque. */
function penalty(m) {
  const n = m.length;
  let score = 0;

  for (let pass = 0; pass < 2; pass++) {          // règle 1 : suites de 5+
    for (let a = 0; a < n; a++) {
      let run = 1, prev = pass ? m[0][a] : m[a][0];
      for (let b = 1; b < n; b++) {
        const v = pass ? m[b][a] : m[a][b];
        if (v === prev) { run++; } else { if (run >= 5) score += 3 + (run - 5); run = 1; prev = v; }
      }
      if (run >= 5) score += 3 + (run - 5);
    }
  }
  for (let r = 0; r < n - 1; r++) for (let c = 0; c < n - 1; c++) {   // règle 2 : blocs 2×2
    const v = m[r][c];
    if (v === m[r][c + 1] && v === m[r + 1][c] && v === m[r + 1][c + 1]) score += 3;
  }
  const P = [1,0,1,1,1,0,1];                       // règle 3 : motif de leurre
  for (let pass = 0; pass < 2; pass++) {
    for (let a = 0; a < n; a++) for (let b = 0; b <= n - 7; b++) {
      let hit = true;
      for (let k = 0; k < 7; k++) if ((pass ? m[b + k][a] : m[a][b + k]) !== P[k]) { hit = false; break; }
      if (!hit) continue;
      const before = [];
      for (let k = b - 4; k < b; k++) before.push(k < 0 ? 0 : (pass ? m[k][a] : m[a][k]));
      const after = [];
      for (let k = b + 7; k < b + 11; k++) after.push(k >= n ? 0 : (pass ? m[k][a] : m[a][k]));
      if (before.every(v => v === 0) || after.every(v => v === 0)) score += 40;
    }
  }
  let dark = 0;                                    // règle 4 : équilibre noir/blanc
  for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) dark += m[r][c];
  score += Math.floor(Math.abs(dark * 100 / (n * n) - 50) / 5) * 10;
  return score;
}

/* -- API ---------------------------------------------------------------- */
export function encode(text) {
  const data = [];
  for (let i = 0; i < text.length; i++) {          // le jeton est en ASCII
    const cp = text.charCodeAt(i);
    if (cp > 255) throw new Error("QR : caractère hors ASCII");
    data.push(cp);
  }
  let ver = 0;
  for (let v = 1; v <= 4; v++) if (data.length <= capacity(v)) { ver = v; break; }
  if (!ver) throw new Error("QR : charge utile trop longue (" + data.length + " octets)");

  const cfg = VERSIONS[ver], total = dataCodewords(ver);

  // Flux binaire : mode 0100, longueur sur 8 bits, données, terminateur, bourrage
  let bits = "0100" + data.length.toString(2).padStart(8, "0");
  data.forEach(b => { bits += b.toString(2).padStart(8, "0"); });
  bits += "0000".slice(0, Math.min(4, total * 8 - bits.length));
  while (bits.length % 8) bits += "0";
  const words = [];
  for (let i = 0; i < bits.length; i += 8) words.push(parseInt(bits.substr(i, 8), 2));
  const PAD = [0xEC, 0x11];
  for (let i = 0; words.length < total; i++) words.push(PAD[i % 2]);

  // Découpage en blocs, correction d'erreur, puis entrelacement
  const dBlocks = [], eBlocks = [];
  let off = 0;
  cfg.blocks.forEach(([count, per]) => {
    for (let i = 0; i < count; i++) {
      const blk = words.slice(off, off + per); off += per;
      dBlocks.push(blk);
      eBlocks.push(eccOf(blk, cfg.ecPerBlock));
    }
  });
  const out = [];
  const maxD = Math.max.apply(null, dBlocks.map(b => b.length));
  for (let i = 0; i < maxD; i++) dBlocks.forEach(b => { if (i < b.length) out.push(b[i]); });
  for (let i = 0; i < cfg.ecPerBlock; i++) eBlocks.forEach(b => out.push(b[i]));

  const g = blank(cfg.size);
  functionPatterns(g, ver);
  const stream = out.slice();
  if (cfg.remainder) stream.push(0);               // bits restants, à zéro
  placeData(g, stream);

  let best = null, bestScore = Infinity;
  for (let mask = 0; mask < 8; mask++) {
    const cand = applied(g, mask), s = penalty(cand);
    if (s < bestScore) { bestScore = s; best = cand; }
  }
  return { modules: best, size: cfg.size, version: ver };
}

/* Dessine sur un canvas, zone de silence de 4 modules comprise. */
export function draw(canvas, text, px) {
  const qr = encode(text);
  const quiet = 4, n = qr.size + quiet * 2;
  const scale = Math.max(1, Math.floor((px || 232) / n));
  const side = scale * n;
  canvas.width = side; canvas.height = side;
  const ctx = canvas.getContext("2d");
  ctx.fillStyle = "#ffffff"; ctx.fillRect(0, 0, side, side);
  ctx.fillStyle = "#12172b";
  for (let r = 0; r < qr.size; r++) for (let c = 0; c < qr.size; c++)
    if (qr.modules[r][c]) ctx.fillRect((c + quiet) * scale, (r + quiet) * scale, scale, scale);
  return qr;
}
