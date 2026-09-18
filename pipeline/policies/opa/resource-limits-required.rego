# OPA Policy: Resource Limits Required
# NovaPay Policy NP-K8S-002
# RBI Mapping: Section 4.2
package kubernetes.admission

deny[msg] {
    input.request.kind.kind == "Pod"
    container := input.request.object.spec.containers[_]
    not container.resources.limits.memory
    msg := sprintf("POLICY VIOLATION NP-K8S-002: Memory limit required for container: %v", [container.name])
}

deny[msg] {
    input.request.kind.kind == "Pod"
    container := input.request.object.spec.containers[_]
    not container.resources.limits.cpu
    msg := sprintf("POLICY VIOLATION NP-K8S-002: CPU limit required for container: %v", [container.name])
}

deny[msg] {
    input.request.kind.kind == "Pod"
    container := input.request.object.spec.containers[_]
    not container.resources.requests.memory
    msg := sprintf("POLICY VIOLATION NP-K8S-002: Memory request required for container: %v", [container.name])
}

deny[msg] {
    input.request.kind.kind == "Pod"
    container := input.request.object.spec.containers[_]
    not container.resources.requests.cpu
    msg := sprintf("POLICY VIOLATION NP-K8S-002: CPU request required for container: %v", [container.name])
}
