CREATE TABLE `user_searches` (
	`id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`query` text NOT NULL,
	`category_id` text,
	`tags_json` text NOT NULL,
	`searched_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE INDEX `user_searches_user_searched_at_idx` ON `user_searches` (`user_id`,`searched_at`);--> statement-breakpoint
ALTER TABLE `listings` ADD `source` text DEFAULT 'user' NOT NULL;