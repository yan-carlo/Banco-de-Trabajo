-- =============================================
-- Recurso: yn-chopshop
-- Descripción: Script de instalación de base de datos
-- ADVERTENCIA: Este script elimina y recrea las tablas
-- =============================================

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS `yn_chopshop_logs`;

SET FOREIGN_KEY_CHECKS = 1;

-- Tabla de logs de trabajos completados (opcional, para estadísticas)
CREATE TABLE IF NOT EXISTS `yn_chopshop_logs` (
    `id`          INT(11)      NOT NULL AUTO_INCREMENT,
    `identifier`  VARCHAR(60)  NOT NULL,
    `earned`      INT(11)      NOT NULL DEFAULT 0,
    `parts_sold`  INT(11)      NOT NULL DEFAULT 0,
    `completed_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
