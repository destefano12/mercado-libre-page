CREATE TABLE IF NOT EXISTS `marketplace_accounts` (
	`id` text PRIMARY KEY NOT NULL,
	`name` text NOT NULL,
	`email` text NOT NULL,
	`location` text NOT NULL,
	`avatar` text NOT NULL,
	`reputation` real DEFAULT 5 NOT NULL,
	`joined_at` text NOT NULL,
	`password_hash` text NOT NULL,
	`password_salt` text NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS `marketplace_accounts_email_unique` ON `marketplace_accounts` (`email`);--> statement-breakpoint
CREATE INDEX IF NOT EXISTS `marketplace_accounts_email_idx` ON `marketplace_accounts` (`email`);--> statement-breakpoint
CREATE TABLE IF NOT EXISTS `marketplace_chat_messages` (
	`id` text PRIMARY KEY NOT NULL,
	`thread_id` text NOT NULL,
	`sender_id` text NOT NULL,
	`body` text NOT NULL,
	`created_at` text NOT NULL,
	`read_at` text
);
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS `marketplace_chat_message_idx` ON `marketplace_chat_messages` (`thread_id`,`created_at`);--> statement-breakpoint
CREATE TABLE IF NOT EXISTS `marketplace_chat_threads` (
	`id` text PRIMARY KEY NOT NULL,
	`listing_id` text NOT NULL,
	`buyer_id` text NOT NULL,
	`seller_id` text NOT NULL,
	`created_at` text NOT NULL,
	`last_message_at` text NOT NULL
);
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS `marketplace_chat_user_idx` ON `marketplace_chat_threads` (`buyer_id`,`seller_id`,`last_message_at`);--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS `marketplace_chat_thread_unique_idx` ON `marketplace_chat_threads` (`listing_id`,`buyer_id`,`seller_id`);--> statement-breakpoint
CREATE TABLE IF NOT EXISTS `marketplace_realtime` (
	`id` text PRIMARY KEY NOT NULL,
	`payload` text NOT NULL,
	`updated_at` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS `marketplace_sessions` (
	`token_hash` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`expires_at` text NOT NULL,
	`created_at` text NOT NULL
);
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS `marketplace_sessions_user_idx` ON `marketplace_sessions` (`user_id`);
