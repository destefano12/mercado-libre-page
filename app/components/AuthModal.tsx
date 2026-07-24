"use client";

import { useState } from "react";
import type { UserProfile } from "../data/marketplace";

interface AuthModalProps {
  users: UserProfile[];
  onLogin: (userId: string) => void;
  onRegister: (input: { name: string; email: string; location: string }) => void;
  onClose: () => void;
}

export function AuthModal({ users, onLogin, onRegister, onClose }: AuthModalProps) {
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [location, setLocation] = useState("Buenos Aires 1772");

  return (
    <div className="modal-layer" role="dialog" aria-modal="true" aria-label="Usuarios">
      <div className="modal-card auth-modal">
        <div className="modal-card__header">
          <div>
            <span>Multiusuario</span>
            <h2>Elegir o crear cuenta</h2>
          </div>
          <button type="button" onClick={onClose} aria-label="Cerrar">
            x
          </button>
        </div>

        <div className="auth-modal__users">
          {users.map((user) => (
            <button
              className="auth-modal__user"
              key={user.id}
              type="button"
              onClick={() => {
                onLogin(user.id);
                onClose();
              }}
            >
              <span>{user.avatar}</span>
              <strong>{user.name}</strong>
              <small>{user.location}</small>
            </button>
          ))}
        </div>

        <form
          className="auth-modal__form"
          onSubmit={(event) => {
            event.preventDefault();
            if (!name.trim() || !email.trim()) {
              return;
            }

            onRegister({ name, email, location });
            onClose();
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
