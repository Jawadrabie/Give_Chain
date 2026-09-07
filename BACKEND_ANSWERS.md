# إجابات مسؤول الباك اند — أسئلة تطبيق GiveChain Mobile

مبنية على فحص الكود الفعلي (Controllers/Services/DTOs) وليس على الوثائق فقط. المراجع لكل إجابة مذكورة أسفلها.

> ملاحظة من فريق الموبايل: وصل هذا الرد بترميز مُشوَّه، فأُعيدت كتابته هنا بترميز UTF-8 سليم مع الحفاظ على المحتوى كما هو. تاريخ الاستلام: 2026-08-23.

---

### 1. بيانات الحسابات البنكية للتحويل الخارجي (Bank Account Details)

**لا يوجد** أي شيء من هذا حالياً:
- لا يوجد Endpoint باسم `GET /api/mobile/bank-accounts` أو ما شابه.
- لا توجد حقول `BankAccountNumber` / `IBAN` / `BankName` في كيان `Charity` ولا في أي DTO خاص بالحملة/الحالة/الجمعية.
- النظام مبني على أن كل تحويل مالي **يُسوّى يدوياً**: الكاش يتحقق منه شخصياً، والتحويل البنكي يتحقق منه عبر إثبات (Attachment) يرفعه المتبرع فقط — لا يوجد أي مرجع IBAN يُعرض للمتبرع ليحوّل عليه.

🔸 **قرار مطلوب من الفريق**: إذا كان التطبيق يحتاج لعرض رقم حساب/IBAN للمتبرع، هذا Feature غير موجود حالياً ويجب إضافته (حقل جديد على `Charity` أو `Center` + Endpoint لجلبه). حالياً الافتراض أن رقم الحساب يُتفق عليه خارج النظام (يُعرض ثابتاً في التطبيق أو يُرسل يدوياً) والتطبيق يكتفي برفع إثبات التحويل بعد إتمامه.

مرجع: `PaymentMethod.cs`، `DonationMobileService.cs`

---

### 2. اسم حقل الملف في Endpoint إشعار التحويل (`Proof Upload`)

اسم الحقل هو **`files`**، وليس `attachments`:

```csharp
[HttpPost("{id:guid}/proof")]
[Consumes("multipart/form-data")]
public async Task<...> AttachProofAsync(
    Guid id,
    [FromForm] List<IFormFile> files,   // ← الاسم هنا "files"
    ...)
```

بالمقابل، عند **إنشاء التبرع نفسه** (`POST /api/mobile/donations`) اسم الحقل هو **`attachments`**:

```csharp
[HttpPost]
[Consumes("multipart/form-data")]
public async Task<...> DonateAsync(
    [FromForm] CreateDonationRequest request,
    [FromForm] List<IFormFile>? attachments = null,   // ← هنا "attachments"
    ...)
```

⚠️ **مهم**: الاسمان مختلفان حسب الـ Endpoint — عند الإنشاء استخدموا `attachments`، وعند رفع الإثبات لاحقاً استخدموا `files`.

مرجع: `DonationsController.cs`

---

### 3. استعلام تفاصيل تبرع واحد بمعرّفه (Single Donation Detail Endpoint)

**غير موجود حالياً.** الـ Endpoints المتاحة في `DonationsController` هي فقط:

- `POST /api/mobile/donations` (إنشاء)
- `GET /api/mobile/donations` (السجل مع فلاتر — `GetMyDonationsAsync`)
- `POST /api/mobile/donations/{id}/proof`
- `POST /api/mobile/donations/{id}/dropped-at-center`
- `GET /api/mobile/donations/trace` و `GET /api/mobile/donations/{id}/trace`

لا يوجد `GET /api/mobile/donations/{id}` يرجع `DonationResponse` مباشرة.

🔸 **الحل المؤقت المتاح الآن**: استخدموا `GET /api/mobile/donations?...` وابحثوا عن التبرع بالـ `Id` في الرد. إذا كانت شاشة التفاصيل مهمة لتجربة الاستخدام، هذا طلب مشروع (Feature Request) بسيط ويمكن إضافته بسرعة — أخبرونا وسنضيفه.

مرجع: `DonationsController.cs`

---

### 4. معرّفات المدن والدول في الـ Centers Endpoint

نعم، **مؤكد** — `cityId` و`countryId` كلاهما من نوع `Guid?` في `GET /api/mobile/centers`، وهما نفس الـ GUID الراجع من:

- `GET /api/lookup/cities` → كل عنصر فيه `Id: Guid` و`CountryId: Guid?`
- `GET /api/lookup/countries` → كل عنصر فيه `Id: Guid`

```csharp
[HttpGet]
public async Task<...> GetAvailableAsync(
    [FromQuery] Guid? cityId, [FromQuery] Guid? countryId, ...)
```

لا حاجة لأي تحويل — استخدموا القيم كما هي من `/api/lookup/*`.

مرجع: `CentersController.cs`، `LookupController.cs`

---

### 5. التبرع لحالة إنسانية بدون `caseNeedId` عبر الـ General Endpoint

الخادم **يرفض الطلب بخطأ Validation** — لا يوجد ربط تلقائي بأي احتياج. في `DonationTargetResolver.ResolveCaseNeedAsync`:

```csharp
if (caseNeedId is null)
    return (null, "CaseNeedId is required for a case donation.");
```

نفس الشيء إذا كان `caseId` نفسه فارغاً (`"CaseId is required for a case donation."`). كما أن نوع التبرع (مال/مادة/خدمة) يجب أن يطابق نوع الاحتياج (`CaseNeedType`)، وإلا رسالة خطأ مشابهة.

🔸 **يعني عملياً**: على شاشة التبرع لحالة، لازم تطبيق الموبايل يجبر المستخدم على اختيار احتياج محدد (`CaseNeed`) قبل إرسال الطلب — لا يوجد Fallback تلقائي.

مرجع: `DonationTargetResolver.cs`

---

### 6. حالة Endpoint تأكيد التحويل (`confirm-payment`) — عاجل

**تأكيد: هذا الـ Endpoint غير موجود إطلاقاً في الكود الحالي.** لا يوجد `POST /api/mobile/donations/{id}/confirm-payment` لا في `DonationsController` ولا في أي مكان آخر بالباك اند.

هذا مقصود في التصميم — تعليق مباشر في الكود يوضح السبب:

> "Payment is always manual — cash is verified in person, bank transfer is verified from an uploaded proof attachment — there is no online payment gateway, so a pledge never needs a follow-up 'confirm payment' step."

**الإجراء المطلوب لديكم**: احذفوا زر/نداء "تأكيد التحويل" من شاشتي نتيجة التبرع وسجل التبرعات في التطبيق — أي طلب له سينتهي بـ 404 كما لاحظتم. المسار الصحيح الوحيد هو `POST /api/mobile/donations/{id}/proof` (بحقل `files`، انظر السؤال 2) لرفع إثبات التحويل، وبعدها الفريق الإداري/الجمعية يراجعه يدوياً ويغيّر حالة التبرع إلى `Verified`.

مرجع: `DonationMobileService.cs` (تعليق التوثيق أعلى الكلاس)، `DonationsController.cs`

---

### 7. التبرع المباشر لجمعية (`TargetType=Charity`) ووجود Endpoints مختصرة

افتراضكم **صحيح جزئياً** — إليكم الصورة الكاملة:

- **لا يوجد** `POST /api/mobile/charities/{id}/donate` — `CharitiesController` ليس فيه أي Action للتبرع. التبرع المباشر لجمعية يتم **فقط** عبر `POST /api/mobile/donations` العام مع `TargetType=Charity (3)` و`CharityId`. هذا صحيح كما افترضتم.

- **لكن يوجد فعلاً** Endpoints مختصرة مشابهة للحملة وللحالة:
  - `POST /api/mobile/campaigns/{id}/donate` — في `CampaignsController`
  - `POST /api/mobile/cases/{id}/donate` — في `CasesController`

  كلاهما يأخذ نفس `CreateDonationRequest` + `attachments`، ويثبّتان تلقائياً `TargetType` و`CampaignId`/`CaseId` من الـ Route:

  ```csharp
  [HttpPost("{id:guid}/donate")]
  public async Task<...> DonateAsync(Guid id, [FromForm] CreateDonationRequest request, ...)
  {
      request = request with { TargetType = DonationTargetType.Campaign, CampaignId = id };
      ...
  }
  ```

  (نفس الشيء في `CasesController` مع `TargetType.Case` — لكن لاحظوا أن `caseNeedId` يبقى مطلوباً في الـ Body حتى مع هذا المختصر، حسب السؤال 5).

🔸 **خلاصة للفريق**: للحملة والحالة استخدموا `{id}/donate` المختصر إن كان أسهل لكم، أو استمروا باستخدام `POST /api/mobile/donations` العام — كلاهما يعمل بنفس المنطق. أما التبرع المباشر للجمعية فمساره الوحيد هو العام.

مرجع: `CampaignsController.cs`، `CasesController.cs`، `CharitiesController.cs`، `DonationTargetResolver.cs`

---

*تم إعداد هذا الملف بالرجوع المباشر لكود الباك اند (Controllers/Services/DTOs الفعلية) بتاريخ 2026-08-23، وليس فقط من الوثائق (`MOBILE_APP_GUIDE.md` / `API_MOBILE.md`) — لأن بعضها قد يكون متأخراً عن الكود.*
