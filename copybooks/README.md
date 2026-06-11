# Copybooks

Estructuras de datos COBOL compartidas entre programas (equivalente a DTOs).

Se crean en la **Fase 3** (Framework COBOL): `CUSTOMER.cpy`, `ACCOUNT.cpy`,
`TRANSACTION.cpy`, `CARD.cpy`, `LOAN.cpy`, `AUDIT.cpy`, etc.

El compilador las resuelve con `cobc -I copybooks/`.
