variable "VPC_ID" {
    type        = string
    description = "The ID of your already existing VPC"
    default     = "vpc-01b7a51a09d27de04"
}

variable "SUBNET_IDs" {
    type        = list(string)
    description = "The IDs of your already existing subnets"
    default     = [ "subnet-0c47ef6fc81ba084a", "subnet-00c68b4e0ee285460", "subnet-0c2e92c1b7b782543" ]

}

variable "DASHBOARD_IMAGE_URI" {
    type        = string
    description = "URI of the dashboard ECR"
    default     = "129033205317.dkr.ecr.eu-west-2.amazonaws.com/goalposting-dashboard-ecr:latest"
    
}

variable "BUCKET_NAME" {
    type        = string
    description = "Name of the bucket"
    default     = "goalposting-s3"
}

variable "GLUE_DB_NAME" {
    type        = string
    description = "Name of the glue database"
    default     = "goalposting-glue-db"
}

variable "CPU" {
    type        = string
    description = "Amount of allocated CPU units"
    default     = "512"
}

variable "MEMORY_SIZE" {
    type        = string
    description = "Amount of allocated memory (in MiB)"
    default     = "3072"
}
