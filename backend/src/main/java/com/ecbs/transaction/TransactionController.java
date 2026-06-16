package com.ecbs.transaction;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

import com.ecbs.cobol.BankingService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/transactions")
@Tag(name = "Transactions", description = "Deposits, withdrawals and transfers")
public class TransactionController {

    private final TransactionRepository repo;
    private final BankingService banking;

    public TransactionController(TransactionRepository repo, BankingService banking) {
        this.repo = repo;
        this.banking = banking;
    }

    @GetMapping
    @Operation(summary = "Movement history of an account (read model)")
    public List<Transaction> byAccount(@RequestParam Long accountId) {
        return repo.findByAccountIdOrderByTimestampDesc(accountId);
    }

    @PostMapping("/deposits")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Deposit (COBOL TXN-DEPOSIT)")
    public Map<String, Object> deposit(@Valid @RequestBody MovementRequest req,
                                       @RequestHeader(value = "X-ECBS-User", required = false) String user) {
        Map<String, Object> p = banking.payload(user);
        p.put("accountId", req.accountId());
        p.put("amount", req.amount());
        if (req.description() != null) p.put("description", req.description());
        return banking.execute("TXN-DEPOSIT", p);
    }

    @PostMapping("/withdrawals")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Withdrawal (COBOL TXN-WITHDRAW, validates funds)")
    public Map<String, Object> withdraw(@Valid @RequestBody MovementRequest req,
                                        @RequestHeader(value = "X-ECBS-User", required = false) String user) {
        Map<String, Object> p = banking.payload(user);
        p.put("accountId", req.accountId());
        p.put("amount", req.amount());
        if (req.description() != null) p.put("description", req.description());
        return banking.execute("TXN-WITHDRAW", p);
    }

    @PostMapping("/transfers")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Atomic transfer (COBOL TXN-TRANSFER)")
    public Map<String, Object> transfer(@Valid @RequestBody TransferRequest req,
                                        @RequestHeader(value = "X-ECBS-User", required = false) String user) {
        Map<String, Object> p = banking.payload(user);
        p.put("fromAccountId", req.fromAccountId());
        p.put("toAccountId", req.toAccountId());
        p.put("amount", req.amount());
        if (req.description() != null) p.put("description", req.description());
        return banking.execute("TXN-TRANSFER", p);
    }

    public record MovementRequest(
            @NotNull Long accountId,
            @NotNull @Positive BigDecimal amount,
            String description) {
    }

    public record TransferRequest(
            @NotNull Long fromAccountId,
            @NotNull Long toAccountId,
            @NotNull @Positive BigDecimal amount,
            String description) {
    }
}
