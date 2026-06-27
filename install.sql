-- devchacha-weed VORP Database Schema
-- Run this file to create or update the required tables and insert items

-- Create the plants table
CREATE TABLE IF NOT EXISTS `rsg_weed_plants` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `strain` varchar(50) NOT NULL DEFAULT 'kalka',
    `coords` text NOT NULL,
    `stage` int(11) NOT NULL DEFAULT 1,
    `water` float NOT NULL DEFAULT 100.0,
    `growth` float NOT NULL DEFAULT 0.0,
    `quality` float NOT NULL DEFAULT 100.0,
    `fertilized` tinyint(1) NOT NULL DEFAULT 0,
    `charid` int(11) DEFAULT NULL,
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Insert items into VORP items database table
INSERT IGNORE INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`) VALUES
('shovel', 'Shovel', 1, 1, 'item_standard', 1),
('fertilizer', 'Fertilizer', 50, 1, 'item_standard', 1),
('wash_barrel', 'Wash Bucket', 5, 1, 'item_standard', 1),
('processing_table', 'Drying Rack', 5, 1, 'item_standard', 1),
('seed_kalka', 'Guarma Gold Seed', 50, 1, 'item_standard', 1),
('seed_purp', 'Ambarino Frost Seed', 50, 1, 'item_standard', 1),
('seed_tex', 'New Austin Haze Seed', 50, 1, 'item_standard', 1),
('leaf_kalka', 'Guarma Gold Leaf', 200, 1, 'item_standard', 0),
('leaf_purp', 'Ambarino Frost Leaf', 200, 1, 'item_standard', 0),
('leaf_tex', 'New Austin Haze Leaf', 200, 1, 'item_standard', 0),
('washed_kalka', 'Washed Guarma Gold', 200, 1, 'item_standard', 0),
('washed_purp', 'Washed Ambarino Frost', 200, 1, 'item_standard', 0),
('washed_tex', 'Washed New Austin Haze', 200, 1, 'item_standard', 0),
('dried_kalka', 'Dried Guarma Gold', 200, 1, 'item_standard', 0),
('dried_purp', 'Dried Ambarino Frost', 200, 1, 'item_standard', 0),
('dried_tex', 'Dried New Austin Haze', 200, 1, 'item_standard', 0),
('trimmed_kalka', 'Guarma Gold Bud', 200, 1, 'item_standard', 1),
('trimmed_purp', 'Ambarino Frost Bud', 200, 1, 'item_standard', 1),
('trimmed_tex', 'New Austin Haze Bud', 200, 1, 'item_standard', 1),
('joint_kalka', 'Guarma Gold Joint', 50, 1, 'item_standard', 1),
('joint_purp', 'Ambarino Frost Joint', 50, 1, 'item_standard', 1),
('joint_tex', 'New Austin Haze Joint', 50, 1, 'item_standard', 1),
('rolling_paper', 'Rolling Paper', 200, 1, 'item_standard', 1),
('emptybucket', 'Empty Bucket', 5, 1, 'item_standard', 1),
('fullbucket', 'Water Bucket', 5, 1, 'item_standard', 1),
('smoking_pipe', 'Smoking Pipe', 5, 1, 'item_standard', 1),
('loaded_pipe_kalka', 'Pipe (Guarma Gold)', 5, 1, 'item_standard', 1),
('loaded_pipe_purp', 'Pipe (Ambarino Frost)', 5, 1, 'item_standard', 1),
('loaded_pipe_tex', 'Pipe (New Austin Haze)', 5, 1, 'item_standard', 1),
('matches', 'Match Box', 10, 1, 'item_standard', 0);
