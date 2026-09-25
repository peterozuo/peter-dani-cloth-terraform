# AWS Serverless Architecture with Terraform

🎥 **[Watch the Project Walkthrough on Loom](https://www.loom.com/share/b1fd4382463b41309e198d481ed194a6)**

## Project Overview

I built this project around a startup scaling challenge.

Imagine a startup running its application on a single EC2 instance. The application currently handles around 1,000 users without major issues, but the company is preparing for a large marketing campaign and expects traffic to potentially reach 100,000 users over one weekend.

The challenge is to design an architecture that can handle a significant increase in traffic while keeping infrastructure costs low when demand drops.

To address this, I built a serverless AWS architecture using S3, CloudFront, API Gateway, Lambda, DynamoDB, IAM, SNS, and CloudWatch, and used Terraform to provision and manage the infrastructure as code.

## Architecture

The application uses:

- Amazon S3 — hosts the static frontend
- Amazon CloudFront — delivers the frontend through a global content delivery network
- Amazon API Gateway — exposes the backend API
- AWS Lambda — runs the backend application code
- Amazon DynamoDB — stores application data
- AWS IAM — manages permissions and access
- Amazon CloudWatch — monitors the application and Lambda errors
- Amazon SNS — sends alerts when the Lambda function encounters errors
- Terraform — provisions and manages the infrastructure as code

### Request Flow

```text
User
  |
  v
CloudFront
  |
  v
S3
  |
  | Frontend
  v
Browser
  |
  | API Request
  v
API Gateway
  |
  v
Lambda
  |
  v
DynamoDB

CloudWatch monitors the backend and can trigger an SNS notification when the Lambda function encounters an error.

Why Serverless?

The goal of this architecture is to avoid relying on a single EC2 server for the application’s backend.

With Lambda, the backend code is invoked when requests or events occur, allowing the application to handle changing demand without manually managing a fleet of servers.

This makes the architecture suitable for workloads where traffic can vary significantly, such as a marketing campaign or other periods of increased demand.

The project is also designed with cost awareness in mind, using managed services and pay-per-use components where appropriate rather than keeping additional servers running continuously during quiet periods.

Infrastructure as Code

I used Terraform to provision and manage the AWS infrastructure.

Instead of creating each resource manually through the AWS Console, the infrastructure is defined as code and can be recreated consistently.

The Terraform configuration manages:

* S3
* CloudFront
* API Gateway
* Lambda
* DynamoDB
* IAM
* SNS
* CloudWatch

Monitoring and Alerts

CloudWatch is used to monitor the Lambda function.

I configured an alarm that monitors Lambda errors. When an error occurs, the alarm can enter the ALARM state and send a notification through Amazon SNS.

I also tested the monitoring setup by intentionally generating a Lambda error and verifying that the CloudWatch alarm and SNS notification were triggered.

Testing

The application was tested by:

1. Deploying the infrastructure with Terraform
2. Accessing the frontend through CloudFront
3. Sending a request to the API through API Gateway
4. Executing the Lambda function
5. Writing application data to DynamoDB
6. Monitoring Lambda execution through CloudWatch
7. Testing the error alarm and SNS notification


Project Structure

peter-dani-cloth/
├── lambda/
│   └── lambda_function.py
├── website/
│   ├── index.html
│   ├── style.css
│   └── script.js
├── main.tf
├── variables.tf
├── terraform.tfvars
├── outputs.tf
├── .gitignore
└── README.md

Project Walkthrough

I recorded a full walkthrough of the project covering the architecture, Terraform configuration, AWS services, deployment, testing, monitoring, and troubleshooting.



What I Practiced

Through this project, I practiced:

* Designing a serverless AWS architecture
* Working with Terraform and Infrastructure as Code
* Connecting AWS managed services together
* Managing IAM permissions
* Deploying Lambda functions
* Working with DynamoDB
* Serving a private S3 frontend through CloudFront
* Building APIs with API Gateway
* Monitoring applications with CloudWatch
* Creating automated error alerts with SNS
* Testing and troubleshooting AWS infrastructure

Key Takeaway

This project helped me understand how different AWS services work together as an application rather than learning each service in isolation.

The main focus was not simply creating resources, but understanding the flow from the user request through the frontend, API, backend, database, and monitoring layer, and how the architecture can respond to changing demand.