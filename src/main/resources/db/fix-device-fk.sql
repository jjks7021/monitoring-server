-- device.user_id FK가 `user` / `users` 테이블에 섞여 있을 때 1회 실행
-- MySQL: mysql -u team_user -p godoksa_db < src/main/resources/db/fix-device-fk.sql

USE godoksa_db;

-- 잘못된 FK 제거 (이름은 SHOW CREATE TABLE device; 로 확인)
SET @fk_old = (
    SELECT CONSTRAINT_NAME FROM information_schema.KEY_COLUMN_USAGE
    WHERE TABLE_SCHEMA = 'godoksa_db' AND TABLE_NAME = 'device'
      AND REFERENCED_TABLE_NAME = 'user' LIMIT 1
);
SET @sql = IF(@fk_old IS NOT NULL,
    CONCAT('ALTER TABLE device DROP FOREIGN KEY ', @fk_old), 'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- users 참조 FK가 없으면 추가
SET @fk_users = (
    SELECT CONSTRAINT_NAME FROM information_schema.KEY_COLUMN_USAGE
    WHERE TABLE_SCHEMA = 'godoksa_db' AND TABLE_NAME = 'device'
      AND REFERENCED_TABLE_NAME = 'users' LIMIT 1
);
SET @sql2 = IF(@fk_users IS NULL,
    'ALTER TABLE device ADD CONSTRAINT fk_device_users FOREIGN KEY (user_id) REFERENCES users(id)',
    'SELECT 1');
PREPARE stmt2 FROM @sql2;
EXECUTE stmt2;
DEALLOCATE PREPARE stmt2;
