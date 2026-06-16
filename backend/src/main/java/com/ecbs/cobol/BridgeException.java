package com.ecbs.cobol;

import org.springframework.http.HttpStatus;

/**
 * Raised when a COBOL program returns a business error envelope
 * ({@code {"status":"ERROR","errorCode":"Exxx","message":"..."}}) or
 * when the bridge itself fails. Carries the ECBS error code and the
 * HTTP status it maps to, so the API can answer with a faithful
 * problem response instead of a generic 500.
 */
public class BridgeException extends RuntimeException {

    private final HttpStatus status;
    private final String errorCode;

    public BridgeException(HttpStatus status, String errorCode, String message) {
        super(message);
        this.status = status;
        this.errorCode = errorCode;
    }

    public HttpStatus getStatus() {
        return status;
    }

    public String getErrorCode() {
        return errorCode;
    }
}
