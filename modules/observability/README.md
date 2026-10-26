# observability

Platform-shipped monitoring for a single resource. **Tenants don't configure observability —
the platform ships it.** Callers may disable a specific baseline alert (the `_enable` flags)
or add their own, but they cannot remove this module's invocation. Thresholds are
hardcoded-but-overridable defaults.

Creates a log sink (when a log bucket is supplied), baseline metric alert policies with a
required runbook link, and a Monitoring dashboard rendered from a JSON template via
`templatefile()` — the one sanctioned use of `templatefile` in this codebase.

It does **not** create the log bucket (tenant bootstrap owns that) or notification channels
(one set per tenant, passed in).

```hcl
module "landing_observability" {
  source                = "git::https://github.com/<org>/multi-tenant-platform.git//modules/observability?ref=v1.0.0"
  project_id            = module.project.project_id
  display_name          = module.landing.name
  metric_filter         = "resource.type = \"gcs_bucket\" AND metric.type = \"storage.googleapis.com/network/sent_bytes_count\""
  notification_channels = [module.tenant_channels.email_channel_id]
  log_bucket_id         = module.tenant_logs.bucket_id
  runbook_url           = "https://github.com/<org>/multi-tenant-config/blob/main/docs/runbooks/gcs-egress.md"
  labels                = local.labels
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 6.0, < 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | 6.50.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_logging_project_sink.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/logging_project_sink) | resource |
| [google_monitoring_alert_policy.egress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_alert_policy) | resource |
| [google_monitoring_dashboard.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_dashboard) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_alert_duration"></a> [alert\_duration](#input\_alert\_duration) | How long the condition must hold before alerting. | `string` | `"300s"` | no |
| <a name="input_display_name"></a> [display\_name](#input\_display\_name) | Human label for the monitored resource (used in alert and dashboard titles), e.g. "abf-dev-landing". | `string` | n/a | yes |
| <a name="input_egress_threshold_bytes"></a> [egress\_threshold\_bytes](#input\_egress\_threshold\_bytes) | Egress-spike alert threshold. Hardcoded-but-overridable default; tenants rarely change it. | `number` | `1073741824` | no |
| <a name="input_enable_egress_alert"></a> [enable\_egress\_alert](#input\_enable\_egress\_alert) | Baseline alert toggle. Callers may disable a specific alert but cannot remove the module invocation (the platform always ships observability). | `bool` | `true` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Resource labels; managed-by is injected automatically. | `map(string)` | n/a | yes |
| <a name="input_log_bucket_id"></a> [log\_bucket\_id](#input\_log\_bucket\_id) | Destination log bucket ID. When set, a log sink routes this resource's logs there. When null, no sink is created (the tenant bootstrap owns the bucket, not this module). | `string` | `null` | no |
| <a name="input_log_filter"></a> [log\_filter](#input\_log\_filter) | Filter for the log sink (which log entries to route). | `string` | `""` | no |
| <a name="input_metric_filter"></a> [metric\_filter](#input\_metric\_filter) | Monitoring filter selecting the primary time series for this resource. Has a sensible default per the caller's resource type. | `string` | n/a | yes |
| <a name="input_notification_channels"></a> [notification\_channels](#input\_notification\_channels) | Notification channel IDs alerts fire to. Created once per tenant, not per resource (so this is passed in, never created here). | `list(string)` | `[]` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project that owns the monitored resource and these monitoring resources. | `string` | n/a | yes |
| <a name="input_runbook_url"></a> [runbook\_url](#input\_runbook\_url) | Runbook link embedded in alert documentation. Policy requires every alert to carry one. | `string` | `"https://github.com/<org>/multi-tenant-config/blob/main/docs/runbooks/observability.md"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_alert_policy_ids"></a> [alert\_policy\_ids](#output\_alert\_policy\_ids) | IDs of the alert policies actually created (respects the \_enable flags). |
| <a name="output_dashboard_id"></a> [dashboard\_id](#output\_dashboard\_id) | The created Monitoring dashboard ID. |
| <a name="output_log_sink_writer_identity"></a> [log\_sink\_writer\_identity](#output\_log\_sink\_writer\_identity) | Writer identity of the log sink (grant it access to the log bucket). Empty if no sink was created. |
<!-- END_TF_DOCS -->
