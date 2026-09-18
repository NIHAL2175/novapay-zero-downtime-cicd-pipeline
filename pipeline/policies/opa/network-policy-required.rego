# OPA Policy: Network Policy Required
# NovaPay Policy NP-K8S-006 & NP-K8S-010
# PCI-DSS Mapping: Req 6.4
package kubernetes.admission

deny[msg] {
    input.request.kind.kind == "Deployment"
    namespace := input.request.object.metadata.namespace
    namespace == "default"
    msg := "POLICY VIOLATION NP-K8S-009: Deployment to 'default' namespace is not allowed. Use a dedicated namespace."
}

deny[msg] {
    input.request.kind.kind == "Pod"
    namespace := input.request.object.metadata.namespace
    namespace == "default"
    msg := "POLICY VIOLATION NP-K8S-009: Pod creation in 'default' namespace is not allowed."
}

# TLS enforcement for Ingress
deny[msg] {
    input.request.kind.kind == "Ingress"
    not input.request.object.spec.tls
    msg := "POLICY VIOLATION NP-K8S-010: All Ingress resources must have TLS configured with TLS 1.3+."
}
