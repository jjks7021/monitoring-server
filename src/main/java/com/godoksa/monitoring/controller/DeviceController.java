package com.godoksa.monitoring.controller;

import com.godoksa.monitoring.entity.Device;
import com.godoksa.monitoring.repository.DeviceRepository;
import org.springframework.web.bind.annotation.*;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/devices")
@RequiredArgsConstructor
public class DeviceController {

    private final DeviceRepository deviceRepository;

    // 기기 등록 API
    @PostMapping("/register")
    public String registerDevice(@RequestBody Device device) {
        deviceRepository.findByHardwareId(device.getHardwareId())
            .ifPresentOrElse(
                d -> System.out.println("이미 등록된 기기입니다."),
                () -> deviceRepository.save(device)
            );
        return "기기 등록 완료!";
    }
}