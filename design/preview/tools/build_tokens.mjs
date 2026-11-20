// Generates preview/tokens.css from design/tokens.json. Run: node design/preview/tools/build_tokens.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const here = path.dirname(fileURLToPath(import.meta.url));
const t = JSON.parse(fs.readFileSync(path.join(here, '../../tokens.json'), 'utf8'));
const kebab = (s) => s.replace(/[A-Z]+/g, (m) => '-' + m.toLowerCase());
let css = `/* GENERATED from design/tokens.json by tools/build_tokens.mjs. Do not edit. */\n`;
css += `@font-face{font-family:Kameron;src:url(assets/fonts/kameron_bold.ttf);font-weight:700}\n`;
for (const [w, n] of [[400, 'Regular'], [500, 'Medium'], [600, 'SemiBold'], [700, 'Bold']])
  css += `@font-face{font-family:Inter;src:url(assets/fonts/Inter-${n}.otf);font-weight:${w}}\n`;
for (const mode of ['light', 'dark']) {
  css += `[data-theme="${mode}"]{color-scheme:${mode};\n`;
  for (const [k, v] of Object.entries(t.color[mode])) css += `  --c${kebab(k)}:${v};\n`;
  css += `}\n`;
}
css += `:root{\n`;
for (const [k, v] of Object.entries(t.spacing)) css += `  --s-${k}:${v}px;\n`;
for (const [k, v] of Object.entries(t.radius)) css += `  --r-${k}:${v}px;\n`;
for (const [k, v] of Object.entries(t.size)) css += `  --z${kebab(k)}:${v}px;\n`;
css += `}\n`;
for (const [k, v] of Object.entries(t.type)) {
  const fam = v.font === 'logo' ? 'Kameron, serif' : 'Inter, sans-serif';
  css += `.t-${kebab(k)}{font-family:${fam};font-size:${v.size}px;line-height:${v.lineHeight}px;font-weight:${v.weight};letter-spacing:${v.letterSpacing}px;${v.tabular ? 'font-variant-numeric:tabular-nums;' : ''}}\n`;
}
fs.writeFileSync(path.join(here, '../tokens.css'), css);
fs.writeFileSync(path.join(here, '../tokens.js'), '// GENERATED from design/tokens.json. Do not edit.\nwindow.TOKENS = ' + JSON.stringify(t) + ';\n');
console.log('tokens.css written');
