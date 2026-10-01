import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Estudiar Mejor",
  description:
    "Plataforma de acompanamiento para estudiantes de secundaria: organiza el estudio, devuelve preguntas y nunca resuelve la tarea.",
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
  openGraph: {
    title: "Estudiar Mejor",
    description: "No hace tu tarea. Te hace pensarla.",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="es">
      <body>{children}</body>
    </html>
  );
}
