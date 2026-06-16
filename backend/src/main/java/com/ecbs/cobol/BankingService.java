package com.ecbs.cobol;

import java.util.HashMap;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * Thin service that dispatches business operations to the COBOL layer
 * through the bridge and turns the COBOL result envelope into either a
 * data map (success) or a {@link BridgeException} (business error).
 *
 * The backend never runs COBOL binaries directly: it always goes
 * through the bridge, the same way a middleware would route to a
 * transaction monitor.
 */
@Service
public class BankingService {

    private final CobolBridgeClient bridge;

    public BankingService(CobolBridgeClient bridge) {
        this.bridge = bridge;
    }

    /** Runs a COBOL program; returns its {@code data} object or throws. */
    @SuppressWarnings("unchecked")
    public Map<String, Object> execute(String program, Map<String, Object> payload) {
        Map<String, Object> response;
        try {
            response = bridge.runProgram(program, payload);
        } catch (Exception ex) {
            throw new BridgeException(HttpStatus.BAD_GATEWAY, "BRIDGE",
                    "COBOL bridge call failed: " + ex.getMessage());
        }

        Object data = response == null ? null : response.get("data");
        if (!(data instanceof Map)) {
            String stderr = response == null ? "" : String.valueOf(response.get("stderr"));
            throw new BridgeException(HttpStatus.BAD_GATEWAY, "BRIDGE",
                    "COBOL program " + program + " returned no parseable result. " + stderr);
        }

        Map<String, Object> result = (Map<String, Object>) data;
        if ("ERROR".equals(result.get("status"))) {
            String code = String.valueOf(result.get("errorCode"));
            String message = String.valueOf(result.get("message"));
            throw new BridgeException(httpStatusFor(code), code, message);
        }
        return result;
    }

    /** Reads a numeric field returned by a COBOL program as a long. */
    public static long asLong(Object value) {
        return ((Number) value).longValue();
    }

    /** Builds a mutable payload pre-loaded with the auditing user. */
    public Map<String, Object> payload(String user) {
        Map<String, Object> payload = new HashMap<>();
        if (user != null && !user.isBlank()) {
            payload.put("user", user);
        }
        return payload;
    }

    /** Maps an ECBS error code to the HTTP status that best describes it. */
    private HttpStatus httpStatusFor(String code) {
        return switch (code) {
            // validation / malformed input
            case "E001", "E002", "E011", "E012", "E013", "E015", "E018" ->
                    HttpStatus.BAD_REQUEST;
            // entity not found
            case "E004" -> HttpStatus.NOT_FOUND;
            // state conflicts
            case "E003", "E007", "E014", "E016", "E017", "E019", "E020", "E022" ->
                    HttpStatus.CONFLICT;
            // business rule rejections
            case "E005", "E008", "E009", "E021" -> HttpStatus.UNPROCESSABLE_ENTITY;
            // internal / SQL
            default -> HttpStatus.INTERNAL_SERVER_ERROR;
        };
    }
}
