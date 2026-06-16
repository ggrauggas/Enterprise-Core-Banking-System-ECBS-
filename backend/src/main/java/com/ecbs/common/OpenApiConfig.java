package com.ecbs.common;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.License;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * OpenAPI / Swagger metadata. The interactive docs are served at
 * /swagger-ui.html and the spec at /v3/api-docs.
 */
@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI ecbsOpenApi() {
        return new OpenAPI().info(new Info()
                .title("ECBS API")
                .version("1.0")
                .description("""
                        Enterprise Core Banking System REST API.

                        Read operations are served from the JPA read model;
                        every business operation (create/update/delete,
                        deposits, transfers, card and loan operations) is
                        dispatched to the COBOL business layer through the
                        bridge, which owns the rules and the audit trail.""")
                .contact(new Contact().name("ECBS").email("gerardgrau2004@gmail.com"))
                .license(new License().name("Internal")));
    }
}
