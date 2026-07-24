import { sql } from "drizzle-orm";
import {
  index,
  integer,
  real,
  sqliteTable,
  text,
  uniqueIndex,
} from "drizzle-orm/sqlite-core";

export const users = sqliteTable(
  "users",
  {
    id: text("id").primaryKey(),
    name: text("name").notNull(),
    email: text("email").notNull().unique(),
    location: text("location").notNull(),
    avatar: text("avatar").notNull(),
    reputation: real("reputation").notNull().default(4.8),
    createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
  },
  (table) => ({
    emailIdx: index("users_email_idx").on(table.email),
  }),
);

export const categories = sqliteTable("categories", {
  id: text("id").primaryKey(),
  label: text("label").notNull(),
  layout: text("layout").notNull(),
  configJson: text("config_json").notNull(),
});

export const listings = sqliteTable(
  "listings",
  {
    id: text("id").primaryKey(),
    sellerId: text("seller_id")
      .notNull()
      .references(() => users.id),
    categoryId: text("category_id")
      .notNull()
      .references(() => categories.id),
    title: text("title").notNull(),
    description: text("description").notNull().default(""),
    price: real("price").notNull(),
    oldPrice: real("old_price"),
    currency: text("currency").notNull().default("ARS"),
    condition: text("condition").notNull(),
    location: text("location").notNull(),
    shipping: text("shipping").notNull(),
    status: text("status").notNull().default("online"),
    source: text("source").notNull().default("user"),
    metadataJson: text("metadata_json").notNull(),
    tagsJson: text("tags_json").notNull(),
    createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
    updatedAt: text("updated_at").notNull().default(sql`CURRENT_TIMESTAMP`),
  },
  (table) => ({
    categoryIdx: index("listings_category_idx").on(table.categoryId),
    sellerIdx: index("listings_seller_idx").on(table.sellerId),
    statusIdx: index("listings_status_idx").on(table.status),
  }),
);

export const listingViews = sqliteTable(
  "listing_views",
  {
    id: text("id").primaryKey(),
    userId: text("user_id")
      .notNull()
      .references(() => users.id),
    listingId: text("listing_id")
      .notNull()
      .references(() => listings.id),
    categoryId: text("category_id").notNull(),
    tagsJson: text("tags_json").notNull(),
    viewedAt: text("viewed_at").notNull().default(sql`CURRENT_TIMESTAMP`),
  },
  (table) => ({
    userViewedAtIdx: index("listing_views_user_viewed_at_idx").on(
      table.userId,
      table.viewedAt,
    ),
  }),
);

export const userSearches = sqliteTable(
  "user_searches",
  {
    id: text("id").primaryKey(),
    userId: text("user_id")
      .notNull()
      .references(() => users.id),
    query: text("query").notNull(),
    categoryId: text("category_id"),
    tagsJson: text("tags_json").notNull(),
    searchedAt: text("searched_at").notNull().default(sql`CURRENT_TIMESTAMP`),
  },
  (table) => ({
    userSearchedAtIdx: index("user_searches_user_searched_at_idx").on(
      table.userId,
      table.searchedAt,
    ),
  }),
);

export const chatThreads = sqliteTable(
  "chat_threads",
  {
    id: text("id").primaryKey(),
    listingId: text("listing_id")
      .notNull()
      .references(() => listings.id),
    buyerId: text("buyer_id")
      .notNull()
      .references(() => users.id),
    sellerId: text("seller_id")
      .notNull()
      .references(() => users.id),
    lastMessageAt: text("last_message_at").notNull().default(sql`CURRENT_TIMESTAMP`),
  },
  (table) => ({
    listingIdx: index("chat_threads_listing_idx").on(table.listingId),
    buyerIdx: index("chat_threads_buyer_idx").on(table.buyerId),
    sellerIdx: index("chat_threads_seller_idx").on(table.sellerId),
  }),
);

export const chatMessages = sqliteTable(
  "chat_messages",
  {
    id: text("id").primaryKey(),
    threadId: text("thread_id")
      .notNull()
      .references(() => chatThreads.id),
    senderId: text("sender_id")
      .notNull()
      .references(() => users.id),
    body: text("body").notNull(),
    createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
    readAt: text("read_at"),
  },
  (table) => ({
    threadCreatedAtIdx: index("chat_messages_thread_created_at_idx").on(
      table.threadId,
      table.createdAt,
    ),
  }),
);

export const shipments = sqliteTable(
  "shipments",
  {
    id: text("id").primaryKey(),
    listingId: text("listing_id")
      .notNull()
      .references(() => listings.id),
    origin: text("origin").notNull(),
    destination: text("destination").notNull(),
    status: text("status").notNull(),
    progress: integer("progress").notNull().default(0),
    etaMinutes: integer("eta_minutes").notNull().default(35),
    routeJson: text("route_json").notNull(),
    updatedAt: text("updated_at").notNull().default(sql`CURRENT_TIMESTAMP`),
  },
  (table) => ({
    listingIdx: index("shipments_listing_idx").on(table.listingId),
    statusIdx: index("shipments_status_idx").on(table.status),
  }),
);

export const marketplaceRealtime = sqliteTable("marketplace_realtime", {
  id: text("id").primaryKey(),
  payload: text("payload").notNull(),
  updatedAt: text("updated_at").notNull(),
});

export const marketplaceAccounts = sqliteTable(
  "marketplace_accounts",
  {
    id: text("id").primaryKey(),
    name: text("name").notNull(),
    email: text("email").notNull().unique(),
    location: text("location").notNull(),
    avatar: text("avatar").notNull(),
    reputation: real("reputation").notNull().default(5),
    joinedAt: text("joined_at").notNull(),
    passwordHash: text("password_hash").notNull(),
    passwordSalt: text("password_salt").notNull(),
  },
  (table) => ({
    emailIdx: index("marketplace_accounts_email_idx").on(table.email),
  }),
);

export const marketplaceSessions = sqliteTable(
  "marketplace_sessions",
  {
    tokenHash: text("token_hash").primaryKey(),
    userId: text("user_id").notNull(),
    expiresAt: text("expires_at").notNull(),
    createdAt: text("created_at").notNull(),
  },
  (table) => ({
    userIdx: index("marketplace_sessions_user_idx").on(table.userId),
  }),
);

export const marketplaceChatThreads = sqliteTable(
  "marketplace_chat_threads",
  {
    id: text("id").primaryKey(),
    listingId: text("listing_id").notNull(),
    buyerId: text("buyer_id").notNull(),
    sellerId: text("seller_id").notNull(),
    createdAt: text("created_at").notNull(),
    lastMessageAt: text("last_message_at").notNull(),
  },
  (table) => ({
    participantIdx: index("marketplace_chat_user_idx").on(
      table.buyerId,
      table.sellerId,
      table.lastMessageAt,
    ),
    participantListingIdx: uniqueIndex("marketplace_chat_thread_unique_idx").on(
      table.listingId,
      table.buyerId,
      table.sellerId,
    ),
  }),
);

export const marketplaceChatMessages = sqliteTable(
  "marketplace_chat_messages",
  {
    id: text("id").primaryKey(),
    threadId: text("thread_id").notNull(),
    senderId: text("sender_id").notNull(),
    body: text("body").notNull(),
    createdAt: text("created_at").notNull(),
    readAt: text("read_at"),
  },
  (table) => ({
    threadIdx: index("marketplace_chat_message_idx").on(
      table.threadId,
      table.createdAt,
    ),
  }),
);
