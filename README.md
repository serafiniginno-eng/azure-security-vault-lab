# Secure Azure Data & Key Management via Terraform
![Azure](https://img.shields.io/badge/azure-%230072C6.svg?style=for-the-badge&logo=microsoftazure&logoColor=white)
![Security](https://img.shields.io/badge/Security-Identity--First-red?style=for-the-badge)

##  Project Overview
This project implements a **Secret Management Strategy** using Azure Key Vault and secure Storage Accounts. It follows the principle of **Least Privilege** to ensure that data is only accessible to authorized identities.

##  Architecture Diagram
```mermaid
graph LR
    User((Admin)) --> KV[Azure Key Vault]
    KV -->|Managed Identity| ST[(Secure Storage)]
    Internet -.->|Blocked| ST 
