package com.godoksa.monitoring.service;

import com.godoksa.monitoring.dto.UserLoginResponse;
import com.godoksa.monitoring.entity.Device;
import com.godoksa.monitoring.entity.User;
import com.godoksa.monitoring.repository.DeviceRepository;
import com.godoksa.monitoring.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;

@Service
@RequiredArgsConstructor
public class UserConnectionService {

    private final UserRepository userRepository;
    private final DeviceRepository deviceRepository;
    private final SecureRandom random = new SecureRandom();

    /**
     * 피보호자 기기: 최초 접속 시 6자리 코드 발급, 동일 기기는 기존 코드 유지.
     */
    @Transactional
    public UserLoginResponse connectPatient(String hardwareId) {
        if (hardwareId == null || hardwareId.isBlank()) {
            throw new IllegalArgumentException("기기 식별 정보가 필요합니다.");
        }

        return deviceRepository.findByHardwareId(hardwareId)
                .map(device -> UserLoginResponse.from(device.getUser()))
                .orElseGet(() -> createPatientWithNewCode(hardwareId));
    }

    /**
     * 보호자: 피보호자가 발급받은 6자리 코드와 일치해야 연결됨.
     */
    @Transactional(readOnly = true)
    public UserLoginResponse connectGuardian(String loginCode) {
        String normalized = normalizeCode(loginCode);
        User user = userRepository.findByLoginCode(normalized)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 연결 코드입니다. 피보호자 코드를 확인해 주세요."));

        if (!"PATIENT".equals(user.getRole())) {
            throw new IllegalArgumentException("피보호자의 6자리 연결 코드를 입력해 주세요.");
        }

        return UserLoginResponse.from(user);
    }

    private UserLoginResponse createPatientWithNewCode(String hardwareId) {
        String code = generateUniqueLoginCode();
        User user = userRepository.save(User.builder()
                .loginCode(code)
                .name("피보호자")
                .role("PATIENT")
                .avgToiletDuration(20)
                .avgActivityRange(1.0)
                .build());

        deviceRepository.save(Device.builder()
                .hardwareId(hardwareId)
                .user(user)
                .role(Device.Role.PATIENT)
                .build());

        return UserLoginResponse.from(user);
    }

    private String generateUniqueLoginCode() {
        for (int attempt = 0; attempt < 200; attempt++) {
            String code = String.format("%06d", random.nextInt(1_000_000));
            if (userRepository.findByLoginCode(code).isEmpty()) {
                return code;
            }
        }
        throw new IllegalStateException("사용 가능한 연결 코드를 만들 수 없습니다. 잠시 후 다시 시도해 주세요.");
    }

    private String normalizeCode(String loginCode) {
        return loginCode.replaceAll("\\s", "").trim();
    }
}
