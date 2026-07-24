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
