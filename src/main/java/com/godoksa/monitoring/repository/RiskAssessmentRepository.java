package com.godoksa.monitoring.repository;

import com.godoksa.monitoring.entity.RiskAssessment;
import com.godoksa.monitoring.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface RiskAssessmentRepository extends JpaRepository<RiskAssessment, Long> {
    List<RiskAssessment> findByUserOrderByCreatedAtDesc(User user);
}
