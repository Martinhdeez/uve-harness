# <NN> — Requirements and verification

Acceptance is decided by tests whose author has not seen the implementation.

## Requirements

One testable sentence each. A requirement states a behaviour and the surface it is checked
through; it never names an internal function.

| Id | Requirement | Checked through |
|---|---|---|
| REQ-XX1-1 | <A customer who … gets …> | <route / exported function / screen> |

## What is verified, and how

| Surface | Items | Check | Test branch |
|---|---|---|---|
| <HTTP API> | XX1 | acceptance tests on the routes | `test/<slug>` |

## Closed to the test author

<The implementation paths and the builder's unit tests the test author must not read.>
