mock_provider "helm" {}

run "default_regional" {
  command = apply

  module {
    source = "./tests/fixtures/default/regional"
  }
}

run "regional_helm_values" {
  command = plan

  module {
    source = "./regional"
  }

  variables {
    labels              = { "app.kubernetes.io/part-of" = "factory" }
    llm_base_url        = "http://agentgateway-proxy.agentgateway.svc.cluster.local/v1"
    namespace           = "kagent"
    substrate_namespace = "ate-system"
  }

  assert {
    condition = (
      yamldecode(helm_release.kagent.values[0]).config.substrate.apiEndpoint == "dns:///api.ate-system.svc:443" &&
      yamldecode(helm_release.kagent.values[0]).controller.substrateClientCertificate.enabled &&
      yamldecode(helm_release.kagent.values[0]).substrateWorkerPool.create &&
      yamldecode(helm_release.kagent.values[0]).substrateWorkerPool.workerImage == "${var.worker_image_repository}:v${var.substrate_version}"
    )
    error_message = "kagent must connect to Agent Substrate with a client certificate and use the matching worker image."
  }

  assert {
    condition     = yamldecode(helm_release.kagent.values[0]).providers.openAI.config.baseUrl == var.llm_base_url
    error_message = "kagent must use the supplied gateway for model requests."
  }

  assert {
    condition     = yamldecode(helm_release.kagent.values[0]).podLabels == var.labels
    error_message = "kagent must apply only the caller's labels to its pods."
  }

  assert {
    condition = (
      yamldecode(helm_release.kagent.values[0]).database.postgres.ownerConnectionStringSecretRef.name == var.postgres_owner_secret_name &&
      yamldecode(helm_release.kagent.values[0]).database.postgres.readWriteConnectionStringSecretRef.name == var.postgres_read_write_secret_name
    )
    error_message = "kagent must use the existing PostgreSQL connection Secrets."
  }
}

run "fractional_worker_replicas_rejected" {
  command = plan

  module {
    source = "./regional"
  }

  variables {
    namespace            = "kagent"
    substrate_namespace  = "ate-system"
    worker_pool_replicas = 1.5
  }

  expect_failures = [var.worker_pool_replicas]
}
