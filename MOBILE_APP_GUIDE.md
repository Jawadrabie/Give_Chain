# GiveChain — Mobile Developer Guide

Everything the **mobile app** developer needs to build the donor experience: the three donation
kinds, uploading proof of a bank transfer, dropping a donation at a GiveChain Center, and tracking
where the money went.

All mobile endpoints live under `/api/mobile/*` (Swagger group `Mobile`).

---

## 0. Conventions

**Response envelope** — every endpoint returns:

```jsonc
{
  "message": "…",        // optional human message (Arabic) — safe to surface in a toast
  "data":    { },        // the payload, null on failure
  "errors":  ["…"],      // null on success
  "isSuccess": true      // computed: errors is null/empty
}
```

Branch on `isSuccess`; show `errors` when false.

**Paged payload**:

```jsonc
{ "items": [], "totalCount": 42, "page": 1, "pageSize": 10, "totalPages": 5 }
```

**Auth**:

```http
POST /api/mobile/auth/login            { … }                 -> data.token
POST /api/mobile/auth/register         multipart/form-data
POST /api/mobile/auth/forgot-password
POST /api/mobile/auth/reset-password
GET  /api/mobile/auth/info-fields      // dynamic profile fields to render at registration
```

Send `Authorization: Bearer <token>` on everything else. The donor's identity always comes from the
token — **no endpoint takes a `userId`**.

**Enums are integers over the wire.** See section 6.

---

## 1. The one thing to understand first

**There is no online payment gateway.** No card form, no in-app checkout, no automatic "payment
succeeded" callback. Every donation is settled physically or manually, and a human confirms it.

That gives the donor two ways to give, and the whole app design follows from this:

### Route A — the donor goes to a GiveChain Center

The donor picks a physical Center (owned and staffed by GiveChain, not by the charity), goes there,
and hands over cash or goods at the counter. A Center employee confirms receipt in their own app.

### Route B — the donor gives from the app

The donor transfers money by bank outside the app, then **uploads a photo of the transfer receipt**.
GiveChain dashboard staff review that image by hand and either verify or reject the donation.

A donation is only real once someone has confirmed it. Design the UI so the donor understands their
donation is *pending review*, not *complete*, until `status` reaches `Verified (3)`.

---

## 2. Making a donation

```http
POST /api/mobile/donations
Content-Type: multipart/form-data
```

One request shape covers all three donation kinds. Send the `CreateDonationRequest` fields as form
fields, and any images as repeated `attachments` file parts.

### Common fields

| Field | Type | Notes |
|---|---|---|
| `donationType` | int | **Money 1 / Item 2 / Service 3** — drives which fields below are required |
| `targetType` | int | Campaign 1 / Case 2 |
| `campaignId` | guid? | Required when `targetType = Campaign` |
| `caseId` | guid? | When `targetType = Case` |
| `caseNeedId` | guid? | **Required when `targetType = Case`** — the specific need being funded |
| `message` | string? | Optional note from the donor |
| `centerId` | guid? | Set this to route the donation through a Center (money or item only) |
| `deliveryMethod` | int | DropOff 1 / Delivery 2 / Electronic 3 — item and service donations |

> A case donation targets a **need**, not the case as a whole. Show the case's needs list and make
> the donor pick one; send its id as `caseNeedId`.

### Money donation (`donationType = 1`)

| Field | Notes |
|---|---|
| `amount` | decimal, required |
| `paymentMethod` | **Cash 0** or **BankTransfer 1** |

- **Cash** — the donor will hand the money over in person. Either set `centerId` (drop off at a
  Center) or leave it null (hand it directly to the charity). No upload needed.
- **BankTransfer** — the donor transfers outside the app, then attaches the receipt image. Attach it
  here, or later via the proof endpoint in section 3.

### Item donation (`donationType = 2`)

| Field | Notes |
|---|---|
| `itemName` | required — e.g. "معاطف شتوية" |
| `itemDescription` | optional — condition, size, brand |
| `quantity` | int |
| `unit` | `CaseNeedUnit` |

Photos of the goods go in `attachments`.

### Service donation (`donationType = 3`)

| Field | Notes |
|---|---|
| `serviceDescription` | required — e.g. a free medical checkup, transport, tutoring |
| `scheduledAt` | date? — when the donor will perform it |

Service donations cannot be routed through a Center — a Center cannot take custody of a service.
Don't offer the Center picker for this type.

### Response

`DonationResponse` (see section 4). The new donation comes back as `status = Pledged (1)`.

---

## 3. After donating

```http
POST /api/mobile/donations/{id}/proof              multipart/form-data, field: files
POST /api/mobile/donations/{id}/dropped-at-center
```

**Upload proof later** — for a donor who pledged a bank transfer without attaching the receipt.
Their donation sits at `Pledged` with an empty `medias[]`. Prompt them from the donation detail
screen: an unverified bank-transfer donation with no attachment is stuck and will eventually be
rejected. This is the single most important nudge in the app.

**Mark dropped at a Center** — the donor tells the app they have handed the donation over at the
Center. Status moves to `DroppedAtCenter (6)`. This is the donor's claim, not proof: the donation
still waits for the Center employee to confirm, which moves it to `ConfirmedByCenter (7)`. Make that
distinction visible so the donor is not surprised that it is still not "done".

---

## 4. My donations

```http
GET /api/mobile/donations?<filters>
```

**One endpoint for every view of the donor's history** — the donor id comes from the token, so this
only ever returns their own donations. Build tabs and filter chips over this one call rather than
expecting extra routes.

Useful filters (all optional): `status`, `donationType`, `targetType`, `campaignId`, `caseId`,
`caseNeedId`, `centerId`, `throughCenter`, `paymentMethod`, `fromDate`, `toDate`, `minAmount`,
`maxAmount`, `search`, `page`, `pageSize`.

| Tab | Filter |
|---|---|
| قيد المراجعة | `status=1` |
| في المركز | `throughCenter=true` |
| موثّقة | `status=3` |
| مرفوضة | `status=4` |

### `DonationResponse`

Flat across all three kinds — type-specific fields are `null` when they don't apply. Switch the
detail view on `donationType`:

```jsonc
{
  "id": "…", "donationType": 1, "targetType": 1,
  "entityId": "…",            // Campaign.Id when targetType=Campaign, CaseNeed.Id when Case
  "entityName": "…",          // display name of whatever entityId points at — use this
  "charityId": "…",
  "userId": "…", "donorName": "…",
  "message": "…", "donationDate": "…", "status": 1,

  // Money
  "amount": 500.00, "paymentMethod": 1, "paymentStatus": 0,
  "paymentReference": null, "acceptedAmount": null,

  // Item
  "itemName": null, "itemDescription": null, "quantity": null,
  "unit": null, "acceptedQuantity": null,

  // Service
  "serviceDescription": null, "scheduledAt": null,

  "deliveryMethod": 1,

  // Center
  "centerId": null, "centerConfirmedAt": null,
  "centerConfirmationNotes": null, "transferredToCharityAt": null,

  // Verification
  "verifiedAt": null, "verificationNotes": null,

  "medias": [ { "id": "…", "url": "…", "mediaType": 1, "isPrimary": true, "uploadedAt": "…" } ]
}
```

Notes that will save debugging time:

- **`entityName`** is the display name for the target. Use it; don't try to resolve `entityId`
  yourself, and don't assume it is a campaign id.
- **`acceptedAmount` / `acceptedQuantity`** are what staff actually confirmed receiving. When these
  differ from `amount` / `quantity`, show both — "تبرعت بـ 500، تم توثيق 450" — because the
  difference is exactly the kind of thing a donor wants explained.
- **`verificationNotes`** carries the rejection reason when `status = Rejected (4)`. Always surface it.
- **`medias[].url`** is directly loadable in an image widget.

---

## 5. Centers

```http
GET /api/mobile/centers?cityId=&countryId=
```

Returns `CenterResponse[]`: `id`, `name`, `countryId`, `countryName`, `cityId`, `cityName`,
`addressDetails`. Only Centers available to receive donations are returned.

Use it for the Center picker in the donation flow (filter by the donor's city), and for a
standalone "أقرب مركز" screen.

---

## 6. Tracking — "where did my money go?"

```http
GET /api/mobile/donations/trace           // graph across all of the donor's donations
GET /api/mobile/donations/{id}/trace      // graph for one donation
```

Both return a `FundFlowGraph`. This is the platform's trust feature — the donor can see their money
travel from their pledge, through verification, to the beneficiary who received it. Render it as a
flow or timeline, not a table.

---

## 7. Enum reference

```
DonationType            Money 1 | Item 2 | Service 3
DonationTargetType      Campaign 1 | Case 2
DonationDeliveryMethod  DropOff 1 | Delivery 2 | Electronic 3
PaymentMethod           Cash 0 | BankTransfer 1
PaymentStatus           NotApplicable 0 | Pending 1 | Processing 2 | Completed 3 | Failed 4 | Refunded 5

DonationStatus
  0 PendingPayment        1 Pledged              2 Received
  3 Verified              4 Rejected             5 PaymentFailed
  6 DroppedAtCenter       7 ConfirmedByCenter    8 TransferredToCharity
```

### What the donor sees change over time

```
                    ┌─ direct to charity ──────────────────────────────┐
 Pledged (1) ───────┤                                                  ├──► Verified (3)
                    └─ via Center ─► DroppedAtCenter (6)               │     or Rejected (4)
                                          │                            │
                                    ConfirmedByCenter (7)              │
                                          │                            │
                                    TransferredToCharity (8) ─► Received (2) ─┘
```

Suggested donor-facing wording — the raw enum names are internal and mean little to a donor:

| Status | Suggested label | Meaning to the donor |
|---|---|---|
| `Pledged` 1 | قيد المراجعة | We have your pledge, waiting on confirmation |
| `DroppedAtCenter` 6 | بانتظار تأكيد المركز | You said you dropped it off; the Center hasn't confirmed yet |
| `ConfirmedByCenter` 7 | تم الاستلام في المركز | The Center has it |
| `TransferredToCharity` 8 | سُلِّم للجمعية | On its way to the charity |
| `Received` 2 | استلمته الجمعية | The charity has it |
| `Verified` 3 | موثّق ✓ | Done — counted toward the campaign or case |
| `Rejected` 4 | مرفوض | Show `verificationNotes` as the reason |

Only `Verified` is a success state. Everything from `Pledged` through `Received` is "in progress" —
use one colour for the whole in-progress range so the donor doesn't read each step as a problem.

---

## 8. Build checklist

- [ ] Register / login / forgot-password, with dynamic `info-fields` at registration
- [ ] Browse campaigns and cases (see the other mobile endpoints in Swagger)
- [ ] Donation flow with a type switcher: Money / Item / Service
- [ ] Case donations: needs list, send `caseNeedId`
- [ ] Money: cash vs bank transfer branch; receipt image picker for bank transfer
- [ ] Center picker (money and item only), filtered by city
- [ ] Multipart upload of `attachments` alongside the donation
- [ ] "Upload proof later" prompt for bank-transfer donations with empty `medias[]`
- [ ] "I dropped it at the Center" action
- [ ] My donations: one endpoint, filter chips, pagination
- [ ] Donation detail: type-switched layout, accepted-vs-pledged difference, rejection reason,
      image gallery
- [ ] Fund-flow trace screen
- [ ] Status-to-Arabic-label map with the in-progress vs done vs rejected colour scheme
