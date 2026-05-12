package com.godoksa.monitoring.controller;

import com.godoksa.monitoring.entity.User;
import com.godoksa.monitoring.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.ResponseEntity;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserRepository userRepository;

    // 6자리 코드로 로그인하는 API
    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody String loginCode) {
        // 찬우님이 보낸 코드와 DB에 있는 코드를 비교
        return userRepository.findByLoginCode(loginCode)
                .map(user -> ResponseEntity.ok(user)) // 코드 맞으면 유저 정보 전송
                .orElse(ResponseEntity.status(401).build()); // 틀리면 401 에러
    }
}