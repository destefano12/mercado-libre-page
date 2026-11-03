import type { Metadata } from "next";
import "./duomate.css";

export const metadata: Metadata = {
  title: "Duomate | Mates, bombillas y yerbas · Sucursal Palermo",
  description:
    "Mates curados a mano, bombillas de alpaca, yerbas estacionadas y termos. Comprá online y retirá en la sucursal Duomate Palermo en menos de 2 horas.",
  icons: { icon: [{ url: "/duomate.svg", type: "image/svg+xml" }] },
  openGraph: {
    title: "Duomate · Sucursal Palermo",
    description: "El mate se comparte. El buen mate, se elige.",
  },
};

export default function LayoutDuomate({ children }: { children: React.ReactNode }) {
  return (
    <>
      <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="" />
      {/* Fuentes solo para esta ruta. */}
      {/* eslint-disable-next-line @next/next/no-page-custom-font */}
      <link
        rel="stylesheet"
        href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,500;9..144,600;9..144,700&family=Nunito+Sans:opsz,wght@6..12,400;6..12,600;6..12,700;6..12,800&display=swap"
      />
      {children}
    </>
  );
}
