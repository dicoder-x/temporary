variable "CRAWLER_NAME" {
    type        = string
    description = "Name of the glue crawler"
    default     = "goalposting-crawler"
}

variable "BUCKET_ARN" {
    type        = string
    description = "ARN of the bucket"
    default     = "arn:aws:s3:::goalposting-s3"
}

variable "GLUE_DB_NAME" {
    type        = string
    description = "Name of the glue database"
    default     = "goalposting-db"
}