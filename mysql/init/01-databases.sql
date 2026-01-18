-- Create WordPress databases and users
-- Note: Root password should be set via MYSQL_ROOT_PASSWORD env var

-- Create 'boira' database for boira.band
CREATE DATABASE IF NOT EXISTS `boira` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create 'lodragonet' database for lodrago.net
CREATE DATABASE IF NOT EXISTS `lodragonet` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create 'forge' user with full privileges on WordPress databases
CREATE USER IF NOT EXISTS 'forge'@'%' IDENTIFIED BY 'forge_changeme';
GRANT ALL PRIVILEGES ON `boira`.* TO 'forge'@'%';
GRANT ALL PRIVILEGES ON `lodragonet`.* TO 'forge'@'%';

-- Create 'lodragonet' user for lodrago.net specifically
CREATE USER IF NOT EXISTS 'lodragonet'@'%' IDENTIFIED BY 'lodragonet';
GRANT ALL PRIVILEGES ON `lodragonet`.* TO 'lodragonet'@'%';

-- Flush privileges
FLUSH PRIVILEGES;
