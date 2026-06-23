package com.ecbs.customer;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

import com.ecbs.cobol.BankingService;
import com.ecbs.cobol.BridgeException;
import com.ecbs.common.PageResponse;
import com.ecbs.common.Paging;

import org.springframework.data.domain.Page;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/customers")
@Tag(name = "Customers", description = "Customer registration and lifecycle")
public class CustomerController {

    private final CustomerRepository repo;
    private final BankingService banking;

    public CustomerController(CustomerRepository repo, BankingService banking) {
        this.repo = repo;
        this.banking = banking;
    }

    @GetMapping
    @Operation(summary = "List customers; paginated when 'page' is given (DELETED hidden unless status filter)")
    public Object list(@RequestParam(required = false) Customer.Status status,
                       @RequestParam(required = false) String q,
                       @RequestParam(required = false) Integer page,
                       @RequestParam(required = false) Integer size) {
        // Backward-compatible: without 'page' the legacy full List is returned.
        if (page == null) {
            return status != null ? repo.findByStatus(status) : repo.findByStatusNot(Customer.Status.DELETED);
        }
        String q2 = Paging.like(q);
        Page<Customer> result = status != null
                ? repo.searchByStatus(status, q2, Paging.of(page, size, "customerId"))
                : repo.searchByStatusNot(Customer.Status.DELETED, q2, Paging.of(page, size, "customerId"));
        return PageResponse.of(result);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get one customer by id")
    public Customer get(@PathVariable Long id) {
        return repo.findById(id)
                .orElseThrow(() -> new BridgeException(HttpStatus.NOT_FOUND, "E004",
                        "Customer " + id + " not found"));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Register a customer (COBOL CUST-CREATE)")
    public Customer create(@Valid @RequestBody CreateRequest req,
                           @RequestHeader(value = "X-ECBS-User", required = false) String user) {
        Map<String, Object> p = banking.payload(user);
        p.put("firstName", req.firstName());
        p.put("lastName", req.lastName());
        p.put("birthDate", req.birthDate().toString());
        p.put("email", req.email());
        p.put("phone", req.phone());
        Map<String, Object> data = banking.execute("CUST-CREATE", p);
        return fetch(BankingService.asLong(data.get("customerId")));
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update a customer (COBOL CUST-UPDATE)")
    public Customer update(@PathVariable Long id, @RequestBody UpdateRequest req,
                           @RequestHeader(value = "X-ECBS-User", required = false) String user) {
        Map<String, Object> p = banking.payload(user);
        p.put("customerId", id);
        if (req.firstName() != null) p.put("firstName", req.firstName());
        if (req.lastName() != null) p.put("lastName", req.lastName());
        if (req.email() != null) p.put("email", req.email());
        if (req.phone() != null) p.put("phone", req.phone());
        banking.execute("CUST-UPDATE", p);
        return fetch(id);
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Logical delete (COBOL CUST-DELETE)")
    public Customer delete(@PathVariable Long id,
                           @RequestHeader(value = "X-ECBS-User", required = false) String user) {
        Map<String, Object> p = banking.payload(user);
        p.put("customerId", id);
        banking.execute("CUST-DELETE", p);
        return fetch(id);
    }

    private Customer fetch(Long id) {
        return repo.findById(id).orElseThrow(() ->
                new BridgeException(HttpStatus.INTERNAL_SERVER_ERROR, "E010",
                        "Customer " + id + " not found after operation"));
    }

    public record CreateRequest(
            @NotBlank String firstName,
            @NotBlank String lastName,
            @NotNull LocalDate birthDate,
            @NotBlank String email,
            @NotBlank String phone) {
    }

    public record UpdateRequest(
            String firstName,
            String lastName,
            String email,
            String phone) {
    }
}
