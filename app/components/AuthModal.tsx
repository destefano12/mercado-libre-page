"use client";

import { useState } from "react";
import type { UserProfile } from "../data/marketplace";

interface AuthModalProps {
  users: UserProfile[];
  onLogin: (userId: string) => void;
  onRegister: (input: { name: string; email: string; location: string }) => void;
  onClose?: () => void;
  blocking?: boolean;
}

export function AuthModal({ users, onLogin, onRegister, onClose, blocking }: AuthModalProps) {
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [location, setLocation] = useState("Buenos Aires 1772");
  const loginUsers = users.filter((user) => !user.isSystem);

  return (
    <div
      className={`modal-layer ${blocking ? "modal-layer--blocking" : ""}`}
      role="dialog"
      aria-modal="true"
      aria-label="Usuarios"
    >
      <div className="modal-card auth-modal">
        <div className="modal-card__header">
          <div>
            <span>Cuenta propia</span>
            <h2>Inicia sesion o registrate</h2>
          </div>
          {onClose ? (
            <button type="button" onClick={onClose} aria-label="Cerrar">
              x
            </button>
          ) : null}
        </div>

        {loginUsers.length > 0 ? (
          <div className="auth-modal__users">
            {loginUsers.map((user) => (
              <button
                className="auth-modal__user"
                key={user.id}
                type="button"
                onClick={() => {
                  onLogin(user.id);
                  onClose?.();
                }}
              >
                <span>{user.avatar}</span>
                <strong>{user.name}</strong>
                <small>{user.location}</small>
              </button>
            ))}
          </div>
        ) : (
          <p className="auth-modal__empty">
            Todavia no hay cuentas creadas en este navegador. Crea la primera para empezar.
          </p>
        )}

        <form
          className="auth-modal__form"
          onSubmit={(event) => {
            event.preventDefault();
            if (!name.trim() || !email.trim()) {
              return;
            }

            onRegister({ name, email, location });
            onClose?.();
          }}
        >
          <label>
            Nombre
            <input value={name} onChange={(event) => setName(event.target.value)} placeholder="Tu nombre" />
          </label>
          <label>
            Email
            <input
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              placeholder="nombre@demo.local"
              type="email"
            />
          </label>
          <label>
            Ubicacion
            <input
              value={location}
              onChange={(event) => setLocation(event.target.value)}
              placeholder="Ciudad o direccion"
            />
          </label>
          <button type="submit">Crear cuenta y entrar</button>
        </form>
      </div>
    </div>
  );
}
