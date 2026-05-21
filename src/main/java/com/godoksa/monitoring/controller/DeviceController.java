package com.godoksa.monitoring.controller;

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
    private final MonitoringService monitoringService; // 현성님이 만든 분석 서비스 주입!

    /**
     * 1. 기기 등록 API
     * 앱이 처음 실행될 때 스마트폰의 UUID를 서버에 등록하고 특정 유저(어르신)와 연결합니다.
     */
    @PostMapping("/register")
    public ResponseEntity<?> registerDevice(@RequestBody Map<String, String> request) {
        String hardwareId = request.get("hardwareId");
        String loginCode = request.get("loginCode"); // 연결할 어르신의 6자리 코드

        // 6자리 코드로 유저 찾기
        User user = userRepository.findByLoginCode(loginCode)
                .orElseThrow(() -> new RuntimeException("해당 코드를 가진 유저가 없습니다."));

        // 기기 생성 및 저장
        Device device = Device.builder()
                .hardwareId(hardwareId)
                .user(user)
                .role(Device.Role.valueOf(user.getRole())) // 유저의 역할(PATIENT/WARD)을 기기에도 설정
                .build();

        deviceRepository.save(device);
        return ResponseEntity.ok("기기가 유저 [" + user.getName() + "]님에게 등록되었습니다.");
    }

    /**
     * 2. 좌표 데이터 수신 및 고독사 예방 알고리즘 분석 API (현성님 핵심 기획)
     * 앱(Edge)에서 MoveNet으로 뽑은 x, y 좌표와 체류 정보를 이쪽으로 쏩니다.
     */
    @PostMapping("/coordinates")
    public ResponseEntity<?> receiveCoordinates(@RequestBody Map<String, Object> data) {
        try {
            // 앱이 보내온 데이터 파싱
            String loginCode = (String) data.get("loginCode");
            Double x = Double.valueOf(data.get("x").toString());
            Double y = Double.valueOf(data.get("y").toString());
            String locationTag = (String) data.get("locationTag"); // "TOILET" 또는 "ROOM"
            int currentDuration = Integer.parseInt(data.get("currentDuration").toString()); // 현재 체류 시간 (분)

            // 현성님이 구현한 핵심 알고리즘 서비스 호출! (DB 저장 및 300% 체류 검사)
            monitoringService.analyzeMovement(loginCode, x, y, locationTag, currentDuration);

            return ResponseEntity.ok("데이터 수신 및 분석 완료");
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("데이터 처리 중 오류 발생: " + e.getMessage());
        }
    }

    /**
     * 3. 어르신 주거지별 활동 통계 조회 API (보호자 앱 리포트용)
     * 찬우님이 보호자 화면에서 도넛 차트나 파이 그래프를 그릴 수 있게 통계용 맵(Map) 데이터를 반환합니다.
     */
    @GetMapping("/statistics/{loginCode}")
    public ResponseEntity<?> getStatistics(@PathVariable("loginCode") String loginCode) {
        try {
            Map<String, Long> stats = monitoringService.getLocationStatistics(loginCode);
            return ResponseEntity.ok(stats);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("통계 조회 실패: " + e.getMessage());
        }
    }
}