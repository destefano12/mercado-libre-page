import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Mercado Live | Demo marketplace multiusuario",
  description:
    "Marketplace interactivo inspirado en Mercado Libre con usuarios, publicaciones, chat, recomendaciones y GPS simulado.",
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
  openGraph: {
    title: "Mercado Live",
    description:
      "Demo marketplace con personalizacion, publicaciones en vivo, chat y seguimiento de envios.",
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
