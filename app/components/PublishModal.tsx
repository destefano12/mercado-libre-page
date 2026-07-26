"use client";

import { useMemo, useRef, useState } from "react";
import type { ClipboardEvent } from "react";
import { categories, type CategoryConfig, type CategoryId } from "../data/marketplace";
import type { PublishListingInput } from "../lib/useMarketplaceStore";

interface PublishModalProps {
  onPublish: (input: PublishListingInput) => void;
  onClose: () => void;
}

const categoryDefaults: Partial<Record<CategoryId, Record<string, string | number>>> = {
  vehiculos: { anio: "2024", kilometraje: "30.000 km", transmision: "Automatica", marca: "Toyota" },
  inmuebles: { ambientes: "2 ambientes", metros: "65 m2", ubicacion: "Palermo", operacion: "Alquiler" },
  streaming: { plataforma: "HBO Max", tipo: "Membresia", entrega: "Instantanea", duracion: "1 mes" },
  tecnologia: { marca: "Apple", memoria: "256 GB", envio: "Full", estado: "Nuevo" },
  moda: { talle: "M", color: "Negro", marca: "Adidas", envio: "Full" },
  hogar: { ambiente: "Living", material: "Madera", medida: "Mediano", envio: "Gratis" },
  herramientas: { uso: "Profesional", marca: "Bosch", potencia: "18 V", kit: "Con accesorios" },
  supermercado: { pasillo: "Limpieza", marca: "Ala", pack: "6 unidades", entrega: "Hoy" },
};

const saleTypeDescriptions: Partial<Record<CategoryId, string>> = {
  vehiculos: "Autos, motos y otros vehiculos",
  inmuebles: "Casas, departamentos y terrenos",
  streaming: "Servicios y accesos digitales",
  tecnologia: "Celulares, computadoras y accesorios",
  moda: "Ropa, calzado y accesorios",
  hogar: "Muebles, decoracion y articulos del hogar",
  herramientas: "Herramientas, maquinas e insumos",
  supermercado: "Alimentos, limpieza y consumo diario",
};

const titlePlaceholders: Partial<Record<CategoryId, string>> = {
  vehiculos: "Ej.: Toyota Corolla 2021 automatico",
  inmuebles: "Ej.: Departamento 2 ambientes en Palermo",
  streaming: "Ej.: Acceso HBO Max 1 mes",
  tecnologia: "Ej.: Samsung Galaxy S24 Ultra 256 GB",
  moda: "Ej.: Campera de jean talle M",
  hogar: "Ej.: Mesa ratona de madera para living",
  herramientas: "Ej.: Taladro inalambrico 18 V",
  supermercado: "Ej.: Pack de productos de limpieza",
};

function metadataFor(category: CategoryConfig, overrides: Record<string, string>) {
  return category.filters.reduce<Record<string, string>>((meta, filter) => {
    const key = filter.label.toLowerCase();
    meta[key] = overrides[key] || String(categoryDefaults[category.id]?.[key] ?? filter.values[0]);
    return meta;
  }, {});
}

function loadImage(file: File) {
  return new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onerror = () => reject(new Error("No se pudo leer la imagen"));
    reader.onload = () => {
      const image = new Image();
      image.onerror = () => reject(new Error("El archivo no es una imagen válida"));
      image.onload = () => {
        const maxSide = 1000;
        const scale = Math.min(1, maxSide / Math.max(image.width, image.height));
        const canvas = document.createElement("canvas");
        canvas.width = Math.max(1, Math.round(image.width * scale));
        canvas.height = Math.max(1, Math.round(image.height * scale));
        const context = canvas.getContext("2d");
        if (!context) {
          reject(new Error("No se pudo procesar la imagen"));
          return;
        }
        context.fillStyle = "#ffffff";
        context.fillRect(0, 0, canvas.width, canvas.height);
        context.drawImage(image, 0, 0, canvas.width, canvas.height);
        resolve(canvas.toDataURL("image/jpeg", 0.78));
      };
      image.src = String(reader.result);
    };
    reader.readAsDataURL(file);
  });
}

export function PublishModal({ onPublish, onClose }: PublishModalProps) {
  const fileInput = useRef<HTMLInputElement>(null);
  const [step, setStep] = useState(1);
  const [categoryId, setCategoryId] = useState<CategoryId>("tecnologia");
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [price, setPrice] = useState(0);
  const [condition, setCondition] = useState<"Nuevo" | "Usado" | "Digital">("Nuevo");
  const [location, setLocation] = useState("Buenos Aires");
  const [shipping, setShipping] = useState("Envío por Mercado Envíos");
  const [tags, setTags] = useState("");
  const [metaValues, setMetaValues] = useState<Record<string, string>>({});
  const [images, setImages] = useState<string[]>([]);
  const [imageError, setImageError] = useState("");
  const [draggingPhotos, setDraggingPhotos] = useState(false);

  const category = useMemo(
    () => categories.find((candidate) => candidate.id === categoryId) ?? categories[0],
    [categoryId],
  );

  async function addImages(files: FileList | File[] | null) {
    if (!files?.length) return;
    setImageError("");
    try {
      const available = Math.max(0, 6 - images.length);
      if (available === 0) {
        setImageError("Ya cargaste el maximo de 6 fotos.");
        return;
      }
      const selected = Array.from(files)
        .filter((file) => file.type.startsWith("image/"))
        .slice(0, available);
      if (selected.length === 0) {
        setImageError("Pegá o arrastrá una imagen JPG, PNG o WEBP.");
        return;
      }
      const encoded = await Promise.all(selected.map(loadImage));
      setImages((previous) => [...previous, ...encoded].slice(0, 6));
    } catch (error) {
      setImageError(error instanceof Error ? error.message : "No se pudo cargar la imagen");
    }
  }

  function pasteImages(event: ClipboardEvent) {
    const files = Array.from(event.clipboardData.files).filter((file) =>
      file.type.startsWith("image/"),
    );
    if (files.length > 0) {
      event.preventDefault();
      void addImages(files);
    }
  }

  function nextStep() {
    if (step === 1 && !title.trim()) return;
    if (step === 2 && images.length === 0) {
      setImageError("Agregá al menos una foto para continuar.");
      return;
    }
    setStep((current) => Math.min(3, current + 1));
  }

  function finishPublication() {
    if (!title.trim() || price < 0 || images.length === 0) return;
    onPublish({
      title,
      description,
      categoryId,
      price,
      condition,
      location,
      shipping,
      images,
      tags: [
        ...tags.split(",").map((tag) => tag.trim()).filter(Boolean),
        ...title.toLowerCase().split(/\s+/).filter((word) => word.length > 2),
      ],
      meta: metadataFor(category, metaValues),
    });
  }

  return (
    <div className="publish-layer" role="dialog" aria-modal="true" aria-label="Publicar" onPaste={pasteImages}>
      <header className="publish-header">
        <button type="button" onClick={onClose} aria-label="Cerrar publicación">×</button>
        <strong>Publicar</strong>
        <span />
      </header>

      <main className="publish-flow">
        <div className="publish-progress" aria-label={`Paso ${step} de 3`}>
          {[1, 2, 3].map((number) => (
            <span className={number <= step ? "is-active" : ""} key={number}>
              <i>{number}</i>
              {number === 1 ? "Producto" : number === 2 ? "Datos" : "Venta"}
            </span>
          ))}
        </div>

        {step === 1 ? (
          <section className="publish-step">
            <h1>¿Qué querés vender?</h1>
            <p>Elegí el tipo de publicación.</p>
            <div className="sale-type-grid">
              {categories.map((type) => (
                <button
                  className={categoryId === type.id ? "is-active" : ""}
                  key={type.id}
                  type="button"
                  onClick={() => {
                    setCategoryId(type.id);
                    setCondition(type.id === "streaming" ? "Digital" : "Nuevo");
                    setMetaValues({});
                  }}
                >
                  <span />
                  <strong>{type.label}</strong>
                  <small>{saleTypeDescriptions[type.id] ?? "Productos, servicios o articulos de esta categoria"}</small>
                </button>
              ))}
            </div>

            <label className="publish-field">
              Categoría
              <select
                value={categoryId}
                onChange={(event) => {
                  const next = event.target.value as CategoryId;
                  setCategoryId(next);
                  setCondition(next === "streaming" ? "Digital" : "Nuevo");
                  setMetaValues({});
                }}
              >
                {categories.map((option) => (
                  <option key={option.id} value={option.id}>{option.label}</option>
                ))}
              </select>
            </label>

            <label className="publish-field">
              Indicá qué producto es
              <input
                value={title}
                onChange={(event) => setTitle(event.target.value)}
                placeholder={titlePlaceholders[categoryId] ?? `Ej.: Publicacion de ${category.label.toLowerCase()}`}
                maxLength={60}
              />
              <small>{title.length}/60</small>
            </label>
          </section>
        ) : null}

        {step === 2 ? (
          <section className="publish-step">
            <h1>Completá los datos del producto</h1>
            <p>La primera foto será la portada de tu publicación.</p>

            <div
              className={`photo-uploader${draggingPhotos ? " is-dragging" : ""}`}
              onDragEnter={(event) => {
                event.preventDefault();
                setDraggingPhotos(true);
              }}
              onDragOver={(event) => {
                event.preventDefault();
                setDraggingPhotos(true);
              }}
              onDragLeave={(event) => {
                event.preventDefault();
                setDraggingPhotos(false);
              }}
              onDrop={(event) => {
                event.preventDefault();
                setDraggingPhotos(false);
                void addImages(event.dataTransfer.files);
              }}
              onPaste={pasteImages}
              tabIndex={0}
              role="button"
              aria-label="Agregar fotos arrastrando, pegando o seleccionando archivos"
            >
              <input
                ref={fileInput}
                type="file"
                accept="image/jpeg,image/png,image/webp"
                multiple
                onChange={(event) => void addImages(event.target.files)}
              />
              <button type="button" onClick={() => fileInput.current?.click()}>
                <span>+</span>
                Agregar fotos
              </button>
              <small>JPG, PNG o WEBP. Hasta 6 fotos. Tambien podes arrastrar una imagen o copiarla y pegarla aca.</small>
            </div>
            {imageError ? <p className="publish-error">{imageError}</p> : null}
            {images.length > 0 ? (
              <div className="photo-previews">
                {images.map((image, index) => (
                  <div key={`${image.slice(-20)}-${index}`}>
                    <img src={image} alt={`Foto ${index + 1} de ${title}`} />
                    {index === 0 ? <span>Portada</span> : null}
                    <button
                      type="button"
                      aria-label={`Eliminar foto ${index + 1}`}
                      onClick={() => setImages((previous) => previous.filter((_, itemIndex) => itemIndex !== index))}
                    >
                      ×
                    </button>
                  </div>
                ))}
              </div>
            ) : null}

            <div className="publish-form-grid">
              <label className="publish-field">
                Condición
                <select value={condition} onChange={(event) => setCondition(event.target.value as typeof condition)}>
                  <option>Nuevo</option>
                  <option>Usado</option>
                  <option>Digital</option>
                </select>
              </label>
              {category.filters.map((filter) => {
                const key = filter.label.toLowerCase();
                const value = metaValues[key] || String(categoryDefaults[category.id]?.[key] ?? filter.values[0]);
                if (key === "marca") {
                  return (
                    <label className="publish-field" key={filter.label}>
                      {filter.label}
                      <input
                        value={metaValues[key] ?? ""}
                        onChange={(event) =>
                          setMetaValues((previous) => ({ ...previous, [key]: event.target.value }))
                        }
                        placeholder="Escribi la marca. Ej.: Glaciar, Xiaomi, Genérica"
                      />
                    </label>
                  );
                }
                return (
                  <label className="publish-field" key={filter.label}>
                    {filter.label}
                    <select
                      value={value}
                      onChange={(event) =>
                        setMetaValues((previous) => ({ ...previous, [key]: event.target.value }))
                      }
                    >
                      {filter.values.map((option) => <option key={option}>{option}</option>)}
                    </select>
                  </label>
                );
              })}
              <label className="publish-field publish-field--wide">
                Descripción
                <textarea
                  value={description}
                  onChange={(event) => setDescription(event.target.value)}
                  placeholder="Describí el estado, los detalles y qué incluye."
                  rows={5}
                />
              </label>
            </div>
          </section>
        ) : null}

        {step === 3 ? (
          <section className="publish-step">
            <h1>Definí las condiciones de venta</h1>
            <p>Revisá el precio y la forma de entrega.</p>
            <div className="sale-conditions">
              <div className="publish-form-grid">
                <label className="publish-field">
                  Precio
                  <span className="price-input"><b>$</b><input min={0} value={price || ""} onChange={(event) => setPrice(Number(event.target.value))} type="number" /></span>
                </label>
                <label className="publish-field">
                  Forma de entrega
                  <select value={shipping} onChange={(event) => setShipping(event.target.value)}>
                    <option>Envío por Mercado Envíos</option>
                    <option>Retiro en persona</option>
                    <option>A coordinar con el comprador</option>
                    <option>Entrega digital inmediata</option>
                  </select>
                </label>
                <label className="publish-field">
                  Ubicación
                  <input value={location} onChange={(event) => setLocation(event.target.value)} />
                </label>
                <label className="publish-field">
                  Palabras clave
                  <input value={tags} onChange={(event) => setTags(event.target.value)} placeholder="marca, modelo, color" />
                </label>
              </div>
              <aside className="publish-preview">
                <img src={images[0]} alt={title} />
                <span>{condition}</span>
                <h2>{title}</h2>
                <strong>{price ? new Intl.NumberFormat("es-AR", { style: "currency", currency: "ARS", maximumFractionDigits: 0 }).format(price) : "$ 0"}</strong>
                <p>{shipping}</p>
              </aside>
            </div>
          </section>
        ) : null}

        <footer className="publish-actions">
          {step > 1 ? <button type="button" onClick={() => setStep((current) => current - 1)}>Volver</button> : <span />}
          {step < 3 ? (
            <button className="publish-actions__primary" type="button" onClick={nextStep}>Continuar</button>
          ) : (
            <button className="publish-actions__primary" type="button" onClick={finishPublication}>Publicar</button>
          )}
        </footer>
      </main>
    </div>
  );
}
