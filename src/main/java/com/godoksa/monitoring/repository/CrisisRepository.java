package com.godoksa.monitoring.repository;

import com.godoksa.monitoring.entity.Crisis;
import com.godoksa.monitoring.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface CrisisRepository extends JpaRepository<Crisis, Long> {
    // 아직 해결되지 않은 특정 유저의 위험 상황 찾기
    Optional<Crisis> findByUserAndStatus(User user, Crisis.CrisisStatus status);

    // 현재 발생한 모든 실시간 위험 상황 목록 조회 (관리자용)
    List<Crisis> findByStatus(Crisis.CrisisStatus status);

    List<Crisis> findByUser_LoginCodeAndStatus(String loginCode, Crisis.CrisisStatus status);
}