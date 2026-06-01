package com.godoksa.monitoring.dto;

import com.godoksa.monitoring.entity.User;
import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
public class UserLoginResponse {
    private final Long id;
    private final String loginCode;
    private final String name;
    private final String role;

    public static UserLoginResponse from(User user) {
        return UserLoginResponse.builder()
                .id(user.getId())
                .loginCode(user.getLoginCode())
                .name(user.getName())
                .role(user.getRole())
                .build();
    }
}
