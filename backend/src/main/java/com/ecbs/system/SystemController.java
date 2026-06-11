package com.ecbs.system;

import java.time.OffsetDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

import com.ecbs.cobol.CobolBridgeClient;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * System information endpoint used to smoke-test the whole chain:
 * frontend -> backend -> COBOL bridge -> COBOL program.
 */
@RestController
@RequestMapping("/api/v1/system")
public class SystemController {

    private final CobolBridgeClient cobolBridge;

    public SystemController(CobolBridgeClient cobolBridge) {
        this.cobolBridge = cobolBridge;
    }

    @GetMapping("/info")
    public Map<String, Object> info() {
        Map<String, Object> info = new LinkedHashMap<>();
        info.put("service", "ecbs-backend");
        info.put("version", "0.1.0");
        info.put("timestamp", OffsetDateTime.now().toString());

        try {
            info.put("cobolBridge", cobolBridge.health());
            info.put("cobolHello", cobolBridge.runProgram("HELLO", Map.of()));
        } catch (Exception ex) {
            info.put("cobolBridge", Map.of("status", "DOWN", "error", ex.getMessage()));
        }
        return info;
    }
}
