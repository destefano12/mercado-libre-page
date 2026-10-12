import { redirect } from "next/navigation";

/**
 * La raiz del sitio lleva al marketplace, Mercado Live.
 * Estudiar Mejor sigue disponible en /estudiar-mejor.
 */
export default function Home() {
  redirect("/mercado-live");
}
