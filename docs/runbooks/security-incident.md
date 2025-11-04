# docs/runbooks/security-incident.md
# Security Incident Response Runbook

## Overview
Handle breaches, vulnerabilities, or unauthorized access.

## Detection
- Alerts: Prometheus rules for anomalous logins, high error rates.
- Tools: Falco for K8s runtime security, audit logs in Kafka.

## Response Steps
1. **Isolate**: Apply NetworkPolicies to quarantine affected pods.
2. **Assess**: Check logs (`kubectl logs`), scan images with Trivy.
3. **Remediate**: Rotate secrets (`kubectl rollout restart`), patch vulnerabilities.
4. **Notify**: Report to compliance@ if PII involved (GDPR).
5. **Post-Mortem**: Update RBAC, add scans to CI.

## Prevention
- TLS everywhere, SASL/SCRAM for Kafka.
- Least-privilege RBAC.
- Secret rotation every 90 days.

## Contacts
- Security team: sec@telemetry.com
- Legal: If breach, notify within 72hrs.