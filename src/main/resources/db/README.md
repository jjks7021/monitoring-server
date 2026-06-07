# DB 구성 가이드

## 필요한 것

| 항목 | 값 |
|------|-----|
| DB 이름 | `godoksa_db` |
| 사용자 | `team_user` |
| 비밀번호 | `team1234!` |
| 포트 | `3306` |
| 테이블 | Spring Boot 첫 실행 시 **자동 생성** (`ddl-auto=update`) |

## 테이블 (JPA가 만듦)

- `users` — 피보호자/보호자, 6자리 `login_code`
- `device` — 기기 UUID, `user_id` → `users`
- `activity_log` — 좌표·장소
- `crisis` — 위험 알림
- `risk_assessment` — AI 위험도 기록

## 방법 A: 스크립트 (권장)

```bash
chmod +x scripts/setup-db.sh
./scripts/setup-db.sh
./gradlew bootRun
```

## 방법 B: Docker

```bash
docker compose up -d
./gradlew bootRun
```

## 방법 C: Homebrew MySQL 수동

```bash
brew services start mysql
mysql -u root -p < src/main/resources/db/init-local.sql
mysql -u team_user -pteam1234! godoksa_db -e "SHOW TABLES;"
./gradlew bootRun
```

## FK 오류 시 (device.user_id)

```bash
mysql -u team_user -pteam1234! godoksa_db < src/main/resources/db/fix-device-fk.sql
```

## 연결 확인

```bash
mysql -u team_user -pteam1234! -h 127.0.0.1 godoksa_db -e "SHOW TABLES;"
curl -s http://127.0.0.1:8080/api/patient/ping
```
