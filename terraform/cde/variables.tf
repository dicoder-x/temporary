variable "CRAWLER_NAME" {
    type        = string
    description = "Name of the glue crawler"
    default     = "cde-testing-crawler"
}

variable "BUCKET_NAME" {
    type        = string
    description = "ARN of the bucket"
    default     = "goalposting-s3"
}

variable "GLUE_DB_NAME" {
    type        = string
    description = "Name of the glue database"
    default     = "cde-testing-db"
}
