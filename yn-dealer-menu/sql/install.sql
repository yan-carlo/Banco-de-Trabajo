-- =============================================
-- Recurso : yn-dealer-menu
-- Versión  : 1.0.0
-- ADVERTENCIA: Este script elimina y recrea la tabla dealer_vehicles
-- =============================================

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS `dealer_vehicles`;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE IF NOT EXISTS `dealer_vehicles` (
    `id`           INT(11)       NOT NULL AUTO_INCREMENT,
    `seller_id`    VARCHAR(60)   NOT NULL                 COMMENT 'Identifier del vendedor (ESX) o citizenid (QBCore)',
    `seller_name`  VARCHAR(100)  NOT NULL DEFAULT '',
    `plate`        VARCHAR(20)   NOT NULL,
    `model_hash`   VARCHAR(50)   NOT NULL DEFAULT '',
    `vehicle_data` LONGTEXT      DEFAULT NULL             COMMENT 'JSON: colores, mods estéticos y de rendimiento',
    `description`  VARCHAR(255)  DEFAULT '',
    `price`        INT(11)       NOT NULL DEFAULT 0,
    `pos_x`        FLOAT         NOT NULL DEFAULT 0,
    `pos_y`        FLOAT         NOT NULL DEFAULT 0,
    `pos_z`        FLOAT         NOT NULL DEFAULT 0,
    `pos_h`        FLOAT         NOT NULL DEFAULT 0,
    `network_id`   INT(11)       NOT NULL DEFAULT 0,
    `status`       ENUM('sale','sold','cancelled') NOT NULL DEFAULT 'sale',
    `created_at`   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_plate`   (`plate`),
    KEY `idx_status`  (`status`),
    KEY `idx_seller`  (`seller_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
