# GiveChain — Mobile App Guide

> **One doc for the whole mobile app.** Part A explains the **product & screens** (for UI/UX). Part B is the **API reference** (for the developer). They share one enum table (§B-17) and one open-questions list (§C).
>
> **Base URL (local dev):** `http://localhost:5096` · **Swagger:** `{baseUrl}/swagger` → **Mobile** · **OpenAPI JSON:** `{baseUrl}/swagger/mobile/swagger.json`

---

## Contents

**Part A — Product & Screens (UI/UX)**
- [A-1 What the app is](#a-1-what-the-app-is)
- [A-2 Navigation structure](#a-2-navigation-structure)
- [A-3 Onboarding & Auth](#a-3-onboarding--auth)
- [A-4 Home feed](#a-4-home-feed)
- [A-5 Charities](#a-5-charities)
- [A-6 Campaigns](#a-6-campaigns)
- [A-7 Cases](#a-7-cases)
- [A-8 Donation flow](#a-8-donation-flow-the-heart-of-the-app)
- [A-9 My donations & fund tracing](#a-9-my-donations--fund-tracing)
- [A-10 Benefits](#a-10-benefits-apply-for-aid)
- [A-11 Complaints](#a-11-complaints)
- [A-12 Notifications](#a-12-notifications)
- [A-13 Profile & settings](#a-13-profile--settings)
- [A-14 Cross-cutting UI states](#a-14-cross-cutting-ui-states)
- [A-15 Screen inventory](#a-15-screen-inventory-checklist)

**Part B — API Reference (Developer)**
- [B-1 Getting started (envelope, paging, auth)](#b-1-getting-started)
- [B-2 Auth](#b-2-auth) · [B-3 Home](#b-3-home-feed) · [B-4 Charities](#b-4-charities) · [B-5 Campaigns](#b-5-campaigns) · [B-6 Cases](#b-6-cases)
- [B-7 Donations](#b-7-donations) · [B-8 Fund tracing](#b-8-fund-tracing) · [B-9 Benefits](#b-9-benefits) · [B-10 Complaints](#b-10-complaints)
- [B-11 Notifications](#b-11-notifications) · [B-12 Profile](#b-12-profile) · [B-13 Lookups](#b-13-lookups) · [B-14 Media](#b-14-media)
- [B-17 Enum reference](#b-17-enum-reference) · [B-18 Build order](#b-18-suggested-build-order)

**Part C — [Open questions to confirm](#part-c--open-questions-to-confirm)**

---
---

# Part A — Product & Screens (UI/UX)

## A-1 What the app is

GiveChain is a **donation & charity platform**. A public user can:

- Discover charities, donation **campaigns**, and individual **cases** (people/families in need).
- **Donate** money, physical items, or services — and later **trace where their money went**.
- **Apply for benefits** offered by charities (e.g. a food basket, medical aid).
- **File complaints** against a charity.
- Manage their **profile** and receive **notifications**.

**The core emotional hook is trust & transparency:** the user gives, and the app *shows them the impact and the money trail*. Lean into that in the visual design — progress bars, "verified" badges, and the fund-flow trace are the trust-building moments.

### Language & direction
The backend labels are **Arabic**. Design the app **Arabic-first, RTL (right-to-left)**. Mirror layouts, align text right, and flip directional icons (back arrows, chevrons). Plan for an English toggle later, but Arabic RTL is the default.

---

## A-2 Navigation structure

A **bottom tab bar** (5 tabs):

| Tab | Screen | Purpose |
|---|---|---|
| 🏠 **Home** | Home feed | Featured campaigns, recent charities & cases — the discovery entry point |
| 🔍 **Explore** | Browse charities / campaigns / cases | Full lists with search & filters |
| ➕ **Donate** | (center action) | Quick entry to donate / view targets |
| 🔔 **Notifications** | Notifications list | Activity & updates, with an unread badge |
| 👤 **Profile** | Profile & account | My info, my donations, my requests, my complaints, settings |

Secondary flows (donation checkout, benefit application, complaint filing, fund-flow trace, charity details) open as **pushed screens / modals** on top of the tabs.

> **Auth gating:** Home, Explore, and viewing charities/campaigns/cases are **public** (browse before you sign in). The moment the user tries to **donate, apply, complain, or open Profile/Notifications**, prompt sign-in. Keep browsing frictionless; gate only actions. *(API detail: [B-1 Authentication](#authentication).)*

---

## A-3 Onboarding & Auth

**Screens:** Splash → Welcome → Login / Register → Forgot/Reset password. *(API: [B-2 Auth](#b-2-auth).)*

### Welcome
Short value pitch ("Give with confidence — see exactly where your donation goes"). Two buttons: **Login**, **Register**. A **"Browse as guest"** link that drops into Home.

### Login
- Fields: **email _or_ username**, **password**. (Backend accepts either identifier.)
- "Forgot password?" link.
- On success → land on Home, now authenticated.

### Register
A single form (or a short 2-step wizard):
- Required: first name, last name, username, email, password.
- Optional: birth date, national number, **country → city** (dependent dropdowns from lookups), **gender**, **profile photo**.
- May also show **extra custom fields** the platform requires (fetched dynamically) — render as a dynamic form section.
- On success the user is **logged in immediately** (no separate login step).

### Forgot / Reset password
1. Enter email → "we sent you a code".
2. Enter **code + new password** → success → back to Login.

**States to design:** loading spinners on submit, inline field validation, "invalid credentials", "email not found", success toasts.

---

## A-4 Home feed

**One screen, scrollable, three sections** *(API: [B-3](#b-3-home-feed))*:

1. **Featured campaigns** — horizontal carousel of campaign cards (cover image, name, progress bar, charity).
2. **Recent charities** — horizontal row of charity chips/logos.
3. **Recent cases** — vertical list of case cards (photo, title, priority tag, charity).

Each card taps into its detail screen. Include a top greeting/search entry. Make it visual and inviting.

**States:** skeleton loaders per section, empty state ("No campaigns yet — check back soon"), pull-to-refresh.

---

## A-5 Charities

*(API: [B-4](#b-4-charities))*

### Charity list (Explore → Charities)
Paged, scrollable list. Each **charity card**: logo, name, city/country, category chips, short description. Infinite scroll.

### Charity detail
Header with logo, name, location, **status** and **category** chips, description. Then **tabbed content**:
- **Campaigns** tab → the charity's active campaigns.
- **Cases** tab → the charity's open cases.
- **Benefit types** tab → what you can **apply for** at this charity (each item → starts a benefit application).

Primary actions: **Donate** (to a campaign/case), **Apply for a benefit**, **File a complaint** (against this charity).

---

## A-6 Campaigns

*(API: [B-5](#b-5-campaigns))*

### Campaign list
Paged list/grid of campaign cards. Each card: cover image, name, charity, **goal progress** (e.g. "42,000 / 100,000"), status tag.

> **Progress bar:** use `achievedAmount / targetAmount` for money goals, or `achievedQuantity / targetQuantity` for item/volunteer/service goals. Show the right unit.

### Campaign detail
- **Image gallery** (media carousel; the "primary" image is the cover).
- Name, charity, description, start/end dates, **status** badge.
- **Goal progress** prominently (big progress ring or bar + amounts).
- Campaign **type** chip.
- Sticky **"Donate"** button → opens the donation flow pre-targeted to this campaign.

**States:** if a campaign is `Completed`/`Cancelled`, show that state and disable/adjust the Donate button.

---

## A-7 Cases

Cases are individual needs (a family, a person, a specific requirement). *(API: [B-6](#b-6-cases))*

### Case list
Paged list of case cards: photo, title, **priority tag** (Low/Normal/High/**Urgent**), charity, short description. Urgent cases should stand out (color/badge).

### Case detail
- Image gallery.
- Title, description, **category**, **priority**, location details, published date.
- **Status** (Open / In Progress / Resolved / Closed).
- If the case has specific **needs**, let the donor choose which need to fund.
- Sticky **"Donate"** button → donation flow pre-targeted to this case.

---

## A-8 Donation flow (the heart of the app)

Triggered from a campaign, a case, or the Donate tab. A **short wizard** with a clear summary and confirmation. *(API: [B-7](#b-7-donations).)*

### Step 1 — Choose donation type
Three big choices: **Money 💵 · Item 📦 · Service 🛠️**. The following fields change based on this choice.

### Step 2 — Details (depends on type)
- **Money:** amount, **payment method** (Cash, Bee transfer, Bank transfer, **Stripe card**, ShamCash).
- **Item:** item name, description, quantity + **unit** (kg, piece, box, liter…), delivery method (drop-off / delivery).
- **Service:** service description, scheduled date, delivery method.
- All types: optional **message** to the charity, optional **photo attachments**.

### Step 3 — Review & confirm
Summary card: target (campaign/case name), type, amount/details, method. Big **"Confirm donation"** button.

### Step 4 — Payment (money only)
- **Cash:** no online step. Show "Bring it to the charity — they'll verify it." Status starts as *Pledged*.
- **Online card (Stripe / ShamCash):** the response gives a **payment URL** → open it in a web view / browser for the donor to pay. On return, the donation auto-updates.
- **Bee / Bank transfer:** after the donor pays externally, show a **"Confirm payment"** screen where they enter a **payment reference** to submit.

### Step 5 — Success
Celebratory confirmation ("Thank you! ❤️"). Follow-up actions: **"Trace my donation"** and **"Back to campaign/case"**.

**Donation status vocabulary** (show as a labeled badge, not a raw number):
`Pending payment · Pledged · Received · Verified · Rejected · Payment failed`. "Verified" is the trust milestone — highlight it (green check).

---

## A-9 My donations & fund tracing

*(API: [B-7 my donations](#b-7-donations) + [B-8 tracing](#b-8-fund-tracing))*

### My donations (Profile → My donations)
Paged history list. Each row: target name, amount/details, date, **status badge**. Tap → donation detail with media and a **"Trace this donation"** action.

### Fund-flow trace ("Where did my money go?")
The signature transparency feature. The API returns a **graph** of nodes and edges:
- **Nodes:** You (donor) → Transaction → Charity → Campaign/Case → Beneficiary.
- **Edges:** money-weighted arrows with amounts and labels.

**Design it as a vertical flow / timeline** (easier on mobile than a free-form graph): each hop is a card connected by an arrow showing the amount. Two entry points:
- Trace **one** donation.
- Trace **all** my donations combined — a bigger map.

Worth extra design polish — it's the app's "wow, I can actually see it" moment.

---

## A-10 Benefits (apply for aid)

The user isn't only a giver — they can also **request help**. *(API: [B-9](#b-9-benefits).)*

### Discover
From a charity's **Benefit types** tab, each item (e.g. "Food basket") is something you can apply for.

### Apply — dynamic form
Each benefit type has its own **questions**. Render a **dynamic form** from those questions (text, number, choice… depending on field type; some required). Submit answers together.

### My benefit requests (Profile → My requests)
Paged list: benefit type name, request number, submitted date, **status** (Pending / Approved / Rejected), and — when reviewed — **review notes**. Tapping shows the submitted answers and the decision.

**States:** pending (neutral), approved (green + notes), rejected (red + reason).

---

## A-11 Complaints

Let users hold charities accountable. *(API: [B-10](#b-10-complaints).)*

### File a complaint
Choose the **charity**, **type** (General / Financial / Staff / Service / Other), **severity** (Low → Critical), a **description**, and optional **evidence photos**.

### My complaints (Profile → My complaints)
Paged list: complaint number, charity, type, **severity**, **status** (Open / In Progress / Resolved / Closed), date. Detail view shows the full description, attached evidence, and — once handled — **resolution notes**.

---

## A-12 Notifications

*(API: [B-11](#b-11-notifications))*
- **List** (Notifications tab): title, body, timestamp, read/unread styling. Newest first.
- **Unread badge** on the tab (from the unread-count endpoint).
- Tap a notification → **mark it read** and, when it has a reference id, **deep-link** to the related item (a donation, case, request…).
- **"Mark all as read"** action at the top.

---

## A-13 Profile & settings

A hub screen with avatar, name, and menu *(API: [B-12](#b-12-profile))*:
- **My profile** → view/edit personal info (name, national number, birth date, gender, country/city, photo).
- **My info answers** → view/update answers to the platform's custom fields.
- **My donations** → history + tracing (A-9).
- **My benefit requests** → (A-10).
- **My complaints** → (A-11).
- **Change password**.
- **Log out**.

---

## A-14 Cross-cutting UI states

Design these once, reuse everywhere:

| State | When | What to show |
|---|---|---|
| **Loading** | Any fetch | Skeletons for lists/cards; spinners for actions |
| **Empty** | List has 0 items | Friendly illustration + one-line message + optional CTA |
| **Error** | Request failed (`isSuccess: false`) | Show the returned message; offer **Retry** |
| **Auth required** | Guest taps a gated action | Sign-in sheet, then continue the original action |
| **Success** | After donate/apply/submit | Toast or celebratory screen; next-step CTA |
| **Pull-to-refresh** | Feed & lists | Standard refresh control |
| **Pagination** | Long lists | Infinite scroll / "load more" |

**Status → color mapping** (consistent app-wide):
- 🟢 Green = Verified / Approved / Resolved / Active
- 🟡 Amber = Pending / In Progress / Paused
- 🔴 Red = Rejected / Failed / Cancelled / Critical
- ⚪ Grey = Draft / Closed / Planning

> The API returns **numbers** for statuses and types. Map every number to a **localized label + color** in one place (see [B-17 enum reference](#b-17-enum-reference)) — never show a raw number to the user.

---

## A-15 Screen inventory (checklist)

**Auth:** Splash · Welcome · Login · Register · Forgot password · Reset password
**Home:** Home feed
**Explore:** Charity list · Campaign list · Case list (with search/filter)
**Details:** Charity detail (tabs) · Campaign detail · Case detail
**Donate:** Type picker · Details form · Review · Payment / web-checkout · Confirm-payment (Bee/Bank) · Success
**Trace:** Single-donation trace · All-donations trace
**Benefits:** Benefit types (per charity) · Apply (dynamic form) · My requests · Request detail
**Complaints:** File complaint · My complaints · Complaint detail
**Notifications:** Notifications list
**Profile:** Profile hub · Edit profile · Info answers · My donations · Donation detail · Change password
**Shared:** Media viewer/gallery · Image uploader · Country/City pickers

**Design priorities:** put the strongest visual craft into **campaign/case cards & progress**, the **donation success moment**, and the **fund-flow trace** — those three carry the product's promise.

---
---

# Part B — API Reference (Developer)

## B-1 Getting started

### Response envelope
**Every** endpoint returns this wrapper (`ApiResponse<T>`):
```jsonc
{
  "message": "Optional human message (may be Arabic)",
  "data": { /* payload — shape depends on endpoint; null on failure */ },
  "errors": ["error 1", "error 2"],   // null when successful
  "isSuccess": true                    // false when "errors" is non-empty
}
```
- HTTP **200** → `isSuccess: true`, read `data`.
- HTTP **400** → `isSuccess: false`, read `message` / `errors`, `data` is null.
- **Always branch on `isSuccess`**, not just the HTTP code.

### Paged lists
List endpoints wrap results in `PagedResult<T>` inside `data`:
```jsonc
{ "items": [ /* T[] */ ], "totalCount": 137, "page": 1, "pageSize": 10, "totalPages": 14 }
```
Query params for all paged endpoints: `?page=1&pageSize=10` (both optional; defaults shown).

### Authentication
- **Scheme:** JWT Bearer. Send `Authorization: Bearer <token>` on every authenticated call.
- **Token lifetime:** 30 days (43200 minutes).
- **Where the token comes from:** the `token` field in the login/register response.
- The token identifies the current user; the backend reads the user id from it, so **you never pass a user id in the body** for "my …" endpoints.

> **Important for testing:** the `[Authorize]` guard is currently commented out on most mobile endpoints, but any endpoint that acts on "the current user" (donations, complaints, profile, benefits, notifications) reads the user id **from the token**. Calling those without a valid `Authorization` header will fail with a **500**. Treat all "my …" endpoints as **auth-required**. Public browse endpoints (home, charities, cases, campaigns, lookups) work without a token.

Import the OpenAPI JSON (`{baseUrl}/swagger/mobile/swagger.json`) into Postman/Insomnia for a ready-made collection.

---

## B-2 Auth

Base: `/api/mobile/auth`

| Method | Route | Auth | Summary |
|---|---|---|---|
| POST | `/login` | No | Sign in |
| POST | `/register` | No | Register a public user (multipart — supports profile image) |
| POST | `/forgot-password` | No | Send reset code to email |
| POST | `/reset-password` | No | Reset password using the code |
| GET | `/info-fields` | No | Extra custom fields required at registration for a public user |

### POST `/login`
Request (JSON) — pass **either** `email` or `userName`, plus `password`:
```jsonc
{ "email": "user@example.com", "userName": "", "password": "secret" }
```
Response `data` = **AuthResponse**:
```jsonc
{
  "userId": "guid",
  "token": "eyJhbGci...",       // store this, send as Bearer
  "email": "user@example.com",
  "fullName": "Sara Ali",
  "userType": 0,                 // 0 = PublicUser
  "isAdmin": null,
  "userName": "sara",
  "userStatus": 0,               // 0 = Active
  "roleId": null, "role": null, "permissions": null
}
```

### POST `/register`
**multipart/form-data** — **MobileRegisterRequest**:

| Field | Type | Required | Notes |
|---|---|---|---|
| `FirstName` | string | ✔ | |
| `LastName` | string | ✔ | |
| `Username` | string | ✔ | |
| `Email` | string | ✔ | |
| `Password` | string | ✔ | |
| `BirthOfDate` | date | – | ISO 8601 |
| `NationalNumber` | string | – | |
| `CountryId` | guid | – | from lookups |
| `CityId` | guid | – | from lookups |
| `Gender` | enum int | ✔ | 0 = Male, 1 = Female |
| `ProfileImage` | file | – | image upload |

Response `data` = **AuthResponse** (logged in immediately).

### POST `/forgot-password`
```jsonc
{ "email": "user@example.com" }
```
`data` = boolean.

### POST `/reset-password`
```jsonc
{ "email": "user@example.com", "code": "123456", "newPassword": "..." }
```
`data` = boolean.

### GET `/info-fields`
`data` = **PersonInfoFieldResponse[]**:
```jsonc
{ "id": "guid", "fieldName": "...", "fieldType": 0, "userType": 0, "isRequired": true }
```
Collect answers and submit later via [Profile → info-answers](#b-12-profile).

---

## B-3 Home feed

Base: `/api/mobile/home` — GET `/` (no auth). `data` = **HomeFeedResponse**:
```jsonc
{
  "featuredCampaigns": [ /* CampaignResponse[] */ ],
  "recentCharities":   [ /* CharityResponse[]  */ ],
  "recentCases":       [ /* CaseResponse[]     */ ]
}
```

---

## B-4 Charities

Base: `/api/mobile/charities`

| Method | Route | Auth | Summary |
|---|---|---|---|
| GET | `/?page=&pageSize=` | No | Browse all charities (paged) |
| GET | `/{id}` | No | Charity details |
| GET | `/{id}/campaigns?page=&pageSize=` | No | Charity's active campaigns |
| GET | `/{id}/cases?page=&pageSize=` | No | Charity's open cases |
| GET | `/{id}/benefit-types` | No | Active benefit types offered by the charity |

**CharityResponse**:
```jsonc
{
  "id": "guid", "name": "...", "description": "...",
  "subDomain": "noor", "logoUrl": "https://.../logo.png",
  "country": "Syria", "city": "Damascus",
  "status": 0,                 // CharityStatus
  "date": "2026-01-01T00:00:00Z",
  "categories": [ { "id": "guid", "name": "...", "description": "..." } ]
}
```
`/{id}/benefit-types` → **BenefitTypeResponse[]**:
```jsonc
{ "id": "guid", "name": "Food basket", "description": "...", "isActive": true }
```

---

## B-5 Campaigns

Base: `/api/mobile/campaigns`

| Method | Route | Auth | Summary |
|---|---|---|---|
| GET | `/?page=&pageSize=` | No | List active campaigns |
| GET | `/by-charity/{charityId}?page=&pageSize=` | No | A charity's active campaigns |
| GET | `/{id}` | No | Campaign details |
| POST | `/{id}/donate` | **Yes** | Donate to this campaign (multipart) |

**CampaignResponse** (key fields):
```jsonc
{
  "id": "guid", "charityId": "guid",
  "ownerType": 0,               // 0 Charity, 1 Platform
  "isTrusted": true,
  "campaignName": "...", "campaignDescription": "...",
  "startDate": "2026-06-01T00:00:00Z", "endDate": "2026-09-01T00:00:00Z",
  "status": 1,                  // CampaignStatus
  "campaignTypeId": "guid",
  "campaignType": { "id": "guid", "name": "...", "iconUrl": "...", "charityCategoryId": "guid" },
  "goalType": 1,                // 1 Money,2 Items,3 Volunteers,4 Services
  "targetAmount": 100000.0, "achievedAmount": 42000.0,   // progress bar
  "targetQuantity": null, "achievedQuantity": null, "goalUnit": null,
  "creator": { "id": "guid", "userName": "...", "email": "...", "isCharityUser": true },
  "medias": [ /* MediaFileResponse[] — images/cover */ ]
}
```

### POST `/{id}/donate`
**multipart/form-data**. Body is a [CreateDonationRequest](#createdonationrequest-multipartform-data) — do **not** set `targetType`/`campaignId`, the backend fixes them to this campaign. Optional files as `attachments`.

---

## B-6 Cases

Base: `/api/mobile/cases`

| Method | Route | Auth | Summary |
|---|---|---|---|
| GET | `/?page=&pageSize=` | No | Browse all **open** cases |
| GET | `/{id}` | No | Case details |
| GET | `/by-charity/{charityId}?page=&pageSize=` | No | A charity's open cases |
| POST | `/{id}/donate` | **Yes** | Donate to this case (multipart) |

**CaseResponse**:
```jsonc
{
  "id": "guid", "charityId": "guid",
  "categoryId": "guid",
  "category": { "id": "guid", "name": "...", "iconUrl": "...", "charityCategoryId": "guid" },
  "priority": 1,                // CasePriority: 0 Low,1 Normal,2 High,3 Urgent
  "cityId": "guid", "locationDetails": "...",
  "title": "...", "description": "...",
  "status": 0,                  // CaseStatus: 0 Open,1 InProgress,2 Resolved,3 Closed
  "publishedAt": "2026-06-10T00:00:00Z", "closedAt": null, "closedNotes": null,
  "medias": [ /* MediaFileResponse[] */ ]
}
```

### POST `/{id}/donate`
Backend fixes `targetType=Case` and `caseId`. If the case has specific **needs**, set `caseNeedId` in the body. Multipart with optional `attachments`.

---

## B-7 Donations

Base: `/api/mobile/donations`

| Method | Route | Auth | Summary |
|---|---|---|---|
| POST | `/` | **Yes** | Create a donation (money / item / service), multipart |
| POST | `/{id}/confirm-payment` | **Yes** | Confirm electronic payment (e.g. Bee) |
| GET | `/?page=&pageSize=` | **Yes** | My donation history |
| GET | `/trace` | **Yes** | Full "where did my money go" graph (all my donations) |
| GET | `/{id}/trace` | **Yes** | Fund-flow graph for one donation |

> You can also donate through the campaign/case donate endpoints ([B-5](#b-5-campaigns)/[B-6](#b-6-cases)).

### CreateDonationRequest (multipart/form-data)
One request shape covers all three kinds; which fields matter depends on `donationType`:

| Field | Type | Applies to | Notes |
|---|---|---|---|
| `donationType` | enum int | all | 1 Money, 2 Item, 3 Service |
| `targetType` | enum int | all | 1 Campaign, 2 Case *(auto-set by campaign/case donate endpoints)* |
| `campaignId` | guid | Campaign target | |
| `caseId` | guid | Case target | |
| `caseNeedId` | guid | Case target | the specific need being funded |
| `message` | string | all | optional donor note |
| `amount` | decimal | **Money** | required for money |
| `paymentMethod` | enum int | Money | 0 Cash, 1 BeeTransfer, 2 BankTransfer, 3 Stripe, 4 ShamCash |
| `itemName` | string | **Item** | required for item |
| `itemDescription` | string | Item | |
| `quantity` | int | Item | |
| `unit` | enum int | Item | CaseNeedUnit |
| `serviceDescription` | string | **Service** | required for service |
| `scheduledAt` | date | Service | |
| `deliveryMethod` | enum int | Item / Service | 1 DropOff, 2 Delivery, 3 Electronic |
| `attachments` | file[] | all | optional images/docs |

### DonationResponse (key fields)
```jsonc
{
  "id": "guid", "donationType": 1, "targetType": 1,
  "campaignId": "guid", "campaignName": "...", "caseId": null, "caseNeedId": null,
  "charityId": "guid", "userId": "guid",
  "message": "...", "donationDate": "2026-07-01T10:00:00Z",
  "status": 1,                  // DonationStatus
  "amount": 500.0, "paymentMethod": 3, "paymentStatus": 1, "paymentReference": "...", "acceptedAmount": null,
  "paymentUrl": "https://checkout.stripe.com/...",  // redirect for online gateways; null for cash
  "itemName": null, "quantity": null, "unit": null, "acceptedQuantity": null,
  "serviceDescription": null, "scheduledAt": null, "deliveryMethod": null,
  "verifiedAt": null, "verificationNotes": null,
  "medias": [ /* MediaFileResponse[] */ ]
}
```

**Payment flow — online gateways (Stripe / ShamCash):**
1. POST the donation with `paymentMethod: 3` (Stripe) or `4` (ShamCash).
2. Response has a **`paymentUrl`** → open it (web view / browser) to complete payment.
3. Gateway settles; donation moves to `Pledged`/`Verified` automatically.

**Bee / Bank transfer:** after paying, call **POST `/{id}/confirm-payment`**:
```jsonc
{ "paymentReference": "TXN-12345" }   // ConfirmPaymentRequest
```
`data` = updated **DonationResponse**.

**Cash:** no payment step — the charity verifies manually; status stays `Pledged` until then.

---

## B-8 Fund tracing

Trace endpoints return a **FundFlowGraph**:
```jsonc
{
  "nodes": [ { "id": "guid", "type": 0, "label": "You" } ],  // type: 0 Donor,1 Transaction,2 Charity,3 Campaign,4 Case,5 Beneficiary
  "edges": [ { "from": "guid", "to": "guid", "amount": 500.0, "label": "donated" } ]
}
```
- `GET /api/mobile/donations/trace` → graph across **all** my donations.
- `GET /api/mobile/donations/{id}/trace` → graph for one donation.

---

## B-9 Benefits

Base: `/api/mobile/benefits`

| Method | Route | Auth | Summary |
|---|---|---|---|
| POST | `/` | **Yes** | Submit a benefit application |
| GET | `/?page=&pageSize=` | **Yes** | My benefit requests |

**Flow:** pick a charity → `GET /api/mobile/charities/{id}/benefit-types` → present the type's questions → submit.

### POST `/` — SubmitBenefitRequestRequest
```jsonc
{ "benefitTypeId": "guid", "answers": [ { "questionId": "guid", "answer": "text answer" } ] }
```

### GET `/` → **BenefitRequestResponse[]** (paged)
```jsonc
{
  "id": "guid", "benefitTypeId": "guid", "benefitTypeName": "Food basket",
  "personId": "guid", "requestNumber": "REQ-...", "submittedAt": "2026-07-01T00:00:00Z",
  "status": 0,                  // BenefitStatus: 0 Pending,1 Approved,2 Rejected
  "reviewNotes": null, "reviewedAt": null,
  "answers": [ { "questionId": "guid", "questionText": "How many in your family?", "answer": "5" } ]
}
```

---

## B-10 Complaints

Base: `/api/mobile/complaints`

| Method | Route | Auth | Summary |
|---|---|---|---|
| POST | `/` | **Yes** | File a complaint against a charity (multipart, evidence files) |
| GET | `/?page=&pageSize=` | **Yes** | My complaints |
| GET | `/{id}` | **Yes** | My complaint details |

### POST `/` — CreateComplaintRequest (multipart/form-data)
| Field | Type | Notes |
|---|---|---|
| `CharityId` | guid | who the complaint is against |
| `ComplaintType` | enum int | 0 General,1 Financial,2 Staff,3 Service,4 Other |
| `Description` | string | |
| `Severity` | enum int | 0 Low,1 Medium,2 High,3 Critical |
| `attachments` | file[] | optional evidence images |

### ComplaintResponse
```jsonc
{
  "id": "guid", "complaintNumber": "CMP-20260701-AB12CD",
  "charityId": "guid", "submittedById": "guid",
  "complaintType": 1, "description": "...", "severity": 2,
  "status": 0,                  // ComplaintStatus: 0 Open,1 InProgress,2 Resolved,3 Closed
  "createdAt": "2026-07-01T00:00:00Z",
  "resolvedById": null, "resolvedAt": null, "resolutionNotes": null,
  "medias": [ /* MediaFileResponse[] */ ]
}
```

---

## B-11 Notifications

Base: `/api/mobile/notifications` — **all require auth**

| Method | Route | Summary |
|---|---|---|
| GET | `/?page=&pageSize=` | My notifications (default pageSize 20) |
| GET | `/unread-count` | Unread badge count → `data` is an int |
| PATCH | `/{id}/read` | Mark one as read → `data` bool |
| PATCH | `/read-all` | Mark all as read → `data` bool |

**NotificationResponse**:
```jsonc
{
  "id": "guid", "title": "...", "body": "...",
  "type": 0,                    // NotificationType
  "isRead": false,
  "referenceId": "guid-or-null", // related donation/case id for deep-linking
  "createdAt": "2026-07-01T00:00:00Z"
}
```

---

## B-12 Profile

Base: `/api/mobile/profile` — **all require auth**

| Method | Route | Summary |
|---|---|---|
| GET | `/` | View my profile |
| PUT | `/` | Update my profile |
| GET | `/info-answers` | My answers to custom info fields |
| PUT | `/info-answers` | Add/update one custom info answer |
| PUT | `/password` | Change password |

### GET `/` → **PersonResponse**
```jsonc
{
  "id": "guid", "firstName": "Sara", "lastName": "Ali",
  "nationalNumber": "...", "birthOfDate": "2000-01-01T00:00:00Z",
  "userType": 0, "gender": 1,
  "country": { "id": "guid", "countryName": "Syria", "cities": [] },
  "city":    { "id": "guid", "cityName": "Damascus", "countryId": "guid", "countryName": "Syria" },
  "imagePath": "https://.../me.png",
  "user": { /* UserSummaryResponse: username, email, status … */ }
}
```

### PUT `/` — UpdatePersonRequest (JSON, all optional)
```jsonc
{ "firstName": "...", "lastName": "...", "nationalNumber": "...", "birthOfDate": "2000-01-01", "gender": 1, "countryId": "guid", "cityId": "guid" }
```

### GET `/info-answers` → **PersonInfoAnswerResponse[]**
```jsonc
{ "id":"guid","personId":"guid","fieldId":"guid","fieldName":"...","answer":"...","attachments":[] }
```

### PUT `/info-answers` — UpsertPersonInfoAnswerRequest
```jsonc
{ "fieldId": "guid", "answer": "new value" }
```

### PUT `/password` — ChangePasswordRequest
```jsonc
{ "currentPassword": "...", "newPassword": "..." }
```

---

## B-13 Lookups

Base: `/api/lookup` (shared, **no auth**) — populate dropdowns.

| Method | Route | Summary |
|---|---|---|
| GET | `/countries` | All countries → **CountryResponse[]** |
| GET | `/cities` | All cities → **CityResponse[]** |
| GET | `/case-categories?charityId=&charityCategoryId=` | Case categories (optionally filtered) |
| GET | `/case-categories/{id}` | One case category |
| GET | `/campaign-types?charityId=&charityCategoryId=` | Campaign types (optionally filtered) |
| GET | `/campaign-types/{id}` | One campaign type |

Also: `GET /api/charities/lookup?subdomain=noor` (charity id by subdomain) · `GET /api/version` (`{ "version": "1.0.0" }`).

**CountryResponse** `{ id, countryName, cities: [...] }` · **CityResponse** `{ id, cityName, countryId, countryName }`

---

## B-14 Media

Base: `/api/media` (shared)

| Method | Route | Auth | Summary |
|---|---|---|---|
| POST | `/` | optional | Upload files and attach to an entity |
| GET | `/?ownerType=&ownerId=` | No | Get an entity's media |
| DELETE | `/{id}` | – | Delete a media file |

Most create flows (donation, complaint) accept `attachments` directly in their multipart body, so you usually **don't** need this endpoint — use it to attach media to an already-created entity.

### POST `/` (multipart/form-data)
| Field | Type | Notes |
|---|---|---|
| `ownerType` | enum int | 1 Case, 2 Campaign, 3 Donation, 4 Complaint, 5 Ticket, 6 BenefitRequest, 7 CaseUpdate |
| `ownerId` | guid | the entity's id |
| `files` | file[] | max 50 MB per request |

**MediaFileResponse** (embedded in other DTOs too):
```jsonc
{
  "id": "guid", "ownerType": 2, "ownerId": "guid",
  "url": "https://.../media/campaign/abc.png",   // ready-to-display absolute URL
  "mediaType": 0,                                 // MediaType (image/video/doc)
  "isPrimary": true,                              // the cover image
  "uploadedAt": "2026-07-01T00:00:00Z"
}
```
> Cover image = the media with `isPrimary: true` (fall back to the first).

---

## B-17 Enum reference

Enums serialize as **integers**. Map each to a localized label + color (see [A-14](#a-14-cross-cutting-ui-states)).

| Enum | Values |
|---|---|
| **UserType** | 0 PublicUser, 1 CharityUser, 2 SystemUser |
| **UserStatus** | 0 Active, 1 Inactive, 2 Suspended |
| **Gender** | 0 Male, 1 Female |
| **CampaignStatus** | 0 Planning, 1 Active, 2 Paused, 3 Completed, 4 Cancelled |
| **CampaignOwnerType** | 0 Charity, 1 Platform |
| **CompaignGoalType** | 1 Money, 2 Items, 3 Volunteers, 4 Services |
| **CaseStatus** | 0 Open, 1 InProgress, 2 Resolved, 3 Closed |
| **CasePriority** | 0 Low, 1 Normal, 2 High, 3 Urgent |
| **CaseNeedUnit** | 0 Money, 1 Kilogram, 2 Gram, 3 Piece, 4 Box, 5 Liter, 6 Meter, 7 Pack |
| **DonationType** | 1 Money, 2 Item, 3 Service |
| **DonationTargetType** | 1 Campaign, 2 Case |
| **DonationStatus** | 0 PendingPayment, 1 Pledged, 2 Received, 3 Verified, 4 Rejected, 5 PaymentFailed |
| **PaymentMethod** | 0 Cash, 1 BeeTransfer, 2 BankTransfer, 3 Stripe, 4 ShamCash |
| **PaymentStatus** | 0 NotApplicable, 1 Pending, 2 Processing, 3 Completed, 4 Failed, 5 Refunded |
| **DonationDeliveryMethod** | 1 DropOff, 2 Delivery, 3 Electronic |
| **BenefitStatus** | 0 Pending, 1 Approved, 2 Rejected |
| **ComplaintType** | 0 General, 1 Financial, 2 Staff, 3 Service, 4 Other |
| **ComplaintSeverity** | 0 Low, 1 Medium, 2 High, 3 Critical |
| **ComplaintStatus** | 0 Open, 1 InProgress, 2 Resolved, 3 Closed |
| **MediaOwnerType** | 0 None, 1 Case, 2 Campaign, 3 Donation, 4 Complaint, 5 Ticket, 6 BenefitRequest, 7 CaseUpdate |
| **FundFlowNodeType** | 0 Donor, 1 Transaction, 2 Charity, 3 Campaign, 4 Case, 5 Beneficiary |

---

## B-18 Suggested build order

1. **Auth** (login/register) → store token, add Bearer interceptor.
2. **Lookups** → countries/cities/categories for forms.
3. **Home + Charities + Campaigns + Cases** browse (all public — easy to start).
4. **Donations** (money first, then item/service) + payment redirect + confirm.
5. **Profile** + custom info answers.
6. **Benefits** apply/track, **Complaints** file/track.
7. **Notifications** + badge.
8. **Fund-flow trace** visualization (do last).

---
---

# Part C — Open questions to confirm

**With the backend team:**
- **Auth enforcement:** `[Authorize]` is commented out on mobile endpoints right now. Confirm it will be on before release, and that "my …" endpoints return **401** (not 500) when the token is missing/expired.
- **Reset-password payload:** confirm exact `ResetPasswordRequest` field names (`code` vs `token`, `newPassword`).
- **Benefit questions:** confirm the endpoint/shape that returns a benefit type's **questions** (options, field types) so dynamic apply-forms can be rendered.
- **Enum serialization:** integers vs strings (see [B-17](#b-17-enum-reference)).
- **File URLs:** confirm `MediaFileResponse.url` is always an absolute, directly-loadable URL in all environments.
- **Search/filters:** mobile list endpoints currently support paging only. Confirm whether server-side **search/filters** (category, city, priority, status) will be added for Explore, or if filtering is client-side for now.
- **Notification deep-links:** confirm what `referenceId` points to per notification type, for correct navigation.

**Design/product:**
- **Localization:** Arabic is primary (RTL). Confirm if/when English is needed so layouts stay bidirectional-ready.
