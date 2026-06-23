package com.ecbs.cobol;

import java.util.Map;

import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.HealthIndicator;
import org.springframework.stereotype.Component;

/**
 * Contributes the COBOL bridge liveness to {@code /actuator/health}
 * (Fase 15). When the bridge is unreachable the aggregate health turns
 * DOWN, so an orchestrator or load balancer can route around or restart a
 * backend whose business layer is gone.
 */
@Component("cobolBridge")
public class BridgeHealthIndicator implements HealthIndicator {

    private final CobolBridgeClient bridge;

    public BridgeHealthIndicator(CobolBridgeClient bridge) {
        this.bridge = bridge;
    }

    @Override
    public Health health() {
        try {
            Map<String, Object> body = bridge.health();
            Object status = body == null ? null : body.get("status");
            if (body != null && "UP".equals(status)) {
                return Health.up()
                        .withDetail("programCount", body.getOrDefault("programCount", "unknown"))
                        .build();
            }
            return Health.down().withDetail("bridgeStatus", String.valueOf(status)).build();
        } catch (Exception ex) {
            return Health.down().withDetail("error", ex.getMessage()).build();
        }
    }
}
