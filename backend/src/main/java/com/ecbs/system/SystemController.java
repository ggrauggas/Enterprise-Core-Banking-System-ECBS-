package com.ecbs.system;

import java.time.OffsetDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

import com.ecbs.account.AccountRepository;
import com.ecbs.audit.AuditLogRepository;
import com.ecbs.batch.BatchRunRepository;
import com.ecbs.card.CardRepository;
import com.ecbs.cobol.CobolBridgeClient;
import com.ecbs.customer.CustomerRepository;
import com.ecbs.loan.LoanRepository;
import com.ecbs.transaction.TransactionRepository;

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
    private final CustomerRepository customers;
    private final AccountRepository accounts;
    private final TransactionRepository transactions;
    private final CardRepository cards;
    private final LoanRepository loans;
    private final AuditLogRepository auditLogs;
    private final BatchRunRepository batchRuns;

    public SystemController(CobolBridgeClient cobolBridge,
                            CustomerRepository customers,
                            AccountRepository accounts,
                            TransactionRepository transactions,
                            CardRepository cards,
                            LoanRepository loans,
                            AuditLogRepository auditLogs,
                            BatchRunRepository batchRuns) {
        this.cobolBridge = cobolBridge;
        this.customers = customers;
        this.accounts = accounts;
        this.transactions = transactions;
        this.cards = cards;
        this.loans = loans;
        this.auditLogs = auditLogs;
        this.batchRuns = batchRuns;
    }

    /** Row counts per domain table, proving the JPA model maps the schema. */
    @GetMapping("/model-stats")
    public Map<String, Long> modelStats() {
        Map<String, Long> stats = new LinkedHashMap<>();
        stats.put("customers", customers.count());
        stats.put("accounts", accounts.count());
        stats.put("transactions", transactions.count());
        stats.put("cards", cards.count());
        stats.put("loans", loans.count());
        stats.put("auditLogs", auditLogs.count());
        stats.put("batchRuns", batchRuns.count());
        return stats;
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
