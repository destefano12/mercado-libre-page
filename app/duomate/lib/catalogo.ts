export type Categoria = "mates" | "bombillas" | "yerbas" | "termos" | "materas" | "kits";

export type Arte = "imperial" | "camionero" | "torpedo" | "vidrio" | "acero" | "calabaza" | "bombilla" | "yerba" | "termo" | "matera" | "kit";

export type Variante = { nombre: string; color: string };

export type Producto = {
  id: string;
  nombre: string;
  categoria: Categoria;
  precio: number;
  precioAnterior?: number;
  puntaje: number;
  opiniones: number;
  etiqueta?: "Más vendido" | "Nuevo" | "Edición limitada" | "Oferta";
  arte: Arte;
  variantes: Variante[];
  resumen: string;
  descripcion: string;
  detalles: string[];
  stock: number;
};

export const CATEGORIAS: { id: Categoria | "todo"; nombre: string }[] = [
  { id: "todo", nombre: "Todo" },
  { id: "mates", nombre: "Mates" },
  { id: "bombillas", nombre: "Bombillas" },
  { id: "yerbas", nombre: "Yerbas" },
  { id: "termos", nombre: "Termos" },
  { id: "materas", nombre: "Materas" },
  { id: "kits", nombre: "Kits" },
];

export const PRODUCTOS: Producto[] = [
  {
    id: "kit-duo",
    nombre: "Kit Duo Clásico",
    categoria: "kits",
    precio: 64900,
    precioAnterior: 78400,
    puntaje: 4.9,
    opiniones: 412,
    etiqueta: "Más vendido",
    arte: "kit",
    variantes: [
      { nombre: "Suela", color: "#8a5a36" },
      { nombre: "Negro", color: "#2a2522" },
    ],
    resumen: "Camionero de cuero, bombilla pico de loro y 1 kg de Blend Suave.",
    descripcion:
      "El combo con el que arranca la mayoría de nuestros clientes. Un camionero de calabaza forrado en cuero, una bombilla de alpaca que no se tapa y nuestra yerba de la casa. Viene en caja de regalo con instructivo de curado.",
    detalles: ["Mate camionero 250 ml", "Bombilla pico de loro de alpaca", "Yerba Duomate Blend Suave 1 kg", "Caja de regalo"],
    stock: 18,
  },
  {
    id: "imperial-cincelado",
    nombre: "Mate Imperial Cincelado",
    categoria: "mates",
    precio: 68900,
    puntaje: 4.9,
    opiniones: 186,
    etiqueta: "Edición limitada",
    arte: "imperial",
    variantes: [
      { nombre: "Suela", color: "#8a5a36" },
      { nombre: "Chocolate", color: "#4a2f22" },
      { nombre: "Negro", color: "#2a2522" },
    ],
    resumen: "Calabaza seleccionada, virola de alpaca cincelada a mano.",
    descripcion:
      "Cada imperial lo termina un artesano de San Antonio de Areco. La virola de alpaca se cincela a mano, así que no hay dos iguales. La calabaza viene curada y lista para la primera cebada.",
    detalles: ["Calabaza seleccionada", "Virola y base de alpaca cincelada", "Forrado en cuero vacuno", "Capacidad 230 ml"],
    stock: 6,
  },
  {
    id: "camionero-cuero",
    nombre: "Mate Camionero de Cuero",
    categoria: "mates",
    precio: 42500,
    puntaje: 4.8,
    opiniones: 298,
    arte: "camionero",
    variantes: [
      { nombre: "Negro", color: "#2a2522" },
      { nombre: "Suela", color: "#8a5a36" },
      { nombre: "Verde", color: "#2f4a35" },
    ],
    resumen: "Boca ancha, virola de acero y cuero cosido a mano.",
    descripcion:
      "El mate de boca ancha para cebar con espuma. Calabaza gruesa, virola lisa de acero inoxidable y forrado en cuero cosido con tiento.",
    detalles: ["Calabaza gruesa", "Virola de acero inoxidable", "Costura de tiento", "Capacidad 260 ml"],
    stock: 24,
  },
  {
    id: "torpedo-algarrobo",
    nombre: "Mate Torpedo de Algarrobo",
    categoria: "mates",
    precio: 24900,
    puntaje: 4.7,
    opiniones: 143,
    etiqueta: "Nuevo",
    arte: "torpedo",
    variantes: [
      { nombre: "Natural", color: "#a8703f" },
      { nombre: "Oscuro", color: "#5e3a22" },
    ],
    resumen: "Torneado en una sola pieza de algarrobo del norte.",
    descripcion:
      "La madera de algarrobo le da un dulzor suave a los primeros mates. Torneado en una pieza, con la forma alargada que mantiene la yerba firme.",
    detalles: ["Algarrobo macizo", "Torneado artesanal", "Terminación con aceite vegetal", "Capacidad 180 ml"],
    stock: 31,
  },
  {
    id: "calabaza-bronce",
    nombre: "Calabaza Natural Bronce",
    categoria: "mates",
    precio: 36900,
    puntaje: 4.8,
    opiniones: 97,
    arte: "calabaza",
    variantes: [
      { nombre: "Natural", color: "#b88a4a" },
      { nombre: "Tostada", color: "#7d5530" },
    ],
    resumen: "Calabaza sin forrar con virola de bronce pulido.",
    descripcion:
      "Para los puristas: calabaza a la vista, con su veta natural y una virola de bronce que se pone más linda con los años.",
    detalles: ["Calabaza a la vista", "Virola de bronce pulido", "Pie de bronce", "Capacidad 200 ml"],
    stock: 12,
  },
  {
    id: "acero-termico",
    nombre: "Mate de Acero Térmico",
    categoria: "mates",
    precio: 28500,
    precioAnterior: 33900,
    puntaje: 4.6,
    opiniones: 221,
    etiqueta: "Oferta",
    arte: "acero",
    variantes: [
      { nombre: "Verde yerba", color: "#2f5a3e" },
      { nombre: "Crema", color: "#e9dcc3" },
      { nombre: "Grafito", color: "#3b3d40" },
    ],
    resumen: "Doble pared: el agua no se enfría y no te quemás la mano.",
    descripcion:
      "Ideal para la oficina o el viaje. Doble pared de acero, no necesita curado y se lava en segundos.",
    detalles: ["Acero inoxidable 304", "Doble pared al vacío", "No requiere curado", "Capacidad 230 ml"],
    stock: 40,
  },
  {
    id: "vidrio-forrado",
    nombre: "Mate de Vidrio Forrado",
    categoria: "mates",
    precio: 15900,
    puntaje: 4.5,
    opiniones: 164,
    arte: "vidrio",
    variantes: [
      { nombre: "Suela", color: "#8a5a36" },
      { nombre: "Negro", color: "#2a2522" },
    ],
    resumen: "Interior de vidrio: no toma sabor y es fácil de limpiar.",
    descripcion:
      "El primer mate perfecto. Vaso de vidrio grueso forrado en cuero sintético, sin curado ni mantenimiento.",
    detalles: ["Vaso de vidrio grueso", "Forro de cuero sintético", "Apto lavavajillas (sin forro)", "Capacidad 200 ml"],
    stock: 55,
  },
  {
    id: "bombilla-pico-loro",
    nombre: "Bombilla Pico de Loro",
    categoria: "bombillas",
    precio: 18900,
    puntaje: 4.9,
    opiniones: 254,
    etiqueta: "Más vendido",
    arte: "bombilla",
    variantes: [
      { nombre: "Alpaca", color: "#c9ccd1" },
      { nombre: "Alpaca y bronce", color: "#c59b55" },
    ],
    resumen: "Alpaca maciza con filtro desarmable. No se tapa.",
    descripcion:
      "La bombilla de pico curvo que se apoya cómoda en los labios. El filtro de virola se desarma para limpiarla a fondo.",
    detalles: ["Alpaca maciza", "Filtro desarmable", "Largo 19 cm", "Garantía de por vida"],
    stock: 33,
  },
  {
    id: "bombilla-resorte",
    nombre: "Bombilla de Acero con Resorte",
    categoria: "bombillas",
    precio: 9900,
    puntaje: 4.6,
    opiniones: 189,
    arte: "bombilla",
    variantes: [
      { nombre: "Acero", color: "#b8bcc2" },
      { nombre: "Negra", color: "#3a3a3c" },
    ],
    resumen: "Filtro de resorte: ideal para yerbas con mucho polvo.",
    descripcion: "Acero quirúrgico con filtro de resorte que retiene el polvo. Liviana y muy fácil de limpiar.",
    detalles: ["Acero inoxidable 316", "Filtro de resorte", "Largo 17 cm"],
    stock: 60,
  },
  {
    id: "yerba-blend-suave",
    nombre: "Yerba Duomate Blend Suave",
    categoria: "yerbas",
    precio: 7800,
    puntaje: 4.8,
    opiniones: 532,
    etiqueta: "Más vendido",
    arte: "yerba",
    variantes: [
      { nombre: "1 kg", color: "#3d6b47" },
      { nombre: "500 g", color: "#5b8a5f" },
    ],
    resumen: "Estacionada 24 meses. Rendidora y sin amargor.",
    descripcion:
      "Nuestra yerba de la casa: hoja de Misiones estacionada naturalmente 24 meses, con poco palo y un sabor redondo que dura toda la ronda.",
    detalles: ["Origen Misiones", "Estacionamiento natural 24 meses", "Con palo, bajo en polvo"],
    stock: 120,
  },
  {
    id: "yerba-barbacua",
    nombre: "Yerba Barbacuá Ahumada",
    categoria: "yerbas",
    precio: 6400,
    puntaje: 4.7,
    opiniones: 211,
    arte: "yerba",
    variantes: [{ nombre: "500 g", color: "#6b4a2b" }],
    resumen: "Secada a leña al estilo barbacuá. Intensa y ahumada.",
    descripcion:
      "Secado tradicional sobre fuego de leña. Para quienes buscan un mate intenso con notas ahumadas.",
    detalles: ["Secado barbacuá a leña", "Sabor intenso", "500 g"],
    stock: 48,
  },
  {
    id: "yerba-serranas",
    nombre: "Yerba con Hierbas Serranas",
    categoria: "yerbas",
    precio: 5900,
    puntaje: 4.6,
    opiniones: 176,
    arte: "yerba",
    variantes: [{ nombre: "500 g", color: "#7a8b3a" }],
    resumen: "Con peperina, menta y burrito de Córdoba.",
    descripcion: "Nuestro Blend Suave con hierbas serranas cosechadas en Traslasierra. Fresca y digestiva.",
    detalles: ["Peperina, menta y burrito", "Hierbas de Traslasierra", "500 g"],
    stock: 64,
  },
  {
    id: "termo-pico-cebador",
    nombre: "Termo Acero 1 L Pico Cebador",
    categoria: "termos",
    precio: 54900,
    puntaje: 4.9,
    opiniones: 307,
    arte: "termo",
    variantes: [
      { nombre: "Verde yerba", color: "#2f5a3e" },
      { nombre: "Negro mate", color: "#262626" },
      { nombre: "Crema", color: "#e9dcc3" },
    ],
    resumen: "Mantiene el agua caliente 24 h. Pico cebador de precisión.",
    descripcion:
      "El pico cebador corta el chorro justo, sin gotear. Doble pared de acero al vacío: el agua se mantiene a temperatura de mate todo el día.",
    detalles: ["Acero inoxidable 18/8", "24 h caliente, 24 h frío", "Pico cebador antigoteo", "Capacidad 1 L"],
    stock: 22,
  },
  {
    id: "termo-media-manija",
    nombre: "Termo Media Manija 1,2 L",
    categoria: "termos",
    precio: 61500,
    precioAnterior: 69900,
    puntaje: 4.8,
    opiniones: 128,
    etiqueta: "Oferta",
    arte: "termo",
    variantes: [
      { nombre: "Grafito", color: "#3b3d40" },
      { nombre: "Terracota", color: "#a5512f" },
    ],
    resumen: "Más capacidad y manija plegable para la ruta.",
    descripcion: "Para las rondas largas. 1,2 litros, manija plegable y tapón con traba de seguridad.",
    detalles: ["Capacidad 1,2 L", "Manija plegable", "Tapón con traba", "Pico cebador"],
    stock: 14,
  },
  {
    id: "matera-vaqueta",
    nombre: "Matera de Cuero Vaqueta",
    categoria: "materas",
    precio: 79900,
    puntaje: 4.9,
    opiniones: 88,
    etiqueta: "Edición limitada",
    arte: "matera",
    variantes: [
      { nombre: "Suela", color: "#8a5a36" },
      { nombre: "Chocolate", color: "#4a2f22" },
    ],
    resumen: "Cuero vacuno curtido al vegetal. Lleva todo el equipo.",
    descripcion:
      "Cuero vaqueta curtido al vegetal que gana carácter con el uso. Compartimentos para termo de 1 L, mate, yerbera y azucarera.",
    detalles: ["Cuero vaqueta curtido al vegetal", "Entra termo de 1 L", "Correa regulable", "Herrajes de bronce"],
    stock: 9,
  },
];

export const formatearPrecio = (n: number) =>
  new Intl.NumberFormat("es-AR", { style: "currency", currency: "ARS", maximumFractionDigits: 0 }).format(n);

export const ENVIO_GRATIS_DESDE = 80000;
export const COSTO_ENVIO = 4500;
export const CUPONES: Record<string, number> = { DUO10: 0.1 };
