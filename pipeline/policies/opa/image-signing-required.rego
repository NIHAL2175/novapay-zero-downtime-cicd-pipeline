# OPA Policy: Image Signing Required
# NovaPay Policy NP-K8S-003 & NP-K8S-004
# RBI Mapping: Section 5.4 | PCI-DSS: Req 6.3
package kubernetes.admission

approved_registries := ["artifactory.novapay.internal/docker-local"]

deny[msg] {
    input.request.kind.kind == "Pod"
    container := input.request.object.spec.containers[_]
    not approved_registry(container.image)
    msg := sprintf("POLICY VIOLATION NP-K8S-003: Image %v is not from an approved registry. Approved: %v", [container.image, approved_registries])
}

approved_registry(image) {
    registry := approved_registries[_]
    startswith(image, registry)
}

deny[msg] {
    input.request.kind.kind == "Pod"
    container := input.request.object.spec.containers[_]
    endswith(container.image, ":latest")
    msg := sprintf("POLICY VIOLATION NP-K8S-007: Image tag 'latest' is not allowed in production: %v. Use a specific SemVer or SHA tag.", [container.image])
}

deny[msg] {
    input.request.kind.kind == "Pod"
    container := input.request.object.spec.containers[_]
    not contains(container.image, ":")
    msg := sprintf("POLICY VIOLATION NP-K8S-007: Image %v has no tag specified. Use a specific version tag.", [container.image])
}
