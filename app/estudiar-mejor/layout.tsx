import type { Metadata } from "next";
import "./estudiar.css";

export const metadata: Metadata = {
  title: "Estudiar Mejor | Acompañamiento para estudiantes de secundaria",
  // El SVG sirve para la pestaña; los teléfonos necesitan el PNG aparte, y sin
  // él iOS dibuja una letra en vez del logo al agregarla a la pantalla de inicio.
  icons: {
    icon: [
      { url: "/estudiar-mejor.svg", type: "image/svg+xml" },
      { url: "/icono-192.png", sizes: "192x192", type: "image/png" },
    ],
    shortcut: "/estudiar-mejor.svg",
    apple: [{ url: "/apple-touch-icon.png", sizes: "180x180", type: "image/png" }],
  },
  manifest: "/manifest.webmanifest",
  appleWebApp: { capable: true, title: "Estudiar Mejor", statusBarStyle: "black-translucent" },
  description:
    "Plataforma que organiza, pregunta y hace razonar. Nunca resuelve tareas ni redacta trabajos: planificador, tutor socrático, mapa de dominio, registro de errores y simulacros, todo en tu navegador.",
};

export default function LayoutEstudiarMejor({ children }: { children: React.ReactNode }) {
  return (
    <>
      {/* React eleva estos enlaces al <head>. */}
      <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="" />
      {/* A propósito sólo en esta ruta: el marketplace de "/" no usa estas fuentes. */}
      {/* eslint-disable-next-line @next/next/no-page-custom-font */}
      <link
        rel="stylesheet"
        href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400&family=Source+Serif+4:opsz,wght@8..60,600;8..60,700&display=swap"
      />
      {children}
    </>
  );
}
