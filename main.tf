terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "1.4.0"
    }
  }
}

resource "confluent_environment" "tfenv" {
  display_name = "Terraform"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "basic" {
  display_name = "Inventory"
  availability = "SINGLE_ZONE"
  cloud        = "AWS"
  region       = "ap-southeast-1"
  basic {}
  environment {
    id = confluent_environment.tfenv.id
  }
}

data "confluent_user" "rvoon" {
  id = "u-xmop8q"
}

resource "confluent_role_binding" "rvoon-cloud-cluster-admin" {
  principal   = "User:${data.confluent_user.rvoon.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.basic.rbac_crn
}

resource "confluent_api_key" "rvoon-kafka-api-key" {
  display_name = "rvoon-kafka-api-key"
  description  = "Kafka API Key that is owned by 'Ryan Voon' user account"
  owner {
    id          = data.confluent_user.rvoon.id
    api_version = data.confluent_user.rvoon.api_version
    kind        = data.confluent_user.rvoon.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.basic.id
    api_version = confluent_kafka_cluster.basic.api_version
    kind        = confluent_kafka_cluster.basic.kind

    environment {
      id = confluent_environment.tfenv.id
    }
  }
  depends_on = [
    confluent_role_binding.rvoon-cloud-cluster-admin
  ]
}

resource "confluent_kafka_topic" "orders" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  topic_name    = "orders"
  partitions_count = 1
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key = confluent_api_key.rvoon-kafka-api-key.id
    secret = confluent_api_key.rvoon-kafka-api-key.secret
  }
}

resource "confluent_kafka_acl" "rvoon-read-on-topic" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "TOPIC"
  resource_name = confluent_kafka_topic.orders.topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${data.confluent_user.rvoon.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key = confluent_api_key.rvoon-kafka-api-key.id
    secret = confluent_api_key.rvoon-kafka-api-key.secret
  }
}

resource "confluent_kafka_acl" "rvoon-read-on-group" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "GROUP"
  resource_name = "consumer_"
  pattern_type  = "PREFIXED"
  principal     = "User:${data.confluent_user.rvoon.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key = confluent_api_key.rvoon-kafka-api-key.id
    secret = confluent_api_key.rvoon-kafka-api-key.secret
  }
}
