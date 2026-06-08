# Silver Care Monitoring

Spring Boot 백엔드 + Flutter 앱 (카메라 포즈 → 서버 → AI 고독사 위험 분석)

## 로컬 개발 (기본)

### 1. MySQL (DB·계정 생성)

```bash
chmod +x scripts/setup-db.sh
./scripts/setup-db.sh
```

Docker가 있으면 자동으로 `docker compose up -d`, 없으면 Homebrew MySQL에 `godoksa_db` + `team_user` 를 만듭니다.

- DB: `godoksa_db` / `team_user` / `team1234!` / `3306`
- **테이블**은 `./gradlew bootRun` 첫 실행 시 JPA가 자동 생성 (`ddl-auto=update`)
- 상세: [src/main/resources/db/README.md](src/main/resources/db/README.md)

### 2. Groq API 키 (AI 분석)

```bash
cp application-secrets.properties.example application-secrets.properties
# application-secrets.properties 에 AI_API_KEY=... 입력
```

또는 환경변수 `AI_API_KEY` 설정. IntelliJ Run에 **빈** `AI_API_KEY`가 있으면 키가 덮어써져 AI가 동작하지 않을 수 있습니다.

### 3. 백엔드

프로젝트 **루트**에서 ( `app/src` 아래 Spring Boot 아님 ):

```bash
./gradlew bootRun
```

또는 IntelliJ → `MonitoringServerApplication` (루트 `src/main/java`)

### 4. Flutter

```bash
cd app
flutter pub get
flutter emulators --launch <본인_에뮬레이터_이름>
flutter run -d emulator
```

에뮬레이터 실행 시 기본적으로 로컬 서버와 연동되며, **같은 PC에서 Spring Boot가 떠 있어야** 합니다.

피보호자·보호자 동시 테스트: 터미널 2개에서 각각 에뮬레이터를 띄워 실행 (Spring은 **한 대만**).

---

## 팀원 원격 접속 (나중에)

**Spring Boot는 호스트(당신) PC 1대만** 실행합니다.

1. 호스트: `docker compose up -d` + `./gradlew bootRun`
2. 호스트: `ngrok http 8080` → HTTPS URL 복사
3. 팀원: Spring **실행하지 않음**, Flutter만:

```bash
cd app
flutter emulators --launch <본인_에뮬레이터_이름>
flutter run -d emulator --dart-define=API_BASE_URL=https://<할당받은_ngrok_도메인>.ngrok-free.dev
```

MySQL만 ngrok으로 열면 DB만 공유되고 WebSocket·긴급 사진·실시간 알림은 깨집니다. 자세히는 [app/CONNECTION.md](app/CONNECTION.md).

---

## API

| 메서드 | 경로 | 설명 |
|--------|------|------|
| POST | `/api/users/patient/connect` | 피보호자 연결 코드 발급 |
| POST | `/api/users/guardian/connect` | 보호자 연결 |
| POST | `/api/devices/coordinates` | 좌표 + AI 분석 |
| GET | `/api/crisis/active?loginCode=` | 활성 위험 |
| GET | `/api/risk/latest/{loginCode}` | 최신 AI 평가 |
| POST | `/api/guardian/photo-request/{loginCode}` | 긴급 사진 요청 |

테스트: [TESTING.md](TESTING.md)
