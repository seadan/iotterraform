provider "azurerm" {
  version = "~> 2.01.0"

  features {

  }
}

resource "azurerm_resource_group" "iotDeployment" {
  name     = format("%sRG%s01" ,var.prefix, var.env) 
  location = var.location
  tags = {
    cc = var.cctag
    expiration_date = var.expiration_date
    environment = var.environment
  }
}

resource "azurerm_storage_account" "iotDeployment1" {
  name                     = lower(format("%sSA%s01" ,var.prefix, var.env))
  resource_group_name      = azurerm_resource_group.iotDeployment.name
  location                 = azurerm_resource_group.iotDeployment.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = "true"
  tags = {
    cc = var.cctag
    expiration_date = var.expiration_date
  }
}

resource "azurerm_storage_account" "iotDeployment2" {
  name                     = lower(format("%sSA%s02" ,var.prefix, var.env))
  resource_group_name      = azurerm_resource_group.iotDeployment.name
  location                 = azurerm_resource_group.iotDeployment.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags = {
    cc = var.cctag
    expiration_date = var.expiration_date
  }
}

resource "azurerm_storage_container" "iotDeployment" {
  name                  = lower(format("%sCTR%s01" ,var.prefix, var.env))
  storage_account_name  = azurerm_storage_account.iotDeployment1.name
  container_access_type = "private"
}

resource "azurerm_eventhub_namespace" "iotDeployment" {
  name                = format("%sEHN%s01" ,var.prefix, var.env) 
  resource_group_name = azurerm_resource_group.iotDeployment.name
  location            = azurerm_resource_group.iotDeployment.location
  sku                 = "Basic"

  tags = {
    cc = var.cctag
    expiration_date = var.expiration_date
  }
}

resource "azurerm_eventhub" "iotDeployment" {
  name                = format("%sEH%s01" ,var.prefix, var.env) 
  resource_group_name = azurerm_resource_group.iotDeployment.name
  namespace_name      = azurerm_eventhub_namespace.iotDeployment.name
  partition_count     = 2
  message_retention   = 1
}

resource "azurerm_eventhub_authorization_rule" "iotDeployment" {
  resource_group_name = azurerm_resource_group.iotDeployment.name
  namespace_name      = azurerm_eventhub_namespace.iotDeployment.name
  eventhub_name       = azurerm_eventhub.iotDeployment.name
  name                = "acctest"
  send                = true
}

resource "azurerm_iothub" "iotDeployment" {
  name                = format("%sHUBS%s01" ,var.prefix, var.env) 
  resource_group_name = azurerm_resource_group.iotDeployment.name
  location            = azurerm_resource_group.iotDeployment.location

  sku {
    name     = "S1"
    capacity = "1"
  }

  endpoint {
    type                       = "AzureIotHub.StorageContainer"
    connection_string          = azurerm_storage_account.iotDeployment1.primary_blob_connection_string
    name                       = "export"
    batch_frequency_in_seconds = 60
    max_chunk_size_in_bytes    = 10485760
    container_name             = azurerm_storage_container.iotDeployment.name
    encoding                   = "Avro"
    file_name_format           = "{iothub}/{partition}_{YYYY}_{MM}_{DD}_{HH}_{mm}"
  }

  endpoint {
    type              = "AzureIotHub.EventHub"
    connection_string = azurerm_eventhub_authorization_rule.iotDeployment.primary_connection_string
    name              = "export2"
  }

  route {
    name           = "export"
    source         = "DeviceMessages"
    condition      = "true"
    endpoint_names = ["export"]
    enabled        = true
  }

  route {
    name           = "export2"
    source         = "DeviceMessages"
    condition      = "true"
    endpoint_names = ["export2"]
    enabled        = true
  }

  tags = {
    cc = var.cctag
    expiration_date = var.expiration_date
  }
}

resource "azurerm_stream_analytics_job" "iotDeployment" {
  name                                     = format("%sSTRA%s01" ,var.prefix, var.env) 
  resource_group_name                      = azurerm_resource_group.iotDeployment.name
  location                                 = azurerm_resource_group.iotDeployment.location
  compatibility_level                      = "1.1"
  data_locale                              = "en-GB"
  events_late_arrival_max_delay_in_seconds = 60
  events_out_of_order_max_delay_in_seconds = 50
  events_out_of_order_policy               = "Adjust"
  output_error_policy                      = "Drop"
  streaming_units                          = 3

  tags = {
    CC = var.cctag
    expiration_date = var.expiration_date
  }

  transformation_query = <<QUERY
        SELECT *
    INTO output-to-blob-storage
    FROM iothub-input
QUERY
}


resource "azurerm_stream_analytics_stream_input_iothub" "iotDeployment" {
  name                         = "iothub-input"
  stream_analytics_job_name    = azurerm_stream_analytics_job.iotDeployment.name
  resource_group_name          = azurerm_stream_analytics_job.iotDeployment.resource_group_name
  endpoint                     = "messages/events"
  eventhub_consumer_group_name = "$Default"
  iothub_namespace             = azurerm_iothub.iotDeployment.name
  shared_access_policy_key     = azurerm_iothub.iotDeployment.shared_access_policy[0].primary_key
  shared_access_policy_name    = "iothubowner"

  serialization {
    type     = "Json"
    encoding = "UTF8"
  }
}

resource "azurerm_stream_analytics_output_blob" "iotDeployment" {
  name                      = "output-to-blob-storage"
  stream_analytics_job_name = azurerm_stream_analytics_job.iotDeployment.name
  resource_group_name       = azurerm_stream_analytics_job.iotDeployment.resource_group_name
  storage_account_name      = azurerm_storage_account.iotDeployment1.name
  storage_account_key       = azurerm_storage_account.iotDeployment1.primary_access_key
  storage_container_name    = azurerm_storage_container.iotDeployment.name
  path_pattern              = ""
  date_format               = "yyyy-MM-dd"
  time_format               = "HH"

  serialization {
    type            = "Csv"
    encoding        = "UTF8"
    field_delimiter = ","
  }
}

resource "azurerm_app_service_plan" "iotDeployment" {
  name                = format("%sFNP%s01" ,var.prefix, var.env) 
  location            = azurerm_resource_group.iotDeployment.location
  resource_group_name = azurerm_resource_group.iotDeployment.name
  kind                = "FunctionApp"

  sku {
    tier = "Dynamic"
    size = "Y1"
  }

  tags = {
    cc = var.cctag
    expiration_date = var.expiration_date
  }
}

resource "azurerm_function_app" "iotDeployment" {
  name                      = format("%sFUN%s01" ,var.prefix, var.env) 
  location                  = azurerm_resource_group.iotDeployment.location
  resource_group_name       = azurerm_resource_group.iotDeployment.name
  app_service_plan_id       = azurerm_app_service_plan.iotDeployment.id
  storage_connection_string = azurerm_storage_account.iotDeployment1.primary_connection_string

  tags = {
    cc = var.cctag
    expiration_date = var.expiration_date
  }
}
