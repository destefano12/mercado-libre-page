"use client";

import { useMemo, useState } from "react";
import type { ChatThread, Listing, UserProfile } from "../data/marketplace";

interface ChatDockProps {
  listing: Listing;
  thread?: ChatThread;
  activeUser: UserProfile;
  users: UserProfile[];
  onSend: (listing: Listing, body: string) => void;
  onClose: () => void;
}

function messageTime(value: string) {
  return new Intl.DateTimeFormat("es-AR", {
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value));
}

export function ChatDock({ listing, thread, activeUser, users, onSend, onClose }: ChatDockProps) {
  const [draft, setDraft] = useState("");
  const seller = users.find((user) => user.id === listing.sellerId);
  const messages = thread?.messages ?? [];
  const counterpart = useMemo(() => {
    if (!thread) {
      return seller;
    }

    const otherId = [thread.buyerId, thread.sellerId].find((id) => id !== activeUser.id);
    return users.find((user) => user.id === otherId) ?? seller;
  }, [activeUser.id, seller, thread, users]);

  return (
    <aside className="chat-dock" aria-label="Chat interno">
      <div className="chat-dock__header">
        <div>
          <span>Chat en tiempo real</span>
          <h3>{counterpart?.name ?? "Vendedor"}</h3>
        </div>
        <button type="button" onClick={onClose} aria-label="Cerrar chat">
          x
        </button>
      </div>
      <p className="chat-dock__product">{listing.title}</p>
      <div className="chat-dock__messages">
        {messages.length === 0 ? (
          <div className="chat-dock__empty">
            Escribi para consultar disponibilidad, envio o detalles.
          </div>
        ) : (
          messages.map((message) => {
            const mine = message.senderId === activeUser.id;
            const sender = users.find((user) => user.id === message.senderId);

            return (
              <div className={`chat-message ${mine ? "chat-message--mine" : ""}`} key={message.id}>
                <p>{message.body}</p>
                <span>
                  {sender?.name ?? "Usuario"} · {messageTime(message.createdAt)}
                </span>
              </div>
            );
          })
        )}
      </div>
      <form
        className="chat-dock__form"
        onSubmit={(event) => {
          event.preventDefault();
          onSend(listing, draft);
          setDraft("");
        }}
      >
        <input
          value={draft}
          onChange={(event) => setDraft(event.target.value)}
          placeholder="Escribi un mensaje..."
          aria-label="Mensaje"
        />
        <button type="submit">Enviar</button>
      </form>
    </aside>
  );
}
