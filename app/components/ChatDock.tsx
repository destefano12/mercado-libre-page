"use client";

import { useEffect, useMemo, useState } from "react";
import type { ChatThread, Listing, UserProfile } from "../data/marketplace";

interface ChatDockProps {
  listing: Listing;
  thread?: ChatThread;
  activeUser: UserProfile;
  users: UserProfile[];
  onSend: (
    listing: Listing,
    body: string,
    threadId?: string,
  ) => Promise<string | null>;
  onRead: (threadId: string) => void;
  onClose: () => void;
}

function messageTime(value: string) {
  return new Intl.DateTimeFormat("es-AR", {
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value));
}

export function ChatDock({
  listing,
  thread,
  activeUser,
  users,
  onSend,
  onRead,
  onClose,
}: ChatDockProps) {
  const [draft, setDraft] = useState("");
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const seller = users.find((user) => user.id === listing.sellerId);
  const messages = thread?.messages ?? [];
  const counterpart = useMemo(() => {
    if (!thread) {
      return seller;
    }

    const otherId = [thread.buyerId, thread.sellerId].find(
      (id) => id !== activeUser.id,
    );
    return users.find((user) => user.id === otherId) ?? seller;
  }, [activeUser.id, seller, thread, users]);

  useEffect(() => {
    if (thread?.id) {
      onRead(thread.id);
    }
  }, [onRead, thread?.id, thread?.lastMessageAt]);

  return (
    <aside className="chat-dock" aria-label="Conversación">
      <div className="chat-dock__header">
        <div>
          <span>Mensajes</span>
          <h3>{counterpart?.name ?? "Vendedor"}</h3>
        </div>
        <button type="button" onClick={onClose} aria-label="Cerrar chat">
          ×
        </button>
      </div>
      <p className="chat-dock__product">{listing.title}</p>
      <div className="chat-dock__messages" aria-live="polite">
        {messages.length === 0 ? (
          <div className="chat-dock__empty">
            Escribile al vendedor para consultar por esta publicación.
          </div>
        ) : (
          messages.map((message) => {
            const mine = message.senderId === activeUser.id;
            const sender = users.find((user) => user.id === message.senderId);

            return (
              <div
                className={`chat-message ${mine ? "chat-message--mine" : ""}`}
                key={message.id}
              >
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
        onSubmit={async (event) => {
          event.preventDefault();
          if (!draft.trim() || sending) {
            return;
          }

          setSending(true);
          setError(null);
          const nextError = await onSend(listing, draft, thread?.id);
          setSending(false);
          if (nextError) {
            setError(nextError);
            return;
          }
          setDraft("");
        }}
      >
        {error ? <p className="chat-dock__error" role="alert">{error}</p> : null}
        <input
          value={draft}
          onChange={(event) => setDraft(event.target.value)}
          placeholder="Escribí un mensaje..."
          aria-label="Mensaje"
          maxLength={2000}
        />
        <button type="submit" disabled={!draft.trim() || sending}>
          {sending ? "Enviando..." : "Enviar"}
        </button>
      </form>
    </aside>
  );
}
