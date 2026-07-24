"use client";

import type { Shipment } from "../data/marketplace";

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
        <div className="gps-map__grid" />
        <div className="gps-map__route" />
        {shipment.route.map((point) => (
          <div
            className="gps-map__pin"
            key={point.label}
            style={{ left: `${point.x}%`, top: `${point.y}%` }}
          >
            <span>{point.label}</span>
          </div>
        ))}
        <div
          className="gps-map__vehicle"
          style={{
            left: `${Math.min(88, Math.max(9, activePoint.x + (shipment.progress % 22) / 6))}%`,
            top: `${Math.min(72, Math.max(22, activePoint.y - (shipment.progress % 18) / 8))}%`,
          }}
        />
      </div>
      <div className="gps-card__footer">
        <span>{shipment.origin}</span>
        <span>{shipment.etaMinutes === 0 ? "Entregado" : `${shipment.etaMinutes} min`}</span>
        <span>{shipment.destination}</span>
      </div>
    </section>
  );
}
