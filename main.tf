# Copyright (c) CloudBees, Inc.

locals {
  flow_db_secret_data   = fileexists(var.flow_db_secrets_file) ? yamldecode(file(var.flow_db_secrets_file)) : {}
  create_flow_db_secret = length(local.flow_db_secret_data) > 0
  namespace             = try(var.helm_config.namespace, "cbcd")
}

resource "kubernetes_namespace" "cbcd" {
  metadata {
    name = local.namespace
  }
}

resource "kubernetes_secret" "flow_db_secret" {
  count = local.create_flow_db_secret ? 1 : 0

  metadata {
    name      = "flow-db-secret"
    namespace = kubernetes_namespace.cbcd.metadata[0].name
  }

  data = yamldecode(file(var.flow_db_secrets_file))
}

resource "helm_release" "cloudbees_cd" {

  name             = try(var.helm_config.name, "cloudbees-cd")
  namespace        = local.namespace
  create_namespace = false
  description      = try(var.helm_config.description, null)
  chart            = "cloudbees-flow"
  #Chart versions: #https://artifacthub.io/packages/helm/cloudbees/cloudbees-flow/
  #App version: https://docs.cloudbees.com/docs/release-notes/latest/cloudbees-cd/
  version    = try(var.helm_config.version, "2.28.0")
  repository = try(var.helm_config.repository, "https://public-charts.artifacts.cloudbees.com/repository/public/")
  values = length(trimspace(var.helm_config.values[0])) > 0 ? var.helm_config.values : [templatefile("${path.module}/values.yml", {
    host_name = var.host_name
    cert_arn  = var.cert_arn
  })]

  timeout                    = try(var.helm_config.timeout, 10000)
  repository_key_file        = try(var.helm_config.repository_key_file, null)
  repository_cert_file       = try(var.helm_config.repository_cert_file, null)
  repository_ca_file         = try(var.helm_config.repository_ca_file, null)
  repository_username        = try(var.helm_config.repository_username, null)
  repository_password        = try(var.helm_config.repository_password, null)
  devel                      = try(var.helm_config.devel, null)
  verify                     = try(var.helm_config.verify, null)
  keyring                    = try(var.helm_config.keyring, null)
  disable_webhooks           = try(var.helm_config.disable_webhooks, null)
  reuse_values               = try(var.helm_config.reuse_values, null)
  reset_values               = try(var.helm_config.reset_values, null)
  force_update               = try(var.helm_config.force_update, null)
  recreate_pods              = try(var.helm_config.recreate_pods, null)
  cleanup_on_fail            = try(var.helm_config.cleanup_on_fail, null)
  max_history                = try(var.helm_config.max_history, null)
  atomic                     = try(var.helm_config.atomic, null)
  skip_crds                  = try(var.helm_config.skip_crds, null)
  render_subchart_notes      = try(var.helm_config.render_subchart_notes, null)
  disable_openapi_validation = try(var.helm_config.disable_openapi_validation, null)
  wait                       = try(var.helm_config.wait, false)
  wait_for_jobs              = try(var.helm_config.wait_for_jobs, null)
  dependency_update          = try(var.helm_config.dependency_update, null)
  replace                    = try(var.helm_config.replace, null)
  lint                       = try(var.helm_config.lint, null)

  dynamic "postrender" {
    for_each = can(var.helm_config.postrender_binary_path) ? [1] : []

    content {
      binary_path = var.helm_config.postrender_binary_path
    }
  }

  dynamic "set" {
    for_each = try(var.helm_config.set, [])

    content {
      name  = set.value.name
      value = set.value.value
      type  = try(set.value.type, null)
    }
  }

  dynamic "set_sensitive" {
    for_each = try(var.helm_config.set_sensitive, {})

    content {
      name  = set_sensitive.value.name
      value = set_sensitive.value.value
      type  = try(set_sensitive.value.type, null)
    }
  }

  depends_on = [
    kubernetes_namespace.cbcd,
    kubernetes_secret.flow_db_secret,
    time_sleep.wait_30_seconds
  ]
}

# Need to wait a few seconds when removing the cbcd resource to give helm
# time to finish cleaning up.
#
# Otherwise, after `terraform destroy`:
# │ Error: uninstallation completed with 1 error(s): uninstall: Failed to purge
#   the release: release: not found

resource "time_sleep" "wait_30_seconds" {
  depends_on = [kubernetes_namespace.cbcd]

  destroy_duration = "30s"
}
