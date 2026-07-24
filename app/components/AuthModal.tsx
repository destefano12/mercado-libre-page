"use client";

import { useState } from "react";

interface LoginInput {
  email: string;
  password: string;
}

interface RegisterInput extends LoginInput {
  name: string;
  location: string;
}

interface AuthModalProps {
  onLogin: (input: LoginInput) => Promise<string | null>;
  onRegister: (input: RegisterInput) => Promise<string | null>;
  onClose?: () => void;
  blocking?: boolean;
}

export function AuthModal({
  onLogin,
  onRegister,
  onClose,
  blocking,
}: AuthModalProps) {
  const [mode, setMode] = useState<"login" | "register">("login");
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [location, setLocation] = useState("7043");
  const [password, setPassword] = useState("");
  const [passwordConfirmation, setPasswordConfirmation] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  function changeMode(nextMode: "login" | "register") {
    setMode(nextMode);
    setError(null);
    setPassword("");
    setPasswordConfirmation("");
  }

  return (
    <div
      className={`modal-layer ${blocking ? "modal-layer--blocking" : ""}`}
      role="dialog"
      aria-modal="true"
      aria-label="Acceso a tu cuenta"
    >
      <div className="modal-card auth-modal">
        <div className="modal-card__header">
          <div>
            <span>Tu cuenta</span>
            <h2>{mode === "login" ? "Ingresá" : "Creá tu cuenta"}</h2>
          </div>
          {onClose ? (
            <button type="button" onClick={onClose} aria-label="Cerrar">
              ×
            </button>
          ) : null}
        </div>

        <div className="auth-modal__tabs" role="tablist" aria-label="Tipo de acceso">
          <button
            className={mode === "login" ? "is-active" : ""}
            type="button"
            role="tab"
            aria-selected={mode === "login"}
            onClick={() => changeMode("login")}
          >
            Ingresar
          </button>
          <button
            className={mode === "register" ? "is-active" : ""}
            type="button"
            role="tab"
            aria-selected={mode === "register"}
            onClick={() => changeMode("register")}
          >
            Crear cuenta
          </button>
        </div>

        <p className="auth-modal__intro">
          {mode === "login"
            ? "Usá el email y la contraseña de tu cuenta."
            : "Tus datos de acceso son privados y no se muestran a otros usuarios."}
        </p>

        <form
          className="auth-modal__form"
          onSubmit={async (event) => {
            event.preventDefault();
            setError(null);

            if (password.length < 8) {
              setError("La contraseña debe tener al menos 8 caracteres.");
              return;
            }
            if (mode === "register" && password !== passwordConfirmation) {
              setError("Las contraseñas no coinciden.");
              return;
            }

            setBusy(true);
            const nextError = mode === "login"
              ? await onLogin({ email, password })
              : await onRegister({ name, email, location, password });
            setBusy(false);

            if (nextError) {
              setError(nextError);
              return;
            }
            onClose?.();
          }}
        >
          {mode === "register" ? (
            <label>
              Nombre y apellido
              <input
                value={name}
                onChange={(event) => setName(event.target.value)}
                placeholder="Como figura en tu documento"
                autoComplete="name"
                required
              />
            </label>
          ) : null}

          <label>
            Email
            <input
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              placeholder="nombre@correo.com"
              type="email"
              autoComplete="email"
              required
            />
          </label>

          {mode === "register" ? (
            <label>
              Ubicación / número de casa
              <input
                value={location}
                onChange={(event) => setLocation(event.target.value)}
                placeholder="Ej.: 7043, 9072, 12021"
                autoComplete="street-address"
                required
              />
            </label>
          ) : null}

          <label>
            Contraseña
            <input
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              placeholder="Mínimo 8 caracteres"
              type="password"
              autoComplete={mode === "login" ? "current-password" : "new-password"}
              minLength={8}
              required
            />
          </label>

          {mode === "register" ? (
            <label>
              Repetí la contraseña
              <input
                value={passwordConfirmation}
                onChange={(event) => setPasswordConfirmation(event.target.value)}
                placeholder="Volvé a escribirla"
                type="password"
                autoComplete="new-password"
                minLength={8}
                required
              />
            </label>
          ) : null}

          {error ? <p className="auth-modal__error" role="alert">{error}</p> : null}

          <button type="submit" disabled={busy}>
            {busy
              ? "Procesando..."
              : mode === "login"
                ? "Ingresar"
                : "Crear cuenta"}
          </button>
        </form>
      </div>
    </div>
  );
}
