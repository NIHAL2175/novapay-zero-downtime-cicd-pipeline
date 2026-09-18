# OPA Policy: No Privileged Containers
# NovaPay Policy NP-K8S-001
# RBI Mapping: Section 4.2 | PCI-DSS: Req 6.2
package kubernetes.admission

deny[msg] {
    input.request.kind.kind == "Pod"
    container := input.request.object.spec.containers[_]
    container.securityContext.privileged == true
    msg := sprintf("POLICY VIOLATION NP-K8S-001: Privileged container not allowed: %v. All containers must run as non-root without privileged mode.", [container.name])
}

deny[msg] {
    input.request.kind.kind == "Pod"
    container := input.request.object.spec.containers[_]
    container.securityContext.runAsUser == 0
    msg := sprintf("POLICY VIOLATION NP-K8S-001: Container %v runs as root (UID 0). Use a non-root user.", [container.name])
}

deny[msg] {
    input.request.kind.kind == "Pod"
    container := input.request.object.spec.initContainers[_]
    container.securityContext.privileged == true
    msg := sprintf("POLICY VIOLATION NP-K8S-001: Privileged init container not allowed: %v", [container.name])
}
