"use client";

import { useMemo, useState } from "react";
import {
  categories,
  type CategoryConfig,
  type CategoryId,
} from "../data/marketplace";
import type { PublishListingInput } from "../lib/useMarketplaceStore";

interface PublishModalProps {
  onPublish: (input: PublishListingInput) => void;
  onClose: () => void;
}

const categoryDefaults: Record<CategoryId, Record<string, string | number>> = {
  vehiculos: {
    anio: "2024",
    kilometraje: "30.000 km",
    transmision: "Automatica",
    marca: "Toyota",
  },
  inmuebles: {
    ambientes: "2 ambientes",
    metros: "65 m2",
    ubicacion: "Palermo",
    operacion: "Alquiler",
  },
  streaming: {
    plataforma: "HBO Max",
    tipo: "Membresia",
    entrega: "Instantanea",
    duracion: "1 mes",
  },
  tecnologia: {
    marca: "Apple",
    memoria: "256 GB",
    envio: "Full",
    estado: "Nuevo",
  },
  moda: {
    talle: "M",
    color: "Negro",
    marca: "Adidas",
    envio: "Full",
  },
  hogar: {
    ambiente: "Living",
    material: "Madera",
    medida: "Mediano",
    envio: "Gratis",
  },
  herramientas: {
    uso: "Profesional",
    marca: "Bosch",
    potencia: "18 V",
    kit: "Con accesorios",
  },
  supermercado: {
    pasillo: "Limpieza",
    marca: "Ala",
    pack: "6 unidades",
    entrega: "Hoy",
  },
};

function metadataFor(category: CategoryConfig, overrides: Record<string, string>) {
  return category.filters.reduce<Record<string, string>>((meta, filter) => {
    const key = filter.label.toLowerCase();
    meta[key] = overrides[key] || String(categoryDefaults[category.id][key] ?? filter.values[0]);
    return meta;
  }, {});
}

export function PublishModal({ onPublish, onClose }: PublishModalProps) {
  const [categoryId, setCategoryId] = useState<CategoryId>("tecnologia");
  const [title, setTitle] = useState("Samsung Galaxy S24 Ultra 256 GB");
  const [description, setDescription] = useState("Publicacion creada por usuario con stock real y chat activo.");
  const [price, setPrice] = useState(1200000);
  const [condition, setCondition] = useState<"Nuevo" | "Usado" | "Digital">("Nuevo");
  const [location, setLocation] = useState("Buenos Aires");
  const [shipping, setShipping] = useState("Envio gratis");
  const [tags, setTags] = useState("samsung, celular, full, 256 gb");
  const [metaValues, setMetaValues] = useState<Record<string, string>>({});

  const category = useMemo(
    () => categories.find((candidate) => candidate.id === categoryId) ?? categories[0],
    [categoryId],
  );

  return (
    <div className="modal-layer" role="dialog" aria-modal="true" aria-label="Publicar">
      <form
        className="modal-card publish-modal"
        onSubmit={(event) => {
          event.preventDefault();
          if (!title.trim() || price < 0) {
            return;
          }

          onPublish({
            title,
            description,
            categoryId,
            price,
            condition,
            location,
            shipping,
            tags: tags
              .split(",")
              .map((tag) => tag.trim())
              .filter(Boolean),
            meta: metadataFor(category, metaValues),
          });
          onClose();
        }}
      >
        <div className="modal-card__header">
          <div>
            <span>Publicacion online</span>
            <h2>Vender en Mercado Live</h2>
          </div>
          <button type="button" onClick={onClose} aria-label="Cerrar">
            x
          </button>
        </div>

        <div className="publish-modal__grid">
          <label>
            Categoria
            <select
              value={categoryId}
              onChange={(event) => {
                const nextCategory = event.target.value as CategoryId;
                setCategoryId(nextCategory);
                setMetaValues({});
                setCondition(nextCategory === "streaming" ? "Digital" : "Nuevo");
              }}
            >
              {categories.map((option) => (
                <option key={option.id} value={option.id}>
                  {option.label}
                </option>
              ))}
            </select>
          </label>
          <label>
            Precio
            <input
              min={0}
              value={price}
              onChange={(event) => setPrice(Number(event.target.value))}
              type="number"
            />
          </label>
          <label className="publish-modal__wide">
            Titulo
            <input value={title} onChange={(event) => setTitle(event.target.value)} />
          </label>
          <label className="publish-modal__wide">
            Descripcion
            <textarea value={description} onChange={(event) => setDescription(event.target.value)} rows={3} />
          </label>
          <label>
            Estado
            <select value={condition} onChange={(event) => setCondition(event.target.value as typeof condition)}>
              <option>Nuevo</option>
              <option>Usado</option>
              <option>Digital</option>
            </select>
          </label>
          <label>
            Envio
            <input value={shipping} onChange={(event) => setShipping(event.target.value)} />
          </label>
          <label>
            Ubicacion
            <input value={location} onChange={(event) => setLocation(event.target.value)} />
          </label>
          <label>
            Etiquetas
            <input value={tags} onChange={(event) => setTags(event.target.value)} />
          </label>
        </div>

        <div className="publish-modal__filters">
          {category.filters.map((filter) => {
            const key = filter.label.toLowerCase();
            const value = metaValues[key] || String(categoryDefaults[category.id][key] ?? filter.values[0]);

            return (
              <label key={filter.label}>
                {filter.label}
                <select
                  value={value}
                  onChange={(event) =>
                    setMetaValues((previous) => ({
                      ...previous,
                      [key]: event.target.value,
                    }))
                  }
                >
                  {filter.values.map((option) => (
                    <option key={option}>{option}</option>
                  ))}
                </select>
              </label>
            );
          })}
        </div>

        <button className="publish-modal__submit" type="submit">
          Publicar ahora
        </button>
      </form>
    </div>
  );
}
