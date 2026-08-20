# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary
#
# Emergency access.
#
# The design constraint: an emergency path that is convenient becomes the normal path. This
# one is deliberately not convenient. It holds NO standing permissions — the account exists
# but can do nothing until someone grants it a role with an expiry, and every use alerts.
#
# What it is for: the estate is broken in a way that prevents the normal apply path from
# fixing it. WIF is misconfigured, the state bucket is locked, an org policy is blocking the
# change that would remove the org policy.
#
# What it is not for: being in a hurry.

resource "google_service_account" "break_glass" {
  project      = var.seed_project_id
  account_id   = "sa-break-glass"
  display_name = "Break-glass — NO STANDING PERMISSIONS"
  description  = "Emergency access. Every use alerts. Grants are time-bound. See docs/break-glass.md."
}

# Named individuals only. A group address here would make the audit trail say "someone in a
# group of twelve", which is not an audit trail.
resource "google_service_account_iam_member" "break_glass_impersonation" {
  for_each = var.break_glass_principals

  service_account_id = google_service_account.break_glass.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:${each.value}"
}

# ---------------------------------------------------------------------------------------
# The alert
# ---------------------------------------------------------------------------------------
# The credential's value comes from the alert, not from the restriction. Someone determined
# enough will find a way to elevate; what matters is that it is impossible to do quietly.

resource "google_project_service" "monitoring" {
  project = var.seed_project_id
  service = "monitoring.googleapis.com"

  disable_on_destroy = false
}

resource "google_monitoring_notification_channel" "security" {
  project      = var.seed_project_id
  display_name = "Security — break-glass"
  type         = "email"

  labels = {
    email_address = var.security_contact
  }
}

resource "google_logging_metric" "break_glass_use" {
  project = var.seed_project_id
  name    = "break_glass_use"

  # Matches both impersonation and any action taken AS the account.
  filter = <<-EOT
    protoPayload.authenticationInfo.principalEmail="${google_service_account.break_glass.email}"
    OR (protoPayload.serviceName="iamcredentials.googleapis.com"
        AND protoPayload.resourceName=~"${google_service_account.break_glass.unique_id}")
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}

resource "google_monitoring_alert_policy" "break_glass" {
  project      = var.seed_project_id
  display_name = "Break-glass credential used"
  combiner     = "OR"
  severity     = "CRITICAL"

  conditions {
    display_name = "Any use of sa-break-glass"

    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.break_glass_use.name}\" AND resource.type=\"global\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.security.id]

  alert_strategy {
    # Close the incident an hour after the last use, so a later activation opens a NEW
    # incident rather than reopening one somebody already reviewed.
    auto_close = "3600s"

    # Re-notify every 30 minutes for as long as it is in use.
    #
    # auto_close alone does not do this — it only governs when the incident closes. Without
    # the block below the alert fires exactly once, and a single notification at 03:00 is
    # the one that gets missed. The comment here previously claimed the re-notification
    # behaviour that this block actually provides.
    notification_channel_strategy {
      renotify_interval = "1800s"
      notification_channel_names = [
        google_monitoring_notification_channel.security.id,
      ]
    }
  }

  documentation {
    subject   = "CRITICAL: break-glass credential used"
    content   = <<-EOT
      The break-glass service account was used.

      If you are not expecting this, treat it as a compromise: revoke the grant, rotate,
      and open an incident.

      If you are expecting it, this alert is still correct — the post-use review in
      bootstrap/docs/break-glass.md is required within 24 hours.

      Who, what, when:
        gcloud logging read \
          'protoPayload.authenticationInfo.principalEmail="${google_service_account.break_glass.email}"' \
          --project=${var.seed_project_id} --limit=50 --format=json
    EOT
    mime_type = "text/markdown"
  }
}

