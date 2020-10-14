variable "prefix"{
  type = string
  description = "This will be the prefix all resources will have"
  default = "MYIOTPOC"
}

variable "env"{
  type = string
  description = "This will be used in your service name. Environment: Dev, QA, Prod, Sbx, etc..."
  default = "D"
}

variable "location" {
  type        = string
  description = "Resource Location"
  default = "East US 2"
}

variable "cctag" {
  type        = string
  description = "Cost Center"
  default = "Supply Chain"
}

variable "expiration_date" {
  type        = string
  description = "Cost Center"
  default = "20201120"
}

variable "environment" {
  type        = string
  description = "This will be a tag. Select your environment from: Demo, PoC, Hackathon, Dev, QA, Performance, Pre-Prod, Prod"
  default = "PoC"
}
