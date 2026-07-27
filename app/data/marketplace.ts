export type CategoryId =
  | "vehiculos"
  | "inmuebles"
  | "streaming"
  | "tecnologia"
  | "internacional"
  | "moda"
  | "hogar"
  | "electrodomesticos"
  | "herramientas"
  | "construccion"
  | "deportes"
  | "accesorios-vehiculos"
  | "negocio"
  | "mascotas"
  | "juegos"
  | "bebes"
  | "belleza"
  | "salud"
  | "industrias"
  | "agro"
  | "sustentables"
  | "servicios"
  | "mas-vendidos"
  | "tiendas-oficiales"
  | "supermercado";

export type ProductVisual =
  | {
      type: "image";
      src: string;
      alt: string;
      objectPosition?: string;
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
  email?: string;
  location: string;
  avatar: string;
  reputation: number;
  joinedAt: string;
  isSystem?: boolean;
}

export interface RatingSummary {
  average: number;
  count: number;
}

export interface RatingSummaries {
  listings: Record<string, RatingSummary>;
  sellers: Record<string, RatingSummary>;
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
  source: "catalog" | "user";
  visual: ProductVisual;
  images: string[];
}

function assetSource(asset: string | { src: string }) {
  return typeof asset === "string" ? asset : asset.src;
}

export interface ViewEvent {
  id: string;
  userId: string;
  listingId: string;
  categoryId: CategoryId;
  tags: string[];
  viewedAt: string;
}

export interface SearchEvent {
  id: string;
  userId: string;
  query: string;
  categoryId?: CategoryId;
  tags: string[];
  searchedAt: string;
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
  buyerId: string;
  originalPrice?: number;
  paidPrice?: number;
  couponCode?: string;
  couponDiscount?: number;
  origin: string;
  destination: string;
  status: string;
  progress: number;
  etaMinutes: number;
  route: Array<{ label: string; x: number; y: number }>;
  courierId?: string;
  courierRobloxUserId?: string;
  courierRobloxUsername?: string;
}

export interface NotificationEvent {
  id: string;
  text: string;
  createdAt: string;
}

export interface MarketplaceState {
  users: UserProfile[];
  activeUserId: string | null;
  listings: Listing[];
  views: ViewEvent[];
  searches: SearchEvent[];
  chats: ChatThread[];
  shipments: Shipment[];
  notifications: NotificationEvent[];
}

function marketCategory(input: {
  id: CategoryId;
  label: string;
  navLabel?: string;
  bannerTitle?: string;
  bannerText?: string;
  accent: string;
  tint: string;
  filters?: CategoryFilter[];
  sortModes?: string[];
  ads?: CategoryAd[];
}): CategoryConfig {
  return {
    id: input.id,
    label: input.label,
    navLabel: input.navLabel ?? input.label,
    layout: "market",
    bannerTitle: input.bannerTitle ?? `${input.label} publicado por usuarios`,
    bannerText:
      input.bannerText ??
      "Esta categoria se completa con publicaciones reales creadas por usuarios.",
    accent: input.accent,
    tint: input.tint,
    filters: input.filters ?? [
      { label: "Tipo", values: ["Nuevo", "Usado", "Servicio", "Accesorio"] },
      { label: "Entrega", values: ["Hoy", "Programada", "Digital", "A coordinar"] },
      { label: "Estado", values: ["Nuevo", "Usado"] },
      { label: "Ubicacion", values: ["Cerca tuyo", "Zona norte", "Zona sur", "Online"] },
    ],
    sortModes: input.sortModes ?? ["Mas relevantes", "Menor precio", "Mas recientes", "Mas vistos"],
    ads: input.ads ?? [
      {
        eyebrow: input.label,
        title: "Publicaciones reales",
        body: "Los productos aparecen cuando una cuenta los publica.",
        metric: "P2P",
      },
      {
        eyebrow: "Busquedas",
        title: "Recomendaciones por cuenta",
        body: "El historial de cada usuario alimenta resultados relacionados.",
        metric: "Personal",
      },
    ],
  };
}

export const categories: CategoryConfig[] = [
  {
    id: "vehiculos",
    label: "Vehiculos",
    navLabel: "Vehiculos",
    layout: "vehicle",
    bannerTitle: "Vehiculos publicados por usuarios",
    bannerText: "Cuando alguien publique autos o motos, aca se ordenan por anio, kilometraje, transmision y marca.",
    accent: "#3483fa",
    tint: "#eaf3ff",
    filters: [
      { label: "Anio", values: ["2026", "2024", "2022", "2019"] },
      { label: "Kilometraje", values: ["0 km", "Menos de 30.000 km", "60.000 km"] },
      { label: "Transmision", values: ["Automatica", "Manual"] },
      { label: "Marca", values: ["Toyota", "Volkswagen", "Ford", "Honda"] },
    ],
    sortModes: ["Mejor match", "Menor kilometraje", "Mayor anio", "Menor precio"],
    ads: [
      {
        eyebrow: "Autos y motos",
        title: "Publicaciones P2P",
        body: "Los filtros se activan con las publicaciones reales de otros usuarios.",
        metric: "Sin precarga falsa",
      },
      {
        eyebrow: "GPS",
        title: "Despacho coordinado",
        body: "Cada compra puede generar una ruta simulada entre vendedor y comprador.",
        metric: "En vivo",
      },
    ],
  },
  {
    id: "inmuebles",
    label: "Inmuebles",
    navLabel: "Inmuebles",
    layout: "real-estate",
    bannerTitle: "Casas y departamentos publicados por usuarios",
    bannerText: "Si alguien publica una propiedad, se filtra por metros, ambientes, ubicacion y operacion.",
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
        eyebrow: "Mapa barrial",
        title: "Aparece al publicar",
        body: "La categoria empieza vacia y se llena con inmuebles cargados por usuarios.",
        metric: "P2P real",
      },
      {
        eyebrow: "Agenda",
        title: "Chat con propietario",
        body: "Las consultas quedan separadas por cuenta y publicacion.",
        metric: "Privado",
      },
    ],
  },
  {
    id: "streaming",
    label: "Entretenimiento y Streaming",
    navLabel: "Mercado Play",
    layout: "streaming",
    bannerTitle: "Streaming y entretenimiento disponible desde el inicio",
    bannerText: "Disney+, HBO Max, Prime Video y contenido digital quedan como catalogo inicial.",
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
        eyebrow: "Streaming",
        title: "Lo unico precargado",
        body: "El resto del marketplace queda vacio hasta que usuarios reales publiquen.",
        metric: "Catalogo inicial",
      },
      {
        eyebrow: "Personalizacion",
        title: "Busca una plataforma",
        body: "Despues de buscar o abrir un item, aparecen recomendaciones relacionadas.",
        metric: "Por cuenta",
      },
    ],
  },
  {
    id: "tecnologia",
    label: "Tecnologia",
    navLabel: "Tecnologia",
    layout: "market",
    bannerTitle: "Tecnologia publicada por usuarios",
    bannerText: "Celulares, notebooks y accesorios solo aparecen cuando una cuenta los publica.",
    accent: "#1259c3",
    tint: "#edf4ff",
    filters: [
      { label: "Marca", values: ["Apple", "Samsung", "Motorola", "Lenovo"] },
      { label: "Memoria", values: ["128 GB", "256 GB", "512 GB", "1 TB"] },
      { label: "Envio", values: ["Full", "Llega hoy", "Gratis"] },
      { label: "Estado", values: ["Nuevo", "Usado"] },
    ],
    sortModes: ["Mejor match", "Menor precio", "Mayor descuento", "Mas recientes"],
    ads: [
      {
        eyebrow: "Tecnologia",
        title: "Sin productos falsos",
        body: "Publica un celular o notebook para que aparezca en busqueda y categorias.",
        metric: "Online",
      },
      {
        eyebrow: "Historial",
        title: "Recomendaciones reales",
        body: "Buscar Samsung o Apple alimenta el perfil de esa cuenta.",
        metric: "Aprende",
      },
    ],
  },
  {
    id: "moda",
    label: "Moda",
    navLabel: "Moda",
    layout: "fashion",
    bannerTitle: "Moda publicada por usuarios",
    bannerText: "Talles, colores y marcas quedan vacios hasta que alguien publique ropa o accesorios.",
    accent: "#db2777",
    tint: "#fff0f7",
    filters: [
      { label: "Talle", values: ["S", "M", "L", "XL"] },
      { label: "Color", values: ["Negro", "Azul", "Blanco", "Verde"] },
      { label: "Marca", values: ["Topper", "Adidas", "Levi's", "Prune"] },
      { label: "Envio", values: ["Full", "Gratis"] },
    ],
    sortModes: ["Inspirado en tu busqueda", "Menor precio", "Mas recientes", "Mas vistos"],
    ads: [
      {
        eyebrow: "Moda",
        title: "Primero publicar",
        body: "Las tarjetas aparecen despues de que una cuenta carga productos.",
        metric: "P2P",
      },
      {
        eyebrow: "Cuenta",
        title: "Historial separado",
        body: "Cada usuario ve recomendaciones propias segun lo que busca y abre.",
        metric: "Personal",
      },
    ],
  },
  {
    id: "hogar",
    label: "Hogar y Muebles",
    navLabel: "Hogar",
    layout: "market",
    bannerTitle: "Hogar y muebles publicados por usuarios",
    bannerText: "Ambientes, materiales y medidas se usan cuando existan publicaciones reales.",
    accent: "#8b5e34",
    tint: "#fff5e9",
    filters: [
      { label: "Ambiente", values: ["Living", "Cocina", "Dormitorio", "Patio"] },
      { label: "Material", values: ["Madera", "Metal", "Tela", "Vidrio"] },
      { label: "Medida", values: ["Compacto", "Mediano", "Grande"] },
      { label: "Envio", values: ["Gratis", "Con armado"] },
    ],
    sortModes: ["Mas relevantes", "Menor precio", "Mas recientes", "Mayor descuento"],
    ads: [
      {
        eyebrow: "Hogar",
        title: "Categoria vacia",
        body: "No se inventan productos hasta que un vendedor los publique.",
        metric: "Correcto",
      },
      {
        eyebrow: "Envios",
        title: "Mapa al comprar",
        body: "El GPS se crea desde origen de vendedor a destino de comprador.",
        metric: "Simulado",
      },
    ],
  },
  {
    id: "herramientas",
    label: "Herramientas",
    navLabel: "Herramientas",
    layout: "market",
    bannerTitle: "Herramientas publicadas por usuarios",
    bannerText: "Potencia, marca y uso profesional funcionan sobre publicaciones creadas.",
    accent: "#f59e0b",
    tint: "#fff8df",
    filters: [
      { label: "Uso", values: ["Profesional", "Hogar", "Obra", "Jardin"] },
      { label: "Marca", values: ["Bosch", "DeWalt", "Makita", "Stanley"] },
      { label: "Potencia", values: ["600 W", "1200 W", "18 V", "20 V"] },
      { label: "Kit", values: ["Con accesorios", "Solo equipo"] },
    ],
    sortModes: ["Mayor potencia", "Mejor precio", "Mas recientes", "Garantia"],
    ads: [
      {
        eyebrow: "Herramientas",
        title: "Cargadas por vendedores",
        body: "La busqueda global actualiza resultados cuando alguien publica.",
        metric: "Tiempo real",
      },
      {
        eyebrow: "Orden",
        title: "Por potencia y precio",
        body: "El motor usa metadata de cada publicacion.",
        metric: "Avanzado",
      },
    ],
  },
  {
    id: "supermercado",
    label: "Supermercado",
    navLabel: "Supermercado",
    layout: "market",
    bannerTitle: "Supermercado publicado por usuarios",
    bannerText: "Combos y packs aparecen cuando una cuenta vendedora los carga.",
    accent: "#00a650",
    tint: "#ebfff5",
    filters: [
      { label: "Pasillo", values: ["Limpieza", "Bebidas", "Almacen", "Mascotas"] },
      { label: "Marca", values: ["Coca-Cola", "Ala", "Purina", "La Serenisima"] },
      { label: "Pack", values: ["6 unidades", "12 unidades", "Familiar"] },
      { label: "Entrega", values: ["Hoy", "Programada"] },
    ],
    sortModes: ["Reposicion sugerida", "Menor precio", "Descuentos", "Mas recientes"],
    ads: [
      {
        eyebrow: "Supermercado",
        title: "Sin precarga",
        body: "Queda vacio hasta que vendedores suban publicaciones.",
        metric: "P2P",
      },
      {
        eyebrow: "Carrito",
        title: "Aprende de busquedas",
        body: "Buscar bebidas o limpieza arma recomendaciones de esa cuenta.",
        metric: "Personal",
      },
    ],
  },
  marketCategory({
    id: "internacional",
    label: "Internacional",
    accent: "#2563eb",
    tint: "#edf4ff",
    filters: [
      { label: "Origen", values: ["Estados Unidos", "China", "Europa", "Brasil"] },
      { label: "Entrega", values: ["Importacion", "Courier", "A coordinar"] },
      { label: "Estado", values: ["Nuevo", "Usado"] },
      { label: "Categoria", values: ["Tecnologia", "Moda", "Hogar", "Repuestos"] },
    ],
  }),
  marketCategory({
    id: "electrodomesticos",
    label: "Electrodomesticos",
    accent: "#0891b2",
    tint: "#e6faff",
    filters: [
      { label: "Tipo", values: ["Heladera", "Lavarropas", "Cocina", "Aire acondicionado"] },
      { label: "Marca", values: ["Samsung", "LG", "Whirlpool", "Drean"] },
      { label: "Eficiencia", values: ["A", "B", "C"] },
      { label: "Estado", values: ["Nuevo", "Usado"] },
    ],
  }),
  marketCategory({
    id: "construccion",
    label: "Construccion",
    accent: "#d97706",
    tint: "#fff7ed",
    filters: [
      { label: "Rubro", values: ["Materiales", "Pintura", "Sanitarios", "Electricidad"] },
      { label: "Unidad", values: ["Bolsa", "Metro", "Caja", "Kit"] },
      { label: "Entrega", values: ["Obra", "Retiro", "A coordinar"] },
      { label: "Estado", values: ["Nuevo", "Usado"] },
    ],
  }),
  marketCategory({
    id: "deportes",
    label: "Deportes y Fitness",
    accent: "#16a34a",
    tint: "#ecfdf5",
    filters: [
      { label: "Deporte", values: ["Futbol", "Running", "Gimnasio", "Ciclismo"] },
      { label: "Talle", values: ["S", "M", "L", "XL"] },
      { label: "Estado", values: ["Nuevo", "Usado"] },
      { label: "Entrega", values: ["Gratis", "A coordinar"] },
    ],
  }),
  marketCategory({
    id: "accesorios-vehiculos",
    label: "Accesorios para Vehiculos",
    navLabel: "Accesorios Vehiculos",
    accent: "#475569",
    tint: "#f1f5f9",
    filters: [
      { label: "Tipo", values: ["Repuesto", "Audio", "Cubiertas", "Accesorio"] },
      { label: "Vehiculo", values: ["Auto", "Moto", "Camioneta"] },
      { label: "Marca", values: ["Ford", "Toyota", "Volkswagen", "Honda"] },
      { label: "Estado", values: ["Nuevo", "Usado"] },
    ],
  }),
  marketCategory({
    id: "negocio",
    label: "Para tu Negocio",
    accent: "#0f766e",
    tint: "#ecfdf5",
    filters: [
      { label: "Rubro", values: ["Gastronomia", "Comercio", "Oficina", "Deposito"] },
      { label: "Tipo", values: ["Maquina", "Mueble", "Insumo", "Servicio"] },
      { label: "Estado", values: ["Nuevo", "Usado"] },
      { label: "Entrega", values: ["Retiro", "A coordinar"] },
    ],
  }),
  marketCategory({
    id: "mascotas",
    label: "Mascotas",
    accent: "#ea580c",
    tint: "#fff7ed",
    filters: [
      { label: "Mascota", values: ["Perros", "Gatos", "Aves", "Peces"] },
      { label: "Tipo", values: ["Alimento", "Juguete", "Cama", "Accesorio"] },
      { label: "Marca", values: ["Purina", "Royal Canin", "Vitalcan", "Otra"] },
      { label: "Entrega", values: ["Hoy", "Programada"] },
    ],
  }),
  marketCategory({
    id: "juegos",
    label: "Juegos y Juguetes",
    accent: "#9333ea",
    tint: "#f5f3ff",
    filters: [
      { label: "Edad", values: ["0-2", "3-5", "6-9", "10+"] },
      { label: "Tipo", values: ["Juego de mesa", "Muñeco", "Bloques", "Consola"] },
      { label: "Estado", values: ["Nuevo", "Usado"] },
      { label: "Entrega", values: ["Gratis", "A coordinar"] },
    ],
  }),
  marketCategory({
    id: "bebes",
    label: "Bebes",
    accent: "#ec4899",
    tint: "#fff1f2",
    filters: [
      { label: "Tipo", values: ["Cochecito", "Silla", "Ropa", "Higiene"] },
      { label: "Edad", values: ["0-6 meses", "6-12 meses", "1-2 años", "3+"] },
      { label: "Estado", values: ["Nuevo", "Usado"] },
      { label: "Entrega", values: ["Gratis", "A coordinar"] },
    ],
  }),
  marketCategory({
    id: "belleza",
    label: "Belleza y Cuidado Personal",
    accent: "#db2777",
    tint: "#fdf2f8",
    filters: [
      { label: "Tipo", values: ["Perfumes", "Maquillaje", "Pelo", "Skin care"] },
      { label: "Marca", values: ["Natura", "Maybelline", "L'Oreal", "Otra"] },
      { label: "Estado", values: ["Nuevo", "Usado"] },
      { label: "Entrega", values: ["Hoy", "Programada"] },
    ],
  }),
  marketCategory({
    id: "salud",
    label: "Salud y Equipamiento Medico",
    accent: "#0284c7",
    tint: "#eefaff",
    filters: [
      { label: "Tipo", values: ["Ortopedia", "Medicion", "Insumos", "Equipos"] },
      { label: "Uso", values: ["Hogar", "Profesional", "Clinica"] },
      { label: "Estado", values: ["Nuevo", "Usado"] },
      { label: "Entrega", values: ["A coordinar", "Retiro"] },
    ],
  }),
  marketCategory({
    id: "industrias",
    label: "Industrias y Oficinas",
    accent: "#334155",
    tint: "#f8fafc",
    filters: [
      { label: "Rubro", values: ["Oficina", "Industria", "Deposito", "Seguridad"] },
      { label: "Tipo", values: ["Mueble", "Equipo", "Insumo", "Servicio"] },
      { label: "Estado", values: ["Nuevo", "Usado"] },
      { label: "Entrega", values: ["Retiro", "A coordinar"] },
    ],
  }),
  marketCategory({
    id: "agro",
    label: "Agro",
    accent: "#65a30d",
    tint: "#f7fee7",
    filters: [
      { label: "Rubro", values: ["Maquinaria", "Semillas", "Herramientas", "Animales"] },
      { label: "Uso", values: ["Campo", "Jardin", "Produccion"] },
      { label: "Estado", values: ["Nuevo", "Usado"] },
      { label: "Entrega", values: ["A coordinar", "Retiro"] },
    ],
  }),
  marketCategory({
    id: "sustentables",
    label: "Productos Sustentables",
    accent: "#059669",
    tint: "#ecfdf5",
    filters: [
      { label: "Tipo", values: ["Solar", "Reciclado", "Ahorro energia", "Reusable"] },
      { label: "Impacto", values: ["Bajo consumo", "Reciclable", "Eco"] },
      { label: "Estado", values: ["Nuevo", "Usado"] },
      { label: "Entrega", values: ["Gratis", "A coordinar"] },
    ],
  }),
  marketCategory({
    id: "servicios",
    label: "Servicios",
    accent: "#7c3aed",
    tint: "#f5f3ff",
    filters: [
      { label: "Rubro", values: ["Hogar", "Tecnologia", "Eventos", "Profesional"] },
      { label: "Modalidad", values: ["Presencial", "Online", "A domicilio"] },
      { label: "Zona", values: ["Cerca tuyo", "Online", "A coordinar"] },
      { label: "Disponibilidad", values: ["Hoy", "Semana", "Programada"] },
    ],
    sortModes: ["Mas relevantes", "Mas recientes", "Cerca tuyo", "Mejor rating"],
  }),
  marketCategory({
    id: "mas-vendidos",
    label: "Mas vendidos",
    accent: "#f59e0b",
    tint: "#fffbeb",
    sortModes: ["Mas vendidos", "Mas vistos", "Menor precio", "Mas recientes"],
  }),
  marketCategory({
    id: "tiendas-oficiales",
    label: "Tiendas oficiales",
    accent: "#1259c3",
    tint: "#edf4ff",
    filters: [
      { label: "Tienda", values: ["Tecnologia", "Moda", "Hogar", "Supermercado"] },
      { label: "Tipo", values: ["Catalogo", "Usuario verificado", "Marca"] },
      { label: "Entrega", values: ["Full", "Gratis", "Programada"] },
      { label: "Estado", values: ["Nuevo", "Usado"] },
    ],
  }),
];

export const users: UserProfile[] = [
  {
    id: "u-streaming",
    name: "Mercado Play",
    email: "play@demo.local",
    location: "Entrega online",
    avatar: "MP",
    reputation: 0,
    joinedAt: "2026-07-24T00:00:00.000Z",
    isSystem: true,
  },
];

export const listings: Listing[] = [
  {
    id: "stream-hbo",
    title: "HBO Max premium 3 meses",
    description: "Acceso digital inmediato con soporte por chat.",
    categoryId: "streaming",
    sellerId: "u-streaming",
    price: 9800,
    oldPrice: 14500,
    currency: "ARS",
    condition: "Digital",
    location: "Entrega online",
    shipping: "Instantaneo",
    createdAt: "2026-07-24T00:05:00.000Z",
    views: 0,
    sold: 0,
    rating: 0,
    tags: ["hbo max", "streaming", "series", "peliculas", "digital"],
    meta: { plataforma: "HBO Max", tipo: "Membresia", entrega: "Instantanea", duracion: "3 meses" },
    badge: "Digital",
    source: "catalog",
    visual: {
      type: "image",
      src: assetSource(hboWidget),
      alt: "HBO Max",
      objectPosition: "center",
    },
    images: [assetSource(hboWidget)],
  },
  {
    id: "stream-disney",
    title: "Disney+ acceso mensual",
    description: "Contenido familiar y estrenos con entrega digital.",
    categoryId: "streaming",
    sellerId: "u-streaming",
    price: 7600,
    oldPrice: 11200,
    currency: "ARS",
    condition: "Digital",
    location: "Entrega online",
    shipping: "Instantaneo",
    createdAt: "2026-07-24T00:04:00.000Z",
    views: 0,
    sold: 0,
    rating: 0,
    tags: ["disney+", "disney", "streaming", "peliculas", "familia"],
    meta: { plataforma: "Disney+", tipo: "Membresia", entrega: "Instantanea", duracion: "1 mes" },
    badge: "Digital",
    source: "catalog",
    visual: {
      type: "image",
      src: assetSource(disneyWidget),
      alt: "Disney+",
      objectPosition: "center",
    },
    images: [assetSource(disneyWidget)],
  },
  {
    id: "stream-prime",
    title: "Prime Video codigo 30 dias",
    description: "Codigo digital para activar entretenimiento online.",
    categoryId: "streaming",
    sellerId: "u-streaming",
    price: 5900,
    currency: "ARS",
    condition: "Digital",
    location: "Entrega online",
    shipping: "24 horas",
    createdAt: "2026-07-24T00:03:00.000Z",
    views: 0,
    sold: 0,
    rating: 0,
    tags: ["prime video", "streaming", "codigo", "peliculas", "series"],
    meta: { plataforma: "Prime Video", tipo: "Codigo", entrega: "24 horas", duracion: "1 mes" },
    badge: "Codigo",
    source: "catalog",
    visual: {
      type: "image",
      src: assetSource(primeWidget),
      alt: "Prime Video",
      objectPosition: "center",
    },
    images: [assetSource(primeWidget)],
  },
];

export function createInitialMarketplaceState(): MarketplaceState {
  return structuredClone({
    users,
    activeUserId: null,
    listings,
    views: [],
    searches: [],
    chats: [],
    shipments: [],
    notifications: [],
  });
}
import hboWidget from "@/IMG/official/hbo-widget.jpg";
import disneyWidget from "@/IMG/official/disney-widget.jpg";
import primeWidget from "@/IMG/streaming/prime-video-hero.avif";
