package k8sblockingress

# METADATA
# entrypoint: true
violation contains {"msg": msg} if {
	input.review.object.kind == "Ingress"
	ingress_name := input.review.object.metadata.name
	msg := $"Ingress resources are not allowed. Use Istio Gateway instead. Ingress: {ingress_name}"
}
