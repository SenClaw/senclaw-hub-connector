# senclaw-hub-connector on k3s/Kubernetes. Same shape as the go88 backend
# terraform (kubernetes provider, namespace, optional pull secret, Deployment +
# ClusterIP Service + nginx Ingress), reduced to the one service.
#
#   cp env/prod.tfvars.example env/prod.tfvars   # then edit
#   terraform init && terraform apply -var-file=env/prod.tfvars -state=prod.tfstate
#
# The hub keeps its channels in SQLite (/data/hub.db) and pairs the two ends of a
# relay inside one process, so it runs as exactly one pod on a ReadWriteOnce PVC
# with the Recreate strategy: two pods would split the pairs and fight over the
# database file.

terraform {
  required_version = ">= 1.5" # strcontains() in variables.tf

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.36"
    }
  }
}

provider "kubernetes" {
  host                   = var.host
  client_certificate     = var.client_certificate == "" ? null : base64decode(var.client_certificate)
  client_key             = var.client_key == "" ? null : base64decode(var.client_key)
  cluster_ca_certificate = var.cluster_ca_certificate == "" ? null : base64decode(var.cluster_ca_certificate)
  config_path            = var.kube_config_path == "" ? null : var.kube_config_path
}

locals {
  port       = 18080
  labels     = { app = var.name, service = var.name }
  use_secret = var.registry_password != ""
  scheme     = var.tls_secret == "" ? "http" : "https"
  # Referencing the resource (not var.namespace) orders everything after it.
  namespace = var.create_namespace ? kubernetes_namespace_v1.ns[0].metadata[0].name : var.namespace
}

resource "kubernetes_namespace_v1" "ns" {
  count = var.create_namespace ? 1 : 0
  metadata { name = var.namespace }
}

# Image-pull secret for a private GHCR package. Skipped while the package is public.
resource "kubernetes_secret_v1" "registry" {
  count = local.use_secret ? 1 : 0

  metadata {
    name      = "registry-secret"
    namespace = local.namespace
  }
  type = "kubernetes.io/dockerconfigjson"
  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        (var.registry_server) = {
          username = var.registry_username
          password = var.registry_password
          auth     = base64encode("${var.registry_username}:${var.registry_password}")
        }
      }
    })
  }
}

resource "kubernetes_persistent_volume_claim_v1" "data" {
  metadata {
    name      = "${var.name}-data"
    namespace = local.namespace
    labels    = local.labels
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = { storage = var.data_storage }
    }
    storage_class_name = var.storage_class == "" ? null : var.storage_class
  }
  # local-path binds on first use by a pod, so waiting here would deadlock.
  wait_until_bound = false
}

resource "kubernetes_deployment_v1" "this" {
  metadata {
    name      = var.name
    namespace = local.namespace
    labels    = merge(local.labels, { image_tag = var.image_tag })
  }

  spec {
    replicas = 1

    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = { app = var.name }
    }

    template {
      metadata {
        labels = merge(local.labels, { image_tag = var.image_tag })
      }

      spec {
        dynamic "image_pull_secrets" {
          for_each = local.use_secret ? [1] : []
          content {
            name = kubernetes_secret_v1.registry[0].metadata[0].name
          }
        }

        container {
          name  = var.name
          image = "${var.image}:${var.image_tag}"

          env {
            name  = "SHARED_PORT"
            value = ":${local.port}"
          }

          port {
            container_port = local.port
          }

          # The image's WORKDIR is /data and the server opens ./hub.db.
          volume_mount {
            name       = "data"
            mount_path = "/data"
          }

          resources {
            limits = {
              cpu    = var.cpu_limit
              memory = var.memory_limit
            }
            requests = {
              cpu    = var.cpu_request
              memory = var.memory_request
            }
          }

          readiness_probe {
            tcp_socket { port = local.port }
            initial_delay_seconds = 3
            period_seconds        = 10
          }

          liveness_probe {
            tcp_socket { port = local.port }
            initial_delay_seconds = 15
            period_seconds        = 20
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "this" {
  metadata {
    name      = var.name
    namespace = local.namespace
    labels    = local.labels
  }

  spec {
    selector = { app = var.name }
    port {
      port        = local.port
      target_port = local.port
    }
    type = "ClusterIP"
  }
}

# /v1/relay/ws holds long-lived WebSockets, so lift nginx's 60s proxy timeouts.
# Traefik (k3s default) ignores these annotations and needs nothing extra.
resource "kubernetes_ingress_v1" "this" {
  count = var.domain == "" ? 0 : 1

  metadata {
    name      = var.name
    namespace = local.namespace
    annotations = merge({
      "nginx.ingress.kubernetes.io/proxy-read-timeout" = "3600"
      "nginx.ingress.kubernetes.io/proxy-send-timeout" = "3600"
    }, var.ingress_annotations)
  }

  spec {
    ingress_class_name = var.ingress_class == "" ? null : var.ingress_class
    rule {
      host = var.domain
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.this.metadata[0].name
              port { number = local.port }
            }
          }
        }
      }
    }
    dynamic "tls" {
      for_each = var.tls_secret == "" ? [] : [1]
      content {
        hosts       = [var.domain]
        secret_name = var.tls_secret
      }
    }
  }
}
