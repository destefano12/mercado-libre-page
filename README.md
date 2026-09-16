# Mercado Live

Marketplace web multiusuario con publicaciones, busqueda, recomendaciones, chat interno, opiniones de usuarios, reputacion de vendedores y seguimiento de envios con mapa GPS simulado.

## Requisitos

- Node.js 22.13 o superior
- npm

## Ejecutar en localhost

```bash
npm install
npm run dev
```

Luego abrir:

```text
http://localhost:3000/
```

## Scripts

```bash
npm run dev      # servidor local
npm run build    # compilar para produccion
npm test         # compilar y ejecutar pruebas
npm run lint     # revisar calidad del codigo
```

## Estudiar Mejor

El repositorio incluye una segunda aplicacion independiente en `/estudiar-mejor`: una
plataforma de acompanamiento para estudiantes de secundaria. Funciona entera en el
navegador (React + Tailwind, sin backend) y guarda todo en `localStorage`.

Su principio inviolable, publicado como manifiesto dentro de la propia app: nunca
resuelve tareas, nunca redacta trabajos y nunca responde ejercicios. Ante un pedido de
respuesta directa devuelve preguntas que llevan al alumno a encontrarla.

Modulos: planificador con plan diario y porcentaje de avance, tutor socratico que genera
preguntas a partir del material que sube el alumno (con pistas graduales y repaso
espaciado), modo "explicamelo vos" que marca los huecos del razonamiento, mapa de dominio
por temas con colores de semaforo, registro de errores frecuentes que se reinyectan en los
repasos, trabajos grupales con reparto de responsabilidades y avance por integrante, agenda
de entregas y examenes, pomodoro con descansos, panel para familias y docentes que muestra
constancia y proceso pero nunca notas, y simulador de evaluacion cronometrado con correccion
explicada tema por tema.

```text
http://localhost:3000/estudiar-mejor
```

- `app/estudiar-mejor/lib/`: motor de analisis de texto, generador socratico, planificador,
  simulador, guardia anti-respuestas y estado persistido.
- `app/estudiar-mejor/modulos/`: un archivo por modulo.

## Estructura principal

- `app/`: aplicacion, componentes y APIs.
- `IMG/`: imagenes, banners, logos y assets visuales.
- `public/`: archivos publicos basicos.
- `tests/`: pruebas automaticas.

## Publicar desde GitHub

1. Crear un repositorio nuevo en GitHub.
2. Subir este proyecto al repositorio.
3. Conectar el repositorio a Vercel, Cloudflare Pages o Netlify.
4. Configurar el comando de build:

```bash
npm run build
```

5. Usar el directorio de salida que indique el proveedor segun soporte para aplicaciones Next/Vite/Vinext.

## Nota

Este proyecto es una aplicacion marketplace propia. Si se publica para uso real, conviene usar nombre, marca, logos y textos propios para evitar confusion con marcas comerciales existentes.
