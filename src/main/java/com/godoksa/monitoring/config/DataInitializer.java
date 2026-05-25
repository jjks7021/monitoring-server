package com.godoksa.monitoring.config;

import com.godoksa.monitoring.entity.User;
import com.godoksa.monitoring.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@RequiredArgsConstructor
public class DataInitializer {
    private final UserRepository userRepository;

    @Bean
    CommandLineRunner seedUsers() {
        return args -> {
            seed("523891", "김영숙", "PATIENT");
            seed("111111", "김보호", "WARD");
        };
    }

    private void seed(String code, String name, String role) {
        if (userRepository.findByLoginCode(code).isEmpty()) {
            userRepository.save(User.builder()
                    .loginCode(code)
                    .name(name)
                    .role(role)
                    .avgToiletDuration(20)
                    .avgActivityRange(1.0)
                    .build());
        }
    }
}
