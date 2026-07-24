"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  categories,
  createInitialMarketplaceState,
  type CategoryId,
  type ChatMessage,
  type Listing,
  type MarketplaceState,
  type ProductVisual,
  type UserProfile,
} from "../data/marketplace";
import { inferCategoryFromText, tagsFromQuery } from "./recommendations";

const STORAGE_KEY = "mercado-live-state-v5";
const CHANNEL_KEY = "mercado-live-realtime";
const SESSION_KEY = "mercado-live-session-user";

export interface PublishListingInput {
  title: string;
  description: string;
  categoryId: CategoryId;
  price: number;
  condition: "Nuevo" | "Usado" | "Digital";
  location: string;
  shipping: string;
  meta: Record<string, string | number>;
  tags: string[];
  images: string[];
}

function createId(prefix: string) {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
    return `${prefix}-${crypto.randomUUID().slice(0, 8)}`;
  }

  return `${prefix}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
}

function safeParseState(value: string | null): MarketplaceState | null {
  if (!value) {
    return null;
  }

  try {
    const parsed = JSON.parse(value) as MarketplaceState;
    if (!Array.isArray(parsed.users) || !Array.isArray(parsed.listings)) {
      return null;
    }

    const initial = createInitialMarketplaceState();
    const userListings = parsed.listings
      .filter((listing) => listing.source === "user")
      .map((listing) => ({
        ...listing,
        source: "user" as const,
        images: Array.isArray(listing.images)
          ? listing.images
          : listing.visual.type === "image"
            ? [listing.visual.src]
            : [],
      }));

    return {
      ...initial,
      ...parsed,
      activeUserId: null,
      searches: Array.isArray(parsed.searches) ? parsed.searches : [],
      listings: [...initial.listings, ...userListings],
    };
  } catch {
    return null;
  }
}

function saveState(state: MarketplaceState) {
  if (typeof window === "undefined") {
    return;
  }

  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

function makeVisual(categoryId: CategoryId, title: string): ProductVisual {
  const config = categories.find((category) => category.id === categoryId);
  const label =
    title
      .split(" ")
      .filter(Boolean)
      .slice(0, 2)
      .join(" ")
      .slice(0, 14) || "Nuevo";

  return {
    type: "generated",
    gradient: config?.accent ?? "#3483fa",
    label,
  };
}

function getShipmentStatus(progress: number) {
  if (progress >= 100) {
    return "Entregado en destino";
  }

  if (progress >= 72) {
    return "El repartidor esta cerca";
  }

  if (progress >= 45) {
    return "En reparto por tu zona";
  }

  if (progress >= 20) {
    return "En camino al centro de distribucion";
  }

  return "Preparando paquete";
}

export function useMarketplaceStore() {
  const [state, setState] = useState<MarketplaceState>(() => createInitialMarketplaceState());
  const [sessionUserId, setSessionUserId] = useState<string | null>(null);
  const channelRef = useRef<BroadcastChannel | null>(null);
  const clientId = useRef(createId("client"));
  const remoteVersionRef = useRef<string | null>(null);

  const pushRemote = useCallback(async (nextState: MarketplaceState) => {
    try {
      const response = await fetch("/api/realtime", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ state: { ...nextState, activeUserId: null } }),
      });
      const result = await response.json() as { updatedAt?: string };
      if (response.ok && result.updatedAt) {
        remoteVersionRef.current = result.updatedAt;
      }
    } catch {
      // Local state remains available when the online service is unreachable.
    }
  }, []);

  const broadcast = useCallback((nextState: MarketplaceState) => {
    saveState(nextState);
    channelRef.current?.postMessage({
      source: clientId.current,
      state: nextState,
    });
    void pushRemote(nextState);
  }, [pushRemote]);

  const commit = useCallback(
    (producer: (previous: MarketplaceState) => MarketplaceState) => {
      setState((previous) => {
        const nextState = producer(previous);
        broadcast(nextState);
        return nextState;
      });
    },
    [broadcast],
  );

  useEffect(() => {
    const persisted = safeParseState(window.localStorage.getItem(STORAGE_KEY));
    if (!persisted) {
      saveState(state);
    }
    const hydrationTimer = window.setTimeout(() => {
      if (persisted) {
        setState(persisted);
      }
      setSessionUserId(window.sessionStorage.getItem(SESSION_KEY));
    }, 0);

    if ("BroadcastChannel" in window) {
      channelRef.current = new BroadcastChannel(CHANNEL_KEY);
      channelRef.current.onmessage = (event: MessageEvent) => {
        if (event.data?.source === clientId.current) {
          return;
        }

        const incoming = event.data?.state as MarketplaceState | undefined;
        if (incoming?.users && incoming?.listings) {
          setState(incoming);
        }
      };
    }

    const onStorage = (event: StorageEvent) => {
      if (event.key !== STORAGE_KEY) {
        return;
      }

      const incoming = safeParseState(event.newValue);
      if (incoming) {
        setState(incoming);
      }
    };

    window.addEventListener("storage", onStorage);

    let cancelled = false;
    async function pullRemote() {
      try {
        const response = await fetch("/api/realtime", { cache: "no-store" });
        const result = await response.json() as {
          state?: MarketplaceState | null;
          updatedAt?: string | null;
        };
        if (
          cancelled ||
          !response.ok ||
          !result.state ||
          !result.updatedAt ||
          result.updatedAt === remoteVersionRef.current
        ) {
          return;
        }

        const incoming = safeParseState(JSON.stringify(result.state));
        if (!incoming) {
          return;
        }

        remoteVersionRef.current = result.updatedAt;
        saveState(incoming);
        setState(incoming);
      } catch {
        // The local marketplace continues to work offline.
      }
    }

    void pullRemote();
    const remoteTimer = window.setInterval(() => void pullRemote(), 1800);

    return () => {
      cancelled = true;
      window.clearTimeout(hydrationTimer);
      window.clearInterval(remoteTimer);
      window.removeEventListener("storage", onStorage);
      channelRef.current?.close();
      channelRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const activeUser = useMemo(
    () => state.users.find((user) => user.id === sessionUserId && !user.isSystem),
    [sessionUserId, state.users],
  );

  const loginAs = useCallback(
    (userId: string) => {
      if (!state.users.some((user) => user.id === userId && !user.isSystem)) {
        return;
      }
      window.sessionStorage.setItem(SESSION_KEY, userId);
      setSessionUserId(userId);
    },
    [state.users],
  );

  const registerUser = useCallback(
    (input: { name: string; email: string; location: string }) => {
      const initials = input.name
        .split(" ")
        .map((part) => part[0])
        .join("")
        .slice(0, 2)
        .toUpperCase();
      const user: UserProfile = {
        id: createId("u"),
        name: input.name.trim(),
        email: input.email.trim().toLowerCase(),
        location: input.location.trim(),
        avatar: initials || "US",
        reputation: 4.5,
        joinedAt: new Date().toISOString(),
      };

      const existingUser = state.users.find((candidate) => candidate.email === user.email);
      const nextUserId = existingUser?.id ?? user.id;

      commit((previous) => ({
        ...previous,
        users: previous.users.some((candidate) => candidate.email === user.email)
          ? previous.users
          : [...previous.users, user],
        activeUserId: null,
        notifications: [
          {
            id: createId("note"),
            text: `${user.name} creo su cuenta`,
            createdAt: new Date().toISOString(),
          },
          ...previous.notifications,
        ].slice(0, 8),
      }));
      window.sessionStorage.setItem(SESSION_KEY, nextUserId);
      setSessionUserId(nextUserId);
    },
    [commit, state.users],
  );

  const logout = useCallback(() => {
    window.sessionStorage.removeItem(SESSION_KEY);
    setSessionUserId(null);
  }, []);

  const recordSearch = useCallback(
    (query: string) => {
      if (!activeUser || !query.trim()) {
        return;
      }

      const tags = tagsFromQuery(query);
      const categoryId = inferCategoryFromText(query);
      commit((previous) => ({
        ...previous,
        searches: [
          {
            id: createId("search"),
            userId: activeUser.id,
            query: query.trim(),
            categoryId,
            tags,
            searchedAt: new Date().toISOString(),
          },
          ...previous.searches,
        ].slice(0, 80),
      }));
    },
    [activeUser, commit],
  );

  const recordView = useCallback(
    (listingId: string) => {
      if (!activeUser) {
        return;
      }

      commit((previous) => {
        const listing = previous.listings.find((candidate) => candidate.id === listingId);
        if (!listing) {
          return previous;
        }

        const nextView = {
          id: createId("view"),
          userId: activeUser.id,
          listingId,
          categoryId: listing.categoryId,
          tags: listing.tags,
          viewedAt: new Date().toISOString(),
        };

        return {
          ...previous,
          views: [nextView, ...previous.views].slice(0, 80),
          listings: previous.listings.map((candidate) =>
            candidate.id === listingId
              ? { ...candidate, views: candidate.views + 1 }
              : candidate,
          ),
        };
      });
    },
    [activeUser, commit],
  );

  const publishListing = useCallback(
    (input: PublishListingInput) => {
      if (!activeUser) {
        return;
      }

      const listing: Listing = {
        id: createId("prod"),
        title: input.title.trim(),
        description: input.description.trim(),
        categoryId: input.categoryId,
        sellerId: activeUser.id,
        price: input.price,
        currency: "ARS",
        condition: input.condition,
        location: input.location.trim() || activeUser.location,
        shipping: input.shipping.trim() || "A coordinar",
        createdAt: new Date().toISOString(),
        views: 0,
        sold: 0,
        rating: activeUser.reputation,
        tags: input.tags,
        meta: input.meta,
        badge: "Nuevo online",
        source: "user",
        visual: input.images[0]
          ? {
              type: "image",
              src: input.images[0],
              alt: input.title.trim(),
              objectPosition: "center",
            }
          : makeVisual(input.categoryId, input.title),
        images: input.images,
      };

      commit((previous) => ({
        ...previous,
        listings: [listing, ...previous.listings],
        notifications: [
          {
            id: createId("note"),
            text: `${activeUser.name} publico online: ${listing.title}`,
            createdAt: new Date().toISOString(),
          },
          ...previous.notifications,
        ].slice(0, 8),
      }));

      return listing.id;
    },
    [activeUser, commit],
  );

  const buyListing = useCallback(
    (listing: Listing) => {
      if (!activeUser || listing.sellerId === activeUser.id) {
        return;
      }

      commit((previous) => {
        const existing = previous.shipments.find(
          (shipment) => shipment.listingId === listing.id && shipment.buyerId === activeUser.id,
        );
        if (existing) {
          return previous;
        }

        const digital = listing.condition === "Digital";
        const now = new Date().toISOString();
        return {
          ...previous,
          listings: previous.listings.map((candidate) =>
            candidate.id === listing.id ? { ...candidate, sold: candidate.sold + 1 } : candidate,
          ),
          shipments: [
            {
              id: createId("ship"),
              listingId: listing.id,
              buyerId: activeUser.id,
              origin: listing.location,
              destination: digital ? "Entrega online" : activeUser.location,
              status: digital ? "Acceso digital confirmado" : "Preparando paquete",
              progress: digital ? 100 : 8,
              etaMinutes: digital ? 0 : 72,
              route: [
                { label: "Origen", x: 10, y: 70 },
                { label: "Centro", x: 34, y: 42 },
                { label: "Reparto", x: 62, y: 55 },
                { label: "Destino", x: 88, y: 24 },
              ],
            },
            ...previous.shipments,
          ],
          notifications: [
            {
              id: createId("note"),
              text: `${activeUser.name} compro ${listing.title}`,
              createdAt: now,
            },
            ...previous.notifications,
          ].slice(0, 8),
        };
      });
    },
    [activeUser, commit],
  );

  const sendMessage = useCallback(
    (listing: Listing, body: string) => {
      if (!activeUser || !body.trim()) {
        return;
      }

      const seller = state.users.find((user) => user.id === listing.sellerId);
      const counterpart =
        listing.sellerId === activeUser.id
          ? state.users.find((user) => user.id !== activeUser.id && !user.isSystem)
          : seller;

      if (!counterpart) {
        return;
      }

      const buyerId = listing.sellerId === activeUser.id ? counterpart.id : activeUser.id;
      const sellerId = listing.sellerId;
      const threadId = `chat-${listing.id}-${buyerId}-${sellerId}`;
      const now = new Date().toISOString();
      const message: ChatMessage = {
        id: createId("msg"),
        threadId,
        senderId: activeUser.id,
        body: body.trim(),
        createdAt: now,
        read: true,
      };

      commit((previous) => {
        const existing = previous.chats.find((thread) => thread.id === threadId);
        const chats = existing
          ? previous.chats.map((thread) =>
              thread.id === threadId
                ? {
                    ...thread,
                    messages: [...thread.messages, message],
                    lastMessageAt: now,
                  }
                : thread,
            )
          : [
              {
                id: threadId,
                listingId: listing.id,
                buyerId,
                sellerId,
                messages: [message],
                lastMessageAt: now,
              },
              ...previous.chats,
            ];

        return {
          ...previous,
          chats,
          notifications: [
            {
              id: createId("note"),
              text: `Nuevo mensaje en ${listing.title}`,
              createdAt: now,
            },
            ...previous.notifications,
          ].slice(0, 8),
        };
      });

      if (!counterpart.isSystem) {
        return;
      }

      window.setTimeout(() => {
        const replyNow = new Date().toISOString();
        const reply: ChatMessage = {
          id: createId("msg"),
          threadId,
          senderId: counterpart.id,
          body:
            listing.condition === "Digital"
              ? "Te confirmo disponibilidad. Puedo entregar el acceso ahora mismo."
              : "Si, sigue disponible. Puedo coordinar entrega o retiro y responder dudas.",
          createdAt: replyNow,
          read: false,
        };

        commit((previous) => ({
          ...previous,
          chats: previous.chats.map((thread) =>
            thread.id === threadId
              ? {
                  ...thread,
                  messages: [...thread.messages, reply],
                  lastMessageAt: replyNow,
                }
              : thread,
          ),
          notifications: [
            {
              id: createId("note"),
              text: `${counterpart.name} respondio el chat`,
              createdAt: replyNow,
            },
            ...previous.notifications,
          ].slice(0, 8),
        }));
      }, 900);
    },
    [activeUser, commit, state.users],
  );

  const advanceShipments = useCallback(() => {
    setState((previous) => {
      const next = {
        ...previous,
        shipments: previous.shipments.map((shipment) => {
          if (shipment.progress >= 100) {
            return shipment;
          }

          const nextProgress = Math.min(100, shipment.progress + 3);
          return {
            ...shipment,
            progress: nextProgress,
            etaMinutes: Math.max(0, shipment.etaMinutes - 2),
            status: getShipmentStatus(nextProgress),
          };
        }),
      };
      saveState(next);
      return next;
    });
  }, []);

  const resetDemo = useCallback(() => {
    const fresh = createInitialMarketplaceState();
    window.sessionStorage.removeItem(SESSION_KEY);
    setSessionUserId(null);
    setState(fresh);
    broadcast(fresh);
  }, [broadcast]);

  return {
    state,
    activeUser,
    actions: {
      loginAs,
      registerUser,
      logout,
      recordSearch,
      recordView,
      publishListing,
      buyListing,
      sendMessage,
      advanceShipments,
      resetDemo,
    },
  };
}
