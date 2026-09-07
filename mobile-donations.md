# Mobile App — Donations & Donation Centers

## Overview
Donors pledge money, items, or services from the mobile app. There is **no online payment gateway** — payment is always manual:

- **Cash** — handed over in person (to the charity directly, or at a GiveChain Center). No upload needed; a staff member simply confirms they received it.
- **Bank transfer** — the donor transfers money outside the app, then uploads a proof-of-transfer file as a donation attachment. Staff verify that proof manually before the donation counts as confirmed. There is no automatic "payment succeeded" callback.

A donor can optionally route a donation through a physical **GiveChain Center** — a drop-off point owned and staffed by GiveChain itself — instead of handing it straight to the charity.

All endpoints return the shared envelope `{ message, data, errors, isSuccess }`. Auth: `PublicUser` (JWT).

---

## Status Pipeline (what the donor sees change over time)
`Donation.Status`:

```
Pledged ──────────────────────────────────────────────────► Verified
   │  (direct to charity: donor hands over cash/transfer)  ▲   │
   │                                                        │   └─► (on reject) Rejected
   └─(routed through a Center)─► DroppedAtCenter            │
                                       │                     │
                                 ConfirmedByCenter            │
                                       │                     │
                                 TransferredToCharity          │
                                       │                     │
                                    Received ─────────────────┘
```

- **Direct donations** (no Center): `Pledged` → the charity verifies or rejects it directly.
- **Center-routed donations**: `Pledged` → Center staff confirm receipt (`ConfirmedByCenter`) → Center hands it to the charity (`TransferredToCharity`) → charity confirms physical receipt (`Received`) → charity verifies (`Verified`) or rejects.

`PaymentMethod` (money donations only): `Cash = 0`, `BankTransfer = 1`.

---

## Create a donation
`POST /api/mobile/donations` — `multipart/form-data`

| Field | Required | Notes |
|---|---|---|
| `DonationType` | yes | `Money` \| `Item` \| `Service` |
| `TargetType` | yes | `Campaign` \| `Case` |
| `CampaignId` | if TargetType=Campaign | |
| `CaseId`, `CaseNeedId` | if TargetType=Case | the need must match the donation type (money need ← money donation, etc.) |
| `Message` | no | note to the charity |
| `Amount`, `PaymentMethod` | Money only | `PaymentMethod`: `Cash` or `BankTransfer` |
| `ItemName`, `ItemDescription`, `Quantity`, `Unit` | Item only | |
| `ServiceDescription`, `ScheduledAt` | Service only | |
| `DeliveryMethod` | Item/Service | `DropOff` \| `Delivery` \| `Electronic` |
| `CenterId` | no | route this donation through a GiveChain Center (Money/Item only, not Service) — must be an `Active` Center |
| `attachments` | no | files — **required in practice for `BankTransfer`** (proof of transfer); also used for item photos etc. |

**Response** (`DonationResponse`):
- `Id`, `DonationType`, `TargetType`
- `EntityId`, `EntityName` — what's funded (a Campaign's or Case-need's id/name — resolved server-side, no extra lookup needed)
- `CharityId`, `UserId`, `Message`, `DonationDate`
- `Status` — always starts `Pledged`
- Money: `Amount`, `PaymentMethod`, `PaymentReference`, `AcceptedAmount`
- Item: `ItemName`, `ItemDescription`, `Quantity`, `Unit`, `AcceptedQuantity`
- Service: `ServiceDescription`, `ScheduledAt`
- `DeliveryMethod`
- Center fields: `CenterId`, `CenterConfirmedAt`, `CenterConfirmationNotes`, `TransferredToCharityAt`
- `VerifiedAt`, `VerificationNotes`
- `Medias[]` — uploaded attachments (including bank-transfer proof)

## Find a nearby Center
`GET /api/mobile/centers?cityId=&countryId=`
Returns active Centers, preferring an exact city match, falling back to same-country, falling back to all active Centers if neither is supplied. Use this before creating a donation to let the donor pick where they'll drop it off.

## Track donations
| Method | Route | Description |
|---|---|---|
| `GET` | `/api/mobile/donations?page=&pageSize=` | My donation history (paged, newest first) |
| `GET` | `/api/mobile/donations/trace` | Fund-flow graph for all my donations |
| `GET` | `/api/mobile/donations/{id}/trace` | Fund-flow graph for one donation |

---

## Suggested screen flow
1. Donor picks a Campaign or a Case-need to support.
2. Donor chooses Money / Item / Service, fills in the type-specific fields.
3. If Money or Item: donor may pick "drop off at a Center" → call the nearby-Centers endpoint, let them choose one → pass `CenterId`.
4. If `PaymentMethod = BankTransfer`: show upload UI for the proof file, include it in `attachments`.
5. Submit → show the returned `Status` and, for Center/BankTransfer flows, explain what happens next ("awaiting Center confirmation" / "awaiting verification").
6. "My Donations" screen polls `GET /api/mobile/donations` and shows `Status` + `EntityName` per row.
