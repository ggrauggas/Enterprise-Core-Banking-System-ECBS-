package com.ecbs.common;

import java.util.Map;

import com.ecbs.cobol.BridgeException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.BindingResult;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;

/** Unit tests for the global problem-body exception handler. */
class ApiExceptionHandlerTest {

    private final ApiExceptionHandler handler = new ApiExceptionHandler();

    @Test
    void bridgeExceptionKeepsStatusAndCode() {
        ResponseEntity<Map<String, Object>> res = handler.handleBridge(
                new BridgeException(HttpStatus.CONFLICT, "E003", "DUPLICATE"));
        assertThat(res.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        assertThat(res.getBody()).containsEntry("errorCode", "E003");
        assertThat(res.getBody()).containsEntry("message", "DUPLICATE");
        assertThat(res.getBody()).doesNotContainKey("details");
    }

    @Test
    void validationExceptionJoinsFieldErrors() {
        BindingResult binding = mock(BindingResult.class);
        when(binding.getFieldErrors()).thenReturn(java.util.List.of(
                new FieldError("req", "email", "must not be blank"),
                new FieldError("req", "phone", "invalid")));
        MethodArgumentNotValidException ex = mock(MethodArgumentNotValidException.class);
        when(ex.getBindingResult()).thenReturn(binding);

        ResponseEntity<Map<String, Object>> res = handler.handleValidation(ex);

        assertThat(res.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(res.getBody()).containsEntry("errorCode", "VALIDATION");
        assertThat(res.getBody().get("details").toString())
                .contains("email: must not be blank")
                .contains("phone: invalid");
    }

    @Test
    void unexpectedExceptionBecomes500() {
        ResponseEntity<Map<String, Object>> res = handler.handleOther(new IllegalStateException("boom"));
        assertThat(res.getStatusCode()).isEqualTo(HttpStatus.INTERNAL_SERVER_ERROR);
        assertThat(res.getBody()).containsEntry("errorCode", "INTERNAL");
        assertThat(res.getBody()).containsEntry("message", "boom");
    }
}
