# Security Policy: Cloud Infrastructure & DevSecOps Lab

## 1. Declaración de Compromiso
Este repositorio implementa estándares de infraestructura crítica y está sujeto a revisiones de seguridad continuas. Nos comprometemos a mantener la integridad de la cadena de suministro de software (Software Supply Chain Security) y la protección de activos en Azure mediante configuraciones endurecidas (Hardening).

## 2. Versiones Soportadas (Patch Management)
De acuerdo con el ciclo de vida de desarrollo seguro (SDLC), solo las versiones etiquetadas como `Stable` reciben actualizaciones de seguridad proactivas y parches críticos.

| Versión | Estado de Soporte | Rama de Referencia |
| :--- | :--- | :--- |
| **v1.0.x** | :white_check_mark: Soporte Activo | `main` / `production` |
| **v0.5.x** | :warning: Solo Parches Críticos | `legacy` |
| **< v0.5** | :x: End of Life (EOL) | N/A |

## 3. Reporte de Vulnerabilidades (Vulnerability Disclosure)
Si identifica una debilidad en la configuración de Terraform, una falla en el aislamiento de red o una exposición de secretos, proceda bajo nuestra política de **Divulgación Responsable**:

### Procedimiento de Notificación
1. **No abrir un Issue público:** Para evitar ataques de "Día Cero", las vulnerabilidades deben reportarse exclusivamente a través del canal de **[GitHub Private Vulnerability Reporting](https://github.com/tu-usuario/tu-repo/security/advisories/new)**.
2. **Criterios de Aceptación:** El reporte debe incluir una prueba de concepto (PoC) técnica y una evaluación de impacto basada en el estándar **CVSS v3.1**.

## 4. Estándares de Seguridad Implementados
Este laboratorio ha sido validado bajo los siguientes controles de seguridad:
* **SAST (Static Analysis Security Testing):** Análisis de código con `Trivy` e `IaC Scan` para detectar misconfigurations.
* **Secret Management:** Implementación de **Azure Key Vault** con rotación obligatoria y acceso mediante **RBAC**.
* **Zero Trust Architecture:** Identidades administradas asignadas por el usuario (User-Assigned Managed Identities) para eliminar credenciales embebidas.
* **Compliance:** Alineación con el **CIS Microsoft Azure Foundations Benchmark v1.4.0**.

## 5. Exclusión de Responsabilidad
Este laboratorio tiene fines educativos y de endurecimiento de infraestructura. El autor no se hace responsable del mal uso de las configuraciones en entornos de producción sin la debida auditoría previa de seguridad (Pentesting).































