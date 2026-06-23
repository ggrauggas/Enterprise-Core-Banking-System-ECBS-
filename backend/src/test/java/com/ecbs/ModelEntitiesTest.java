package com.ecbs;

import java.lang.reflect.Method;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;

import com.ecbs.account.Account;
import com.ecbs.audit.AuditLog;
import com.ecbs.batch.BatchRun;
import com.ecbs.card.Card;
import com.ecbs.customer.Customer;
import com.ecbs.loan.Loan;
import com.ecbs.transaction.Transaction;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

/**
 * Exercises the JPA domain entities: their accessors and the
 * package-private {@code @PrePersist}/{@code @PreUpdate} lifecycle
 * callbacks (invoked reflectively, as JPA would).
 */
class ModelEntitiesTest {

    private static void invoke(Object entity, String method) throws Exception {
        Method m = entity.getClass().getDeclaredMethod(method);
        m.setAccessible(true);
        m.invoke(entity);
    }

    @Test
    void customerAccessorsAndLifecycle() throws Exception {
        Customer c = new Customer();
        c.setFirstName("Ada");
        c.setLastName("Lovelace");
        c.setBirthDate(LocalDate.of(1990, 1, 1));
        c.setEmail("ada@ecbs.com");
        c.setPhone("+34600111222");
        c.setStatus(Customer.Status.INACTIVE);
        invoke(c, "onCreate");
        invoke(c, "onUpdate");

        assertThat(c.getFirstName()).isEqualTo("Ada");
        assertThat(c.getLastName()).isEqualTo("Lovelace");
        assertThat(c.getBirthDate()).isEqualTo(LocalDate.of(1990, 1, 1));
        assertThat(c.getEmail()).isEqualTo("ada@ecbs.com");
        assertThat(c.getPhone()).isEqualTo("+34600111222");
        assertThat(c.getStatus()).isEqualTo(Customer.Status.INACTIVE);
        assertThat(c.getCustomerId()).isNull();
        assertThat(c.getCreatedAt()).isNotNull();
        assertThat(c.getUpdatedAt()).isAfterOrEqualTo(c.getCreatedAt());
    }

    @Test
    void accountAccessorsAndLifecycle() throws Exception {
        Account a = new Account();
        a.setIban("ES7600000000000000000000");
        a.setCustomerId(1L);
        a.setBalance(new BigDecimal("250.00"));
        a.setAccountType(Account.Type.SAVINGS);
        a.setStatus(Account.Status.CLOSED);
        invoke(a, "onCreate");

        assertThat(a.getIban()).startsWith("ES");
        assertThat(a.getCustomerId()).isEqualTo(1L);
        assertThat(a.getBalance()).isEqualByComparingTo("250.00");
        assertThat(a.getAccountType()).isEqualTo(Account.Type.SAVINGS);
        assertThat(a.getStatus()).isEqualTo(Account.Status.CLOSED);
        assertThat(a.getCreatedAt()).isNotNull();
        assertThat(a.getAccountId()).isNull();
    }

    @Test
    void cardAccessorsAndLifecycle() throws Exception {
        Card card = new Card();
        card.setAccountId(2L);
        card.setCardNumber("4111111111111111");
        card.setCreditLimit(new BigDecimal("1500.00"));
        card.setAvailableCredit(new BigDecimal("1200.00"));
        card.setStatus(Card.Status.BLOCKED);
        invoke(card, "onCreate");

        assertThat(card.getAccountId()).isEqualTo(2L);
        assertThat(card.getCardNumber()).isEqualTo("4111111111111111");
        assertThat(card.getCreditLimit()).isEqualByComparingTo("1500.00");
        assertThat(card.getAvailableCredit()).isEqualByComparingTo("1200.00");
        assertThat(card.getStatus()).isEqualTo(Card.Status.BLOCKED);
        assertThat(card.getCreatedAt()).isNotNull();
        assertThat(card.getCardId()).isNull();
    }

    @Test
    void loanAccessorsAndLifecycle() throws Exception {
        Loan l = new Loan();
        l.setCustomerId(3L);
        l.setAmount(new BigDecimal("10000.00"));
        l.setInterestRate(new BigDecimal("5.50"));
        l.setDurationMonths(24);
        l.setStatus(Loan.Status.APPROVED);
        invoke(l, "onCreate");

        assertThat(l.getCustomerId()).isEqualTo(3L);
        assertThat(l.getAmount()).isEqualByComparingTo("10000.00");
        assertThat(l.getInterestRate()).isEqualByComparingTo("5.50");
        assertThat(l.getDurationMonths()).isEqualTo(24);
        assertThat(l.getStatus()).isEqualTo(Loan.Status.APPROVED);
        assertThat(l.getCreatedAt()).isNotNull();
        assertThat(l.getLoanId()).isNull();
    }

    @Test
    void transactionAccessorsAndLifecycle() throws Exception {
        Transaction t = new Transaction();
        t.setAccountId(4L);
        t.setTransactionType(Transaction.Type.TRANSFER_OUT);
        t.setAmount(new BigDecimal("75.00"));
        t.setDescription("rent");
        t.setRelatedAccountId(5L);
        invoke(t, "onCreate"); // sets timestamp when null
        OffsetDateTime auto = t.getTimestamp();
        assertThat(auto).isNotNull();
        t.setTimestamp(auto); // explicit value is kept
        invoke(t, "onCreate");

        assertThat(t.getAccountId()).isEqualTo(4L);
        assertThat(t.getTransactionType()).isEqualTo(Transaction.Type.TRANSFER_OUT);
        assertThat(t.getAmount()).isEqualByComparingTo("75.00");
        assertThat(t.getDescription()).isEqualTo("rent");
        assertThat(t.getRelatedAccountId()).isEqualTo(5L);
        assertThat(t.getTimestamp()).isEqualTo(auto);
        assertThat(t.getTransactionId()).isNull();
    }

    @Test
    void auditLogAccessorsAndLifecycle() throws Exception {
        AuditLog a = new AuditLog();
        a.setUsername("admin");
        a.setOperation("UPDATE");
        a.setEntityType("CUSTOMER");
        a.setEntityId(7L);
        a.setOldValue("{\"status\":\"ACTIVE\"}");
        a.setNewValue("{\"status\":\"INACTIVE\"}");
        invoke(a, "onCreate");
        OffsetDateTime auto = a.getEventTime();
        a.setEventTime(auto);

        assertThat(a.getUsername()).isEqualTo("admin");
        assertThat(a.getOperation()).isEqualTo("UPDATE");
        assertThat(a.getEntityType()).isEqualTo("CUSTOMER");
        assertThat(a.getEntityId()).isEqualTo(7L);
        assertThat(a.getOldValue()).contains("ACTIVE");
        assertThat(a.getNewValue()).contains("INACTIVE");
        assertThat(a.getEventTime()).isNotNull();
        assertThat(a.getAuditId()).isNull();
    }

    @Test
    void batchRunAccessorsAndLifecycle() throws Exception {
        BatchRun b = new BatchRun();
        b.setRunDate(LocalDate.of(2026, 6, 21));
        b.setStatus(BatchRun.Status.SUCCESS);
        b.setProcessedCount(120);
        b.setErrorCount(2);
        b.setSummary("nightly ok");
        invoke(b, "onCreate");
        OffsetDateTime finished = OffsetDateTime.now();
        b.setFinishedAt(finished);

        assertThat(b.getRunDate()).isEqualTo(LocalDate.of(2026, 6, 21));
        assertThat(b.getStatus()).isEqualTo(BatchRun.Status.SUCCESS);
        assertThat(b.getProcessedCount()).isEqualTo(120);
        assertThat(b.getErrorCount()).isEqualTo(2);
        assertThat(b.getSummary()).isEqualTo("nightly ok");
        assertThat(b.getStartedAt()).isNotNull();
        assertThat(b.getFinishedAt()).isEqualTo(finished);
        assertThat(b.getBatchRunId()).isNull();
    }
}
