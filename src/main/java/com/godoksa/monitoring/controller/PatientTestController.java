package com.godoksa.monitoring.controller;

import com.godoksa.monitoring.entity.User;
import com.godoksa.monitoring.repository.UserRepository;
import com.godoksa.monitoring.service.CrisisAlertService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/patient")
@RequiredArgsConstructor
public class PatientTestController {

    private final UserRepository userRepository;
    private final CrisisAlertService crisisAlertService;

    // 알림 테스트용 (임의로 위험 상황 발생시킴)
    @PostMapping("/trigger-test-crisis")
    @Transactional
    public ResponseEntity<?> triggerTestCrisis(@RequestBody Map<String, String> body) {
        User user = resolvePatient(body.get("loginCode"));
        var crisis = crisisAlertService.raiseManualTestCrisis(user);
        return ResponseEntity.ok(Map.of(
                "message", "테스트 알림만 전송했습니다. 실제 AI 위험 알림과는 별개입니다.",
                "crisisId", crisis.getId(),
                "crisisType", crisis.getCrisisType(),
                "loginCode", user.getLoginCode()));
    }

    @GetMapping("/ping")
    public ResponseEntity<Map<String, String>> ping() {
        return ResponseEntity.ok(Map.of("status", "ok"));
    }

    // 현재 AI 자동 알림 임계값 확인
    @GetMapping("/alert-config")
    public ResponseEntity<?> alertConfig() {
        double threshold = crisisAlertService.getAiCrisisThreshold();
        return ResponseEntity.ok(Map.of(
                "aiCrisisThreshold", threshold,
                "aiCrisisThresholdPercent", threshold * 100,
                "hint", "피보호자 좌표 전송 시 AI 확률이 이 값 이상이면 보호자 알림이 자동 발생합니다."));
    }

    private User resolvePatient(String loginCode) {
        if (loginCode == null || loginCode.isBlank()) {
            throw new IllegalArgumentException("loginCode가 필요합니다.");
        }
        User user = userRepository.findByLoginCode(loginCode.trim())
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 연결 코드입니다."));
        if (!"PATIENT".equals(user.getRole())) {
            throw new IllegalArgumentException("피보호자 계정에서만 호출할 수 있습니다.");
        }
        return user;
    }
}
