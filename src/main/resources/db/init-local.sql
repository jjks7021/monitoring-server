-- 로컬 MySQL 최초 1회 설정 (godoksa_db + team_user)
-- 실행 예: mysql -u root -p < src/main/resources/db/init-local.sql
--
-- 테이블은 Spring Boot 기동 시 JPA(ddl-auto=update)가 자동 생성합니다.
-- 이 스크립트는 DB·계정만 만듭니다.

CREATE DATABASE IF NOT EXISTS godoksa_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'team_user'@'localhost' IDENTIFIED BY 'team1234!';
CREATE USER IF NOT EXISTS 'team_user'@'127.0.0.1' IDENTIFIED BY 'team1234!';

GRANT ALL PRIVILEGES ON godoksa_db.* TO 'team_user'@'localhost';
GRANT ALL PRIVILEGES ON godoksa_db.* TO 'team_user'@'127.0.0.1';

FLUSH PRIVILEGES;

SELECT 'godoksa_db ready' AS status;
