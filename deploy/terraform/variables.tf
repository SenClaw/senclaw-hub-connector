# --- cluster access -----------------------------------------------------------
variable "host" {
  description = "Kubernetes API server (empty -> use kube_config_path)"
  type        = string
  default     = ""
}
variable "client_certificate" {
  description = "Base64 client certificate (used with host)"
  type        = string
  default     = ""
}
variable "client_key" {
  description = "Base64 client key (used with host)"
  type        = string
  default     = ""
  sensitive   = true
}
variable "cluster_ca_certificate" {
  description = "Base64 cluster CA (used with host)"
  type        = string
  default     = ""
}
variable "kube_config_path" {
  description = "Path to a kubeconfig (alternative to host/cert vars), e.g. ~/.kube/config"
  type        = string
  default     = ""
}

# --- namespace + image --------------------------------------------------------
variable "namespace" {
  type    = string
  default = "senclaw-hub"
}
variable "create_namespace" {
  type    = bool
  default = true
}
variable "name" {
  description = "Resource name for the Deployment, Service, Ingress and PVC"
  type        = string
  default     = "senclaw-hub-connector"
}

variable "image" {
  description = "Image repo without a tag; published by .github/workflows/docker.yml"
  type        = string
  default     = "ghcr.io/senclaw/senclaw-hub-connector"

  validation {
    condition     = !strcontains(regex("[^/]*$", var.image), ":")
    error_message = "image must not carry a :tag — put the tag in image_tag."
  }
}
variable "image_tag" {
  description = "Image tag to run, e.g. 0.1.0 (git tag v0.1.0) or sha-abc1234. Pin an immutable tag: a moving one (edge, latest) does not roll the pod on apply."
  type        = string
}

# Only needed while the GHCR package is private. A public package pulls anonymously.
variable "registry_server" {
  type    = string
  default = "ghcr.io"
}
variable "registry_username" {
  type    = string
  default = ""
}
variable "registry_password" {
  description = "Registry token with read:packages. Empty = no pull secret (public image)."
  type        = string
  default     = ""
  sensitive   = true
}

# --- storage ------------------------------------------------------------------
variable "data_storage" {
  description = "Size of the PVC holding the SQLite database (/data/hub.db)"
  type        = string
  default     = "1Gi"
}
variable "storage_class" {
  description = "StorageClass for the PVC ('' = cluster default, local-path on k3s)"
  type        = string
  default     = ""
}

# --- resources ----------------------------------------------------------------
variable "cpu_request" {
  type    = string
  default = "50m"
}
variable "cpu_limit" {
  type    = string
  default = "500m"
}
variable "memory_request" {
  type    = string
  default = "64Mi"
}
variable "memory_limit" {
  type    = string
  default = "256Mi"
}

# --- ingress ------------------------------------------------------------------
variable "domain" {
  description = "Public host for the hub, e.g. hub.example.com. Empty = no Ingress (use kubectl port-forward)."
  type        = string
  default     = ""
}
variable "ingress_class" {
  description = "IngressClass: \"nginx\" (ingress-nginx) or \"traefik\" (k3s default); '' = cluster default"
  type        = string
  default     = "nginx"
}
variable "ingress_annotations" {
  description = "Extra Ingress annotations, e.g. cert-manager.io/cluster-issuer"
  type        = map(string)
  default     = {}
}
variable "tls_secret" {
  description = "TLS secret name for the Ingress host ('' = plain HTTP)"
  type        = string
  default     = ""
}
