package com.ecbs.customer;

import java.util.List;
import java.util.Optional;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CustomerRepository extends JpaRepository<Customer, Long> {

    Optional<Customer> findByEmail(String email);

    boolean existsByEmail(String email);

    List<Customer> findByStatus(Customer.Status status);

    List<Customer> findByStatusNot(Customer.Status status);

    /**
     * Paged search by an optional text term ({@code q}, already lower-cased and
     * wrapped in {@code %…%}, or {@code null}) restricted to a single status.
     */
    @Query("""
            SELECT c FROM Customer c
            WHERE c.status = :status
              AND (:q IS NULL
                   OR LOWER(c.firstName) LIKE :q
                   OR LOWER(c.lastName) LIKE :q
                   OR LOWER(c.email) LIKE :q
                   OR c.phone LIKE :q
                   OR CAST(c.customerId AS string) LIKE :q)
            """)
    Page<Customer> searchByStatus(@Param("status") Customer.Status status,
                                  @Param("q") String q, Pageable pageable);

    /** Paged search excluding a status (used to hide DELETED in the default view). */
    @Query("""
            SELECT c FROM Customer c
            WHERE c.status <> :status
              AND (:q IS NULL
                   OR LOWER(c.firstName) LIKE :q
                   OR LOWER(c.lastName) LIKE :q
                   OR LOWER(c.email) LIKE :q
                   OR c.phone LIKE :q
                   OR CAST(c.customerId AS string) LIKE :q)
            """)
    Page<Customer> searchByStatusNot(@Param("status") Customer.Status status,
                                     @Param("q") String q, Pageable pageable);
}
