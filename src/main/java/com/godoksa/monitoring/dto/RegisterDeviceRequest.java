package com.godoksa.monitoring.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
public class RegisterDeviceRequest {
    private String hardwareId;
    private String loginCode;
}
