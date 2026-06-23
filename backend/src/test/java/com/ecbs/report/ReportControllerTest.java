package com.ecbs.report;

import java.util.HashMap;
import java.util.Map;

import com.ecbs.cobol.BankingService;
import com.ecbs.cobol.BridgeException;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.HttpStatus;
import org.springframework.test.web.servlet.MockMvc;

/** Web-layer tests for the reporting endpoints. */
@WebMvcTest(ReportController.class)
class ReportControllerTest {

    @Autowired
    private MockMvc mvc;

    @MockBean
    private BankingService banking;

    @BeforeEach
    void stubPayload() {
        when(banking.payload(any())).thenReturn(new HashMap<>());
    }

    @Test
    void bankReport() throws Exception {
        when(banking.execute(eq("RPT-BANK"), any())).thenReturn(Map.of("totalCustomers", 10));
        mvc.perform(get("/api/v1/reports/bank"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalCustomers").value(10));
    }

    @Test
    void customerReport() throws Exception {
        when(banking.execute(eq("RPT-CUSTOMER"), argThat(p -> p.containsKey("customerId"))))
                .thenReturn(Map.of("customerId", 3));
        mvc.perform(get("/api/v1/reports/customers/3"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.customerId").value(3));
    }

    @Test
    void customerReportMissingMapsTo404() throws Exception {
        when(banking.execute(eq("RPT-CUSTOMER"), any()))
                .thenThrow(new BridgeException(HttpStatus.NOT_FOUND, "E004", "CUSTOMER NOT FOUND"));
        mvc.perform(get("/api/v1/reports/customers/999"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("E004"));
    }

    @Test
    void accountReportWithLimit() throws Exception {
        when(banking.execute(eq("RPT-ACCOUNT"), argThat(p ->
                p.containsKey("accountId") && p.containsKey("limit"))))
                .thenReturn(Map.of("accountId", 5));
        mvc.perform(get("/api/v1/reports/accounts/5").param("limit", "20"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accountId").value(5));
    }

    @Test
    void accountReportWithoutLimit() throws Exception {
        when(banking.execute(eq("RPT-ACCOUNT"), any())).thenReturn(Map.of("accountId", 5));
        mvc.perform(get("/api/v1/reports/accounts/5"))
                .andExpect(status().isOk());
    }
}
