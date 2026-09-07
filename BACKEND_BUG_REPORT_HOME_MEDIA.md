# ✅ [مُغلَق — تم الإصلاح والتحقق] صور ووسائط الحملات/الحالات لا تظهر في الرئيسية — `GET /api/mobile/home` لا يُعبِّئ `imageUrl`/`medias`

**التاريخ:** 2026-08-31
**تاريخ إغلاق البلاغ:** 2026-09-01
**المكوّن:** `HomeController` (أو الخدمة التي تبني `featuredCampaigns` / `recentCases` ضمن `GET /api/mobile/home`)
**الخطورة:** متوسطة-عالية — كانت كل صور الحملات والحالات تظهر بديلاً (placeholder) في الشاشة الرئيسية، بينما تظهر بشكل صحيح في شاشات القوائم والتفاصيل لنفس العناصر بالضبط.
**الحالة النهائية:** ✅ **مُصلَح ومُتحقَّق منه على `production` بتاريخ 2026-09-01** — راجع القسم 8 في نهاية الملف. لم يتطلّب الإصلاح أي تعديل على تطبيق الموبايل.

---

## 1. ملخّص المشكلة في سطرين

`GET /api/mobile/home` يُرجع نفس الحملات/الحالات الموجودة في `GET /api/mobile/campaigns` و`GET /api/mobile/cases`، لكن بنسخة **منزوعة الحقول** — تحديدًا `imageUrl` و`medias` يرجعان دائمًا `null`/`[]` حتى لو كانت القوائم والتفاصيل تُرجع صورًا حقيقية وصالحة لنفس الـ `id`.

**النتيجة:** كل بطاقة حملة/حالة في الشاشة الرئيسية تعرض أيقونة بديلة (قلب) بدل الصورة الفعلية، بينما نفس البطاقة في شاشة "الحملات"/"الحالات" أو عند فتح التفاصيل تعرض الصورة الصحيحة فورًا.

---

## 2. ما يراه المستخدم فعلياً

- الشاشة الرئيسية → قسم "حملات مختارة لك" وقسم "حالات تحتاج دعمك": كل البطاقات تظهر بأيقونة قلب بديلة على خلفية رمادية متدرجة، بلا أي مؤشر تحميل (لأنه لا يوجد رابط ليُحمَّل أصلًا).
- الضغط على أي بطاقة → شاشة التفاصيل تُعيد الجلب من `GET /api/mobile/campaigns/{id}` أو `GET /api/mobile/cases/{id}` وتُظهر الصورة الصحيحة فورًا.
- نفس الملاحظة تنطبق على شاشة "الحملات"/"الحالات" (تستخدم `GET /api/mobile/campaigns` و`GET /api/mobile/cases` مباشرة) — الصور تظهر فيها بشكل طبيعي.

**هذا التباين بالذات (يظهر في التفاصيل ولا يظهر في الرئيسية لنفس العنصر) هو ما لفت انتباهنا للمشكلة.**

---

## 3. إثبات عملي من الخادم الحيّ (production)، بتاريخ 2026-08-31

### 3.1 حملة حقيقية معها صورة — تختفي فقط على `/home`

الحملة **"جواد تست"** (`id: f668f621-0bfe-4284-8005-7fa7a72fdfb8`):

```
GET https://givechain.runasp.net/api/mobile/campaigns?page=1&pageSize=20
```
```json
{
  "id": "f668f621-0bfe-4284-8005-7fa7a72fdfb8",
  "campaignNumber": "CMP-20260831-71116F",
  "isTrusted": true,
  "trustImageUrl": "https://givechain.runasp.net/Images/Campaigns/Trust/ccb7f65f-5ba0-479e-b146-63129d6cc2ec.jpg",
  "imageUrl": "https://givechain.runasp.net/Images/Campaigns/31edb742-d790-42b4-837e-6726c3d67208.jpg",
  "campaignName": "جواد تست",
  "createdBy": "9e053bd3-5681-4162-9e76-0d7294252433",
  "createdByUserName": "admin",
  "creator": { "id": "9e053bd3-...", "userName": "admin", "email": "admin@gmail.com", "isCharityUser": false },
  "campaignTypeId": "dd3b6d95-1ff5-4953-85b1-2b9e5872512a",
  "campaignType": { "id": "dd3b6d95-...", "name": "الأسهم الخيرية", "...": "..." },
  "medias": []
}
```

```
GET https://givechain.runasp.net/api/mobile/home
```
```json
{
  "id": "f668f621-0bfe-4284-8005-7fa7a72fdfb8",
  "campaignNumber": "",
  "isTrusted": false,
  "trustImageUrl": null,
  "imageUrl": null,
  "campaignName": "جواد تست",
  "createdBy": null,
  "createdByUserName": null,
  "creator": null,
  "campaignTypeId": null,
  "campaignType": null,
  "medias": []
}
```

**نفس الـ `id` بالضبط، لكن `/home` يُرجع `imageUrl: null` بينما `/campaigns` يُرجع رابطًا صحيحًا يعمل فعليًا (تحققنا: `HTTP 200`, `image/jpeg`, 2.8MB).**

ملاحظة: التباين لا يقتصر على الصورة — `campaignNumber`, `isTrusted`, `trustImageUrl`, `createdBy`/`createdByUserName`/`creator`, و`campaignTypeId`/`campaignType` **كلها أيضًا فارغة على `/home`** بينما هي مُعبَّأة على `/campaigns`. يبدو أن `/home` يُنشئ الحملة من DTO مختلف (أو استعلام أضيق) لا يجلب هذه الحقول إطلاقًا، وليست مشكلة صور فقط.

### 3.2 حالة حقيقية معها صورة — نفس النمط

الحالة **"شخص من ذوي الإعاقة يحتاج كرسياً"** (`id: 45438dae-7865-4764-8fa1-5341f16b79a2`):

```
GET https://givechain.runasp.net/api/mobile/cases?page=1&pageSize=20
```
```json
{
  "id": "45438dae-7865-4764-8fa1-5341f16b79a2",
  "categoryId": "78db8a6e-5e83-46ec-bf17-5f3f1c117220",
  "medias": [
    {
      "id": "ffa2ca18-a23a-44b7-a3d9-eea6c76a0692",
      "url": "https://givechain.runasp.net/Media/Case/seed_4.jpg",
      "mediaType": 1,
      "isPrimary": true,
      "uploadedAt": "2026-06-28T19:06:52.9203653"
    }
  ]
}
```

```
GET https://givechain.runasp.net/api/mobile/home
```
```json
{
  "id": "45438dae-7865-4764-8fa1-5341f16b79a2",
  "categoryId": null,
  "medias": []
}
```

هنا الحقل `imageUrl` كان `null` أصلًا في الاثنين (الحالة تعتمد فقط على `medias`)، لكن `medias` نفسه **يُفرَّغ بالكامل** على `/home` رغم وجود صورة حقيقية فيه على `/cases`. ونفس الشيء لـ `categoryId`.

### 3.3 نطاق المشكلة — فحصنا كل عناصر `/home`

قارنّا كل حملة وحالة تظهر في `GET /api/mobile/home` (8 حملات ضمن `featuredCampaigns`، 10 حالات ضمن `recentCases`) بنفس الـ `id` على `/api/mobile/campaigns` و`/api/mobile/cases`:

| القسم | عدد العناصر | `imageUrl`/`medias` صحيح على `/home`؟ |
|---|---:|---|
| `featuredCampaigns` | 8 | **0 من 8** — الحملة الوحيدة التي تملك صورة حقيقية (`جواد تست`) ظهرت `null` على `/home` |
| `recentCases` | 10 | **0 من 10** — كل الحالات التي تملك `medias` حقيقية (4 حالات من أصل 10) ظهرت `medias: []` على `/home` |

**كل حملة/حالة بلا استثناء تُرجع `imageUrl: null` و`medias: []` على `/home`، بغض النظر عمّا يوجد فعليًا في قاعدة البيانات.**

---

## 4. التأثير على تطبيق الموبايل

- تطبيق الموبايل يستخدم `NetworkOrPlaceholder` الذي يعرض أيقونة بديلة فقط عندما يكون الرابط فارغًا فعلًا — وهذا هو ما يحدث هنا: لا يوجد خطأ في منطق العرض، الحقل يصل فارغًا من المصدر.
- عند فتح تفاصيل أي عنصر من الرئيسية، الشاشة تُعيد الجلب من `GET /api/mobile/campaigns/{id}` أو `GET /api/mobile/cases/{id}` (وليس من بيانات `/home` المُمرَّرة)، لذلك الصورة **تظهر بشكل صحيح** في التفاصيل — وهذا بالضبط ما لاحظه فريقنا: "الصورة تظهر بالتفاصيل ولا تظهر من الخارج".
- لا حاجة لأي تعديل على تطبيق الموبايل؛ إصلاح `/home` وحده كافٍ لإظهار الصور فور توفرها في الاستجابة.

---

## 5. المطلوب من الباك اند

1. تعديل الاستعلام/الـ DTO المستخدم لبناء `featuredCampaigns` و`recentCases` ضمن `GET /api/mobile/home` ليُعبِّئ **كل** الحقول التي يُعبِّئها `GET /api/mobile/campaigns` و`GET /api/mobile/cases` لنفس النوع، وعلى الأقل: `imageUrl`, `medias`, `campaignNumber`, `isTrusted`, `trustImageUrl`, `createdBy`/`createdByUserName`/`creator`, `campaignTypeId`/`campaignType` (للحملات)، و`categoryId`/`category` (للحالات).
2. **تحققنا: `recentCharities` غير متأثر** — قارنّا `logoUrl` لكل جمعية ضمن `recentCharities` بنفس الجمعية على `/api/mobile/charities` وتطابقت القيم تمامًا في كل الحالات الثلاث. المشكلة مقتصرة على `featuredCampaigns` و`recentCases`.
3. **مقترح:** الأفضل تقنيًا أن يُعيد `/home` استخدام نفس دالة/DTO التحويل (mapper) المستخدمة في `/campaigns` و`/cases` بدل تكرار منطق تحويل منفصل ناقص الحقول — هذا يمنع تكرار هذا النوع من الانحراف مستقبلاً كلما أُضيف حقل جديد لأحدهما دون الآخر. لاحظ أن `recentCharities` (السليم) قد يكون فعلاً يُعيد استخدام مُحوِّل الجمعيات، بينما الحملات والحالات لا تفعل ذلك — يستحق المقارنة عند الإصلاح.

---

## 7. 🔴 إعادة تحقّق بتاريخ 2026-08-31 (بعد إبلاغكم بالإصلاح) — لم يُصلَح بعد

أُبلغنا بأن الإصلاح تم تطبيقه، فأعدنا فحص نفس الأمثلة أعلاه على `production` في نفس اليوم. **النتيجة: المشكلة لا تزال قائمة كما هي تمامًا.**

### حملة "جواد تست" — لا تزال فارغة على `/home`

```
GET https://givechain.runasp.net/api/mobile/home
```
```json
{
  "id": "f668f621-0bfe-4284-8005-7fa7a72fdfb8",
  "campaignName": "جواد تست",
  "campaignNumber": "",
  "isTrusted": false,
  "trustImageUrl": null,
  "imageUrl": null,
  "createdBy": null,
  "campaignTypeId": null,
  "campaignType": null,
  "medias": []
}
```
بينما `GET /api/mobile/campaigns` لا يزال يُرجع لنفس الـ `id`:
```json
"imageUrl": "https://givechain.runasp.net/Images/Campaigns/31edb742-d790-42b4-837e-6726c3d67208.jpg"
```

### مسح كامل مُعاد — نفس النمط بالضبط

قارنّا كل الحملات (8) والحالات (10) في `/home` بنظيراتها على `/campaigns` و`/cases` من جديد:

| القسم | العناصر التي تملك وسائط حقيقية على `/campaigns`\|`/cases` | كم منها ظهر صحيحًا على `/home`؟ |
|---|---:|---:|
| `featuredCampaigns` | 1 (جواد تست) | **0 من 1** |
| `recentCases` | 4 | **0 من 4** |

مثال إضافي — الحالة **"أسرة محتاجة في الرياض"** (`id: f46c7f64-e10b-4c3a-a56d-5e08c15f828d`) تملك **صورتين** حقيقيتين على `/api/mobile/cases`، وتظهر الآن على `/home`:
```json
"imageUrl": null,
"medias": [],
"categoryId": null
```
(بينما `categoryId` وحده تحديدًا صحيح على `/cases`: `"f5d32b01-b47c-4538-9f26-3cd23d6754f5"`).

**الخلاصة: لا فرق ملموس عمّا وثّقناه في القسم 3 أعلاه.** يبدو أن التعديل إمّا لم يُنشر فعليًا على `production`، أو أنه عالج مصدرًا مختلفًا عن الذي يغذي `featuredCampaigns`/`recentCases` ضمن `/api/mobile/home`. نرجو التأكد من:
1. أن آخر نشر (`deploy`) شمل هذا التعديل فعلاً على بيئة `production` (وليس فقط `staging` أو فرع غير مدموج).
2. أن التعديل استهدف نفس الاستعلام الذي يبني **هاتين المصفوفتين تحديدًا** ضمن `HomeController` — لاحظنا أن `recentCharities` ضمن نفس الاستجابة سليم تمامًا (راجع القسم 5، البند 2)، فالمشكلة على الأرجح معزولة في مسار كود مختلف خاص بالحملات/الحالات فقط.

---

## 6. كيفية إعادة الاختبار بعد الإصلاح

```
GET https://givechain.runasp.net/api/mobile/home
```
تحقق أن حملة `f668f621-0bfe-4284-8005-7fa7a72fdfb8` ("جواد تست") ضمن `featuredCampaigns` تُرجع:
```json
"imageUrl": "https://givechain.runasp.net/Images/Campaigns/31edb742-d790-42b4-837e-6726c3d67208.jpg"
```
وأن حالة `45438dae-7865-4764-8fa1-5341f16b79a2` ضمن `recentCases` تُرجع `medias` بعنصر واحد على الأقل (`seed_4.jpg`).

---

## 8. ✅ إعادة تحقّق بتاريخ 2026-09-01 — تم الإصلاح بنجاح، البلاغ مُغلَق

بعد النشر الثاني، أعدنا نفس الفحوصات على `production` بتاريخ **2026-09-01 الساعة 09:39 UTC**. **النتيجة: المشكلة مُصلَحة بالكامل.**

### 8.1 حملة "جواد تست" — الصورة صارت تصل على `/home`

```
GET https://givechain.runasp.net/api/mobile/home   →  featuredCampaigns[جواد تست]
  "imageUrl": "https://givechain.runasp.net/Images/Campaigns/31edb742-d790-42b4-837e-6726c3d67208.jpg"

GET https://givechain.runasp.net/api/mobile/campaigns  →  items[جواد تست]
  "imageUrl": "https://givechain.runasp.net/Images/Campaigns/31edb742-d790-42b4-837e-6726c3d67208.jpg"
```

القيمتان متطابقتان تمامًا الآن (كانت `null` على `/home` سابقًا).

### 8.2 مسح شامل — صفر اختلافات

قارنّا **كل** حملة وحالة ضمن `/home` بنظيرتها على `/campaigns` و`/cases` (مطابقة `imageUrl` + عدد عناصر `medias`):

| القسم | عدد العناصر المفحوصة | عناصر مطابقة | اختلافات |
|---|---:|---:|---:|
| `featuredCampaigns` | 9 | **9** | **0** |
| `recentCases` | 10 | **10** | **0** |
| **الإجمالي** | **19** | **19** | **0** |

وشمل ذلك الحالات التي تملك وسائط حقيقية والتي كانت تظهر فارغة سابقًا:

| العنصر | `medias` على `/home` قبل | `medias` على `/home` الآن | `/cases` |
|---|---:|---:|---:|
| شخص من ذوي الإعاقة يحتاج كرسياً | 0 ❌ | **1** ✅ | 1 |
| طفل يحتاج دعماً تعليمياً | 0 ❌ | **1** ✅ | 1 |
| أسرة محتاجة في الرياض | 0 ❌ | **2** ✅ | 2 |
| أسرة محتاجة في الرياض (2) | 0 ❌ | **1** ✅ | 1 |
| حملة الصحة للجميع | 0 ❌ | **1** ✅ | 1 |

### 8.3 الخلاصة

- ✅ `imageUrl` و`medias` صارا يصلان صحيحين في `featuredCampaigns` و`recentCases`.
- ✅ لم يتطلّب الأمر أي تعديل على تطبيق الموبايل — الصور تظهر تلقائيًا في بطاقات الشاشة الرئيسية الآن.
- ✅ `flutter analyze` نظيف بعد التحقق.

**شكرًا لفريق الباك اند على الإصلاح. البلاغ مُغلَق.**
