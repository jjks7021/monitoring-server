package com.godoksa.monitoring.repository;

import com.godoksa.monitoring.entity.Crisis;
import com.godoksa.monitoring.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface CrisisRepository extends JpaRepository<Crisis, Long> {
    // 특정 유저의 특정 상태 위기 조회
    Optional<Crisis> findByUserAndStatus(User user, Crisis.CrisisStatus status);

    // 모든 활성 위기 조회
    List<Crisis> findByStatus(Crisis.CrisisStatus status);

    List<Crisis> findByUser_LoginCodeAndStatus(String loginCode, Crisis.CrisisStatus status);
}