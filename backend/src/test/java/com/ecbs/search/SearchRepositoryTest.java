package com.ecbs.search;

import java.math.BigDecimal;
import java.time.LocalDate;

import com.ecbs.account.Account;
import com.ecbs.account.AccountRepository;
import com.ecbs.card.Card;
import com.ecbs.card.CardRepository;
import com.ecbs.customer.Customer;
import com.ecbs.customer.CustomerRepository;
import com.ecbs.loan.Loan;
import com.ecbs.loan.LoanRepository;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.data.domain.PageRequest;
import org.springframework.test.context.TestPropertySource;

/**
 * Exercises the paginated search queries against a real (embedded) database so
 * the {@code @Query} HQL — including {@code CAST(... AS string)} id matching and
 * the nullable filter parameters — is actually parsed and executed.
 */
@DataJpaTest
@TestPropertySource(properties = "spring.jpa.hibernate.ddl-auto=create-drop")
class SearchRepositoryTest {

    @Autowired private CustomerRepository customers;
    @Autowired private AccountRepository accounts;
    @Autowired private CardRepository cards;
    @Autowired private LoanRepository loans;

    private Customer customer(String first, String last, String email, String phone, Customer.Status status) {
        Customer c = new Customer();
        c.setFirstName(first);
        c.setLastName(last);
        c.setBirthDate(LocalDate.of(1990, 1, 1));
        c.setEmail(email);
        c.setPhone(phone);
        c.setStatus(status);
        return c;
    }

    private Account account(String iban, long customerId, Account.Status status) {
        Account a = new Account();
        a.setIban(iban);
        a.setCustomerId(customerId);
        a.setAccountType(Account.Type.CHECKING);
        a.setStatus(status);
        a.setBalance(new BigDecimal("100.00"));
        return a;
    }

    private Card card(String number, long accountId, Card.Status status) {
        Card c = new Card();
        c.setAccountId(accountId);
        c.setCardNumber(number);
        c.setCreditLimit(new BigDecimal("1000.00"));
        c.setAvailableCredit(new BigDecimal("1000.00"));
        c.setStatus(status);
        return c;
    }

    private Loan loan(long customerId, Loan.Status status) {
        Loan l = new Loan();
        l.setCustomerId(customerId);
        l.setAmount(new BigDecimal("5000.00"));
        l.setInterestRate(new BigDecimal("5.00"));
        l.setDurationMonths(24);
        l.setStatus(status);
        return l;
    }

    @Test
    void customerSearchHidesDeletedFiltersAndPaginates() {
        customers.save(customer("Ada", "Lovelace", "ada@ecbs.sim", "+34600000001", Customer.Status.ACTIVE));
        customers.save(customer("Alan", "Turing", "alan@ecbs.sim", "+34600000002", Customer.Status.ACTIVE));
        customers.save(customer("Grace", "Hopper", "grace@ecbs.sim", "+34600000003", Customer.Status.INACTIVE));
        customers.save(customer("Old", "Record", "old@ecbs.sim", "+34600000004", Customer.Status.DELETED));

        // DELETED hidden in the default view.
        assertThat(customers.searchByStatusNot(Customer.Status.DELETED, null, PageRequest.of(0, 10))
                .getTotalElements()).isEqualTo(3);

        // Text term matches a single surname.
        var byTerm = customers.searchByStatusNot(Customer.Status.DELETED, "%lov%", PageRequest.of(0, 10));
        assertThat(byTerm.getContent()).hasSize(1);
        assertThat(byTerm.getContent().get(0).getLastName()).isEqualTo("Lovelace");

        // Status filter + page size honoured.
        var active = customers.searchByStatus(Customer.Status.ACTIVE, null, PageRequest.of(0, 1));
        assertThat(active.getTotalElements()).isEqualTo(2);
        assertThat(active.getContent()).hasSize(1);
    }

    @Test
    void accountSearchByTermIdAndFilters() {
        Account a = accounts.save(account("ES0000000000000000000001", 1L, Account.Status.ACTIVE));
        accounts.save(account("ES0000000000000000000002", 1L, Account.Status.CLOSED));
        accounts.save(account("ES9900000000000000000099", 2L, Account.Status.ACTIVE));

        // IBAN substring.
        assertThat(accounts.search(null, null, "%000099%", PageRequest.of(0, 10)).getTotalElements())
                .isEqualTo(1);
        // Match by generated id via CAST(... AS string).
        assertThat(accounts.search(null, null, "%" + a.getAccountId() + "%", PageRequest.of(0, 10))
                .getContent()).isNotEmpty();
        // customerId + status filters.
        assertThat(accounts.search(1L, Account.Status.ACTIVE, null, PageRequest.of(0, 10)).getTotalElements())
                .isEqualTo(1);
        // No filters returns everything.
        assertThat(accounts.search(null, null, null, PageRequest.of(0, 10)).getTotalElements()).isEqualTo(3);
    }

    @Test
    void cardSearchByNumberAccountAndStatus() {
        cards.save(card("5111111111111111", 10L, Card.Status.ACTIVE));
        cards.save(card("5222222222222222", 10L, Card.Status.BLOCKED));
        cards.save(card("5333333333333333", 20L, Card.Status.ACTIVE));

        assertThat(cards.search(null, null, "%2222%", PageRequest.of(0, 10)).getTotalElements()).isEqualTo(1);
        assertThat(cards.search(10L, null, null, PageRequest.of(0, 10)).getTotalElements()).isEqualTo(2);
        assertThat(cards.search(null, Card.Status.ACTIVE, null, PageRequest.of(0, 10)).getTotalElements())
                .isEqualTo(2);
    }

    @Test
    void loanSearchByCustomerStatusAndId() {
        Loan l = loans.save(loan(100L, Loan.Status.REQUESTED));
        loans.save(loan(100L, Loan.Status.APPROVED));
        loans.save(loan(200L, Loan.Status.REQUESTED));

        assertThat(loans.search(100L, null, null, PageRequest.of(0, 10)).getTotalElements()).isEqualTo(2);
        assertThat(loans.search(null, Loan.Status.REQUESTED, null, PageRequest.of(0, 10)).getTotalElements())
                .isEqualTo(2);
        assertThat(loans.search(null, null, "%" + l.getLoanId() + "%", PageRequest.of(0, 10)).getContent())
                .isNotEmpty();
    }
}
