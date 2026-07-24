"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import {
  categories,
  createInitialMarketplaceState,
  type CategoryId,
  type ChatThread,
  type Listing,
  type MarketplaceState,
  type ProductVisual,
  type RatingSummaries,
  type UserProfile,
} from "../data/marketplace";
import { inferCategoryFromText, tagsFromQuery } from "./recommendations";

const STORAGE_KEY = "mercado-live-state-v5";
const CHANNEL_KEY = "mercado-live-realtime";
const EMPTY_RATINGS: RatingSummaries = { listings: {}, sellers: {} };

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
        rating: 0,
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
      users: parsed.users.map((user) => ({
        ...user,
        email: undefined,
        reputation: 0,
      })),
      searches: Array.isArray(parsed.searches) ? parsed.searches : [],
      listings: [...initial.listings, ...userListings],
      chats: [],
    };
  } catch {
    return null;
  }
}

function publicState(state: MarketplaceState): MarketplaceState {
  return {
    ...state,
    activeUserId: null,
    users: state.users.map((user) => ({ ...user, email: undefined })),
    chats: [],
  };
}

function withAuthenticatedUser(
  state: MarketplaceState,
  user: UserProfile | null,
): MarketplaceState {
  if (!user) {
    return state;
  }

  const existing = state.users.findIndex((candidate) => candidate.id === user.id);
  if (existing === -1) {
    return { ...state, users: [...state.users, user] };
  }

  return {
    ...state,
    users: state.users.map((candidate, index) =>
      index === existing ? { ...candidate, ...user } : candidate,
    ),
  };
}

function saveState(state: MarketplaceState) {
  if (typeof window === "undefined") {
    return;
  }

  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(publicState(state)));
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

const housingZones = [
  { label: "Vivienda 704", x: 21.4, y: 45.7 },
  { label: "Vivienda 405", x: 18.6, y: 60.4 },
  { label: "Vivienda 907", x: 57.4, y: 31.4 },
  { label: "Vivienda 1202", x: 84.2, y: 65.4 },
];

function destinationZoneFor(location: string) {
  const digits = location.match(/\d+/)?.[0] ?? "";
  if (digits.startsWith("4")) {
    return housingZones[1];
  }
  if (digits.startsWith("9")) {
    return housingZones[2];
  }
  if (digits.startsWith("12")) {
    return housingZones[3];
  }
  if (digits.startsWith("7") || digits.startsWith("8")) {
    return housingZones[0];
  }

  const seed = Array.from(location).reduce(
    (total, character) => total + character.charCodeAt(0),
    0,
  );
  return housingZones[seed % housingZones.length];
}

export function useMarketplaceStore() {
  const [state, setState] = useState<MarketplaceState>(() => createInitialMarketplaceState());
  const [sessionUser, setSessionUser] = useState<UserProfile | null>(null);
  const [authReady, setAuthReady] = useState(false);
  const [ratingSummaries, setRatingSummaries] =
    useState<RatingSummaries>(EMPTY_RATINGS);
  const channelRef = useRef<BroadcastChannel | null>(null);
  const clientId = useRef(createId("client"));
  const remoteVersionRef = useRef<string | null>(null);
  const sessionUserRef = useRef<UserProfile | null>(null);

  const pushRemote = useCallback(async (nextState: MarketplaceState) => {
    try {
      const response = await fetch("/api/realtime", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ state: publicState(nextState) }),
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
      state: publicState(nextState),
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

  const refreshRatings = useCallback(async () => {
    try {
      const response = await fetch("/api/reviews?summary=1", { cache: "no-store" });
      const result = await response.json() as RatingSummaries;
      if (!response.ok || !result.listings || !result.sellers) {
        return;
      }
      setRatingSummaries(result);
      setState((previous) => ({
        ...previous,
        listings: previous.listings.map((listing) => ({
          ...listing,
          rating: result.listings[listing.id]?.average ?? 0,
        })),
        users: previous.users.map((user) => ({
          ...user,
          reputation: result.sellers[user.id]?.average ?? 0,
        })),
      }));
    } catch {
      // Ratings stay at their last verified values while the service reconnects.
    }
  }, []);

  useEffect(() => {
    const initialTimer = window.setTimeout(() => void refreshRatings(), 0);
    const timer = window.setInterval(() => void refreshRatings(), 5000);
    return () => {
      window.clearTimeout(initialTimer);
      window.clearInterval(timer);
    };
  }, [refreshRatings]);

  useEffect(() => {
    const persisted = safeParseState(window.localStorage.getItem(STORAGE_KEY));
    if (!persisted) {
      saveState(state);
    }
    const hydrationTimer = window.setTimeout(() => {
      if (persisted) {
        setState((previous) => ({
          ...withAuthenticatedUser(persisted, sessionUserRef.current),
          chats: previous.chats,
        }));
      }
    }, 0);

    let authCancelled = false;
    async function restoreSession() {
      try {
        const response = await fetch("/api/auth", { cache: "no-store" });
        const result = await response.json() as { user?: UserProfile };
        if (!authCancelled && response.ok && result.user) {
          sessionUserRef.current = result.user;
          setSessionUser(result.user);
          setState((previous) => withAuthenticatedUser(previous, result.user ?? null));
        }
      } catch {
        // The login form remains available when the session service is unreachable.
      } finally {
        if (!authCancelled) {
          setAuthReady(true);
        }
      }
    }
    void restoreSession();

    if ("BroadcastChannel" in window) {
      channelRef.current = new BroadcastChannel(CHANNEL_KEY);
      channelRef.current.onmessage = (event: MessageEvent) => {
        if (event.data?.source === clientId.current) {
          return;
        }

        const incoming = event.data?.state as MarketplaceState | undefined;
        if (incoming?.users && incoming?.listings) {
          setState((previous) => ({
            ...withAuthenticatedUser(incoming, sessionUserRef.current),
            chats: previous.chats,
          }));
        }
      };
    }

    const onStorage = (event: StorageEvent) => {
      if (event.key !== STORAGE_KEY) {
        return;
      }

      const incoming = safeParseState(event.newValue);
      if (incoming) {
        setState((previous) => ({
          ...withAuthenticatedUser(incoming, sessionUserRef.current),
          chats: previous.chats,
        }));
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
        setState((previous) => ({
          ...withAuthenticatedUser(incoming, sessionUserRef.current),
          chats: previous.chats,
        }));
      } catch {
        // The local marketplace continues to work offline.
      }
    }

    void pullRemote();
    const remoteTimer = window.setInterval(() => void pullRemote(), 1800);

    return () => {
      cancelled = true;
      authCancelled = true;
      window.clearTimeout(hydrationTimer);
      window.clearInterval(remoteTimer);
      window.removeEventListener("storage", onStorage);
      channelRef.current?.close();
      channelRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (!sessionUser?.id) {
      return;
    }

    let cancelled = false;
    async function pullMessages() {
      try {
        const response = await fetch("/api/messages", { cache: "no-store" });
        const result = await response.json() as { threads?: ChatThread[] };
        if (!cancelled && response.ok && Array.isArray(result.threads)) {
          setState((previous) => ({ ...previous, chats: result.threads ?? [] }));
        }
      } catch {
        // Existing messages remain visible during a temporary network interruption.
      }
    }

    void pullMessages();
    const timer = window.setInterval(() => void pullMessages(), 1600);
    return () => {
      cancelled = true;
      window.clearInterval(timer);
    };
  }, [sessionUser?.id]);

  const activeUser = sessionUser;

  const authenticate = useCallback(
    async (
      action: "login" | "register",
      input: {
        email: string;
        password: string;
        name?: string;
        location?: string;
      },
    ) => {
      try {
        const response = await fetch("/api/auth", {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ action, ...input }),
        });
        const result = await response.json() as {
          user?: UserProfile;
          error?: string;
        };
        if (!response.ok || !result.user) {
          return result.error ?? "No se pudo completar el acceso";
        }

        sessionUserRef.current = result.user;
        setSessionUser(result.user);
        setAuthReady(true);
        commit((previous) => {
          const next = withAuthenticatedUser(previous, result.user ?? null);
          if (action !== "register") {
            return next;
          }
          return {
            ...next,
            notifications: [
              {
                id: createId("note"),
                text: `${result.user?.name ?? "Un usuario"} creó su cuenta`,
                createdAt: new Date().toISOString(),
              },
              ...next.notifications,
            ].slice(0, 8),
          };
        });
        return null;
      } catch {
        return "No se pudo conectar con el servicio de cuentas";
      }
    },
    [commit],
  );

  const login = useCallback(
    (input: { email: string; password: string }) =>
      authenticate("login", input),
    [authenticate],
  );

  const registerUser = useCallback(
    (input: {
      name: string;
      email: string;
      location: string;
      password: string;
    }) => authenticate("register", input),
    [authenticate],
  );

  const logout = useCallback(async () => {
    try {
      await fetch("/api/auth", { method: "DELETE" });
    } finally {
      const currentUserId = sessionUserRef.current?.id;
      sessionUserRef.current = null;
      setSessionUser(null);
      setState((previous) => ({
        ...previous,
        chats: [],
        users: previous.users.map((user) =>
          user.id === currentUserId ? { ...user, email: undefined } : user,
        ),
      }));
    }
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
        rating: 0,
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

  const deleteListing = useCallback(
    (listingId: string) => {
      if (!activeUser) {
        return false;
      }

      let removed = false;
      commit((previous) => {
        const listing = previous.listings.find((candidate) => candidate.id === listingId);
        if (
          !listing ||
          listing.source !== "user" ||
          listing.sellerId !== activeUser.id
        ) {
          return previous;
        }

        removed = true;
        return {
          ...previous,
          listings: previous.listings.filter((candidate) => candidate.id !== listingId),
          favorites: previous.favorites.filter((favorite) => favorite.listingId !== listingId),
          carts: previous.carts.filter((cart) => cart.listingId !== listingId),
          chats: previous.chats.filter((thread) => thread.listingId !== listingId),
          shipments: previous.shipments.filter((shipment) => shipment.listingId !== listingId),
          views: previous.views.filter((view) => view.listingId !== listingId),
          notifications: [
            {
              id: createId("note"),
              text: `${activeUser.name} elimino la publicacion: ${listing.title}`,
              createdAt: new Date().toISOString(),
            },
            ...previous.notifications,
          ].slice(0, 8),
        };
      });
      return removed;
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
        const destinationZone = destinationZoneFor(activeUser.location);
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
                { label: "Creacion", x: 49.5, y: 77.6 },
                { label: "Reparto / retiro", x: 47.8, y: 61.1 },
                { label: "En camino", x: (47.8 + destinationZone.x) / 2, y: (61.1 + destinationZone.y) / 2 },
                { label: destinationZone.label, x: destinationZone.x, y: destinationZone.y },
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
    async (listing: Listing, body: string, threadId?: string) => {
      if (!activeUser || !body.trim()) {
        return "Escribí un mensaje antes de enviarlo";
      }

      try {
        const response = await fetch("/api/messages", {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({
            listingId: listing.id,
            threadId,
            body: body.trim(),
          }),
        });
        const result = await response.json() as {
          thread?: ChatThread;
          error?: string;
        };
        if (!response.ok || !result.thread) {
          return result.error ?? "No se pudo enviar el mensaje";
        }

        setState((previous) => ({
          ...previous,
          chats: previous.chats.some((thread) => thread.id === result.thread?.id)
            ? previous.chats
                .map((thread) =>
                  thread.id === result.thread?.id ? result.thread : thread,
                )
                .filter((thread): thread is ChatThread => Boolean(thread))
            : [result.thread, ...previous.chats],
        }));
        return null;
      } catch {
        return "No se pudo conectar con Mensajes";
      }
    },
    [activeUser],
  );

  const markThreadRead = useCallback(
    (threadId: string) => {
      if (!activeUser) {
        return;
      }
      setState((previous) => ({
        ...previous,
        chats: previous.chats.map((thread) =>
          thread.id === threadId
            ? {
                ...thread,
                messages: thread.messages.map((message) =>
                  message.senderId === activeUser.id
                    ? message
                    : { ...message, read: true },
                ),
              }
            : thread,
        ),
      }));
      void fetch("/api/messages", {
        method: "PATCH",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ threadId }),
      });
    },
    [activeUser],
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
    const fresh = withAuthenticatedUser(
      createInitialMarketplaceState(),
      sessionUserRef.current,
    );
    setState(fresh);
    broadcast(fresh);
  }, [broadcast]);

  return {
    state,
    activeUser,
    authReady,
    ratingSummaries,
    actions: {
      login,
      registerUser,
      logout,
      recordSearch,
      recordView,
      publishListing,
      deleteListing,
      buyListing,
      sendMessage,
      markThreadRead,
      refreshRatings,
      advanceShipments,
      resetDemo,
    },
  };
}
