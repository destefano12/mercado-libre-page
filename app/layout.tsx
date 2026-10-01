import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Estudiar Mejor",
  description:
    "Plataforma de acompanamiento para estudiantes de secundaria: organiza el estudio, devuelve preguntas y nunca resuelve la tarea.",
  icons: {
    icon: "/estudiar-mejor.svg",
    shortcut: "/estudiar-mejor.svg",
  },
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
