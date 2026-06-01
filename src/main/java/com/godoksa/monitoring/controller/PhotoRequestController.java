package com.godoksa.monitoring.controller;

import com.godoksa.monitoring.dto.PhotoRequestEvent;
import com.godoksa.monitoring.entity.Crisis;
import com.godoksa.monitoring.entity.User;
import com.godoksa.monitoring.repository.CrisisRepository;
import com.godoksa.monitoring.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/guardian")
@RequiredArgsConstructor
public class PhotoRequestController {

    private final UserRepository userRepository;
    private final CrisisRepository crisisRepository;
    private final SimpMessagingTemplate messagingTemplate;

    @PostMapping("/photo-request/{loginCode}")
    public ResponseEntity<?> requestPhoto(@PathVariable String loginCode) {
        User user = userRepository.findByLoginCode(loginCode)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 사용자 코드입니다."));

        boolean hasCrisis = !crisisRepository
                .findByUser_LoginCodeAndStatus(loginCode, Crisis.CrisisStatus.CRISIS)
                .isEmpty();
        if (!hasCrisis) {
            return ResponseEntity.status(403).body(
                    Map.of("error", "긴급 위험 상황이 감지된 경우에만 사진 요청이 가능합니다."));
        }

        PhotoRequestEvent event = new PhotoRequestEvent(
                "PHOTO_REQUEST",
                loginCode,
                user.getName(),
                "보호자가 실시간 안전 확인 사진을 요청했습니다.");
        messagingTemplate.convertAndSend("/topic/photo-request/" + loginCode, event);

        return ResponseEntity.ok(Map.of("message", "피보호자 기기에 촬영 요청을 전송했습니다."));
    }
}
