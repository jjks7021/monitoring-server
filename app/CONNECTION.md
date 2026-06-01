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

```powershell
cd app
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

Chrome/Windows: `--dart-define=API_BASE_URL=http://localhost:8080`
