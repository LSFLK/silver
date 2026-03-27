# Thunder API Consumer Contract Guide for Silver

## Overview

This document describes the Thunder APIs Silver depends on through its provisioning and bootstrap scripts.
It is a consumer contract, not a full provider API documentation set.

Use this together with the OpenAPI consumer spec to:

- document exactly what Silver uses,
- detect breaking changes early,
- define a clear change-notification process.

## Scope

In scope:

- APIs called from `scripts/thunder/01-default-resources.sh`.
- APIs called from `scripts/thunder/02-sample-resources.sh`.
- Only request/response fields Silver scripts actually send, parse, or branch on.

Out of scope:

- Thunder endpoints not called by these scripts.
- Response fields Silver does not read.
- Internal helper implementation details not visible in these script files.

## Integration Flows

### 1) Default platform bootstrap flow

- Creates default organization unit.
- Creates default user schema.
- Creates admin user.
- Creates system resource server and hierarchical resources/actions.
- Creates administrator role and assignment.

### 2) Flow inventory and flow ID resolution

- Lists existing authentication, registration, and user-onboarding flows.
- Resolves flow IDs by handle for later application configuration.

### 3) Application bootstrap flow

- Creates DEVELOP application with OAuth2 inbound auth configuration.
- Creates sample SPA Email App application with OAuth2 inbound auth configuration.
- Falls back to application list query when app already exists.

### 4) Optional design and localization bootstrap flow

- Creates themes from local JSON files.
- Seeds translations by language.

## API Summary

| # | Method | Endpoint | Used for |
|---|---|---|---|
| 1 | POST | /organization-units | Create default OU |
| 2 | GET | /organization-units/tree/default | Resolve existing default OU ID on conflict |
| 3 | POST | /user-schemas | Create default Person schema |
| 4 | POST | /users | Create admin user |
| 5 | GET | /users | Resolve existing admin user ID on conflict |
| 6 | POST | /resource-servers | Create system resource server |
| 7 | GET | /resource-servers | Resolve existing system resource server ID on conflict |
| 8 | POST | /resource-servers/{resourceServerId}/resources | Create system and child resources |
| 9 | GET | /resource-servers/{resourceServerId}/resources | Resolve existing system resource ID |
| 10 | GET | /resource-servers/{resourceServerId}/resources?parentId=... | Resolve existing child resource IDs |
| 11 | POST | /resource-servers/{resourceServerId}/resources/{resourceId}/actions | Create view actions |
| 12 | POST | /roles | Create Administrator role and assignment |
| 13 | GET | /flows?flowType=AUTHENTICATION&limit=200 | Inventory authentication flows |
| 14 | GET | /flows?flowType=REGISTRATION&limit=200 | Inventory registration flows |
| 15 | GET | /flows?flowType=USER_ONBOARDING&limit=200 | Inventory user onboarding flows |
| 16 | POST | /applications | Create DEVELOP app and sample Email App |
| 17 | GET | /applications | Resolve existing application ID by client_id |
| 18 | POST | /design/themes | Create themes |
| 19 | POST | /i18n/languages/{language}/translations | Seed translations |

## Endpoint Contracts

### 1) Create Default Organization Unit

Method: POST  
Path: /organization-units  
Used by: default bootstrap

Request fields:

| Field | Required | Notes |
|---|---|---|
| handle | Yes | Silver sends `default` |
| name | Yes | Silver sends `Default` |
| description | Yes | Human-readable description |

Response fields read by Silver:

| Field | Required | Notes |
|---|---|---|
| id | Yes on 200/201 | Stored as default OU ID for downstream requests |

Expected statuses:

- 200 or 201: created/accepted
- 409: already exists, triggers OU tree lookup fallback

### 2) Resolve Existing Default OU

Method: GET  
Path: /organization-units/tree/default  
Used by: fallback when OU create returns conflict

Response fields read by Silver:

| Field | Required | Notes |
|---|---|---|
| id | Yes | Used as `ouId` / `organizationUnit` downstream |

Expected status:

- 200: existing default OU found

### 3) Create Default User Schema

Method: POST  
Path: /user-schemas  
Used by: bootstrap

Request fields sent by Silver:

| Field | Required | Notes |
|---|---|---|
| name | Yes | Silver sends `Person` |
| ouId | Yes | Default OU ID |
| schema.username | Yes | type string, required true, unique true |
| schema.email | Yes | type string, required true, unique true, regex validation |
| schema.password | Yes | type string, required true, credential true |
| systemAttributes.display | Yes | Silver sends `username` |

Expected statuses:

- 200 or 201: created/accepted
- 409: already exists (treated as non-fatal)

### 4) Create Admin User

Method: POST  
Path: /users  
Used by: bootstrap

Request fields sent by Silver:

| Field | Required | Notes |
|---|---|---|
| type | Yes | Silver sends `Person` |
| organizationUnit | Yes | Default OU ID |
| attributes.username | Yes | Admin username from env/default |
| attributes.password | Yes | Admin password from env/default |
| attributes.email | Yes | Admin email |

Response fields read by Silver:

| Field | Required | Notes |
|---|---|---|
| id | Recommended | Captured for role assignment |

Expected statuses:

- 200 or 201: created
- 409: already exists, triggers user list fallback

### 5) List Users (Fallback Admin ID Resolution)

Method: GET  
Path: /users  
Used by: fallback when admin create returns conflict

Response fields read by Silver:

| Field | Required | Notes |
|---|---|---|
| users[].id | Yes | Used as Administrator role assignment target |
| users[].attributes.username | Yes | Matched against configured admin username |

Expected status:

- 200: user list fetched

### 6) Create System Resource Server

Method: POST  
Path: /resource-servers  
Used by: bootstrap

Request fields sent by Silver:

| Field | Required | Notes |
|---|---|---|
| name | Yes | Silver sends `System` |
| identifier | Yes | Silver sends `system` |
| ouId | Yes | Default OU ID |

Response fields read by Silver:

| Field | Required | Notes |
|---|---|---|
| id | Yes on 200/201 | Used for resource and role operations |

Expected statuses:

- 200 or 201: created
- 409: already exists, triggers list fallback

### 7) List Resource Servers (Fallback ID Resolution)

Method: GET  
Path: /resource-servers  
Used by: fallback when create conflicts

Response fields read by Silver:

| Field | Required | Notes |
|---|---|---|
| resourceServers[].id | Yes | Used as `resourceServerId` |
| resourceServers[].identifier | Yes | Matched against `system` |

Expected status:

- 200: list fetched

### 8) Create Resources Under Resource Server

Method: POST  
Path: /resource-servers/{resourceServerId}/resources  
Used by: bootstrap

Request fields sent by Silver:

| Field | Required | Notes |
|---|---|---|
| name | Yes | Resource display name |
| handle | Yes | One of `system`, `ou`, `user`, `userschema`, `group` |
| parent | Conditionally | Required for child resources (`ou`, `user`, `userschema`, `group`) |

Response fields read by Silver:

| Field | Required | Notes |
|---|---|---|
| id | Yes on 200/201 | Used for action creation and child relations |

Expected statuses:

- 200 or 201: created
- 409: already exists, triggers resource-list fallback

### 9) List Resources (Fallback Resource ID Resolution)

Method: GET  
Paths:

- /resource-servers/{resourceServerId}/resources
- /resource-servers/{resourceServerId}/resources?parentId={resourceId}

Used by: fallback when resource create conflicts

Response fields read by Silver:

| Field | Required | Notes |
|---|---|---|
| resources[].id | Yes | Captured and reused |
| resources[].handle | Yes | Matched against expected handle |

Expected status:

- 200: list fetched

### 10) Create View Actions

Method: POST  
Path: /resource-servers/{resourceServerId}/resources/{resourceId}/actions  
Used by: bootstrap

Request fields sent by Silver:

| Field | Required | Notes |
|---|---|---|
| name | Yes | Silver sends `View` |
| handle | Yes | Silver sends `view` |
| description | Yes | Read-only description |

Expected statuses:

- 200 or 201: created
- 409: already exists (treated as non-fatal)

### 11) Create Administrator Role

Method: POST  
Path: /roles  
Used by: bootstrap

Request fields sent by Silver:

| Field | Required | Notes |
|---|---|---|
| name | Yes | Silver sends `Administrator` |
| ouId | Yes | Default OU ID |
| permissions[].resourceServerId | Yes | System resource server ID |
| permissions[].permissions[] | Yes | Silver sends `system` |
| assignments[].id | Yes | Admin user ID |
| assignments[].type | Yes | Silver sends `user` |

Response fields read by Silver:

| Field | Required | Notes |
|---|---|---|
| id | Optional | Logged when present |

Expected statuses:

- 200 or 201: created
- 409: already exists (treated as non-fatal)

### 12) List Flows by Type

Methods: GET  
Paths:

- /flows?flowType=AUTHENTICATION&limit=200
- /flows?flowType=REGISTRATION&limit=200
- /flows?flowType=USER_ONBOARDING&limit=200

Used by: flow inventory and ID resolution

Response fields read by Silver:

| Field | Required | Notes |
|---|---|---|
| flows[].id | Yes | Used to update flows or bind app flow IDs |
| flows[].handle | Yes | Matched to local flow definitions |

Expected status:

- 200: flow list fetched

Contract notes:

- Silver assumes flow handle uniqueness within each flow type lookup context.
- Silver requires stable `id` and `handle` presence for matching.

### 13) Create Applications (DEVELOP and Email App)

Method: POST  
Path: /applications  
Used by: bootstrap and sample app setup

Core request fields sent by Silver:

| Field | Required | Notes |
|---|---|---|
| name | Yes | `Develop` or sample app name |
| description | Yes | App description |
| is_registration_flow_enabled | Yes | Silver sends false |
| allowed_user_types | Yes | Includes `Person` |
| inbound_auth_config[].type | Yes | Silver sends `oauth2` |
| inbound_auth_config[].config.client_id | Yes | `DEVELOP` or `EMAIL_APP` |
| inbound_auth_config[].config.redirect_uris | Yes | Includes configured callback URIs |
| inbound_auth_config[].config.grant_types | Yes | Includes `authorization_code`; sample app also sends `refresh_token` |
| inbound_auth_config[].config.response_types | Yes | Includes `code` |
| inbound_auth_config[].config.pkce_required | Yes | Silver sends true |
| inbound_auth_config[].config.token_endpoint_auth_method | Yes | Silver sends `none` |
| inbound_auth_config[].config.public_client | Yes | Silver sends true |
| auth_flow_id | Conditionally | Required by DEVELOP app payload |
| registration_flow_id | Conditionally | Required by DEVELOP app payload |

Response fields read by Silver:

| Field | Required | Notes |
|---|---|---|
| id | Recommended | Logged as app ID |
| client_id | Optional | Logged in sample app script when present |

Expected statuses:

- 200, 201, or 202: success
- 409: already exists, triggers application list fallback
- 400 with known duplicate-app patterns (`Application already exists` or `APP-1022`): treated as already exists in specific code paths

### 14) List Applications (Fallback App ID Resolution)

Method: GET  
Path: /applications  
Used by: fallback when app create returns already-exists outcome

Response fields read by Silver:

| Field | Required | Notes |
|---|---|---|
| applications[].id | Yes | Stored/logged as existing app ID |
| applications[].client_id | Yes | Matched against `DEVELOP` |

Expected status:

- 200: application list fetched

### 15) Create Themes

Method: POST  
Path: /design/themes  
Used by: optional theme bootstrap

Request body:

- Raw theme JSON loaded from local files.

Response fields read by Silver:

| Field | Required | Notes |
|---|---|---|
| id | Optional | Logged when present |

Expected statuses:

- 200 or 201: created
- 409: already exists (treated as non-fatal)

### 16) Seed Language Translations

Method: POST  
Path: /i18n/languages/{language}/translations  
Used by: optional i18n bootstrap

Request body:

- Raw translation JSON loaded from language files.

Response fields read by Silver:

| Field | Required | Notes |
|---|---|---|
| totalResults | Recommended | Logged for translation count |

Expected status:

- 200: seeded successfully

## Common Protocol Expectations

- Authorization scheme for protected management endpoints: Bearer token (provided by shared helper).
- Content-Type for JSON POST requests: application/json.
- Silver scripts call Thunder over HTTPS-compatible base URL settings.

## Breaking Change Policy

The following are breaking for Silver provisioning unless coordinated:

- Remove or rename any endpoint listed in this guide.
- Change HTTP method of any listed endpoint.
- Remove request fields Silver sends for successful create operations.
- Remove or rename response fields Silver parses (`id`, `handle`, `identifier`, `client_id`, `totalResults`, and admin username-containing user attributes where used).
- Change semantic meaning of `handle`, `identifier`, `client_id`, or role assignment shape such that Silver cannot match existing resources.
- Change duplicate-resource signaling behavior without preserving currently handled statuses/patterns (`409`; and specific `400` duplicate-app patterns where currently relied on).
- Return non-success for list lookups used as fallback recovery (`/users`, `/applications`, `/resource-servers`, flow list endpoints).

Non-breaking examples:

- Add optional response fields.
- Add new endpoints Silver does not call.
- Add optional request fields with backward-compatible defaults.

## Change Notification Process

Before a breaking change, Thunder should share:

- change summary,
- updated OpenAPI consumer contract,
- sample request/response payloads,
- migration notes,
- rollout timeline.

Recommended lead time: 30 days minimum for breaking changes.

## Verification Strategy

Silver uses this guide and the OpenAPI consumer spec to:

- validate bootstrap behavior in integration/setup tests,
- detect schema and behavior drift,
- block releases on contract-breaking changes for provisioning paths.

## Ownership

- Consumer: Silver team
- Provider: Thunder team
- Source of truth: docs folder and consumer OpenAPI spec in Silver repository

## Versioning

Suggested model:

- Major: breaking changes
- Minor: backward-compatible additions
- Patch: editorial updates

Current version: 1.0.0
