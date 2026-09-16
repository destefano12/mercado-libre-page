import type { Metadata } from "next";
import "./estudiar.css";

export const metadata: Metadata = {
  title: "Estudiar Mejor | Acompañamiento para estudiantes de secundaria",
  description:
    "Plataforma que organiza, pregunta y hace razonar. Nunca resuelve tareas ni redacta trabajos: planificador, tutor socrático, mapa de dominio, registro de errores y simulacros, todo en tu navegador.",
};

export default function LayoutEstudiarMejor({ children }: { children: React.ReactNode }) {
  return children;
}
