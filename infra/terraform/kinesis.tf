# usage metrics stream
resource "aws_kinesis_stream" "augmentor_usage_metrics_stream" {
    name = "augmentor-usage-metrics-stream"
    shard_count = 1
    retention_period = 24
}