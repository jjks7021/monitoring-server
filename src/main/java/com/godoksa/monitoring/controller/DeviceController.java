package com.godoksa.monitoring.controller;

import com.godoksa.monitoring.dto.CoordinateRequest;
import com.godoksa.monitoring.dto.CoordinateResponse;
import com.godoksa.monitoring.dto.RegisterDeviceRequest;
import com.godoksa.monitoring.entity.Device;
import com.godoksa.monitoring.entity.User;
import com.godoksa.monitoring.repository.DeviceRepository;
import com.godoksa.monitoring.repository.UserRepository;
import com.godoksa.monitoring.service.MonitoringService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/devices")
@RequiredArgsConstructor
public class DeviceController {

    private final DeviceRepository deviceRepository;
    private final UserRepository userRepository;
    private final MonitoringService monitoringService;

    @PostMapping("/register")
    public ResponseEntity<?> registerDevice(@RequestBody RegisterDeviceRequest request) {
        User user = userRepository.findByLoginCode(request.getLoginCode())
                .orElseThrow(() -> new IllegalArgumentException("해당 코드를 가진 유저가 없습니다."));

        if (deviceRepository.findByHardwareId(request.getHardwareId()).isPresent()) {
            return ResponseEntity.ok("이미 등록된 기기입니다.");
        }

        Device device = Device.builder()
                .hardwareId(request.getHardwareId())
                .user(user)
                .role(Device.Role.valueOf(user.getRole()))
                .build();
        deviceRepository.save(device);
        return ResponseEntity.ok("기기가 유저 [" + user.getName() + "]님에게 등록되었습니다.");
    }

    @PostMapping("/coordinates")
    public ResponseEntity<?> receiveCoordinates(@RequestBody CoordinateRequest request) {
        try {
            if (!deviceRepository.findByHardwareId(request.getHardwareId()).isPresent()) {
                return ResponseEntity.badRequest().body("등록되지 않은 기기입니다. 먼저 /register를 호출하세요.");
            }
            int duration = request.getCurrentDuration() != null ? request.getCurrentDuration() : 0;
            String tag = request.getLocationTag() != null ? request.getLocationTag() : "ROOM";

            CoordinateResponse response = monitoringService.analyzeMovement(
                    request.getLoginCode(),
                    request.getHardwareId(),
                    request.getX(),
                    request.getY(),
                    request.getZ(),
                    tag,
                    duration);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("데이터 처리 중 오류: " + e.getMessage());
        }
    }

    @GetMapping("/statistics/{loginCode}")
    public ResponseEntity<?> getStatistics(@PathVariable String loginCode) {
        try {
            return ResponseEntity.ok(monitoringService.getLocationStatistics(loginCode));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("통계 조회 실패: " + e.getMessage());
        }
    }
}
