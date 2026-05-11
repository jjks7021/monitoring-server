package com.godoksa.monitoring.repository;

import com.godoksa.monitoring.entity.Device;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface DeviceRepository extends JpaRepository<Device, Long> {
    Optional<Device> findByHardwareId(String hardwareId);
}