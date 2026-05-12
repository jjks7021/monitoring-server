package com.godoksa.monitoring.controller;

import com.godoksa.monitoring.entity.Device;
import com.godoksa.monitoring.entity.User;
import com.godoksa.monitoring.repository.DeviceRepository;
import com.godoksa.monitoring.repository.UserRepository;
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
     * 2. 좌표 데이터 수신 API (현성님 핵심 기획)
     * 앱(Edge)에서 MoveNet으로 뽑은 x, y 좌표를 이쪽으로 쏩니다.
     */
    @PostMapping("/coordinates")
    public ResponseEntity<?> receiveCoordinates(@RequestBody Map<String, Object> data) {
        // 실제로는 여기서 ActivityLog 엔티티를 생성하고 저장해야 합니다.
        // 그리고 여기서 '무기력 지수'나 '화장실 체류 시간' 분석 로직을 호출하게 됩니다.
        
        System.out.println("좌표 수신: " + data.toString());
        return ResponseEntity.ok("데이터 수신 완료");
    }
}