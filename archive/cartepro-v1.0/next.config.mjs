/** @type {import('next').NextConfig} */
const nextConfig = {
  // Export statique : le démonstrateur n'a pas de backend à servir, et cette
  // sortie se déploie sur n'importe quel hébergeur de fichiers.
  output: "export",
  images: { unoptimized: true },
  trailingSlash: true
};
export default nextConfig;
