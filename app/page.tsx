import { redirect } from "next/navigation";

/**
 * La raiz del sitio lleva a Estudiar Mejor, que es la aplicacion publicada.
 * El marketplace, proyecto original de este repositorio, queda en /mercado-live.
 */
export default function Home() {
  redirect("/estudiar-mejor");
}
