"use client";

import { motion, useMotionValueEvent, useScroll, useSpring, useTransform, type MotionValue } from "framer-motion";
import { useEffect, useRef, useState } from "react";
import type { Escena } from "../lib/escena3d";
import { ArteProducto } from "./ArteProducto";
import { IconoFlecha } from "./Iconos";

const PASOS = [
  { desde: 0.0, hasta: 0.24, n: "01", titulo: "Abrí tu yerba", texto: "Duomate Blend Suave: hoja de Misiones estacionada 24 meses. Poco polvo, sabor redondo." },
  { desde: 0.27, hasta: 0.64, n: "02", titulo: "Llená ¾ del mate", texto: "Volcá la yerba sin miedo. Después tapá la boca, invertí y sacudí: el polvo queda arriba." },
  { desde: 0.66, hasta: 0.87, n: "03", titulo: "Inclinalo y clavá la bombilla", texto: "Formá la montañita en diagonal y apoyá la bombilla del lado bajo, hasta el fondo. No la muevas más." },
  { desde: 0.89, hasta: 0.965, n: "04", titulo: "Cebá a 75–80 °C", texto: "Nunca hervida: el agua muy caliente quema la yerba. Primero en el hueco, después a la ronda." },
];

export function RitualScroll() {
  const seccion = useRef<HTMLElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const escena = useRef<Escena | null>(null);
  const [estado, setEstado] = useState<"cargando" | "listo" | "sin-3d">("cargando");

  const { scrollYProgress } = useScroll({ target: seccion, offset: ["start start", "end end"] });
  const progreso = useSpring(scrollYProgress, { stiffness: 90, damping: 26, mass: 0.6, restDelta: 0.0002 });

  useMotionValueEvent(progreso, "change", (v) => escena.current?.setProgreso(v));

  useEffect(() => {
    let cancelado = false;
    let observador: IntersectionObserver | null = null;
    let alRedimensionar: (() => void) | null = null;
    const lienzo = canvas.current;
    if (!lienzo) return;

    const prueba = document.createElement("canvas");
    const soporta = !!(prueba.getContext("webgl2") || prueba.getContext("webgl"));
    if (!soporta) {
      Promise.resolve().then(() => !cancelado && setEstado("sin-3d"));
      return;
    }

    // Three.js se descarga solo cuando hace falta: no pesa en la carga inicial.
    import("../lib/escena3d")
      .then(({ crearEscena }) => crearEscena(lienzo))
      .then((e) => {
        if (cancelado) {
          e.destruir();
          return;
        }
        escena.current = e;
        e.setProgreso(progreso.get());
        alRedimensionar = () => e.redimensionar();
        window.addEventListener("resize", alRedimensionar);
        observador = new IntersectionObserver(([entrada]) => e.activar(entrada.isIntersecting), { rootMargin: "200px" });
        if (seccion.current) observador.observe(seccion.current);
        setEstado("listo");
      })
      .catch(() => !cancelado && setEstado("sin-3d"));

    return () => {
      cancelado = true;
      observador?.disconnect();
      if (alRedimensionar) window.removeEventListener("resize", alRedimensionar);
      escena.current?.destruir();
      escena.current = null;
    };
  }, [progreso]);

  return (
    <section id="ritual" ref={seccion} className="dm-ritual3d" aria-labelledby="titulo-ritual3d">
      <div className="dm-ritual3d-fijo">
        <div className="dm-ritual3d-fondo" aria-hidden="true" />
        <canvas ref={canvas} className={`dm-ritual3d-lienzo ${estado === "listo" ? "es-visible" : ""}`} aria-hidden="true" />

        {estado === "sin-3d" && (
          <div className="dm-ritual3d-respaldo" aria-hidden="true">
            <ArteProducto arte="kit" color="#8a5a36" className="dm-arte" />
          </div>
        )}
        {estado === "cargando" && <div className="dm-ritual3d-cargando" aria-hidden="true" />}

        <div className="dm-contenedor dm-ritual3d-capa">
          <header className="dm-ritual3d-titulo">
            <span className="dm-sobretitulo">El ritual · hacé scroll</span>
            <h2 id="titulo-ritual3d">Cómo se prepara un buen mate</h2>
          </header>

          <ol className="dm-ritual3d-pasos">
            {PASOS.map((p) => (
              <Paso key={p.n} paso={p} progreso={progreso} />
            ))}
          </ol>

          <Riel progreso={progreso} />
          <Final progreso={progreso} />
        </div>
      </div>
    </section>
  );
}

function Paso({ paso, progreso }: { paso: (typeof PASOS)[number]; progreso: MotionValue<number> }) {
  const { desde, hasta } = paso;
  const opacidad = useTransform(progreso, [desde, desde + 0.04, hasta - 0.04, hasta], [0, 1, 1, 0]);
  const y = useTransform(progreso, [desde, desde + 0.05, hasta - 0.05, hasta], [40, 0, 0, -40]);
  const desenfoque = useTransform(progreso, [desde, desde + 0.04, hasta - 0.04, hasta], ["blur(8px)", "blur(0px)", "blur(0px)", "blur(8px)"]);
  return (
    <motion.li className="dm-ritual3d-paso" style={{ opacity: opacidad, y, filter: desenfoque }}>
      <span className="dm-ritual3d-numero">{paso.n}</span>
      <h3>{paso.titulo}</h3>
      <p>{paso.texto}</p>
    </motion.li>
  );
}

function Riel({ progreso }: { progreso: MotionValue<number> }) {
  const alto = useTransform(progreso, [0, 1], ["0%", "100%"]);
  return (
    <div className="dm-ritual3d-riel" aria-hidden="true">
      <motion.span style={{ height: alto }} />
      {PASOS.map((p) => (
        <PuntoRiel key={p.n} progreso={progreso} desde={p.desde} />
      ))}
    </div>
  );
}

function PuntoRiel({ progreso, desde }: { progreso: MotionValue<number>; desde: number }) {
  const escala = useTransform(progreso, [desde, desde + 0.03], [0.6, 1]);
  const fondo = useTransform(progreso, [desde, desde + 0.03], ["#d8cfbd", "#b4572e"]);
  return <motion.i style={{ top: `${desde * 100}%`, scale: escala, background: fondo }} />;
}

function Final({ progreso }: { progreso: MotionValue<number> }) {
  const opacidad = useTransform(progreso, [0.965, 0.99], [0, 1]);
  const y = useTransform(progreso, [0.965, 0.99], [30, 0]);
  const eventos = useTransform(progreso, (v) => (v > 0.965 ? "auto" : "none"));
  return (
    <motion.div className="dm-ritual3d-final" style={{ opacity: opacidad, y, pointerEvents: eventos }}>
      <strong>¡A matear!</strong>
      <a href="#tienda" className="dm-boton dm-boton-principal">
        Armá tu equipo <IconoFlecha size={18} />
      </a>
    </motion.div>
  );
}
