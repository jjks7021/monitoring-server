package com.godoksa.monitoring.repository;

import com.godoksa.monitoring.entity.Device;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface DeviceRepository extends JpaRepository<Device, Long> {
    // 스마트폰 고유 ID(UUID)로 기기 정보를 찾는 기능을 추가합니다.
    Optional<Device> findByHardwareId(String hardwareId);
}