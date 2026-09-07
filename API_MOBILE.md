# GiveChain Mobile API Reference

Base route prefix: **`api/mobile/...`**. This API serves the donor-facing mobile app — the app used by individuals who browse charities/campaigns/cases and make/track their own donations (as opposed to the charity/dashboard-facing API used by charity staff and GiveChain admins).

All responses are wrapped in `ApiResponse<T>`:
```
{ "message": string | null, "data": T | null, "errors": string[] | null, "isSuccess": bool }
```
`isSuccess` is `true` when `errors` is null/empty. Controllers return HTTP 200 on success and 400 on failure (see `BaseController.ToActionResult`). Paged endpoints wrap items in `PagedResult<T>`:
```
{ "items": T[], "totalCount": int, "page": int, "pageSize": int, "totalPages": int }
```

**Authentication note:** `[Authorize]` is commented out on nearly every action across this codebase (only `NotificationsController` currently enforces it). Endpoints that read `CurrentUserId` (from a `UserId` claim, via `BaseController`) will still throw/fail at runtime if called without a valid token even though the attribute isn't enforcing it yet — treat every non-`AllowAnonymous` endpoint below as requiring a bearer token in practice. `CurrentUserId` is read from the JWT's `UserId` claim.

Endpoints that accept files use `multipart/form-data` (`[FromForm]`); everything else is JSON body (`[FromBody]`) or query string (`[FromQuery]`).

---

## Auth

Controller: `MobileAuthController` — `api/mobile/auth`

### POST `api/mobile/auth/login`
`[AllowAnonymous]`. Logs a user in.

Request body (`LoginRequest`):
| Field | Type | Required | Notes |
|---|---|---|---|
| Email | string | one of Email/UserName | |
| UserName | string | one of Email/UserName | |
| Password | string | yes | |

Response: `AuthResponse` — `UserId`, `Token` (JWT), `Email`, `FullName`, `UserType` (enum), `IsAdmin?`, `UserName?`, `UserStatus?` (enum), `RoleId?`, `Role?` (`RoleResponse`), `Permissions?` (`RolePermissionResponse[]`).

### POST `api/mobile/auth/register`
`[AllowAnonymous]`. `multipart/form-data`. Registers a new public (donor) user.

Request (`MobileRegisterRequest`, form fields):
| Field | Type | Required | Notes |
|---|---|---|---|
| FirstName | string | yes | |
| LastName | string | yes | |
| Username | string | yes | |
| Email | string | yes | |
| Password | string | yes | |
| BirthOfDate | DateTime? | no | |
| NationalNumber | string? | no | |
| CountryId | Guid? | no | |
| CityId | Guid? | no | |
| Gender | enum `Gender` | yes | |
| ProfileImage | file (IFormFile) | no | |

Response: `AuthResponse` (same shape as login).

### POST `api/mobile/auth/forgot-password`
`[AllowAnonymous]`. Sends a reset code/token to the user's email.

Request (`ForgotPasswordRequest`): `Email` (string, required).
Response: `bool`.

### POST `api/mobile/auth/reset-password`
`[AllowAnonymous]`. Resets password using the token emailed by forgot-password.

Request (`ResetPasswordRequest`): `Email` (string, required), `Token` (string, required), `NewPassword` (string, required).
Response: `bool`.

### GET `api/mobile/auth/info-fields`
Returns the extra registration/profile fields required for the `PublicUser` user type (dynamic per-tenant fields, e.g. custom questions asked at signup).

Response: `PersonInfoFieldResponse[]` — `Id`, `FieldName`, `FieldType` (enum), `UserType` (enum), `IsRequired`.

---

## Profile

Controller: `ProfileController` — `api/mobile/profile`. All endpoints act on the current authenticated user (`CurrentUserId`).

### GET `api/mobile/profile`
Returns the caller's profile.

Response: `PersonResponse` — `Id`, `FirstName`, `LastName`, `NationalNumber?`, `BirthOfDate?`, `UserType` (enum), `Gender` (enum), `Country?` (`CountryResponse`), `City?` (`CityResponse`), `ImagePath?`, `User?` (`UserSummaryResponse`: `Id`, `Email`, `UserName`, `RoleName?`, `IsAdmin`, `Status` enum), `Answers` (`PersonInfoAnswerResponse[]` — the dynamic field answers, see below).

### PUT `api/mobile/profile`
Updates the caller's profile. All fields optional/partial-update.

Request (`UpdatePersonRequest`):
| Field | Type | Required | Notes |
|---|---|---|---|
| FirstName | string? | no | |
| LastName | string? | no | |
| NationalNumber | string? | no | |
| BirthOfDate | DateTime? | no | |
| Gender | enum? | no | |
| CountryId | Guid? | no | |
| CityId | Guid? | no | |
| ProfileImage | file | no | |
| Email | string? | no | dashboard/admin-oriented field, present on the shared DTO but not typically set by the mobile app |
| UserName | string? | no | same as above |
| RoleId | Guid? | no | admin-only field, ignore on mobile |

Response: `PersonResponse`.

### GET `api/mobile/profile/info-answers`
Returns the caller's answers to the dynamic personal-info questions (from `info-fields`).

Response: `PersonInfoAnswerResponse[]` — `Id`, `PersonId`, `FieldId`, `FieldName`, `Answer?`, `Attachments` (string URLs, for `FieldType.Attachment` questions).

### PUT `api/mobile/profile/info-answers`
Upserts (creates or updates) a single answer.

Request (`UpsertPersonInfoAnswerRequest`): `FieldId` (Guid, required), `Answer` (string?, optional — the answer value; for `Attachment`/`Option` fields this is the file URL/selected option value).

Response: `PersonInfoAnswerResponse`.

### PUT `api/mobile/profile/password`
Changes the caller's password.

Request (`ChangePasswordRequest`): `CurrentPassword` (string, required), `NewPassword` (string, required).
Response: `bool`.

---

## Home / Feed

Controller: `HomeController` — `api/mobile/home`

### GET `api/mobile/home`
Home-page feed: featured campaigns, recent charities, recent cases (no pagination — fixed-size curated lists per the service implementation).

Response (`HomeFeedResponse`):
- `FeaturedCampaigns`: `CampaignResponse[]`
- `RecentCharities`: `CharityResponse[]`
- `RecentCases`: `CaseResponse[]`

See the **Campaigns**, **Charities**, and **Cases** sections below for the shape of each item.

---

## Charities

Controller: `CharitiesController` — `api/mobile/charities`

### GET `api/mobile/charities`
Browse all charities. Query: `page` (int, default 1), `pageSize` (int, default 10).

Response item (`CharityResponse`): `Id`, `Name`, `Description`, `SubDomain`, `LogoUrl?`, `CountryId?`, `Country?` (`CountryResponse`), `CityId?`, `City?` (`CityResponse`), `Status` (enum `CharityStatus`), `StatusCode` (int, 1=active/0=blocked shortcut), `SuspendedReason?`, `SuspendedAt?`, `Date` (created date), `OwnerUserId?`, `Owner?` (`UserSummaryResponse`), `Categories` (`CharityCategoryResponse[]`: `Id`, `Name`, `Description`).

### GET `api/mobile/charities/{id:guid}`
Charity details. Response: `CharityResponse` (same shape).

### GET `api/mobile/charities/{id:guid}/campaigns`
Active campaigns for one charity. Query: `page`, `pageSize`. Response: paged `CampaignResponse[]` — see **Campaigns**.

### GET `api/mobile/charities/{id:guid}/cases`
Open cases for one charity. Query: `page`, `pageSize`. Response: paged `CaseResponse[]` — see **Cases**.

### GET `api/mobile/charities/{id:guid}/benefit-types`
Active benefit types (aid programs) offered by the charity, used to know what a user can apply for via **Benefits**.

Response: `BenefitTypeResponse[]` — `Id`, `CharityId`, `Name`, `Description?`, `IsActive`, `Questions` (`BenefitTypeQuestionResponse[]`: `Id`, `QuestionText`, `FieldType` (enum), `Order`, `IsRequired`, `Options` (string[], for choice-type questions)).

---

## Campaigns

Controller: `CampaignsController` — `api/mobile/campaigns`

### GET `api/mobile/campaigns`
Active campaigns (platform-wide). Query: `page`, `pageSize`.

Response item (`CampaignResponse`): `Id`, `CharityId?` (null for platform-owned), `CampaignNumber`, `OwnerType` (enum `CampaignOwnerType`: `Charity=0`, `Platform=1`), `IsTrusted` (bool), `TrustImageUrl?`, `CampaignName`, `CampaignDescription?`, `StartDate`, `EndDate?`, `Status` (enum `CampaignStatus`), `CreatedBy?`, `CreatedByUserName?`, `Creator?` (`CreatorResponse`), `CampaignTypeId?`, `CampaignType?` (`CampaignTypeResponse`: `Id`, `Name`, `Description?`, `IconUrl?`, `CharityCategoryIds`, `CharityCategoryNames`), goal summary — `GoalType?` (enum `CompaignGoalType`), `TargetAmount?`, `AchievedAmount?`, `TargetQuantity?`, `AchievedQuantity?`, `GoalUnit?`, `Medias` (`MediaFileResponse[]`).

### GET `api/mobile/campaigns/by-charity/{charityId:guid}`
Active campaigns for a charity. Query: `page`, `pageSize`. Same response shape.

### GET `api/mobile/campaigns/{id:guid}`
Campaign details. Response: `CampaignResponse`.

### POST `api/mobile/campaigns/{id:guid}/donate`
`multipart/form-data`. Donate to this campaign. The controller forces `TargetType = Campaign` and `CampaignId = {id}` on the request regardless of what's submitted. See **Donations — Create donation** for the full request/response shape and enum rules; do not send `CampaignId`/`TargetType` yourself here (they're overwritten).

---

## Cases

Controller: `CasesController` — `api/mobile/cases`

### GET `api/mobile/cases`
Browse all open cases. Query: `page`, `pageSize`.

Response item (`CaseResponse`): `Id`, `CharityId`, `CaseNumber`, `CategoryId?`, `Category?` (`CaseCategoryResponse`: `Id`, `Name`, `IconUrl?`, `CharityCategoryIds`, `CharityCategoryNames`), `Priority` (enum `CasePriority`), `CityId?`, `LocationDetails?`, `Title`, `Description`, `Status` (enum `CaseStatus`), `PublishedAt`, `ClosedAt?`, `ClosedNotes?`, `CreatedBy?`, `CreatedByUserName?`, `Creator?` (`CreatorResponse`), `Medias` (`MediaFileResponse[]`), `IsStatusLocked` (bool — true means a GiveChain admin locked the status, charity can't change it), `StatusLockNote?`.

Note: a case's donatable "needs" (`CaseNeed`, with `CaseNeedId` used when donating) aren't exposed as a distinct field on `CaseResponse` in this controller set — needs are referenced by id when creating a donation (see below); check with the backend team if a needs-listing endpoint is required.

### GET `api/mobile/cases/{id:guid}`
Case details. Response: `CaseResponse`.

### GET `api/mobile/cases/by-charity/{charityId:guid}`
Open cases for a charity. Query: `page`, `pageSize`. Same response shape.

### POST `api/mobile/cases/{id:guid}/donate`
`multipart/form-data`. Donate to this case (money, item, or service). The controller forces `TargetType = Case` and `CaseId = {id}` regardless of what's submitted. See **Donations — Create donation** below for the full shape; you still need to supply `CaseNeedId` yourself (required for case donations) since it isn't inferred from the route.

---

## Donations

Controller: `DonationsController` — `api/mobile/donations`. This is the core, polymorphic donation flow — money / item / service donations to a campaign, a case, or directly to a charity's general pool.

### POST `api/mobile/donations`
`multipart/form-data`. Creates a donation directly (campaign/case/charity all selectable here, unlike the `/campaigns/{id}/donate` and `/cases/{id}/donate` shortcuts which pin the target). Optional file attachments (e.g. bank transfer proof, item photos) go in the `attachments` form field.

Request (`CreateDonationRequest`) — one shape for all three donation kinds; required fields depend on `DonationType`:

| Field | Type | Required | Notes |
|---|---|---|---|
| DonationType | enum `DonationType` | yes (default `Money`) | `Money=1`, `Item=2`, `Service=3` |
| TargetType | enum `DonationTargetType` | yes (default `Campaign`) | `Campaign=1`, `Case=2`, `Charity=3` |
| CampaignId | Guid? | required if TargetType=Campaign | |
| CaseId | Guid? | required if TargetType=Case | |
| CaseNeedId | Guid? | required if TargetType=Case | the specific need within the case being funded |
| CharityId | Guid? | required if TargetType=Charity | hands donation to charity's general pool, unassigned |
| Message | string? | no | donor's note |
| Amount | decimal? | **required if DonationType=Money** | pledged amount |
| PaymentMethod | enum `PaymentMethod` | yes for Money (default `Cash`) | `Cash=0`, `BankTransfer=1` (no online gateway; BankTransfer needs a proof-of-transfer attachment) |
| ItemName | string? | **required if DonationType=Item** | |
| ItemDescription | string? | no | |
| Quantity | int? | no (Item) | |
| Unit | enum `CaseNeedUnit`? | no (Item) | `Money, Kilogram, Gram, Piece, Box, Liter, Meter, Pack` |
| ServiceDescription | string? | **required if DonationType=Service** | |
| ScheduledAt | DateTime? | no (Service) | |
| DeliveryMethod | enum `DonationDeliveryMethod` | yes for Item/Service (default `DropOff`) | `DropOff=1`, `Delivery=2`, `Electronic=3` |
| CenterId | Guid? | no | routes the donation through a GiveChain Center (money/item only); see **Centers** |

Response: `DonationResponse` (see field table below).

### GET `api/mobile/donations`
"My donations" — single endpoint with every filter optional (query string, `DonationFilterRequest`).

Query fields: `CharityId?`, `Status?` (enum `DonationStatus`), `DonationType?` (enum), `TargetType?` (enum), `CampaignId?`, `CaseId?`, `CaseNeedId?`, `CenterId?`, `ThroughCenter?` (bool — true = only Center-routed, false = only direct), `UserId?` (server forces this to the caller regardless), `PaymentMethod?` (enum), `FromDate?`/`ToDate?` (inclusive bounds on `DonationDate`), `MinAmount?`/`MaxAmount?` (money donations), `Search?` (free text over message/item name/service description), `Page` (default 1), `PageSize` (default 10).

Response: paged `DonationResponse[]`.

**`DonationResponse` field reference** (flattened for all kinds — type-specific fields are null when not applicable):
| Field | Type | Applies to |
|---|---|---|
| Id | Guid | all |
| DonationType | enum | all |
| TargetType | enum | all |
| EntityId | Guid | all — Campaign.Id when TargetType=Campaign, or CaseNeed.Id when Case |
| EntityName | string? | all — the campaign name or case-need name |
| CharityId | Guid | all |
| UserId | Guid | all — `Guid.Empty` for an anonymous walk-in donation logged by Center staff |
| DonorName | string? | all |
| Message | string? | all |
| DonationDate | DateTime | all |
| Status | enum `DonationStatus` | all — see lifecycle below |
| Amount | decimal? | Money |
| PaymentMethod | enum? | Money |
| PaymentStatus | enum? | Money (electronic only; `NotApplicable` for cash) |
| PaymentReference | string? | Money |
| AcceptedAmount | decimal? | Money — amount actually verified by charity |
| ItemName | string? | Item |
| ItemDescription | string? | Item |
| Quantity | int? | Item |
| Unit | enum? | Item |
| AcceptedQuantity | int? | Item — quantity actually verified |
| ServiceDescription | string? | Service |
| ScheduledAt | DateTime? | Service |
| DeliveryMethod | enum? | Item/Service |
| CenterId | Guid? | Center-routed donations |
| CenterConfirmedAt | DateTime? | Center-routed |
| CenterConfirmationNotes | string? | Center-routed |
| TransferredToCharityAt | DateTime? | Center-routed |
| VerifiedAt | DateTime? | all |
| VerificationNotes | string? | all |
| Medias | `MediaFileResponse[]` | all — attachments (proof, photos) |

`DonationStatus` lifecycle: `PendingPayment=0` → `Pledged=1` → `Received=2` → `Verified=3` (or `Rejected=4`); electronic path adds `PaymentFailed=5`; Center hand-off path adds `DroppedAtCenter=6` → `ConfirmedByCenter=7` → `TransferredToCharity=8`.

### POST `api/mobile/donations/{id:guid}/proof`
`multipart/form-data`, field `files` (`List<IFormFile>`, required). Attaches transfer-proof/photos to a donation made without an attachment. File is reviewed by the platform before the donation is verified.

Response: `DonationResponse`.

### POST `api/mobile/donations/{id:guid}/dropped-at-center`
No body. Donor self-reports having physically dropped the donation at its assigned Center. This is informational only — status becomes `DroppedAtCenter` and still waits on Center staff confirmation (`ConfirmedByCenter`).

Response: `DonationResponse`.

### GET `api/mobile/donations/trace`
"Where did all my money go?" — fund-flow graph across every donation the caller has made.

Response (`FundFlowGraph`): `Nodes` (`FundFlowNode[]`: `Id`, `Type` (enum `FundFlowNodeType`: `Donor, Transaction, Charity, Campaign, Case, Beneficiary`), `Label`), `Edges` (`FundFlowEdge[]`: `From` (Guid), `To` (Guid), `Amount` (decimal), `Label` (string)).

### GET `api/mobile/donations/{id:guid}/trace`
Fund-flow graph for one specific donation. Same `FundFlowGraph` response shape as above.

---

## Centers

Controller: `CentersController` — `api/mobile/centers`. GiveChain-owned physical intake points where a donor can hand off a pledge (see `CreateDonationRequest.CenterId`).

### GET `api/mobile/centers`
Lists active centers, optionally filtered. Query: `cityId?` (Guid), `countryId?` (Guid).

Response: `CenterResponse[]` — `Id`, `Name`, `CountryId?`, `CityId?`, `AddressDetails?`, `WorkingHours?`, `OpensAt` (DateTime), `ClosesAt?` (DateTime), `Status` (enum `CenterStatus`: `Active=0`, `Inactive=1`), `IsCurrentlyOpen` (bool, computed).

---

## Benefits

Controller: `BenefitsController` — `api/mobile/benefits`. Donor-side "apply for aid" flow (requesting to receive help from a charity's benefit program, the flip side of donating).

### POST `api/mobile/benefits`
Submits a benefit request (application) against a charity's `BenefitType` (see `charities/{id}/benefit-types`), answering that type's configured questions.

Request (`SubmitBenefitRequestRequest`): `BenefitTypeId` (Guid, required), `Answers` (`BenefitRequestAnswerRequest[]`: `QuestionId` (Guid), `Answer` (string?) — one entry per question, required ones per `BenefitTypeQuestionResponse.IsRequired`).

Response: `BenefitRequestResponse` — `Id`, `BenefitTypeId`, `BenefitTypeName`, `PersonId`, `Person` (`PersonResponse`), `RequestNumber`, `SubmittedAt`, `Status` (enum `BenefitStatus`: `Pending, Approved, Rejected`), `ReviewNotes?`, `ReviewedAt?`, `Answers` (`BenefitRequestAnswerResponse[]`: `QuestionId`, `QuestionText`, `Answer?`).

### GET `api/mobile/benefits`
"My benefit requests." Query: `page` (default 1), `pageSize` (default 10).

Response: paged `BenefitRequestResponse[]` (same shape as above).

---

## Complaints

Controller: `ComplaintsController` — `api/mobile/complaints`. Donor-facing complaint filing against a charity.

### POST `api/mobile/complaints`
`multipart/form-data`. Files a complaint. Evidence images go in `attachments`.

Request (`CreateComplaintRequest`):
| Field | Type | Required | Notes |
|---|---|---|---|
| CharityId | Guid | yes | charity being complained about |
| ComplaintType | enum `ComplaintType` | yes | `General=0, Financial=1, Staff=2, Service=3, Other=4` |
| Description | string | yes | |
| Severity | enum `ComplaintSeverity` | yes | `Low=0, Medium=1, High=2, Critical=3` |

Response: `ComplaintResponse` — `Id`, `ComplaintNumber`, `CharityId`, `SubmittedById?`, `ComplaintType`, `Description`, `Severity`, `Status` (enum `ComplaintStatus`: `Open=0, InProgress=1, Resolved=2, Closed=3`), `CreatedAt`, `ResolvedById?`, `ResolvedAt?`, `ResolutionNotes?`, `Medias` (`MediaFileResponse[]`).

### GET `api/mobile/complaints`
"My complaints." Query: `page` (default 1), `pageSize` (default 10). Response: paged `ComplaintResponse[]`.

### GET `api/mobile/complaints/{id:guid}`
One of the caller's own complaints (scoped to `CurrentUserId` server-side). Response: `ComplaintResponse`.

---

## Notifications

Controller: `NotificationsController` — `api/mobile/notifications`. **The only controller in this API where `[Authorize]` is actually active** (applied at the class level, not commented out).

### GET `api/mobile/notifications`
"My notifications." Query: `page` (default 1), `pageSize` (default 20).

Response: paged `NotificationResponse[]` — `Id`, `Title`, `Body`, `Type` (enum `NotificationType`: `CampaignReachedTarget, NewDonationReceived, CampaignCompleted, BeneficiaryApproved, BeneficiaryRejected, InventoryLowStock, CharityApproved, CharityRejected, TicketUpdated, ComplaintUpdated, General`), `IsRead` (bool), `ReferenceId?` (string — id of the related entity, e.g. a donation or campaign id, for deep-linking), `CreatedAt`.

### GET `api/mobile/notifications/unread-count`
Response: `int`.

### PATCH `api/mobile/notifications/{id:guid}/read`
Marks one notification read. Response: `bool`.

### PATCH `api/mobile/notifications/read-all`
Marks all of the caller's notifications read. Response: `bool`.

---

## Not implemented (routes exist as dead/commented-out code — do not build against these)

The following controllers under `Controllers/Mobile/ToDo/**` are entirely commented out in source and are **not currently registered/callable**: `BlockchainController` (`api/mobile/blockchain/donations/{id}/transactions`), `ConversationsController` (`api/mobile/conversations` — start/list charity chat), `FundFlowController` (`api/mobile/donations/{id}/trace`, `api/mobile/fund-flow/path` — superseded by the live `TraceMyDonationsAsync`/`TraceDonationAsync` endpoints under **Donations** above), `GeographicController` (`api/mobile/geographic/charities/nearest`), `RecommendationsController` (`api/mobile/recommendations/campaigns`). If the mobile app needs any of these features, confirm with backend whether/when they'll be wired up.

---

## Enum quick reference

| Enum | Values |
|---|---|
| `UserType` | `PublicUser, CharityUser, SystemUser` |
| `Gender` | `Male=0, Female=1` |
| `UserStatus` | `Active=0, Inactive=1, Suspended=2` |
| `FieldType` | `Text, Numeric, Boolean, Date, Attachment, Option, MultiOption` |
| `CharityStatus` | `Active=0, Suspended=1, Deleted=2` |
| `CampaignStatus` | `Planning=0, Active=1, Paused=2, Completed=3, Cancelled=4` |
| `CampaignOwnerType` | `Charity=0, Platform=1` |
| `CompaignGoalType` | `Money=1, Items=2, Volunteers=3, Services=4` |
| `CaseStatus` | `Open, InProgress, Resolved, Closed` |
| `CasePriority` | `Low=0, Normal=1, High=2, Urgent=3` |
| `CaseNeedUnit` | `Money, Kilogram, Gram, Piece, Box, Liter, Meter, Pack` |
| `DonationType` | `Money=1, Item=2, Service=3` |
| `DonationTargetType` | `Campaign=1, Case=2, Charity=3` |
| `DonationStatus` | `PendingPayment=0, Pledged=1, Received=2, Verified=3, Rejected=4, PaymentFailed=5, DroppedAtCenter=6, ConfirmedByCenter=7, TransferredToCharity=8` |
| `PaymentMethod` | `Cash=0, BankTransfer=1` (no online gateway) |
| `PaymentStatus` | `NotApplicable=0, Pending=1, Processing=2, Completed=3, Failed=4, Refunded=5` |
| `DonationDeliveryMethod` | `DropOff=1, Delivery=2, Electronic=3` |
| `CenterStatus` | `Active=0, Inactive=1` |
| `BenefitStatus` | `Pending, Approved, Rejected` |
| `ComplaintType` | `General=0, Financial=1, Staff=2, Service=3, Other=4` |
| `ComplaintSeverity` | `Low=0, Medium=1, High=2, Critical=3` |
| `ComplaintStatus` | `Open=0, InProgress=1, Resolved=2, Closed=3` |
| `NotificationType` | `CampaignReachedTarget, NewDonationReceived, CampaignCompleted, BeneficiaryApproved, BeneficiaryRejected, InventoryLowStock, CharityApproved, CharityRejected, TicketUpdated, ComplaintUpdated, General` |
| `FundFlowNodeType` | `Donor, Transaction, Charity, Campaign, Case, Beneficiary` |
