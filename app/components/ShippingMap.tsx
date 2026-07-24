"use client";

import type { CSSProperties } from "react";
import type { Shipment } from "../data/marketplace";
import erlcDeliveryMap from "@/IMG/official/erlc-delivery-map.jpg";

interface ShippingMapProps {
  shipment?: Shipment;
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

  const pointIndex = Math.min(
    shipment.route.length - 1,
    Math.floor((shipment.progress / 100) * shipment.route.length),
  );
  const activePoint = shipment.route[pointIndex] ?? shipment.route[0];
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
          <span><i className="is-origin" /> Creacion 3031</span>
          <span><i className="is-hub" /> Reparto / retiro 308</span>
          <span><i className="is-home" /> Viviendas</span>
        </div>
        <div
          className="gps-map__route"
          style={{ "--route-progress": `${routeProgress}%` } as CSSProperties}
        />
        {shipment.route.map((point, index) => (
          <div
            className={`gps-map__pin gps-map__pin--${index === 0 ? "origin" : index === 1 ? "hub" : index === shipment.route.length - 1 ? "home" : "transit"}`}
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
        <span>Creacion: 3031</span>
        <span>{shipment.etaMinutes === 0 ? "Entregado" : `${shipment.etaMinutes} min`}</span>
        <span>Destino: {shipment.destination}</span>
      </div>
    </section>
  );
}
