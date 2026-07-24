"use client";

import type {
  ChatThread,
  Listing,
  UserProfile,
} from "../data/marketplace";
import { ListingVisual } from "./ProductCard";

interface MessagesViewProps {
  activeUser: UserProfile;
  threads: ChatThread[];
  listings: Listing[];
  users: UserProfile[];
  onHome: () => void;
  onOpen: (thread: ChatThread, listing: Listing) => void;
}

function messageDate(value: string) {
  return new Intl.DateTimeFormat("es-AR", {
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value));
}

export function MessagesView({
  activeUser,
  threads,
  listings,
  users,
  onHome,
  onOpen,
}: MessagesViewProps) {
  return (
    <section className="messages-page">
      <div className="breadcrumb">
        <button type="button" onClick={onHome}>Inicio</button>
        <span>›</span>
        <span>Mensajes</span>
      </div>

      <div className="messages-page__heading">
        <h1>Mensajes</h1>
        <p>Conversaciones de tus compras y publicaciones.</p>
      </div>

      {threads.length > 0 ? (
        <div className="message-thread-list">
          {threads.map((thread) => {
            const listing = listings.find(
              (candidate) => candidate.id === thread.listingId,
            );
            if (!listing) {
              return null;
            }
            const counterpartId = thread.buyerId === activeUser.id
              ? thread.sellerId
              : thread.buyerId;
            const counterpart = users.find((user) => user.id === counterpartId);
            const lastMessage = thread.messages.at(-1);
            const unread = thread.messages.filter(
              (message) => message.senderId !== activeUser.id && !message.read,
            ).length;

            return (
              <button
                className={`message-thread ${unread ? "message-thread--unread" : ""}`}
                key={thread.id}
                type="button"
                onClick={() => onOpen(thread, listing)}
              >
                <ListingVisual visual={listing.visual} />
                <span className="message-thread__avatar">
                  {counterpart?.avatar ?? "US"}
                </span>
                <span className="message-thread__body">
                  <span>
                    <strong>{counterpart?.name ?? "Usuario"}</strong>
                    <time dateTime={thread.lastMessageAt}>
                      {messageDate(thread.lastMessageAt)}
                    </time>
                  </span>
                  <b>{listing.title}</b>
                  <small>{lastMessage?.body ?? "Conversación iniciada"}</small>
                </span>
                {unread ? (
                  <span className="message-thread__unread" aria-label={`${unread} sin leer`}>
                    {unread}
                  </span>
                ) : null}
              </button>
            );
          })}
        </div>
      ) : (
        <div className="messages-empty">
          <span className="messages-empty__icon" />
          <h2>Todavía no tenés mensajes</h2>
          <p>Cuando consultes una publicación o te escriba un comprador, aparecerá acá.</p>
          <button type="button" onClick={onHome}>Volver al inicio</button>
        </div>
      )}
    </section>
  );
}
