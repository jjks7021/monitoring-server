package com.godoksa.monitoring.controller;

import com.godoksa.monitoring.dto.LoginRequest;
import com.godoksa.monitoring.dto.UserLoginResponse;
import com.godoksa.monitoring.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserRepository userRepository;

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody LoginRequest request) {
        return userRepository.findByLoginCode(request.getLoginCode())
                .map(user -> ResponseEntity.ok(UserLoginResponse.from(user)))
                .orElse(ResponseEntity.status(401).build());
    }
}
