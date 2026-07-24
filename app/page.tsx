import type { Metadata } from "next";
import { MarketplaceApp } from "./components/MarketplaceApp";

export const metadata: Metadata = {
  title: "Mercado Live | Home",
  description:
    "Replica web funcional de marketplace con categorias, recomendaciones, publicaciones, chat y envios simulados.",
};

export default function Home() {
  return <MarketplaceApp />;
}
