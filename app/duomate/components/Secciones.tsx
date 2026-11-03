"use client";

import { AnimatePresence, motion, useScroll, useSpring, useTransform } from "framer-motion";
import { useEffect, useRef, useState, useSyncExternalStore } from "react";
import { PRODUCTOS, formatearPrecio, type Producto } from "../lib/catalogo";
import { useCarrito } from "../lib/carrito";
import { ArteProducto } from "./ArteProducto";
import {
  Estrellas,
  IconoBolsa,
  IconoCamion,
  IconoCheck,
  IconoEscudo,
  IconoFlecha,
  IconoHoja,
  IconoInstagram,
  IconoMenu,
  IconoCerrar,
  IconoPin,
  IconoReloj,
  IconoTelefono,
  IconoTienda,
} from "./Iconos";

const aparecer = {
  initial: { opacity: 0, y: 28 },
  whileInView: { opacity: 1, y: 0 },
  viewport: { once: true, margin: "-80px" },
  transition: { duration: 0.6, ease: [0.22, 1, 0.36, 1] as const },
};

export function Logo() {
  return (
    <a href="#inicio" className="dm-logo" aria-label="Duomate, ir al inicio">
      <svg viewBox="0 0 40 40" width="34" height="34" aria-hidden="true">
        <circle cx="20" cy="20" r="19" fill="var(--dm-verde)" />
        <path d="M12 16 C 10 24, 13 31, 20 32 C 27 31, 30 24, 28 16 Z" fill="var(--dm-crema)" />
        <path d="M11 14 h18 v3 H11 Z" fill="var(--dm-oro)" />
        <path d="M23 15 l4 -9" stroke="var(--dm-oro)" strokeWidth="2.4" strokeLinecap="round" />
      </svg>
      <span>
        duo<strong>mate</strong>
      </span>
    </a>
  );
}

/* ---------------------------------- Encabezado ---------------------------------- */

export function Encabezado() {
  const { unidades, setAbierto, destinoRef, pulso } = useCarrito();
  const [scroll, setScroll] = useState(false);
  const [menu, setMenu] = useState(false);
  const { scrollYProgress } = useScroll();
  const barra = useSpring(scrollYProgress, { stiffness: 120, damping: 30 });

  useEffect(() => {
    const f = () => setScroll(window.scrollY > 24);
    f();
    window.addEventListener("scroll", f, { passive: true });
    return () => window.removeEventListener("scroll", f);
  }, []);

  const enlaces = [
    ["#tienda", "Tienda"],
    ["#ritual", "El ritual"],
    ["#sucursal", "Sucursal"],
    ["#opiniones", "Opiniones"],
  ];

  return (
    <>
      <div className="dm-cinta">
        <p>
          <IconoTienda size={15} /> Retiro gratis en sucursal · <IconoCamion size={15} /> Envío gratis desde {formatearPrecio(80000)} · Cupón <strong>DUO10</strong>
        </p>
      </div>
      <header className={`dm-header ${scroll ? "es-flotante" : ""}`}>
        <div className="dm-contenedor dm-header-fila">
          <Logo />
          <nav className="dm-nav" aria-label="Principal">
            {enlaces.map(([href, t]) => (
              <a key={href} href={href}>
                {t}
              </a>
            ))}
          </nav>
          <div className="dm-header-acciones">
            <a className="dm-boton dm-boton-fantasma dm-solo-escritorio" href="#sucursal">
              <IconoPin size={17} /> Palermo
            </a>
            <motion.button ref={destinoRef} className="dm-boton-carrito" onClick={() => setAbierto(true)} aria-label={`Abrir carrito, ${unidades} productos`}>
              <motion.span key={pulso} animate={pulso ? { scale: [1, 1.3, 0.9, 1], rotate: [0, -12, 8, 0] } : undefined} transition={{ duration: 0.5 }}>
                <IconoBolsa size={22} />
              </motion.span>
              <AnimatePresence>
                {unidades > 0 && (
                  <motion.span key="burbuja" className="dm-burbuja" initial={{ scale: 0 }} animate={{ scale: 1 }} exit={{ scale: 0 }} transition={{ type: "spring", stiffness: 500, damping: 18 }}>
                    <AnimatePresence mode="popLayout" initial={false}>
                      <motion.span key={unidades} initial={{ y: -8, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: 8, opacity: 0 }}>
                        {unidades}
                      </motion.span>
                    </AnimatePresence>
                  </motion.span>
                )}
              </AnimatePresence>
            </motion.button>
            <button className="dm-menu-boton" onClick={() => setMenu((m) => !m)} aria-expanded={menu} aria-controls="dm-menu-movil" aria-label="Menú">
              {menu ? <IconoCerrar /> : <IconoMenu />}
            </button>
          </div>
        </div>
        <AnimatePresence>
          {menu && (
            <motion.nav
              id="dm-menu-movil"
              className="dm-menu-movil"
              initial={{ height: 0, opacity: 0 }}
              animate={{ height: "auto", opacity: 1 }}
              exit={{ height: 0, opacity: 0 }}
              aria-label="Menú móvil"
            >
              {enlaces.map(([href, t]) => (
                <a key={href} href={href} onClick={() => setMenu(false)}>
                  {t} <IconoFlecha size={16} />
                </a>
              ))}
            </motion.nav>
          )}
        </AnimatePresence>
        <motion.div className="dm-progreso-scroll" style={{ scaleX: barra }} aria-hidden="true" />
      </header>
    </>
  );
}

/* ---------------------------------- Hero ---------------------------------- */

export function Hero({ onVer }: { onVer: (p: Producto) => void }) {
  const ref = useRef<HTMLElement>(null);
  const { scrollYProgress } = useScroll({ target: ref, offset: ["start start", "end start"] });
  const y = useTransform(scrollYProgress, [0, 1], [0, 120]);
  const rot = useTransform(scrollYProgress, [0, 1], [0, 10]);
  const destacado = PRODUCTOS.find((p) => p.id === "imperial-cincelado")!;
  const { agregar } = useCarrito();
  const estadoHero = useEstadoSucursal();
  const titulo = ["El", "mate", "se", "comparte.", "El", "buen", "mate,", "se", "elige."];

  return (
    <section id="inicio" ref={ref} className="dm-hero">
      <div className="dm-hero-fondo" aria-hidden="true">
        <motion.span className="dm-mancha dm-mancha-1" animate={{ scale: [1, 1.08, 1], x: [0, 20, 0] }} transition={{ duration: 12, repeat: Infinity, ease: "easeInOut" }} />
        <motion.span className="dm-mancha dm-mancha-2" animate={{ scale: [1, 1.12, 1], y: [0, -24, 0] }} transition={{ duration: 14, repeat: Infinity, ease: "easeInOut" }} />
      </div>
      <div className="dm-contenedor dm-hero-grilla">
        <div className="dm-hero-texto">
          <motion.span className="dm-pastilla" initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.1 }}>
            <span className={`dm-punto-vivo ${estadoHero && !estadoHero.abierta ? "es-cerrado" : ""}`} /> {estadoHero ? `Sucursal Palermo · ${estadoHero.texto.toLowerCase()}` : "Sucursal Palermo · retiro en menos de 2 h"}
          </motion.span>
          <h1>
            {titulo.map((palabra, i) => (
              <motion.span
                key={i}
                className={`dm-palabra ${i >= 4 ? "dm-palabra-acento" : ""}`}
                initial={{ opacity: 0, y: 40, rotateX: -60 }}
                animate={{ opacity: 1, y: 0, rotateX: 0 }}
                transition={{ delay: 0.2 + i * 0.06, duration: 0.6, ease: [0.22, 1, 0.36, 1] }}
              >
                {palabra}
              </motion.span>
            ))}
          </h1>
          <motion.p className="dm-hero-bajada" {...aparecer} transition={{ ...aparecer.transition, delay: 0.75 }}>
            Mates curados por artesanos, bombillas de alpaca y yerbas estacionadas 24 meses. Elegí online y retirá en nuestra sucursal en menos de 2 horas.
          </motion.p>
          <motion.div className="dm-hero-botones" initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.9 }}>
            <a href="#tienda" className="dm-boton dm-boton-principal dm-boton-grande">
              Comprar ahora <IconoFlecha size={18} />
            </a>
            <a href="#ritual" className="dm-boton dm-boton-secundario dm-boton-grande">
              Cómo curar tu mate
            </a>
          </motion.div>
          <motion.ul className="dm-hero-datos" initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 1.1 }}>
            <li>
              <strong>4,9</strong>
              <Estrellas valor={4.9} size={13} />
              <span>2.800+ opiniones</span>
            </li>
            <li>
              <strong>12 años</strong>
              <span>cebando en el barrio</span>
            </li>
            <li>
              <strong>&lt; 2 h</strong>
              <span>para retirar tu pedido</span>
            </li>
          </motion.ul>
        </div>

        <motion.div className="dm-hero-visual" style={{ y }}>
          <motion.div className="dm-hero-disco" initial={{ scale: 0.6, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} transition={{ duration: 0.9, ease: [0.22, 1, 0.36, 1] }} />
          <motion.div className="dm-vapor" aria-hidden="true">
            {[0, 1, 2].map((i) => (
              <motion.span
                key={i}
                animate={{ y: [-0, -70], opacity: [0, 0.7, 0], scaleX: [1, 1.4, 1.8] }}
                transition={{ duration: 3.2, repeat: Infinity, delay: i * 1.05, ease: "easeOut" }}
              />
            ))}
          </motion.div>
          <motion.div
            className="dm-hero-mate"
            style={{ rotate: rot }}
            initial={{ y: 60, opacity: 0, rotate: -12 }}
            animate={{ y: [0, -14, 0], opacity: 1 }}
            transition={{ y: { duration: 5, repeat: Infinity, ease: "easeInOut", delay: 1 }, opacity: { duration: 0.8, delay: 0.3 } }}
          >
            <ArteProducto arte="imperial" color="#8a5a36" className="dm-arte" />
          </motion.div>

          <motion.button
            className="dm-hero-ficha"
            initial={{ opacity: 0, x: 40 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 1.2, type: "spring", stiffness: 160, damping: 18 }}
            whileHover={{ y: -4 }}
            onClick={() => onVer(destacado)}
          >
            <span className="dm-sobretitulo">Edición limitada</span>
            <strong>{destacado.nombre}</strong>
            <span>{formatearPrecio(destacado.precio)}</span>
          </motion.button>

          <motion.button
            className="dm-hero-ficha dm-hero-ficha-2"
            initial={{ opacity: 0, x: -40 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 1.4, type: "spring", stiffness: 160, damping: 18 }}
            whileHover={{ y: -4 }}
            onClick={(e) => agregar(PRODUCTOS[0], PRODUCTOS[0].variantes[0].nombre, 1, e.currentTarget.getBoundingClientRect())}
          >
            <span className="dm-hero-ficha-icono">
              <IconoBolsa size={18} />
            </span>
            <span>
              <strong>Kit Duo Clásico</strong>
              <span>Sumar al carrito · {formatearPrecio(PRODUCTOS[0].precio)}</span>
            </span>
          </motion.button>
        </motion.div>
      </div>
    </section>
  );
}

/* ---------------------------------- Beneficios ---------------------------------- */

export function Beneficios() {
  const items = [
    { icono: <IconoTienda />, titulo: "Retiro en 2 horas", texto: "Comprá online y pasá por la sucursal sin hacer fila." },
    { icono: <IconoCamion />, titulo: "Envío gratis", texto: `En CABA y GBA en compras desde ${formatearPrecio(80000)}.` },
    { icono: <IconoEscudo />, titulo: "Garantía Duomate", texto: "Si tu mate se raja en los primeros 6 meses, te lo cambiamos." },
    { icono: <IconoHoja />, titulo: "Curado incluido", texto: "Todos los mates de calabaza salen curados y listos." },
  ];
  return (
    <section className="dm-beneficios" aria-label="Beneficios">
      <div className="dm-contenedor dm-beneficios-grilla">
        {items.map((b, i) => (
          <motion.div key={b.titulo} className="dm-beneficio" {...aparecer} transition={{ ...aparecer.transition, delay: i * 0.08 }}>
            <span className="dm-beneficio-icono">{b.icono}</span>
            <div>
              <h3>{b.titulo}</h3>
              <p>{b.texto}</p>
            </div>
          </motion.div>
        ))}
      </div>
    </section>
  );
}

export function Marquesina() {
  const frases = ["Mates curados a mano", "Yerba estacionada 24 meses", "Bombillas de alpaca", "Retiro en sucursal", "Hecho en Argentina", "Garantía de 6 meses"];
  const fila = [...frases, ...frases];
  return (
    <div className="dm-marquesina" aria-hidden="true">
      <motion.div className="dm-marquesina-pista" animate={{ x: ["0%", "-50%"] }} transition={{ duration: 28, repeat: Infinity, ease: "linear" }}>
        {fila.map((f, i) => (
          <span key={i}>
            {f} <IconoHoja size={18} />
          </span>
        ))}
      </motion.div>
    </div>
  );
}

/* ---------------------------------- Ritual ---------------------------------- */

export function Ritual() {
  const pasos = [
    { n: "01", t: "Llená ¾ con yerba", d: "Tapá la boca con la mano, invertí y sacudí: el polvo queda arriba y no tapa la bombilla." },
    { n: "02", t: "Inclinalo y humedecé", d: "Dejá la yerba en diagonal y volcá un chorrito de agua tibia en el hueco. Esperá un minuto." },
    { n: "03", t: "Clavá la bombilla", d: "Tapá el pico con el pulgar y apoyala en el lado húmedo, hasta el fondo. No la muevas más." },
    { n: "04", t: "Cebá a 75–80 °C", d: "Nunca hervida: el agua muy caliente quema la yerba y amarga. El termo Duomate te avisa." },
  ];
  return (
    <section id="ritual" className="dm-seccion dm-ritual" aria-labelledby="titulo-ritual">
      <div className="dm-contenedor dm-ritual-grilla">
        <motion.div className="dm-ritual-intro" {...aparecer}>
          <span className="dm-sobretitulo dm-sobretitulo-claro">El ritual</span>
          <h2 id="titulo-ritual">Cuatro pasos para el mate perfecto</h2>
          <p>Lo enseñamos todos los sábados a las 11 h en la sucursal, gratis. Y si es tu primer mate de calabaza, te lo entregamos curado.</p>
          <div className="dm-temperatura" aria-hidden="true">
            <span>Temperatura ideal</span>
            <div className="dm-termometro">
              <motion.span initial={{ width: 0 }} whileInView={{ width: "78%" }} viewport={{ once: true }} transition={{ duration: 1.4, ease: [0.22, 1, 0.36, 1], delay: 0.3 }} />
            </div>
            <strong>75–80 °C</strong>
          </div>
        </motion.div>
        <ol className="dm-pasos">
          {pasos.map((p, i) => (
            <motion.li key={p.n} className="dm-paso" {...aparecer} transition={{ ...aparecer.transition, delay: i * 0.1 }} whileHover={{ x: 6 }}>
              <span className="dm-paso-numero">{p.n}</span>
              <div>
                <h3>{p.t}</h3>
                <p>{p.d}</p>
              </div>
            </motion.li>
          ))}
        </ol>
      </div>
    </section>
  );
}

/* ---------------------------------- Sucursal ---------------------------------- */

const HORARIOS = [
  ["Lunes a viernes", "9:00 – 20:00"],
  ["Sábados", "10:00 – 19:00"],
  ["Domingos y feriados", "11:00 – 17:00"],
];

const suscribirMinuto = (avisar: () => void) => {
  const t = setInterval(avisar, 60_000);
  return () => clearInterval(t);
};

function estadoSucursal(fecha: Date) {
  const d = fecha.getDay();
  const h = fecha.getHours() + fecha.getMinutes() / 60;
  const [abre, cierra] = d === 0 ? [11, 17] : d === 6 ? [10, 19] : [9, 20];
  return h >= abre && h < cierra ? { abierta: true, texto: `Abierta ahora · cierra a las ${cierra} h` } : { abierta: false, texto: `Cerrada · abre a las ${abre} h` };
}

/** El horario depende del reloj de quien mira: en el servidor devuelve null. */
function useEstadoSucursal() {
  const crudo = useSyncExternalStore(
    suscribirMinuto,
    () => {
      const e = estadoSucursal(new Date());
      return `${e.abierta ? 1 : 0}|${e.texto}`;
    },
    () => "",
  );
  return crudo ? { abierta: crudo.startsWith("1"), texto: crudo.slice(2) } : null;
}

export function Sucursal() {
  const estado = useEstadoSucursal();

  return (
    <section id="sucursal" className="dm-seccion dm-sucursal" aria-labelledby="titulo-sucursal">
      <div className="dm-contenedor dm-sucursal-grilla">
        <motion.div className="dm-sucursal-info" {...aparecer}>
          <span className="dm-sobretitulo">Nuestra sucursal</span>
          <h2 id="titulo-sucursal">Duomate Palermo</h2>
          {estado && (
            <p className={`dm-estado ${estado.abierta ? "es-abierta" : ""}`}>
              <span className="dm-punto-vivo" /> {estado.texto}
            </p>
          )}
          <ul className="dm-sucursal-datos">
            <li>
              <IconoPin />
              <div>
                <strong>Gorriti 4820, Palermo Soho</strong>
                <span>Ciudad de Buenos Aires · a 3 cuadras de Plaza Serrano</span>
              </div>
            </li>
            <li>
              <IconoReloj />
              <div>
                <strong>Horarios</strong>
                <dl className="dm-horarios">
                  {HORARIOS.map(([d, h]) => (
                    <div key={d}>
                      <dt>{d}</dt>
                      <dd>{h}</dd>
                    </div>
                  ))}
                </dl>
              </div>
            </li>
            <li>
              <IconoTelefono />
              <div>
                <strong>WhatsApp 11 5555-0420</strong>
                <span>Respondemos en el horario de la sucursal</span>
              </div>
            </li>
          </ul>
          <div className="dm-sucursal-botones">
            <a className="dm-boton dm-boton-principal" href="https://www.google.com/maps/search/?api=1&query=Gorriti+4820+Palermo+Buenos+Aires" target="_blank" rel="noopener noreferrer">
              Cómo llegar <IconoFlecha size={18} />
            </a>
            <a className="dm-boton dm-boton-secundario" href="#tienda">
              Reservar para retirar
            </a>
          </div>
        </motion.div>

        <motion.div className="dm-mapa" {...aparecer} transition={{ ...aparecer.transition, delay: 0.15 }} aria-label="Mapa ilustrativo de la zona de la sucursal" role="img">
          <svg viewBox="0 0 400 320" className="dm-mapa-svg" aria-hidden="true">
            <rect width="400" height="320" fill="var(--dm-mapa-fondo)" />
            {[40, 110, 180, 250].map((y) => (
              <rect key={`h${y}`} x="0" y={y} width="400" height="16" fill="var(--dm-mapa-calle)" />
            ))}
            {[60, 150, 240, 330].map((x) => (
              <rect key={`v${x}`} x={x} y="0" width="16" height="320" fill="var(--dm-mapa-calle)" />
            ))}
            <path d="M0 300 L 400 140" stroke="var(--dm-mapa-avenida)" strokeWidth="22" />
            <rect x="246" y="58" width="92" height="44" rx="8" fill="var(--dm-mapa-plaza)" />
            <text x="292" y="84" textAnchor="middle" className="dm-mapa-texto">
              Plaza Serrano
            </text>
            <text x="20" y="34" className="dm-mapa-texto">
              Gorriti
            </text>
            <text x="20" y="104" className="dm-mapa-texto">
              Borges
            </text>
            <text x="150" y="236" className="dm-mapa-texto" transform="rotate(-21.8 150 236)">
              Av. Juan B. Justo
            </text>
          </svg>
          <motion.div className="dm-mapa-pin" initial={{ y: -40, opacity: 0 }} whileInView={{ y: 0, opacity: 1 }} viewport={{ once: true }} transition={{ type: "spring", stiffness: 260, damping: 12, delay: 0.5 }}>
            <span className="dm-mapa-onda" />
            <span className="dm-mapa-onda dm-mapa-onda-2" />
            <span className="dm-mapa-marca">
              <IconoPin size={22} />
            </span>
            <span className="dm-mapa-etiqueta">Duomate</span>
          </motion.div>
        </motion.div>
      </div>
    </section>
  );
}

/* ---------------------------------- Opiniones ---------------------------------- */

const OPINIONES = [
  { nombre: "Lucía F.", barrio: "Villa Crespo", texto: "Compré el imperial para regalarle a mi viejo y quedó fascinado. Lo retiré en una hora y me lo envolvieron re lindo.", puntaje: 5, producto: "Mate Imperial Cincelado" },
  { nombre: "Martín G.", barrio: "Colegiales", texto: "La bombilla pico de loro es otra cosa: no se tapa nunca. Y la Blend Suave rinde muchísimo.", puntaje: 5, producto: "Bombilla Pico de Loro" },
  { nombre: "Sofía R.", barrio: "Almagro", texto: "Fui al taller de los sábados sin saber nada y salí cebando como mi abuela. La atención, un diez.", puntaje: 5, producto: "Taller de los sábados" },
  { nombre: "Joaquín P.", barrio: "Palermo", texto: "El termo mantiene el agua perfecta hasta la noche. El pico cebador no gotea nada, cero quejas.", puntaje: 4.5, producto: "Termo Acero 1 L" },
];

export function Opiniones() {
  const [i, setI] = useState(0);
  const [pausa, setPausa] = useState(false);
  useEffect(() => {
    if (pausa) return;
    const t = setInterval(() => setI((n) => (n + 1) % OPINIONES.length), 6000);
    return () => clearInterval(t);
  }, [pausa]);
  const o = OPINIONES[i];

  return (
    <section id="opiniones" className="dm-seccion dm-opiniones" aria-labelledby="titulo-opiniones" onMouseEnter={() => setPausa(true)} onMouseLeave={() => setPausa(false)}>
      <div className="dm-contenedor">
        <motion.div className="dm-encabezado-seccion" {...aparecer}>
          <span className="dm-sobretitulo">Opiniones</span>
          <h2 id="titulo-opiniones">Lo que dicen en la ronda</h2>
        </motion.div>
        <div className="dm-opinion-marco">
          <AnimatePresence mode="wait">
            <motion.figure key={i} className="dm-opinion" initial={{ opacity: 0, y: 20, filter: "blur(6px)" }} animate={{ opacity: 1, y: 0, filter: "blur(0px)" }} exit={{ opacity: 0, y: -20, filter: "blur(6px)" }} transition={{ duration: 0.45 }}>
              <Estrellas valor={o.puntaje} size={18} />
              <blockquote>“{o.texto}”</blockquote>
              <figcaption>
                <span className="dm-avatar" aria-hidden="true">
                  {o.nombre[0]}
                </span>
                <span>
                  <strong>{o.nombre}</strong> · {o.barrio}
                  <small>
                    <IconoCheck size={13} /> Compra verificada · {o.producto}
                  </small>
                </span>
              </figcaption>
            </motion.figure>
          </AnimatePresence>
          <div className="dm-puntos" role="tablist" aria-label="Elegir opinión">
            {OPINIONES.map((op, n) => (
              <button key={op.nombre} role="tab" aria-selected={n === i} aria-label={`Opinión de ${op.nombre}`} onClick={() => setI(n)} className={n === i ? "es-activo" : ""}>
                {n === i && <motion.span layoutId="punto-activo" />}
              </button>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}

/* ---------------------------------- Newsletter y pie ---------------------------------- */

export function Newsletter() {
  const [email, setEmail] = useState("");
  const [listo, setListo] = useState(false);
  const [error, setError] = useState(false);
  return (
    <section className="dm-newsletter" aria-labelledby="titulo-news">
      <motion.div className="dm-contenedor dm-newsletter-caja" {...aparecer}>
        <div>
          <h2 id="titulo-news">10% off en tu primera compra</h2>
          <p>Sumate a la ronda: lanzamientos, talleres y ofertas de la sucursal. Nada de spam.</p>
        </div>
        <AnimatePresence mode="wait">
          {listo ? (
            <motion.p key="ok" className="dm-news-ok" initial={{ opacity: 0, scale: 0.9 }} animate={{ opacity: 1, scale: 1 }}>
              <IconoCheck /> ¡Listo! Tu código es <strong>DUO10</strong>
            </motion.p>
          ) : (
            <motion.form
              key="form"
              className="dm-news-form"
              exit={{ opacity: 0, scale: 0.95 }}
              onSubmit={(e) => {
                e.preventDefault();
                if (/^\S+@\S+\.\S+$/.test(email)) setListo(true);
                else setError(true);
              }}
              noValidate
            >
              <label htmlFor="news-email" className="dm-oculto">
                Tu email
              </label>
              <input
                id="news-email"
                type="email"
                placeholder="tu@email.com"
                value={email}
                autoComplete="email"
                onChange={(e) => {
                  setEmail(e.target.value);
                  setError(false);
                }}
                aria-invalid={error}
                aria-describedby={error ? "news-error" : undefined}
              />
              <button className="dm-boton dm-boton-acento" type="submit">
                Quiero mi cupón
              </button>
              {error && (
                <span id="news-error" className="dm-error dm-error-claro">
                  Revisá el email.
                </span>
              )}
            </motion.form>
          )}
        </AnimatePresence>
      </motion.div>
    </section>
  );
}

export function Pie() {
  return (
    <footer className="dm-pie">
      <div className="dm-contenedor dm-pie-grilla">
        <div>
          <Logo />
          <p>Mates, bombillas, yerbas y termos elegidos a mano. Sucursal Palermo desde 2014.</p>
          <a className="dm-social" href="https://www.instagram.com/" target="_blank" rel="noopener noreferrer" aria-label="Instagram de Duomate">
            <IconoInstagram /> @duomate
          </a>
        </div>
        <div>
          <h3>Tienda</h3>
          <a href="#tienda">Mates</a>
          <a href="#tienda">Bombillas</a>
          <a href="#tienda">Yerbas</a>
          <a href="#tienda">Termos y materas</a>
        </div>
        <div>
          <h3>Ayuda</h3>
          <a href="#ritual">Cómo curar tu mate</a>
          <a href="#sucursal">Retiro en sucursal</a>
          <a href="#sucursal">Cambios y garantía</a>
          <a href="#sucursal">Contacto</a>
        </div>
        <div>
          <h3>Sucursal</h3>
          <p>
            Gorriti 4820, Palermo Soho
            <br />
            Lun a vie 9–20 h · Sáb 10–19 h
            <br />
            WhatsApp 11 5555-0420
          </p>
        </div>
      </div>
      <div className="dm-contenedor dm-pie-legal">
        <span>© {new Date().getFullYear()} Duomate. Todos los derechos reservados.</span>
        <span>Precios en pesos argentinos con IVA incluido.</span>
      </div>
    </footer>
  );
}
