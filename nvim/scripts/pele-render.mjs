// Render mermaid source (stdin) to a self-contained SVG (stdout) with Pele
// (https://pele.run): no browser, ~0.2s vs ~1-2s for mmdc + headless Chrome.
//   node pele-render.mjs [scale] < block.mmd > block.svg
// Pele is resolved from $PELE_DIR (default ~/.local/share/pele, an
// `npm install pele` dir). On a syntax error it prints the message to stderr
// and exits 1.
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const dir = process.env.PELE_DIR || join(homedir(), ".local/share/pele");
const { render } = await import(pathToFileURL(createRequire(join(dir, "/")).resolve("pele")).href);
const scale = Number(process.argv[2]) || 1;

let svg;
try {
  ({ svg } = render(readFileSync(0, "utf8")));
} catch (e) {
  process.stderr.write(`${e.message}\n`);
  process.exit(1);
}

// Pele colors everything through CSS custom properties (var(--_fg) etc. with
// fallbacks declared on the root). librsvg -- chafa's SVG loader -- does not
// resolve them, so the diagram would come out blank: inline every var().
const vars = {};
for (const m of svg.matchAll(/(--_\w+):var\(--pele-[\w-]+,([^)]+)\)/g)) vars[m[1]] = m[2];
for (let i = 0; i < 3; i++) {
  svg = svg.replace(/var\((--[\w-]+)(?:,([^()]*))?\)/g, (s, name, fallback) => vars[name] ?? fallback ?? s);
}

// Opaque background (the pane behind it may be dark), and a larger intrinsic
// size: chafa draws pixel graphics at their native size, so this sets how big
// the image is on screen. Pele's responsive `max-width:100%;height:auto` style
// would override width/height in librsvg, so drop it.
svg = svg.replace(/<svg\b[^>]*>/, (tag) =>
  tag
    .replace(/\b(width|height)="([\d.]+)"/g, (_, k, v) => `${k}="${v * scale}"`)
    .replace(/max-width:100%;height:auto;?/, "") +
  `<rect width="100%" height="100%" fill="${vars["--_bg"] || "#fff"}"/>`,
);
process.stdout.write(svg);
