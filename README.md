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
    Internet -.->|Blocked| 


## 🛡️ Governance & Compliance
* **Data Encryption:** All data stored is encrypted at rest using **256-bit AES** (Microsoft-managed keys).
* **Network Firewall:** Access is restricted to `Deny` by default, ensuring only trusted services can communicate with the storage.
* **Disaster Recovery:** Soft-delete and purge protection are configured to prevent malicious or accidental data loss.
