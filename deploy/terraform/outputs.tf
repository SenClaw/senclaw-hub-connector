output "service" {
  description = "In-cluster address of the hub"
  value       = "${kubernetes_service_v1.this.metadata[0].name}.${local.namespace}.svc:${local.port}"
}

output "image" {
  value = "${var.image}:${var.image_tag}"
}

output "url" {
  description = "Public URL when an Ingress is configured, else how to reach the hub from a workstation"
  value = var.domain != "" ? "${local.scheme}://${var.domain}" : (
    "kubectl -n ${local.namespace} port-forward svc/${var.name} ${local.port}:${local.port}"
  )
}
