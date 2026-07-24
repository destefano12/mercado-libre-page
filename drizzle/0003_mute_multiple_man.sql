CREATE TABLE IF NOT EXISTS `marketplace_reviews` (
	`id` text PRIMARY KEY NOT NULL,
	`listing_id` text NOT NULL,
	`seller_id` text NOT NULL,
	`author_id` text NOT NULL,
	`product_rating` integer NOT NULL,
	`seller_rating` integer NOT NULL,
	`comment` text NOT NULL,
	`created_at` text NOT NULL,
	`updated_at` text NOT NULL
);
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS `marketplace_reviews_listing_idx` ON `marketplace_reviews` (`listing_id`,`updated_at`);--> statement-breakpoint
CREATE INDEX IF NOT EXISTS `marketplace_reviews_seller_idx` ON `marketplace_reviews` (`seller_id`,`updated_at`);--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS `marketplace_reviews_author_listing_idx` ON `marketplace_reviews` (`listing_id`,`author_id`);--> statement-breakpoint
UPDATE `marketplace_accounts`
SET `reputation` = COALESCE((
	SELECT AVG(`seller_rating`)
	FROM `marketplace_reviews`
	WHERE `seller_id` = `marketplace_accounts`.`id`
), 0);
