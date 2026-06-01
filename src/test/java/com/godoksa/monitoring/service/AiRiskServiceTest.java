package com.godoksa.monitoring.service;

import com.godoksa.monitoring.entity.ActivityLog;
import com.godoksa.monitoring.entity.User;
import com.godoksa.monitoring.repository.CrisisRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

class AiRiskServiceTest {

    @Mock
    private CrisisRepository crisisRepository;

    @InjectMocks
    private AiRiskService aiRiskService;

    @BeforeEach
    void setUp() {
        MockitoAnnotations.openMocks(this);
        // Inject properties from application.properties manually for the test
        ReflectionTestUtils.setField(aiRiskService, "aiApiUrl", "");
        ReflectionTestUtils.setField(aiRiskService, "aiApiKey", "");
        ReflectionTestUtils.setField(aiRiskService, "aiModel", "test-model");
    }

    @Test
    void testAssess() {
        User user = User.builder()
                .id(1L)
                .name("Test User")
                .avgToiletDuration(20)
                .avgActivityRange(1.5)
                .build();

        List<ActivityLog> logs = new ArrayList<>();
        logs.add(ActivityLog.builder()
                .xCoord(0.123)
                .yCoord(0.456)
                .zCoord(0.789)
                .locationTag("ROOM")
                .build());

        when(crisisRepository.findByStatus(any())).thenReturn(new ArrayList<>());

        AiRiskService.AiResult result = aiRiskService.assess(user, logs, 0.1, 0.2, 0.3, "TOILET", 25);

        assertNotNull(result);
        assertNotNull(result.summary());
        assertTrue(result.summary().contains("규칙"));
        assertEquals(0.15, result.probability(), 0.01);
    }
}
