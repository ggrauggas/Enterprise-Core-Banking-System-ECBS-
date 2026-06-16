package com.ecbs.account;

import java.util.List;
import java.util.Map;

import com.ecbs.cobol.BankingService;
import com.ecbs.cobol.BridgeException;
import com.ecbs.transaction.Transaction;
import com.ecbs.transaction.TransactionRepository;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/accounts")
@Tag(name = "Accounts", description = "Account opening, closing and inquiry")
public class AccountController {

    private final AccountRepository repo;
    private final TransactionRepository transactions;
    private final BankingService banking;

    public AccountController(AccountRepository repo, TransactionRepository transactions,
                             BankingService banking) {
        this.repo = repo;
        this.transactions = transactions;
        this.banking = banking;
    }

    @GetMapping
    @Operation(summary = "List accounts, optionally filtered by customer or status")
    public List<Account> list(@RequestParam(required = false) Long customerId,
                              @RequestParam(required = false) Account.Status status) {
        List<Account> base = customerId != null
                ? repo.findByCustomerId(customerId)
                : repo.findAll();
        if (status != null) {
            return base.stream().filter(a -> a.getStatus() == status).toList();
        }
        return base;
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get one account by id")
    public Account get(@PathVariable Long id) {
        return repo.findById(id)
                .orElseThrow(() -> new BridgeException(HttpStatus.NOT_FOUND, "E004",
                        "Account " + id + " not found"));
    }

    @GetMapping("/{id}/transactions")
    @Operation(summary = "Movement history of an account (read model)")
    public List<Transaction> movements(@PathVariable Long id) {
        get(id);
        return transactions.findByAccountIdOrderByTimestampDesc(id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Open an account (COBOL ACCT-OPEN, IBAN generated)")
    public Account open(@Valid @RequestBody OpenRequest req,
                        @RequestHeader(value = "X-ECBS-User", required = false) String user) {
        Map<String, Object> p = banking.payload(user);
        p.put("customerId", req.customerId());
        p.put("accountType", req.accountType().name());
        Map<String, Object> data = banking.execute("ACCT-OPEN", p);
        return fetch(BankingService.asLong(data.get("accountId")));
    }

    @PostMapping("/{id}/close")
    @Operation(summary = "Close an account (COBOL ACCT-CLOSE, balance must be zero)")
    public Account close(@PathVariable Long id,
                         @RequestHeader(value = "X-ECBS-User", required = false) String user) {
        Map<String, Object> p = banking.payload(user);
        p.put("accountId", id);
        banking.execute("ACCT-CLOSE", p);
        return fetch(id);
    }

    private Account fetch(Long id) {
        return repo.findById(id).orElseThrow(() ->
                new BridgeException(HttpStatus.INTERNAL_SERVER_ERROR, "E010",
                        "Account " + id + " not found after operation"));
    }

    public record OpenRequest(
            @NotNull Long customerId,
            @NotNull Account.Type accountType) {
    }
}
