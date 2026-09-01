/* Assemble l'application en un seul fichier HTML : même code que
   l'application Next, bundle par esbuild, feuille de style et script mis en
   ligne. Sert à publier une version cliquable sans hébergement. */

import { build } from "esbuild";
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";

mkdirSync("preview/dist", { recursive: true });

const out = await build({
  entryPoints: ["preview/main.jsx"],
  bundle: true, minify: true, format: "iife", jsx: "automatic",
  target: ["es2020"], write: false,
  define: { "process.env.NODE_ENV": '"production"' },
  loader: { ".js": "jsx" }
});

const js = out.outputFiles[0].text;
const css = readFileSync("app/globals.css", "utf8");

/* Pas de <!doctype>, <html>, <head> ni <body> : la page est destinée à être
   publiée telle quelle comme artefact, où ce squelette est déjà fourni. */
const html = `<title>Ticket Tout</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Public+Sans:wght@400;500;600;700&family=IBM+Plex+Mono:wght@400;500;600&display=swap">
<style>
${css}
</style>
<div id="tickettout-root"></div>
<script>
${js}
</script>
`;

writeFileSync("preview/dist/index.html", html);
console.log("preview/dist/index.html —", (html.length / 1024).toFixed(0), "Ko");
