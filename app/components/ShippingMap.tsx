"use client";

import type { CSSProperties } from "react";
import type { Shipment } from "../data/marketplace";
import erlcDeliveryMap from "@/IMG/official/erlc-delivery-map.webp";

interface ShippingMapProps {
  shipment?: Shipment;
  courierLocation?: LiveCourierLocation | null;
}

export interface LiveCourierLocation {
  player: string;
  robloxUserId: string;
  team: string;
  postalCode?: string;
  streetName?: string;
  buildingNumber?: string;
}

const creationPoint = { label: "Creacion 303", x: 49.6, y: 79.7 };
const hubPoint = { label: "Reparto / retiro 308", x: 47.8, y: 61.1 };

const exactHousePoints: Record<string, { label: string; x: number; y: number }> = {
  "200": { label: "Postal 200", x: 13.2, y: 84.3 },
  "201": { label: "Postal 201", x: 16.6, y: 83.5 },
  "202": { label: "Postal 202", x: 26.6, y: 84.4 },
  "203": { label: "Postal 203", x: 33.1, y: 84.2 },
  "204": { label: "Postal 204", x: 39.8, y: 83.6 },
  "205": { label: "Postal 205", x: 15.2, y: 78.5 },
  "206": { label: "Postal 206", x: 22.8, y: 77.9 },
  "207": { label: "Postal 207", x: 28.6, y: 77.6 },
  "208": { label: "Postal 208", x: 34.3, y: 77.8 },
  "216": { label: "Postal 216", x: 25.4, y: 68.7 },
  "217": { label: "Postal 217", x: 32.1, y: 69.1 },
  "218": { label: "Postal 218", x: 39.6, y: 72.6 },
  "219": { label: "Postal 219", x: 39.4, y: 68.3 },
  "300": { label: "Postal 300", x: 51.0, y: 84.0 },
  "301": { label: "Postal 301", x: 57.1, y: 84.2 },
  "302": { label: "Postal 302", x: 64.8, y: 84.0 },
  "303": { label: "Postal 303", x: 49.6, y: 79.7 },
  "304": { label: "Postal 304", x: 56.3, y: 79.0 },
  "305": { label: "Postal 305", x: 50.0, y: 68.4 },
  "306": { label: "Postal 306", x: 50.7, y: 74.3 },
  "307": { label: "Postal 307", x: 56.8, y: 74.2 },
  "308": { label: "Postal 308", x: 47.8, y: 61.1 },
  "309": { label: "Postal 309", x: 56.2, y: 70.6 },
  "310": { label: "Postal 310", x: 61.8, y: 74.0 },
  "700": { label: "Vivienda 700", x: 11.3, y: 47.1 },
  "701": { label: "Vivienda 701", x: 19.5, y: 51.1 },
  "702": { label: "Vivienda 702", x: 29.3, y: 50.8 },
  "703": { label: "Vivienda 703", x: 38.4, y: 47.2 },
  "704": { label: "Vivienda 704", x: 19.1, y: 44.4 },
  "705": { label: "Vivienda 705", x: 27.4, y: 43.2 },
  "706": { label: "Vivienda 706", x: 33.3, y: 44.9 },
  "707": { label: "Vivienda 707", x: 39.0, y: 42.8 },
  "708": { label: "Vivienda 708", x: 18.0, y: 40.2 },
  "709": { label: "Vivienda 709", x: 26.3, y: 38.2 },
  "710": { label: "Vivienda 710", x: 33.8, y: 37.2 },
  "711": { label: "Vivienda 711", x: 24.4, y: 33.0 },
  "405": { label: "Vivienda 405", x: 18.6, y: 60.4 },
  "907": { label: "Vivienda 907", x: 57.4, y: 31.4 },
  "1104": { label: "Vivienda 1104", x: 80.3, y: 38.3 },
  "1202": { label: "Vivienda 1202", x: 84.2, y: 65.4 },
};

const mapHousingZones = [
  { prefixes: ["70", "71", "8"], label: "Vivienda 703", x: 22.2, y: 44.9 },
  { prefixes: ["40", "41", "2"], label: "Vivienda 405", x: 18.6, y: 60.4 },
  { prefixes: ["30", "31"], label: "Postal 303", x: 49.6, y: 79.7 },
  { prefixes: ["50"], label: "Postal 505", x: 57.9, y: 57.3 },
  { prefixes: ["60"], label: "Postal 604", x: 59.1, y: 42.9 },
  { prefixes: ["90", "91"], label: "Vivienda 907", x: 57.4, y: 31.4 },
  { prefixes: ["11"], label: "Vivienda 1104", x: 80.3, y: 38.3 },
  { prefixes: ["12"], label: "Vivienda 1202", x: 84.2, y: 65.4 },
];

function destinationZoneFor(destination: string) {
  const digits = destination.match(/\d+/)?.[0] ?? "";
  if (exactHousePoints[digits]) {
    return exactHousePoints[digits];
  }
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

function courierPointFor(location?: LiveCourierLocation | null) {
  if (!location?.postalCode) {
    return null;
  }
  const base = destinationZoneFor(location.postalCode);
  const detail = [
    location.postalCode ? `Postal ${location.postalCode}` : "",
    location.streetName,
    location.buildingNumber,
  ].filter(Boolean).join(" · ");
  return {
    ...base,
    label: detail || base.label,
  };
}

export function ShippingMap({ shipment, courierLocation }: ShippingMapProps) {
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
  const liveCourierPoint = courierPointFor(courierLocation);
  const courierPoint = liveCourierPoint ?? activePoint;
  const courierStatus = liveCourierPoint
    ? `Repartidor en vivo: ${courierLocation?.player}`
    : shipment.courierRobloxUsername
      ? `Esperando ubicacion de ${shipment.courierRobloxUsername}`
      : "Repartidor simulado";
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
          <span><i className="is-courier" /> Repartidor</span>
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
            left: `${Math.min(92, Math.max(6, courierPoint.x))}%`,
            top: `${Math.min(88, Math.max(10, courierPoint.y))}%`,
          }}
          title={courierStatus}
        >
          <span aria-hidden="true">🛵</span>
          <small>{liveCourierPoint ? liveCourierPoint.label : courierStatus}</small>
        </div>
      </div>
      <div className="gps-card__footer">
        <span>Creacion: 303</span>
        <span>{shipment.etaMinutes === 0 ? "Entregado" : `${shipment.etaMinutes} min`}</span>
        <span>{courierStatus}</span>
        <span>Destino: {shipment.destination}</span>
      </div>
    </section>
  );
}
