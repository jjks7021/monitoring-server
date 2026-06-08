package com.godoksa.monitoring.controller;

import com.godoksa.monitoring.entity.Crisis;
import com.godoksa.monitoring.repository.CrisisRepository;
import com.godoksa.monitoring.service.PhotoSnapshotService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/guardian")
@RequiredArgsConstructor
public class GuardianPhotoController {

    private final CrisisRepository crisisRepository;
    private final PhotoSnapshotService photoSnapshotService;

    // 보호자가 긴급 사진 1회 열람 (조회 즉시 서버에서 삭제됨)
    @GetMapping("/emergency-photo/{loginCode}")
    public ResponseEntity<?> viewEmergencyPhoto(@PathVariable String loginCode) {
        boolean hasCrisis = !crisisRepository
                .findByUser_LoginCodeAndStatus(loginCode, Crisis.CrisisStatus.CRISIS)
                .isEmpty();
        if (!hasCrisis) {
            return ResponseEntity.status(403).body(
                    Map.of("error", "활성 위험 상황이 없어 사진 열람이 허용되지 않습니다."));
        }

        var photo = photoSnapshotService.consume(loginCode);
        if (photo.isEmpty()) {
            return ResponseEntity.status(404).body(
                    Map.of("error", "열람 가능한 사진이 없거나 이미 조회되었습니다."));
        }
        var cached = photo.get();
        return ResponseEntity.ok()
                .header(HttpHeaders.CACHE_CONTROL, "no-store")
                .contentType(MediaType.parseMediaType(cached.contentType()))
                .body(cached.data());
    }
}
