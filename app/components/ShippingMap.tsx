"use client";

import type { CSSProperties } from "react";
import type { Shipment } from "../data/marketplace";
import erlcDeliveryMap from "@/IMG/official/erlc-delivery-map.webp";

interface ShippingMapProps {
  shipment?: Shipment;
}

const creationPoint = { label: "Creacion 303", x: 49.6, y: 79.7 };
const hubPoint = { label: "Reparto / retiro 308", x: 47.8, y: 61.1 };

const mapHousingZones = [
  { prefixes: ["70", "71", "8"], label: "Vivienda 703", x: 22.2, y: 44.9 },
  { prefixes: ["40", "41", "2"], label: "Vivienda 405", x: 18.6, y: 60.4 },
  { prefixes: ["90", "91"], label: "Vivienda 907", x: 57.4, y: 31.4 },
  { prefixes: ["11"], label: "Vivienda 1104", x: 80.3, y: 38.3 },
  { prefixes: ["12"], label: "Vivienda 1202", x: 84.2, y: 65.4 },
];

function destinationZoneFor(destination: string) {
  const digits = destination.match(/\d+/)?.[0] ?? "";
  return (
    mapHousingZones.find((zone) =>
      zone.prefixes.some((prefix) => digits.startsWith(prefix)),
    ) ?? mapHousingZones[0]
  );
}

function pointBehindHome(home: { label: string; x: number; y: number }) {
  return {
    label: "En camino",
    x: Number((home.x + (hubPoint.x - home.x) * 0.18).toFixed(1)),
    y: Number((home.y + (hubPoint.y - home.y) * 0.18).toFixed(1)),
  };
}

function routeFor(destination: string) {
  const destinationZone = destinationZoneFor(destination);
  return [
    creationPoint,
    hubPoint,
    pointBehindHome(destinationZone),
    destinationZone,
  ];
}

export function ShippingMap({ shipment }: ShippingMapProps) {
  if (!shipment) {
    return (
      <section className="gps-card">
        <div className="gps-map gps-map--empty">
          <span>No hay envio activo para esta publicacion</span>
        </div>
      </section>
    );
  }

  const route = routeFor(shipment.destination);
  const pointIndex = Math.min(
    route.length - 1,
    Math.floor((shipment.progress / 100) * route.length),
  );
  const activePoint = route[pointIndex] ?? route[0];
  const routeProgress = Math.min(100, Math.max(0, shipment.progress));
  const mapSource = typeof erlcDeliveryMap === "string"
    ? erlcDeliveryMap
    : erlcDeliveryMap.src;

  return (
    <section className="gps-card">
      <div className="gps-card__header">
        <div>
          <span className="gps-card__eyebrow">GPS simulado</span>
          <h3>{shipment.status}</h3>
        </div>
        <strong>{shipment.progress}%</strong>
      </div>
      <div className="gps-map" aria-label="Mapa visual de seguimiento de envio">
        <img
          className="gps-map__image"
          src={mapSource}
          alt="Mapa de reparto con zonas de creacion, retiro y viviendas"
        />
        <div className="gps-map__legend" aria-hidden="true">
          <span><i className="is-origin" /> Creacion 303</span>
          <span><i className="is-hub" /> Reparto / retiro 308</span>
          <span><i className="is-home" /> Viviendas</span>
        </div>
        <div
          className="gps-map__route"
          style={{ "--route-progress": `${routeProgress}%` } as CSSProperties}
        />
        {route.map((point, index) => (
          <div
            className={`gps-map__pin gps-map__pin--${index === 0 ? "origin" : index === 1 ? "hub" : index === route.length - 1 ? "home" : "transit"}`}
            key={point.label}
            style={{ left: `${point.x}%`, top: `${point.y}%` }}
          >
            <span>{point.label}</span>
          </div>
        ))}
        <div
          className="gps-map__vehicle"
          style={{
            left: `${Math.min(92, Math.max(6, activePoint.x + (shipment.progress % 18) / 8))}%`,
            top: `${Math.min(88, Math.max(10, activePoint.y - (shipment.progress % 14) / 10))}%`,
          }}
        />
      </div>
      <div className="gps-card__footer">
        <span>Creacion: 303</span>
        <span>{shipment.etaMinutes === 0 ? "Entregado" : `${shipment.etaMinutes} min`}</span>
        <span>Destino: {shipment.destination}</span>
      </div>
    </section>
  );
}
