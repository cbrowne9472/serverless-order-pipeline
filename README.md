# Serverless Event-Driven Order Pipeline

A fully serverless, event-driven backend that processes e-commerce orders through an automated multi-stage pipeline. No servers. No polling. Every stage reacts to events from the previous stage.

## What It Does

Customer places an order → the system validates it, checks inventory, processes payment, and sends a confirmation email — all asynchronously, all without a running server.

## Architecture

```
Customer
    │
    ▼
API Gateway
    │  POST /orders
    ▼
Lambda: Order Intake
    │  • validates request shape
    │  • saves order to DynamoDB (status: PENDING)
    │  • returns order_id immediately (<100ms)
    ▼
DynamoDB (orders table)
    │
    │  DynamoDB Stream fires on INSERT
    ▼
EventBridge (orchestrator)
    │
    ├──────────────────┬──────────────────┐
    ▼                  ▼                  ▼
Lambda             Lambda             Lambda
(Validate)        (Inventory)        (Payment)
    │                  │                  │
    │  OrderValidated  │  InventoryReserved│  PaymentConfirmed
    │─────────────────►│─────────────────►│────────────────►
    │                  │                  │
    ▼                  ▼                  ▼
 SQS DLQ           SQS DLQ          Stripe API (test)
(on failure)      (on failure)
                                          │
                                          ▼
                                   SNS Topic (fan-out)
                                     ├──────────────┐
                                     ▼              ▼
                              Lambda (Email)  Lambda (Warehouse)
                                     │
                                     ▼
                                    SES
                             (confirmation email)
```

## Tech Stack

| Layer | Service | Purpose |
|-------|---------|---------|
| Entry point | API Gateway + Lambda | Receive and acknowledge orders |
| Storage | DynamoDB | Order state, inventory counts |
| Event trigger | DynamoDB Streams | Fire events on record changes |
| Orchestration | EventBridge | Route events between pipeline stages |
| Buffering | SQS + DLQ | Decouple stages, catch failures |
| Notifications | SNS + SES | Fan-out + confirmation emails |
| Payments | Stripe API (test mode) | Real payment processing |
| Observability | CloudWatch + X-Ray | Logs, dashboards, distributed traces |
| Infrastructure | Terraform | All resources as code |
| Frontend | React | Admin dashboard with live order feed |

## Pipeline Stages

### Stage 1 — Order Intake
`POST /orders` → API Gateway → Lambda  
Validates request format, writes order to DynamoDB with `status: PENDING`, returns `order_id` in under 100ms. Everything after this is async.

### Stage 2 — DynamoDB Stream → EventBridge
DynamoDB Streams fires automatically on every `INSERT`. No polling. The stream event is routed to EventBridge, which dispatches it to the validation stage.

### Stage 3 — Validation
Checks item existence, address validity, quantity bounds. On failure: writes `VALIDATION_FAILED` to DynamoDB, drops message to DLQ. On success: publishes `OrderValidated` event.

### Stage 4 — Inventory
Receives `OrderValidated`. Checks stock in DynamoDB and decrements atomically using **conditional writes** — prevents two orders from claiming the last item simultaneously. Publishes `InventoryReserved`.

### Stage 5 — Payment
Receives `InventoryReserved`. Calls Stripe API in test mode. On failure: publishes `PaymentFailed` → inventory released. On success: publishes `PaymentConfirmed`.

### Stage 6 — Notification
Receives `PaymentConfirmed`. SNS fans out to:
- **SES** → confirmation email to customer
- **Warehouse Lambda** → simulates fulfillment notification

### Fault Tolerance
Every Lambda has an SQS dead-letter queue. After 3 failed attempts, the message lands in the DLQ instead of disappearing silently. CloudWatch alarms fire whenever DLQ depth exceeds 0.

## Repo Structure

```
serverless-order-pipeline/
├── README.md
├── architecture/
│   └── diagram.png
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── lambda/
│       ├── queues/
│       ├── eventbridge/
│       ├── database/
│       └── notifications/
│   └── environments/
│       ├── dev/
│       ├── staging/
│       └── prod/
├── services/
│   ├── order-intake/
│   ├── validation/
│   ├── inventory/
│   ├── payment/
│   └── notification/
├── frontend/
│   └── (React admin dashboard)
└── tests/
    ├── unit/
    └── integration/
```

## Prerequisites

- AWS CLI configured (`aws configure`)
- Terraform >= 1.6
- Node.js >= 18
- Python 3.11
- Stripe account (free test mode)

## Deploying

```bash
# Deploy dev environment
cd terraform/environments/dev
terraform init
terraform apply

# Tear down
terraform destroy
```

One command to build everything. One command to tear it down.

## Observability

- **X-Ray** traces the full journey of a single order across all 5 Lambdas
- **CloudWatch Dashboard** — orders/min, failure rate per stage, DLQ depth
- **Alarms** — fires if payment failure rate exceeds 5% or any DLQ depth > 0

## Status

Built in 4 weeks as a portfolio project to demonstrate production-grade serverless architecture patterns.

| Week | Focus |
|------|-------|
| 1 | Foundation — DynamoDB, API Gateway, Order Intake Lambda |
| 2 | Pipeline stages — Validation, Inventory, Payment |
| 3 | Notifications, X-Ray tracing, CloudWatch alarms |
| 4 | React dashboard, deployment, smoke testing |
