
variable "tags" {
  description = "Tags to apply to resources."
  default     = {}
  type        = map(string)
}

variable "host_name" {
  description = "Host name. CloudBees CD Apps is configured to use this host name."
  type        = string
}

variable "hosted_zone" {
  description = "Route 53 Hosted Zone. CloudBees CI Apps is configured to use subdomains in this Hosted Zone."
  type        = string
}

variable "suffix" {
  description = "Unique suffix to be assigned to all resources"
  default     = ""
  type        = string
  validation {
    condition     = length(var.suffix) <= 10
    error_message = "The suffix cannot have more than 10 characters."
  }
}
