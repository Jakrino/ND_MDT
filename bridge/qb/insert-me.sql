DROP TABLE IF EXISTS `nd_mdt_weapons`;
DROP TABLE IF EXISTS `nd_mdt_bolos`;
DROP TABLE IF EXISTS `nd_mdt_records`;
DROP TABLE IF EXISTS `nd_mdt_reports`;

-- QBCore MDT SQL Setup
-- Creates only the necessary additional tables for the MDT system

-- MDT Weapons Registry
CREATE TABLE IF NOT EXISTS `nd_mdt_weapons` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `character` varchar(50) NOT NULL COMMENT 'Owner citizenid',
  `weapon` varchar(100) NOT NULL COMMENT 'Weapon label/name',
  `serial` varchar(100) NOT NULL COMMENT 'Weapon serial number',
  `owner_name` varchar(100) DEFAULT NULL COMMENT 'Registered owner name',
  `stolen` tinyint(1) NOT NULL DEFAULT 0 COMMENT 'Stolen status (1=stolen)',
  PRIMARY KEY (`id`),
  UNIQUE KEY `serial` (`serial`),
  KEY `character` (`character`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- MDT BOLOs (Be On LookOut)
CREATE TABLE IF NOT EXISTS `nd_mdt_bolos` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` varchar(20) NOT NULL COMMENT 'Type (vehicle/person)',
  `data` longtext NOT NULL COMMENT 'JSON data of BOLO details',
  `author` varchar(50) DEFAULT NULL COMMENT 'Creator citizenid',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- MDT Criminal Records
CREATE TABLE IF NOT EXISTS `nd_mdt_records` (
  `citizenid` varchar(50) NOT NULL COMMENT 'Player citizenid',
  `records` longtext NOT NULL COMMENT 'JSON array of criminal records',
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- MDT Police Reports
CREATE TABLE IF NOT EXISTS `nd_mdt_reports` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` varchar(50) NOT NULL COMMENT 'Report type',
  `data` longtext NOT NULL COMMENT 'JSON report data',
  `timestamp` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Add stolen column to player_vehicles if not exists
ALTER TABLE `player_vehicles` 
ADD COLUMN IF NOT EXISTS `stolen` tinyint(1) NOT NULL DEFAULT 0 COMMENT 'Stolen vehicle status (1=stolen)';

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS `nd_mdt_weapons_serial_index` ON `nd_mdt_weapons` (`serial`);
CREATE INDEX IF NOT EXISTS `nd_mdt_bolos_type_index` ON `nd_mdt_bolos` (`type`);
CREATE INDEX IF NOT EXISTS `nd_mdt_reports_type_index` ON `nd_mdt_reports` (`type`);