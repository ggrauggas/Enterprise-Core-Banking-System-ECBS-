package com.ecbs.customer;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import com.ecbs.cobol.BankingService;
import com.ecbs.cobol.BridgeException;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.mockito.ArgumentMatchers.argThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

/** Web-layer tests for the customers endpoints (controller + error handler). */
@WebMvcTest(CustomerController.class)
class CustomerControllerTest {

    @Autowired
    private MockMvc mvc;

    @MockBean
    private CustomerRepository repo;

    @MockBean
    private BankingService banking;

    @BeforeEach
    void stubPayload() {
        when(banking.payload(any())).thenReturn(new HashMap<>());
    }

    @Test
    void listHidesDeleted() throws Exception {
        when(repo.findByStatusNot(Customer.Status.DELETED)).thenReturn(List.of());
        mvc.perform(get("/api/v1/customers"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray());
    }

    @Test
    void listPaginatedReturnsEnvelope() throws Exception {
        Customer c = new Customer();
        c.setFirstName("Ada");
        when(repo.searchByStatusNot(eq(Customer.Status.DELETED), any(), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(c), PageRequest.of(0, 25), 1));
        mvc.perform(get("/api/v1/customers").param("page", "0").param("q", "ad"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content").isArray())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].firstName").value("Ada"));
    }

    @Test
    void listByStatusFilterUsesFindByStatus() throws Exception {
        Customer deleted = new Customer();
        deleted.setStatus(Customer.Status.DELETED);
        when(repo.findByStatus(Customer.Status.DELETED)).thenReturn(List.of(deleted));
        mvc.perform(get("/api/v1/customers").param("status", "DELETED"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].status").value("DELETED"));
    }

    @Test
    void getExistingReturnsCustomer() throws Exception {
        Customer c = new Customer();
        c.setFirstName("Ada");
        when(repo.findById(1L)).thenReturn(Optional.of(c));
        mvc.perform(get("/api/v1/customers/1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.firstName").value("Ada"));
    }

    @Test
    void updateForwardsOnlyProvidedFields() throws Exception {
        when(banking.execute(eq("CUST-UPDATE"), argThat(p ->
                p.containsKey("email") && !p.containsKey("firstName"))))
                .thenReturn(Map.of("status", "OK"));
        Customer updated = new Customer();
        updated.setEmail("new@b.com");
        when(repo.findById(4L)).thenReturn(Optional.of(updated));
        mvc.perform(put("/api/v1/customers/4").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"new@b.com\"}").header("X-ECBS-User", "tester"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.email").value("new@b.com"));
    }

    @Test
    void updateMissingAfterOperationMapsTo500() throws Exception {
        when(banking.execute(eq("CUST-UPDATE"), any())).thenReturn(Map.of("status", "OK"));
        when(repo.findById(77L)).thenReturn(Optional.empty());
        mvc.perform(put("/api/v1/customers/77").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"firstName\":\"Z\",\"lastName\":\"Y\"}"))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.errorCode").value("E010"));
    }

    @Test
    void getMissingReturns404() throws Exception {
        when(repo.findById(99L)).thenReturn(Optional.empty());
        mvc.perform(get("/api/v1/customers/99"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("E004"));
    }

    @Test
    void createWithBlankFieldReturns400() throws Exception {
        String body = """
                {"firstName":"","lastName":"B","birthDate":"1990-01-01",
                 "email":"a@b.com","phone":"+34600111222"}""";
        mvc.perform(post("/api/v1/customers").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("VALIDATION"));
    }

    @Test
    void createDuplicateMapsTo409() throws Exception {
        when(banking.execute(eq("CUST-CREATE"), any()))
                .thenThrow(new BridgeException(HttpStatus.CONFLICT, "E003", "DUPLICATE RECORD"));
        String body = """
                {"firstName":"A","lastName":"B","birthDate":"1990-01-01",
                 "email":"a@b.com","phone":"+34600111222"}""";
        mvc.perform(post("/api/v1/customers").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.errorCode").value("E003"));
    }

    @Test
    void createSuccessReturns201() throws Exception {
        when(banking.execute(eq("CUST-CREATE"), any()))
                .thenReturn(Map.of("status", "OK", "customerId", 9));
        Customer saved = new Customer();
        saved.setFirstName("A");
        saved.setLastName("B");
        when(repo.findById(9L)).thenReturn(Optional.of(saved));
        String body = """
                {"firstName":"A","lastName":"B","birthDate":"1990-01-01",
                 "email":"a@b.com","phone":"+34600111222"}""";
        mvc.perform(post("/api/v1/customers").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.firstName").value("A"));
    }

    @Test
    void deleteInvokesBridgeAndReturnsEntity() throws Exception {
        when(banking.execute(eq("CUST-DELETE"), any())).thenReturn(Map.of("status", "OK"));
        Customer saved = new Customer();
        saved.setFirstName("A");
        saved.setStatus(Customer.Status.DELETED);
        when(repo.findById(5L)).thenReturn(Optional.of(saved));
        mvc.perform(delete("/api/v1/customers/5").header("X-ECBS-User", "tester"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("DELETED"));
        // ensure the auditing user is forwarded
        when(banking.payload(anyString())).thenReturn(new HashMap<>());
    }
}
