export type CategoryId =
  | "vehiculos"
  | "inmuebles"
  | "streaming"
  | "tecnologia"
  | "moda"
  | "hogar"
  | "herramientas"
  | "supermercado";

export type AssetKey = "home" | "categories";

export type ProductVisual =
  | {
      type: "asset";
      asset: AssetKey;
      objectPosition: string;
      label?: string;
    }
  | {
      type: "generated";
      gradient: string;
      label: string;
    };

export interface CategoryFilter {
  label: string;
  values: string[];
}

export interface CategoryAd {
  eyebrow: string;
  title: string;
  body: string;
  metric: string;
}

export interface CategoryConfig {
  id: CategoryId;
  label: string;
  navLabel: string;
  layout: "market" | "vehicle" | "real-estate" | "streaming" | "fashion";
  bannerTitle: string;
  bannerText: string;
  accent: string;
  tint: string;
  filters: CategoryFilter[];
  sortModes: string[];
  ads: CategoryAd[];
}

export interface UserProfile {
  id: string;
  name: string;
  email: string;
  location: string;
  avatar: string;
  reputation: number;
  joinedAt: string;
}

export interface Listing {
  id: string;
  title: string;
  description: string;
  categoryId: CategoryId;
  sellerId: string;
  price: number;
  oldPrice?: number;
  currency: "ARS";
  condition: "Nuevo" | "Usado" | "Digital";
  location: string;
  shipping: string;
  createdAt: string;
  views: number;
  sold: number;
  rating: number;
  tags: string[];
  meta: Record<string, string | number>;
  badge?: string;
  sponsored?: boolean;
  visual: ProductVisual;
}

export interface ViewEvent {
  id: string;
  userId: string;
  listingId: string;
  categoryId: CategoryId;
  tags: string[];
  viewedAt: string;
}

export interface ChatMessage {
  id: string;
  threadId: string;
  senderId: string;
  body: string;
  createdAt: string;
  read: boolean;
}

export interface ChatThread {
  id: string;
  listingId: string;
  buyerId: string;
  sellerId: string;
  messages: ChatMessage[];
  lastMessageAt: string;
}

export interface Shipment {
  id: string;
  listingId: string;
  origin: string;
  destination: string;
  status: string;
  progress: number;
  etaMinutes: number;
  route: Array<{ label: string; x: number; y: number }>;
}

export interface NotificationEvent {
  id: string;
  text: string;
  createdAt: string;
}

export interface MarketplaceState {
  users: UserProfile[];
  activeUserId: string;
  listings: Listing[];
  views: ViewEvent[];
  chats: ChatThread[];
  shipments: Shipment[];
  notifications: NotificationEvent[];
}

export const categories: CategoryConfig[] = [
  {
    id: "vehiculos",
    label: "Vehiculos",
    navLabel: "Vehiculos",
    layout: "vehicle",
    bannerTitle: "Autos, motos y financiacion en tu zona",
    bannerText: "Orden visual por kilometraje, año, transmision y marca.",
    accent: "#3483fa",
    tint: "#eaf3ff",
    filters: [
      { label: "Año", values: ["2026", "2024", "2022", "2019"] },
      { label: "Kilometraje", values: ["0 km", "Menos de 30.000 km", "60.000 km"] },
      { label: "Transmision", values: ["Automatica", "Manual"] },
      { label: "Marca", values: ["Toyota", "Volkswagen", "Ford", "Honda"] },
    ],
    sortModes: ["Mejor match", "Menor kilometraje", "Mayor año", "Menor precio"],
    ads: [
      {
        eyebrow: "Mercado Autos",
        title: "Cotiza tu usado en 2 minutos",
        body: "Comparador de precios con agencias verificadas y test drive coordinado.",
        metric: "18 agencias online",
      },
      {
        eyebrow: "Seguro incluido",
        title: "Cobertura desde el primer viaje",
        body: "Simula cuotas, patente y seguro antes de contactar al vendedor.",
        metric: "Hasta 12 cuotas",
      },
    ],
  },
  {
    id: "inmuebles",
    label: "Inmuebles",
    navLabel: "Inmuebles",
    layout: "real-estate",
    bannerTitle: "Casas y departamentos con mapa barrial",
    bannerText: "Filtros por metros, ambientes, ubicacion y tipo de operacion.",
    accent: "#00a650",
    tint: "#e7f7ef",
    filters: [
      { label: "Ambientes", values: ["1 ambiente", "2 ambientes", "3 ambientes", "4+"] },
      { label: "Metros", values: ["40 m2", "65 m2", "100 m2", "150 m2"] },
      { label: "Ubicacion", values: ["Palermo", "Caballito", "Rosario", "Cordoba"] },
      { label: "Operacion", values: ["Venta", "Alquiler"] },
    ],
    sortModes: ["Relevancia", "Mayor superficie", "Menor precio", "Mas recientes"],
    ads: [
      {
        eyebrow: "Tasacion express",
        title: "Precio de mercado por barrio",
        body: "Promedios por metro cuadrado y demanda real de consultas.",
        metric: "Actualizado hoy",
      },
      {
        eyebrow: "Mudanza simple",
        title: "Reserva visita y envio de documentacion",
        body: "Agenda recorridos y centraliza chats con inmobiliarias.",
        metric: "24 h de respuesta",
      },
    ],
  },
  {
    id: "streaming",
    label: "Entretenimiento y Streaming",
    navLabel: "Mercado Play",
    layout: "streaming",
    bannerTitle: "Peliculas, packs digitales y accesos premium",
    bannerText: "Servicios, codigos y membresias ordenados por plataforma y entrega.",
    accent: "#7c3aed",
    tint: "#f2ecff",
    filters: [
      { label: "Plataforma", values: ["HBO Max", "Disney+", "Prime Video", "Crunchyroll"] },
      { label: "Tipo", values: ["Cuenta", "Codigo", "Membresia", "Pelicula"] },
      { label: "Entrega", values: ["Instantanea", "24 horas"] },
      { label: "Duracion", values: ["1 mes", "3 meses", "12 meses"] },
    ],
    sortModes: ["Entrega mas rapida", "Mas vendidos", "Menor precio", "Mejor rating"],
    ads: [
      {
        eyebrow: "Streaming protegido",
        title: "Accesos digitales con garantia",
        body: "Validacion del vendedor y chat activo antes de liberar el pago.",
        metric: "Entrega instantanea",
      },
      {
        eyebrow: "Estrenos",
        title: "Peliculas y packs por saga",
        body: "Colecciones curadas por genero y ultima interaccion del usuario.",
        metric: "4K y HD",
      },
    ],
  },
  {
    id: "tecnologia",
    label: "Tecnologia",
    navLabel: "Tecnologia",
    layout: "market",
    bannerTitle: "Tecnologia con envio full y comparador",
    bannerText: "Celulares, notebooks y accesorios ordenados por rendimiento y entrega.",
    accent: "#1259c3",
    tint: "#edf4ff",
    filters: [
      { label: "Marca", values: ["Apple", "Samsung", "Motorola", "Lenovo"] },
      { label: "Memoria", values: ["128 GB", "256 GB", "512 GB", "1 TB"] },
      { label: "Envio", values: ["Full", "Llega hoy", "Gratis"] },
      { label: "Estado", values: ["Nuevo", "Usado"] },
    ],
    sortModes: ["Mejor match", "Menor precio", "Mayor descuento", "Mas vendidos"],
    ads: [
      {
        eyebrow: "Semana Tech",
        title: "Celulares con envio Full",
        body: "Comparador de specs, cuotas y reputacion de vendedores.",
        metric: "15% OFF extra",
      },
      {
        eyebrow: "Notebooks",
        title: "Equipos listos para trabajar",
        body: "Filtros por procesador, RAM, almacenamiento y garantia.",
        metric: "Garantia 12 meses",
      },
    ],
  },
  {
    id: "moda",
    label: "Moda",
    navLabel: "Moda",
    layout: "fashion",
    bannerTitle: "Moda, talles y looks personalizados",
    bannerText: "Ordena por talle, color, envio y marcas favoritas.",
    accent: "#db2777",
    tint: "#fff0f7",
    filters: [
      { label: "Talle", values: ["S", "M", "L", "XL"] },
      { label: "Color", values: ["Negro", "Azul", "Blanco", "Verde"] },
      { label: "Marca", values: ["Topper", "Adidas", "Levi's", "Prune"] },
      { label: "Envio", values: ["Full", "Gratis"] },
    ],
    sortModes: ["Inspirado en tus likes", "Menor precio", "Mas vendidos", "Novedades"],
    ads: [
      {
        eyebrow: "Looks por clima",
        title: "Seleccion urbana para Buenos Aires",
        body: "Prendas combinadas con talles y marcas frecuentes.",
        metric: "Cambios gratis",
      },
      {
        eyebrow: "Oficiales",
        title: "Tiendas verificadas",
        body: "Colecciones de temporada y envios flexibles.",
        metric: "Full disponible",
      },
    ],
  },
  {
    id: "hogar",
    label: "Hogar y Muebles",
    navLabel: "Hogar",
    layout: "market",
    bannerTitle: "Hogar, muebles y deco por ambiente",
    bannerText: "Arma espacios filtrando medidas, material, estilo y envio.",
    accent: "#8b5e34",
    tint: "#fff5e9",
    filters: [
      { label: "Ambiente", values: ["Living", "Cocina", "Dormitorio", "Patio"] },
      { label: "Material", values: ["Madera", "Metal", "Tela", "Vidrio"] },
      { label: "Medida", values: ["Compacto", "Mediano", "Grande"] },
      { label: "Envio", values: ["Gratis", "Con armado"] },
    ],
    sortModes: ["Mas relevantes", "Menor precio", "Mejor reputacion", "Mayor descuento"],
    ads: [
      {
        eyebrow: "Deco por ambiente",
        title: "Combina muebles y accesorios",
        body: "Promos de living, cocina y dormitorio en un solo recorrido.",
        metric: "Hasta 35% OFF",
      },
      {
        eyebrow: "Envio coordinado",
        title: "Grandes volumenes con seguimiento",
        body: "Simulador de ruta desde deposito hasta domicilio.",
        metric: "GPS activo",
      },
    ],
  },
  {
    id: "herramientas",
    label: "Herramientas",
    navLabel: "Herramientas",
    layout: "market",
    bannerTitle: "Herramientas para taller, obra y jardin",
    bannerText: "Filtros por potencia, marca, uso profesional y garantia.",
    accent: "#f59e0b",
    tint: "#fff8df",
    filters: [
      { label: "Uso", values: ["Profesional", "Hogar", "Obra", "Jardin"] },
      { label: "Marca", values: ["Bosch", "DeWalt", "Makita", "Stanley"] },
      { label: "Potencia", values: ["600 W", "1200 W", "18 V", "20 V"] },
      { label: "Kit", values: ["Con accesorios", "Solo equipo"] },
    ],
    sortModes: ["Mayor potencia", "Mejor precio", "Mas vendidos", "Garantia"],
    ads: [
      {
        eyebrow: "Taller completo",
        title: "Kits con garantia oficial",
        body: "Compra por uso: carpinteria, mecanica, electricidad o jardin.",
        metric: "18 V lider",
      },
      {
        eyebrow: "Obra express",
        title: "Entrega coordinada en obra",
        body: "Publicaciones con stock cercano y chat tecnico.",
        metric: "Llega hoy",
      },
    ],
  },
  {
    id: "supermercado",
    label: "Supermercado",
    navLabel: "Supermercado",
    layout: "market",
    bannerTitle: "Supermercado con reposicion inteligente",
    bannerText: "Canastas por consumo, marcas frecuentes y entrega programada.",
    accent: "#00a650",
    tint: "#ebfff5",
    filters: [
      { label: "Pasillo", values: ["Limpieza", "Bebidas", "Almacen", "Mascotas"] },
      { label: "Marca", values: ["Coca-Cola", "Ala", "Purina", "La Serenisima"] },
      { label: "Pack", values: ["6 unidades", "12 unidades", "Familiar"] },
      { label: "Entrega", values: ["Hoy", "Programada"] },
    ],
    sortModes: ["Reposicion sugerida", "Menor precio", "Descuentos", "Mas comprados"],
    ads: [
      {
        eyebrow: "Compra recurrente",
        title: "Ahorra armando tu carrito mensual",
        body: "El sistema prioriza marcas vistas y productos repetidos.",
        metric: "2x1 activo",
      },
      {
        eyebrow: "Envio Full",
        title: "Canastas con llegada programada",
        body: "Seguimiento en mapa desde el centro de distribucion.",
        metric: "Hoy 18:00",
      },
    ],
  },
];

export const users: UserProfile[] = [
  {
    id: "u-benjamin",
    name: "BENJAMIN",
    email: "benjamin@demo.local",
    location: "Buenos Aires 1772",
    avatar: "BD",
    reputation: 4.9,
    joinedAt: "2025-02-11T11:00:00.000Z",
  },
  {
    id: "u-lucia",
    name: "Lucia Motors",
    email: "lucia.motors@demo.local",
    location: "Villa Crespo, CABA",
    avatar: "LM",
    reputation: 4.8,
    joinedAt: "2024-10-02T15:40:00.000Z",
  },
  {
    id: "u-mateo",
    name: "Mateo Store",
    email: "mateo.store@demo.local",
    location: "Rosario Centro",
    avatar: "MS",
    reputation: 4.7,
    joinedAt: "2025-05-16T09:10:00.000Z",
  },
  {
    id: "u-nora",
    name: "Nora Inmuebles",
    email: "nora.inmuebles@demo.local",
    location: "Palermo, CABA",
    avatar: "NI",
    reputation: 5,
    joinedAt: "2023-09-21T13:30:00.000Z",
  },
  {
    id: "u-digital",
    name: "Play Digital AR",
    email: "play.digital@demo.local",
    location: "Entrega online",
    avatar: "PD",
    reputation: 4.6,
    joinedAt: "2024-03-04T20:00:00.000Z",
  },
];

export const listings: Listing[] = [
  {
    id: "prod-parche-remo",
    title: "Parche Remo Encore Ambassador Coated 13",
    description: "Parche original para bateria, tono calido y respuesta pareja.",
    categoryId: "hogar",
    sellerId: "u-mateo",
    price: 52000,
    currency: "ARS",
    condition: "Nuevo",
    location: "Rosario Centro",
    shipping: "Envio gratis",
    createdAt: "2026-07-24T01:10:00.000Z",
    views: 128,
    sold: 26,
    rating: 4.8,
    tags: ["musica", "bateria", "parche", "remo", "envio gratis"],
    meta: { ambiente: "Estudio", material: "Coated", medida: "13 pulgadas" },
    badge: "Llega hoy",
    visual: { type: "asset", asset: "home", objectPosition: "31% 80%", label: "Remo" },
  },
  {
    id: "prod-cristiano-panini",
    title: "Cristiano Ronaldo Bronze Panini Extra 2026",
    description: "Figurita coleccionable con proteccion rigida y envio full.",
    categoryId: "streaming",
    sellerId: "u-digital",
    price: 125000,
    currency: "ARS",
    condition: "Nuevo",
    location: "Entrega online",
    shipping: "Envio gratis",
    createdAt: "2026-07-23T20:20:00.000Z",
    views: 560,
    sold: 41,
    rating: 4.9,
    tags: ["coleccion", "futbol", "panini", "mundial", "digital"],
    meta: { plataforma: "Pelicula", tipo: "Coleccion", entrega: "24 horas", duracion: "Permanente" },
    badge: "Full",
    sponsored: true,
    visual: { type: "asset", asset: "home", objectPosition: "45% 65%", label: "Panini" },
  },
  {
    id: "prod-album-fifa",
    title: "Album Oficial Copa Mundial FIFA 2026 tapa dura",
    description: "Album oficial con laminas iniciales y codigo digital.",
    categoryId: "streaming",
    sellerId: "u-digital",
    price: 15999,
    oldPrice: 39999,
    currency: "ARS",
    condition: "Nuevo",
    location: "Entrega online",
    shipping: "Full",
    createdAt: "2026-07-23T19:00:00.000Z",
    views: 870,
    sold: 83,
    rating: 4.7,
    tags: ["mundial", "album", "fifa", "coleccion", "full"],
    meta: { plataforma: "Codigo", tipo: "Pelicula", entrega: "Instantanea", duracion: "Permanente" },
    badge: "60% OFF",
    visual: { type: "asset", asset: "home", objectPosition: "55% 67%", label: "FIFA" },
  },
  {
    id: "prod-ilusionistas",
    title: "Los Ilusionistas - acceso HD por 48 horas",
    description: "Acceso digital inmediato para ver en alta definicion.",
    categoryId: "streaming",
    sellerId: "u-digital",
    price: 0,
    currency: "ARS",
    condition: "Digital",
    location: "Entrega online",
    shipping: "Ver gratis",
    createdAt: "2026-07-24T00:40:00.000Z",
    views: 1200,
    sold: 318,
    rating: 4.6,
    tags: ["pelicula", "streaming", "hd", "mercado play", "gratis"],
    meta: { plataforma: "HBO Max", tipo: "Pelicula", entrega: "Instantanea", duracion: "48 horas" },
    badge: "Ver gratis",
    visual: { type: "asset", asset: "home", objectPosition: "67% 62%", label: "Play" },
  },
  {
    id: "tech-iphone",
    title: "iPhone 15 128 GB azul con garantia oficial",
    description: "Equipo sellado, bateria al 100% y envio Full a CABA.",
    categoryId: "tecnologia",
    sellerId: "u-mateo",
    price: 1299900,
    oldPrice: 1480000,
    currency: "ARS",
    condition: "Nuevo",
    location: "Buenos Aires",
    shipping: "Full",
    createdAt: "2026-07-22T12:00:00.000Z",
    views: 920,
    sold: 14,
    rating: 4.9,
    tags: ["apple", "iphone", "128 gb", "full", "celular"],
    meta: { marca: "Apple", memoria: "128 GB", envio: "Full", estado: "Nuevo" },
    badge: "Llega hoy",
    sponsored: true,
    visual: {
      type: "generated",
      gradient: "linear-gradient(145deg, #d9ecff, #3483fa 55%, #102a56)",
      label: "15",
    },
  },
  {
    id: "tech-notebook",
    title: "Notebook Lenovo IdeaPad Ryzen 7 16 GB 512 GB",
    description: "Pantalla Full HD, SSD NVMe y bateria de larga duracion.",
    categoryId: "tecnologia",
    sellerId: "u-mateo",
    price: 875000,
    oldPrice: 965000,
    currency: "ARS",
    condition: "Nuevo",
    location: "Cordoba",
    shipping: "Envio gratis",
    createdAt: "2026-07-21T18:20:00.000Z",
    views: 744,
    sold: 32,
    rating: 4.8,
    tags: ["notebook", "lenovo", "512 gb", "trabajo", "garantia"],
    meta: { marca: "Lenovo", memoria: "512 GB", envio: "Gratis", estado: "Nuevo" },
    badge: "12 cuotas",
    visual: {
      type: "generated",
      gradient: "linear-gradient(145deg, #f6f7fb, #98a2b3 45%, #111827)",
      label: "Ryzen 7",
    },
  },
  {
    id: "veh-toyota",
    title: "Toyota Corolla XEI 2024 automatico",
    description: "Unico dueño, services oficiales y transferencia lista.",
    categoryId: "vehiculos",
    sellerId: "u-lucia",
    price: 25500000,
    currency: "ARS",
    condition: "Usado",
    location: "Villa Crespo, CABA",
    shipping: "Retiro coordinado",
    createdAt: "2026-07-23T15:15:00.000Z",
    views: 1330,
    sold: 0,
    rating: 4.9,
    tags: ["toyota", "corolla", "automatico", "2024", "autos"],
    meta: { año: "2024", kilometraje: "18.000 km", transmision: "Automatica", marca: "Toyota" },
    badge: "Financiacion",
    sponsored: true,
    visual: {
      type: "generated",
      gradient: "linear-gradient(135deg, #eff6ff, #93c5fd 42%, #1d4ed8)",
      label: "Corolla",
    },
  },
  {
    id: "veh-moto",
    title: "Honda Wave 110 S 2026 0 km",
    description: "Patentamiento bonificado y retiro inmediato.",
    categoryId: "vehiculos",
    sellerId: "u-lucia",
    price: 2630000,
    currency: "ARS",
    condition: "Nuevo",
    location: "San Martin",
    shipping: "Retiro en agencia",
    createdAt: "2026-07-23T10:45:00.000Z",
    views: 622,
    sold: 7,
    rating: 4.7,
    tags: ["honda", "moto", "0 km", "manual", "2026"],
    meta: { año: "2026", kilometraje: "0 km", transmision: "Manual", marca: "Honda" },
    badge: "0 km",
    visual: {
      type: "generated",
      gradient: "linear-gradient(140deg, #fff7ed, #fb923c 45%, #7c2d12)",
      label: "110 S",
    },
  },
  {
    id: "home-palermo",
    title: "Departamento 3 ambientes luminoso en Palermo",
    description: "Balcon, amenities, cochera opcional y visitas por agenda.",
    categoryId: "inmuebles",
    sellerId: "u-nora",
    price: 185000,
    currency: "ARS",
    condition: "Usado",
    location: "Palermo, CABA",
    shipping: "Visita coordinada",
    createdAt: "2026-07-22T16:00:00.000Z",
    views: 487,
    sold: 0,
    rating: 5,
    tags: ["departamento", "palermo", "3 ambientes", "alquiler", "balcon"],
    meta: { ambientes: "3 ambientes", metros: "65 m2", ubicacion: "Palermo", operacion: "Alquiler" },
    badge: "Mapa activo",
    sponsored: true,
    visual: {
      type: "generated",
      gradient: "linear-gradient(135deg, #ecfdf5, #6ee7b7 48%, #065f46)",
      label: "65 m2",
    },
  },
  {
    id: "home-caballito",
    title: "PH reciclado 4 ambientes con patio",
    description: "Entrada independiente, terraza y cocina integrada.",
    categoryId: "inmuebles",
    sellerId: "u-nora",
    price: 124000000,
    currency: "ARS",
    condition: "Usado",
    location: "Caballito, CABA",
    shipping: "Visita coordinada",
    createdAt: "2026-07-20T09:00:00.000Z",
    views: 374,
    sold: 0,
    rating: 4.9,
    tags: ["ph", "caballito", "4 ambientes", "venta", "patio"],
    meta: { ambientes: "4+", metros: "150 m2", ubicacion: "Caballito", operacion: "Venta" },
    badge: "Apto credito",
    visual: {
      type: "generated",
      gradient: "linear-gradient(135deg, #fefce8, #fde68a 40%, #92400e)",
      label: "PH",
    },
  },
  {
    id: "stream-hbo",
    title: "HBO Max premium 3 meses entrega instantanea",
    description: "Acceso digital con soporte por chat y garantia del vendedor.",
    categoryId: "streaming",
    sellerId: "u-digital",
    price: 9800,
    oldPrice: 14500,
    currency: "ARS",
    condition: "Digital",
    location: "Entrega online",
    shipping: "Instantaneo",
    createdAt: "2026-07-24T00:05:00.000Z",
    views: 1540,
    sold: 214,
    rating: 4.6,
    tags: ["hbo max", "streaming", "3 meses", "instantanea", "digital"],
    meta: { plataforma: "HBO Max", tipo: "Membresia", entrega: "Instantanea", duracion: "3 meses" },
    badge: "Mas vendido",
    visual: {
      type: "generated",
      gradient: "linear-gradient(135deg, #1e1b4b, #7c3aed 48%, #db2777)",
      label: "HBO",
    },
  },
  {
    id: "fashion-zapas",
    title: "Zapatillas urbanas Topper cuero blanco",
    description: "Talles completos, cambio gratis y envio Full.",
    categoryId: "moda",
    sellerId: "u-mateo",
    price: 84999,
    oldPrice: 109000,
    currency: "ARS",
    condition: "Nuevo",
    location: "Buenos Aires",
    shipping: "Full",
    createdAt: "2026-07-21T14:20:00.000Z",
    views: 340,
    sold: 56,
    rating: 4.5,
    tags: ["zapatillas", "topper", "blanco", "moda", "full"],
    meta: { talle: "M", color: "Blanco", marca: "Topper", envio: "Full" },
    badge: "Cambio gratis",
    visual: {
      type: "generated",
      gradient: "linear-gradient(135deg, #fff1f2, #f9a8d4 42%, #be185d)",
      label: "Urban",
    },
  },
  {
    id: "tools-taladro",
    title: "Taladro percutor Bosch 650 W con maletin",
    description: "Kit profesional con mechas, garantia y factura A.",
    categoryId: "herramientas",
    sellerId: "u-mateo",
    price: 118500,
    currency: "ARS",
    condition: "Nuevo",
    location: "Cordoba",
    shipping: "Envio gratis",
    createdAt: "2026-07-20T13:00:00.000Z",
    views: 280,
    sold: 19,
    rating: 4.8,
    tags: ["bosch", "taladro", "650 w", "profesional", "kit"],
    meta: { uso: "Profesional", marca: "Bosch", potencia: "600 W", kit: "Con accesorios" },
    badge: "Garantia",
    visual: {
      type: "generated",
      gradient: "linear-gradient(135deg, #fffbeb, #fbbf24 45%, #92400e)",
      label: "650 W",
    },
  },
  {
    id: "super-pack",
    title: "Pack limpieza hogar Ala + desinfectante familiar",
    description: "Combo mensual con reposicion sugerida y entrega programada.",
    categoryId: "supermercado",
    sellerId: "u-mateo",
    price: 24500,
    oldPrice: 32900,
    currency: "ARS",
    condition: "Nuevo",
    location: "Buenos Aires",
    shipping: "Entrega hoy",
    createdAt: "2026-07-23T09:30:00.000Z",
    views: 190,
    sold: 101,
    rating: 4.7,
    tags: ["limpieza", "ala", "pack", "supermercado", "hoy"],
    meta: { pasillo: "Limpieza", marca: "Ala", pack: "6 unidades", entrega: "Hoy" },
    badge: "2x1",
    visual: {
      type: "generated",
      gradient: "linear-gradient(135deg, #ecfeff, #22d3ee 45%, #0f766e)",
      label: "Pack",
    },
  },
];

export const initialViews: ViewEvent[] = [
  {
    id: "view-1",
    userId: "u-benjamin",
    listingId: "prod-parche-remo",
    categoryId: "hogar",
    tags: ["musica", "bateria", "parche", "remo", "envio gratis"],
    viewedAt: "2026-07-24T01:24:00.000Z",
  },
  {
    id: "view-2",
    userId: "u-benjamin",
    listingId: "stream-hbo",
    categoryId: "streaming",
    tags: ["hbo max", "streaming", "3 meses", "instantanea", "digital"],
    viewedAt: "2026-07-24T01:22:00.000Z",
  },
  {
    id: "view-3",
    userId: "u-benjamin",
    listingId: "tech-iphone",
    categoryId: "tecnologia",
    tags: ["apple", "iphone", "128 gb", "full", "celular"],
    viewedAt: "2026-07-23T23:14:00.000Z",
  },
];

export const initialChats: ChatThread[] = [
  {
    id: "chat-stream-hbo-u-benjamin-u-digital",
    listingId: "stream-hbo",
    buyerId: "u-benjamin",
    sellerId: "u-digital",
    lastMessageAt: "2026-07-24T01:26:00.000Z",
    messages: [
      {
        id: "msg-1",
        threadId: "chat-stream-hbo-u-benjamin-u-digital",
        senderId: "u-benjamin",
        body: "Hola, la entrega es instantanea?",
        createdAt: "2026-07-24T01:25:00.000Z",
        read: true,
      },
      {
        id: "msg-2",
        threadId: "chat-stream-hbo-u-benjamin-u-digital",
        senderId: "u-digital",
        body: "Si, te llega el acceso por este chat apenas se acredita.",
        createdAt: "2026-07-24T01:26:00.000Z",
        read: true,
      },
    ],
  },
];

export const initialShipments: Shipment[] = [
  {
    id: "ship-tech-iphone",
    listingId: "tech-iphone",
    origin: "Centro Full Barracas",
    destination: "Buenos Aires 1772",
    status: "En camino al centro de distribucion",
    progress: 38,
    etaMinutes: 42,
    route: [
      { label: "Origen", x: 9, y: 72 },
      { label: "Centro", x: 39, y: 48 },
      { label: "Reparto", x: 65, y: 58 },
      { label: "Destino", x: 88, y: 24 },
    ],
  },
  {
    id: "ship-super-pack",
    listingId: "super-pack",
    origin: "Deposito Mercado Full",
    destination: "Buenos Aires 1772",
    status: "Preparando carrito",
    progress: 18,
    etaMinutes: 65,
    route: [
      { label: "Deposito", x: 8, y: 68 },
      { label: "Picking", x: 33, y: 36 },
      { label: "Reparto", x: 58, y: 52 },
      { label: "Casa", x: 89, y: 25 },
    ],
  },
];

export const initialNotifications: NotificationEvent[] = [
  {
    id: "note-1",
    text: "Play Digital AR publico HBO Max premium hace instantes",
    createdAt: "2026-07-24T01:28:00.000Z",
  },
  {
    id: "note-2",
    text: "Lucia Motors actualizo autos con financiacion",
    createdAt: "2026-07-24T01:18:00.000Z",
  },
];

export function createInitialMarketplaceState(): MarketplaceState {
  return structuredClone({
    users,
    activeUserId: "u-benjamin",
    listings,
    views: initialViews,
    chats: initialChats,
    shipments: initialShipments,
    notifications: initialNotifications,
  });
}
