# Azure Security, Observability & DevSecOps Lab 🛡️☁️

![Security Scan](https://github.com/m-reyes-86/azure-security-vault-lab/actions/workflows/trivy.yml/badge.svg)
![Terraform](https://img.shields.io/badge/IaC-Terraform-blueviolet)
![Azure](https://img.shields.io/badge/Cloud-Azure-blue)

## 📌 Visión General
Este proyecto implementa una infraestructura de alta seguridad en Azure utilizando **Terraform**. Se enfoca en la protección del plano de datos, la gestión de identidades moderna (RBAC) y la observabilidad proactiva ante incidentes.

El despliegue sigue los lineamientos del **Azure Well-Architected Framework** y los **CIS Microsoft Azure Foundations Benchmarks**.

---

## 🏗️ Arquitectura de Seguridad
La arquitectura se basa en el modelo de **Defensa en Profundidad**:

1. **Aislamiento de Red**: Implementación de `Network ACLs` en Azure Key Vault y Storage Accounts con política por defecto `Deny`.
2. **Gestión de Identidades (Zero Trust)**: Uso de **User-Assigned Managed Identities** para eliminar credenciales estáticas.
3. **Control de Acceso**: Migración completa de Access Policies tradicionales a **Azure RBAC**.
4. **Cifrado**: Datos cifrados en reposo mediante AES-256 y tránsito protegido por TLS 1.2+.

---

## 🚀 Pipeline de DevSecOps (Shift-Left)
El repositorio integra un flujo de CI/CD mediante **GitHub Actions** que actúa como gate de seguridad:

* **Validación Estática**: Verificación de sintaxis de Terraform.
* **SAST con Trivy**: Escaneo de seguridad automático en cada `push` para detectar vulnerabilidades en el código de infraestructura antes del despliegue.

---

## 📊 Observabilidad y Respuesta ante Incidentes
Se ha implementado un centro de comando de seguridad mediante **Log Analytics Workspace**:

* **Diagnostic Settings**: Logs de auditoría de Key Vault capturados en tiempo real.
* **Detección KQL**: Consulta personalizada para detectar intentos de acceso no autorizados (`Forbidden`).
* **Alerting**: Alerta programada que notifica intentos de intrusión en una ventana de 5 minutos.

```kql
// Consulta KQL implementada para detección de intrusos
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where ResultSignature == "Forbidden"
| summarize Count = count() by bin(TimeGenerated, 5m), Resource
| where Count > 0
