# Copyright (C) 2026 David Hobley
#
# This file is part of Shedbooks.
#
# Shedbooks is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Shedbooks is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Shedbooks. If not, see <https://www.gnu.org/licenses/>.

# Entra ID App Registration for interactive user login, added alongside (not
# replacing) Auth0 during the Auth0 -> Entra migration — see the migration
# plan for the full phased approach. Auth0 keeps validating tokens
# throughout; nothing here disables it.
#
# Deliberately a separate registration from the existing "ShedBooks" app
# (client id 192514fa-341d-445d-b147-26c45f0af99c, see
# scripts/bootstrap-azure.sh / ~/Downloads/shedbooks-o365-setup.ps1), which
# is an app-only, certificate-authenticated registration used for
# background O365/Exchange Graph automation. Mixing that client-credentials
# flow with interactive user login in one registration would be hard to
# reason about securely.

data "azuread_client_config" "current" {}

resource "azuread_application" "shedbooks_login" {
  display_name     = "Shedbooks Login"
  sign_in_audience = "AzureADMyOrg" # single-tenant: this org's users only

  owners = [data.azuread_client_config.current.object_id]

  # Entra requires a trailing slash (or a path segment) on redirect URIs
  # that have no path — a bare origin like the client's own is rejected.
  #
  # The default ACA FQDN is a literal here rather than a reference to
  # azurerm_container_app.client.ingress[0].fqdn deliberately: this
  # registration is applied out-of-band from the main container_apps.tf
  # stack (see the migration plan), and referencing that resource directly
  # would pull unrelated pending drift on it into this apply. Update the
  # literal below (from `tofu output client_fqdn`) if the container app is
  # ever recreated with a different default FQDN — its custom domain
  # (var.cors_origin) is the one actually used day-to-day.
  single_page_application {
    redirect_uris = distinct([
      "${var.cors_origin}/",
      "https://shedbooks-client.purplefield-35d9c923.australiaeast.azurecontainerapps.io/",
    ])
  }

  # requested_access_token_version = 2 is what makes tokens issued for this
  # app use the v2.0 shape (`iss` ending `/v2.0`, `preferred_username`
  # instead of `upn`, `roles` present when assigned) rather than the
  # structurally different v1.0 default.
  api {
    requested_access_token_version = 2

    # MSAL requests this as scope "<client_id>/access_as_user" (the GUID
    # form) rather than an "api://..." URI, so no separate Application ID
    # URI needs to be configured — avoids a circular reference on this
    # resource's own not-yet-known client_id.
    oauth2_permission_scope {
      id                         = "471583c0-32c6-4444-b55f-ef954c3b4d13"
      admin_consent_description  = "Allow the Shedbooks web app to access Shedbooks data on behalf of the signed-in user."
      admin_consent_display_name = "Access Shedbooks"
      user_consent_description   = "Allow the app to access Shedbooks on your behalf."
      user_consent_display_name  = "Access Shedbooks"
      value                      = "access_as_user"
      type                       = "User"
    }
  }

  # Values match AppRole exactly (server/lib/domain/enums/app_role.dart,
  # client/lib/auth/app_role.dart) so the existing role-parsing code needs
  # no new string mapping once Entra tokens are accepted.
  app_role {
    id                   = "46359b54-f197-4e05-a1a6-95813db4992a"
    allowed_member_types = ["User"]
    description          = "Read-only access to Shedbooks."
    display_name         = "Viewer"
    value                = "viewer"
    enabled              = true
  }
  app_role {
    id                   = "5e4db24c-a397-4edf-ac80-fba5f00bc6e6"
    allowed_member_types = ["User"]
    description          = "Read and write access to general Shedbooks data (not admin resources)."
    display_name         = "Contributor"
    value                = "contributor"
    enabled              = true
  }
  app_role {
    id                   = "47c6f44f-1c64-4c17-9518-5fc94028618a"
    allowed_member_types = ["User"]
    description          = "Full access to Shedbooks, including admin resources."
    display_name         = "Administrator"
    value                = "administrator"
    enabled              = true
  }

  # openid/profile/email are pre-consented by Microsoft for every app —
  # no required_resource_access block needed to request them.
}

resource "azuread_service_principal" "shedbooks_login" {
  client_id = azuread_application.shedbooks_login.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

locals {
  entra_app_role_ids = {
    viewer        = "46359b54-f197-4e05-a1a6-95813db4992a"
    contributor   = "5e4db24c-a397-4edf-ac80-fba5f00bc6e6"
    administrator = "47c6f44f-1c64-4c17-9518-5fc94028618a"
  }

  # One assignment per migrated identity — see the migration plan's old ->
  # new email mapping table. Object ids looked up once via `az ad user
  # show` against the real tenant (all three accounts already existed);
  # update here, not by hand in the portal, if an account is ever recreated.
  entra_role_assignments = {
    "david.hobley@woodgatemensshed.org.au" = {
      object_id = "177e0e3b-d3f6-44b8-a8d6-dfa840a8af7a"
      app_role  = "administrator"
    }
    "john.henderson@woodgatemensshed.org.au" = {
      object_id = "790bfa1c-27a2-422f-a28f-af4c01b631f7"
      app_role  = "administrator"
    }
    "greg.carlson@woodgatemensshed.org.au" = {
      object_id = "df8abfee-fae4-44cb-8aab-2a679e481eef"
      app_role  = "contributor"
    }
  }
}

resource "azuread_app_role_assignment" "shedbooks_login" {
  for_each = local.entra_role_assignments

  app_role_id         = local.entra_app_role_ids[each.value.app_role]
  principal_object_id = each.value.object_id
  resource_object_id  = azuread_service_principal.shedbooks_login.object_id
}
