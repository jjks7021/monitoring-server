package com.godoksa.monitoring.controller;

import com.godoksa.monitoring.dto.RiskAssessmentResponse;
import com.godoksa.monitoring.entity.User;
import com.godoksa.monitoring.repository.RiskAssessmentRepository;
import com.godoksa.monitoring.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/risk")
@RequiredArgsConstructor
public class RiskController {

    private final RiskAssessmentRepository riskAssessmentRepository;
    private final UserRepository userRepository;

    @GetMapping("/latest/{loginCode}")
    public ResponseEntity<RiskAssessmentResponse> getLatestRisk(@PathVariable String loginCode) {
        User user = userRepository.findByLoginCode(loginCode)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 사용자 코드입니다."));

        var assessments = riskAssessmentRepository.findByUserOrderByCreatedAtDesc(user);

        if (assessments.isEmpty()) {
            return ResponseEntity.notFound().build();
        }

        return ResponseEntity.ok(RiskAssessmentResponse.from(assessments.get(0)));
    }
}
