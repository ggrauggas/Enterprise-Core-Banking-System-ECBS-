package com.ecbs.transaction;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import com.ecbs.cobol.BankingService;
import com.ecbs.cobol.BridgeException;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

/** Web-layer tests for deposits, withdrawals and transfers. */
@WebMvcTest(TransactionController.class)
class TransactionControllerTest {

    @Autowired
    private MockMvc mvc;

    @MockBean
    private TransactionRepository repo;

    @MockBean
    private BankingService banking;

    @BeforeEach
    void stubPayload() {
        when(banking.payload(any())).thenReturn(new HashMap<>());
    }

    @Test
    void historyByAccount() throws Exception {
        when(repo.findByAccountIdOrderByTimestampDesc(4L)).thenReturn(List.of(new Transaction()));
        mvc.perform(get("/api/v1/transactions").param("accountId", "4"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1));
    }

    @Test
    void depositReturns201() throws Exception {
        when(banking.execute(eq("TXN-DEPOSIT"), any())).thenReturn(Map.of("transactionId", 1));
        mvc.perform(post("/api/v1/transactions/deposits").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"accountId\":1,\"amount\":50.00,\"description\":\"salary\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.transactionId").value(1));
    }

    @Test
    void withdrawWithInsufficientFundsMapsTo422() throws Exception {
        when(banking.execute(eq("TXN-WITHDRAW"), any()))
                .thenThrow(new BridgeException(HttpStatus.UNPROCESSABLE_ENTITY, "E005", "INSUFFICIENT FUNDS"));
        mvc.perform(post("/api/v1/transactions/withdrawals").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"accountId\":1,\"amount\":9999.00}"))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.errorCode").value("E005"));
    }

    @Test
    void negativeAmountRejectedByValidation() throws Exception {
        mvc.perform(post("/api/v1/transactions/deposits").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"accountId\":1,\"amount\":-5.00}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("VALIDATION"));
    }

    @Test
    void transferReturns201() throws Exception {
        when(banking.execute(eq("TXN-TRANSFER"), any())).thenReturn(Map.of("status", "OK"));
        mvc.perform(post("/api/v1/transactions/transfers").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"fromAccountId\":1,\"toAccountId\":2,\"amount\":25.00,\"description\":\"rent\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("OK"));
    }
}
