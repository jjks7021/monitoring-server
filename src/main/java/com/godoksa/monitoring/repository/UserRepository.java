package com.godoksa.monitoring.repository;

import com.godoksa.monitoring.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {
    // 로그인 코드로 유저를 찾는 기능 추가
    Optional<User> findByLoginCode(String loginCode);
}