package com.godoksa.monitoring.config;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Map;

// DB 스키마 FK 자동 수정 (구버전 스키마 호환용)
@Component
@RequiredArgsConstructor
@Slf4j
public class DatabaseSchemaFix implements ApplicationRunner {

    private static final List<String> TABLES_WITH_USER_ID = List.of(
            "device",
            "activity_log",
            "crisis",
            "risk_assessment");

    private final JdbcTemplate jdbcTemplate;

    @Override
    public void run(ApplicationArguments args) {
        for (String table : TABLES_WITH_USER_ID) {
            if (!tableExists(table)) {
                continue;
            }
            fixUserForeignKey(table);
        }
    }

    private boolean tableExists(String tableName) {
        Integer count = jdbcTemplate.queryForObject("""
                SELECT COUNT(*)
                FROM information_schema.TABLES
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?
                """, Integer.class, tableName);
        return count != null && count > 0;
    }

    private void fixUserForeignKey(String tableName) {
        List<Map<String, Object>> fks = jdbcTemplate.queryForList("""
                SELECT CONSTRAINT_NAME AS name, REFERENCED_TABLE_NAME AS refTable
                FROM information_schema.KEY_COLUMN_USAGE
                WHERE TABLE_SCHEMA = DATABASE()
                  AND TABLE_NAME = ?
                  AND COLUMN_NAME = 'user_id'
                  AND REFERENCED_TABLE_NAME IS NOT NULL
                """, tableName);

        for (Map<String, Object> fk : fks) {
            if ("user".equals(fk.get("refTable"))) {
                String name = (String) fk.get("name");
                jdbcTemplate.execute("ALTER TABLE `" + tableName + "` DROP FOREIGN KEY `" + name + "`");
            }
        }

        boolean hasUsersFk = !jdbcTemplate.queryForList("""
                SELECT 1
                FROM information_schema.KEY_COLUMN_USAGE
                WHERE TABLE_SCHEMA = DATABASE()
                  AND TABLE_NAME = ?
                  AND COLUMN_NAME = 'user_id'
                  AND REFERENCED_TABLE_NAME = 'users'
                LIMIT 1
                """, tableName).isEmpty();

        if (!hasUsersFk) {
            String constraint = "fk_" + tableName + "_users";
            try {
                jdbcTemplate.execute("""
                        ALTER TABLE `%s`
                        ADD CONSTRAINT `%s`
                        FOREIGN KEY (user_id) REFERENCES users(id)
                        """.formatted(tableName, constraint));
            } catch (Exception e) {
                log.warn("Could not add FK on `{}` -> users: {}", tableName, e.getMessage());
            }
        }
    }
}
