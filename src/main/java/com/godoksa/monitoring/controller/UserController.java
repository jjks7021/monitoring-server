package com.godoksa.monitoring.controller;

import com.godoksa.monitoring.dto.ConnectPatientRequest;
import com.godoksa.monitoring.dto.LoginRequest;
import com.godoksa.monitoring.dto.UserLoginResponse;
import com.godoksa.monitoring.service.UserConnectionService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserConnectionService userConnectionService;

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody LoginRequest request) {
        try {
            return ResponseEntity.ok(userConnectionService.connectGuardian(request.getLoginCode()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(401).body(java.util.Map.of("error", e.getMessage()));
        }
    }

    // 피보호자: 랜덤 6자리 코드 발급 (기기당 1코드 유지)
    @PostMapping("/patient/connect")
    public ResponseEntity<?> connectPatient(@RequestBody ConnectPatientRequest request) {
        try {
            UserLoginResponse response = userConnectionService.connectPatient(request.getHardwareId());
            return ResponseEntity.ok(response);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(java.util.Map.of("error", e.getMessage()));
        }
    }

    // 보호자: 피보호자 6자리 코드로 연결
    @PostMapping("/guardian/connect")
    public ResponseEntity<?> connectGuardian(@RequestBody LoginRequest request) {
        try {
            return ResponseEntity.ok(userConnectionService.connectGuardian(request.getLoginCode()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(401).body(java.util.Map.of("error", e.getMessage()));
        }
    }
}
