package com.ecbs.system;

import java.util.Map;

import com.ecbs.account.AccountRepository;
import com.ecbs.audit.AuditLogRepository;
import com.ecbs.batch.BatchRunRepository;
import com.ecbs.card.CardRepository;
import com.ecbs.cobol.CobolBridgeClient;
import com.ecbs.customer.CustomerRepository;
import com.ecbs.loan.LoanRepository;
import com.ecbs.transaction.TransactionRepository;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.web.servlet.MockMvc;

/** Web-layer tests for the system info / model-stats smoke endpoints. */
@WebMvcTest(SystemController.class)
class SystemControllerTest {

    @Autowired
    private MockMvc mvc;

    @MockBean private CobolBridgeClient bridge;
    @MockBean private CustomerRepository customers;
    @MockBean private AccountRepository accounts;
    @MockBean private TransactionRepository transactions;
    @MockBean private CardRepository cards;
    @MockBean private LoanRepository loans;
    @MockBean private AuditLogRepository auditLogs;
    @MockBean private BatchRunRepository batchRuns;

    @Test
    void modelStatsAggregatesCounts() throws Exception {
        when(customers.count()).thenReturn(3L);
        when(accounts.count()).thenReturn(5L);
        when(transactions.count()).thenReturn(9L);
        when(cards.count()).thenReturn(2L);
        when(loans.count()).thenReturn(1L);
        when(auditLogs.count()).thenReturn(20L);
        when(batchRuns.count()).thenReturn(4L);
        mvc.perform(get("/api/v1/system/model-stats"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.customers").value(3))
                .andExpect(jsonPath("$.auditLogs").value(20));
    }

    @Test
    void infoReportsBridgeUpWhenReachable() throws Exception {
        when(bridge.health()).thenReturn(Map.of("status", "UP"));
        when(bridge.runProgram(any(), anyMap())).thenReturn(Map.of("data", Map.of("greeting", "hi")));
        mvc.perform(get("/api/v1/system/info"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.service").value("ecbs-backend"))
                .andExpect(jsonPath("$.cobolBridge.status").value("UP"));
    }

    @Test
    void infoReportsBridgeDownOnFailure() throws Exception {
        when(bridge.health()).thenThrow(new RuntimeException("connection refused"));
        mvc.perform(get("/api/v1/system/info"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.cobolBridge.status").value("DOWN"));
    }
}
