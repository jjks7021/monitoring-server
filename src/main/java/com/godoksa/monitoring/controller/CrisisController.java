package com.godoksa.monitoring.controller;

import com.godoksa.monitoring.dto.CrisisResponse;
import com.godoksa.monitoring.entity.Crisis;
import com.godoksa.monitoring.repository.CrisisRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/crisis")
@RequiredArgsConstructor
public class CrisisController {

    private final CrisisRepository crisisRepository;

    /**
     * 1. 현재 발생한 실시간 위험 상황 목록 조회 API (관제 대시보드 / 찬우님 보호자 앱 연동용)
     */
    @GetMapping("/active")
    @Transactional(readOnly = true)
    public ResponseEntity<List<CrisisResponse>> getActiveCrises(
            @RequestParam(required = false) String loginCode) {
        List<Crisis> activeCrises = loginCode != null && !loginCode.isBlank()
                ? crisisRepository.findByUser_LoginCodeAndStatus(loginCode, Crisis.CrisisStatus.CRISIS)
                : crisisRepository.findByStatus(Crisis.CrisisStatus.CRISIS);
        return ResponseEntity.ok(activeCrises.stream()
                .map(CrisisResponse::from)
                .collect(Collectors.toList()));
    }

    /**
     * 2. 위험 상황 조치 완료(해결) API (생활관리사가 방문 확인 후 해제 버튼 누를 때)
     */
    @PostMapping("/{id}/resolve")
    @Transactional
    public ResponseEntity<?> resolveCrisis(@PathVariable("id") Long id) {
        Crisis crisis = crisisRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 위험 로그입니다."));

        // 엔티티 내부 메서드 호출해서 STATUS -> RESOLVED, 해결 시간 기록
        crisis.resolveCrisis();

        return ResponseEntity.ok("유저 [" + crisis.getUser().getName() + "]님의 위험 상황이 성공적으로 해제 조치되었습니다.");
    }
}