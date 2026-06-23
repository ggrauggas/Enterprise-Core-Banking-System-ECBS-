package com.ecbs.cobol;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import org.junit.jupiter.api.Test;
import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.Status;

/** Unit tests for the COBOL bridge actuator health indicator. */
class BridgeHealthIndicatorTest {

    private final CobolBridgeClient bridge = mock(CobolBridgeClient.class);
    private final BridgeHealthIndicator indicator = new BridgeHealthIndicator(bridge);

    @Test
    void upWhenBridgeReportsUp() {
        when(bridge.health()).thenReturn(Map.of("status", "UP", "programCount", 31));
        Health health = indicator.health();
        assertThat(health.getStatus()).isEqualTo(Status.UP);
        assertThat(health.getDetails()).containsEntry("programCount", 31);
    }

    @Test
    void downWhenBridgeReportsOtherStatus() {
        when(bridge.health()).thenReturn(Map.of("status", "DEGRADED"));
        Health health = indicator.health();
        assertThat(health.getStatus()).isEqualTo(Status.DOWN);
        assertThat(health.getDetails()).containsEntry("bridgeStatus", "DEGRADED");
    }

    @Test
    void downWhenBridgeThrows() {
        when(bridge.health()).thenThrow(new RuntimeException("connection refused"));
        Health health = indicator.health();
        assertThat(health.getStatus()).isEqualTo(Status.DOWN);
        assertThat(health.getDetails()).containsEntry("error", "connection refused");
    }
}
