package com.ecbs.common;

import java.time.OffsetDateTime;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.stream.Collectors;

import com.ecbs.cobol.BridgeException;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * Turns exceptions into a consistent JSON problem body for the whole
 * API: {@code {timestamp, status, errorCode, message, details?}}.
 */
@RestControllerAdvice
public class ApiExceptionHandler {

    @ExceptionHandler(BridgeException.class)
    public ResponseEntity<Map<String, Object>> handleBridge(BridgeException ex) {
        return body(ex.getStatus(), ex.getErrorCode(), ex.getMessage(), null);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> handleValidation(MethodArgumentNotValidException ex) {
        String details = ex.getBindingResult().getFieldErrors().stream()
                .map(fe -> fe.getField() + ": " + fe.getDefaultMessage())
                .collect(Collectors.joining("; "));
        return body(HttpStatus.BAD_REQUEST, "VALIDATION", "Request validation failed", details);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleOther(Exception ex) {
        return body(HttpStatus.INTERNAL_SERVER_ERROR, "INTERNAL", ex.getMessage(), null);
    }

    private ResponseEntity<Map<String, Object>> body(HttpStatus status, String code,
                                                     String message, String details) {
        Map<String, Object> problem = new LinkedHashMap<>();
        problem.put("timestamp", OffsetDateTime.now().toString());
        problem.put("status", status.value());
        problem.put("errorCode", code);
        problem.put("message", message);
        if (details != null) {
            problem.put("details", details);
        }
        return ResponseEntity.status(status).body(problem);
    }
}
