package com.godoksa.monitoring.controller;

import com.godoksa.monitoring.dto.CoordinateRequest;
import com.godoksa.monitoring.dto.CoordinateResponse;
import com.godoksa.monitoring.dto.RegisterDeviceRequest;
import com.godoksa.monitoring.entity.Device;
import com.godoksa.monitoring.entity.User;
import com.godoksa.monitoring.repository.DeviceRepository;
import com.godoksa.monitoring.repository.UserRepository;
import com.godoksa.monitoring.service.MonitoringService;
import com.godoksa.monitoring.service.PhotoSnapshotService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.Map;

@RestController
@RequestMapping("/api/devices")
@RequiredArgsConstructor
public class DeviceController {

    private final DeviceRepository deviceRepository;
    private final UserRepository userRepository;
    private final MonitoringService monitoringService;
    private final PhotoSnapshotService photoSnapshotService;

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

    /**
     * 긴급 상황 시 1회성 스냅샷 업로드 (DB·파일 저장 없음, 메모리 TTL 후 자동 소멸)
     */
    @PostMapping(value = "/emergency-photo", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<?> uploadEmergencyPhoto(
            @RequestParam String loginCode,
            @RequestParam String hardwareId,
            @RequestPart("image") MultipartFile image) {
        try {
            if (!deviceRepository.findByHardwareId(hardwareId).isPresent()) {
                return ResponseEntity.badRequest().body(Map.of("error", "등록되지 않은 기기입니다."));
            }
            if (image.isEmpty()) {
                return ResponseEntity.badRequest().body(Map.of("error", "이미지가 비어 있습니다."));
            }
            String contentType = image.getContentType() != null ? image.getContentType() : "image/jpeg";
            photoSnapshotService.storeAndNotify(loginCode, image.getBytes(), contentType);
            return ResponseEntity.ok(Map.of("message", "긴급 사진이 보호자 열람용으로 준비되었습니다."));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", "사진 업로드 실패: " + e.getMessage()));
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
