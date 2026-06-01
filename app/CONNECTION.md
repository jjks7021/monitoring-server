# 앱 ↔ 서버 연결 방법

## 연결 코드 (6자리)

- **피보호자**: 앱이 서버에서 **랜덤 6자리 코드**를 발급해 화면에 표시합니다. (기기당 동일 코드 유지)
- **보호자**: 피보호자 화면에 표시된 **같은 6자리 코드**를 입력해야 연결됩니다.
- 코드가 일치하지 않으면 보호자 연결이 거부됩니다.

## API

| 역할 | 엔드포인트 | 설명 |
|------|-----------|------|
| 피보호자 | `POST /api/users/patient/connect` | `{ "hardwareId": "..." }` → 랜덤 코드 발급 |
| 보호자 | `POST /api/users/guardian/connect` | `{ "loginCode": "123456" }` → 피보호자(PATIENT)만 허용 |

## 실행 순서

1. 백엔드: `.\gradlew bootRun` (프로젝트 루트)
2. 피보호자 앱: 피보호자 선택 → **내 연결 코드** 확인 → 보호자에게 알려주기 → **모니터링 시작**
3. 보호자 앱: 보호자 선택 → 피보호자가 알려준 **동일 6자리** 입력 → **연결하기**

## Flutter 실행

기본 API 주소는 플랫폼별로 자동 설정됩니다. 별도 `--dart-define` 없이 실행해도 됩니다.

| 환경 | 기본 API |
|------|----------|
| macOS / iOS 시뮬레이터 / Windows / Web | `http://127.0.0.1:8080` |
| Android 에뮬레이터 | `http://10.0.2.2:8080` |
| Android 실기기 | `http://<PC_LAN_IP>:8080` (`--dart-define` 필요) |

macOS:

```bash
cd app
flutter run -d macos
```

Android 에뮬레이터 (명시적 지정이 필요할 때):

```bash
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

## 백엔드 실행 위치

IntelliJ / Gradle Run은 **저장소 루트** `src/main/java/.../MonitoringServerApplication` 을 사용하세요.

`app/src/main/java` 아래 Spring Boot는 구버전(`/api/users/patient/connect` 없음)이므로 피보호자 코드 발급이 되지 않습니다.
