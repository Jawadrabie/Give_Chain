# تقرير تغطية API ↔ الواجهات

عدد العمليات الرسمية: **48**.

| العملية | Method | Endpoint | الشاشة/المسار | الحالة |
|---|---|---|---|---|
| `benefitsCreate` | `POST` | `/api/mobile/benefits` | `/charities/:charityId/benefits/:benefitTypeId/apply` | مكتمل |
| `benefitsMine` | `GET` | `/api/mobile/benefits` | `/benefits/my` | مكتمل |
| `campaignByCharity` | `GET` | `/api/mobile/campaigns/by-charity/{charityId}` | `/charities/:id/campaigns` | مكتمل |
| `campaignById` | `GET` | `/api/mobile/campaigns/{id}` | `/campaigns/:id` | مكتمل |
| `campaignDonate` | `POST` | `/api/mobile/campaigns/{id}/donate` | `/campaigns/:id/donate` | مكتمل |
| `campaignTypeById` | `GET` | `/api/lookup/campaign-types/{id}` | `/campaigns/:id` | مكتمل |
| `campaignTypes` | `GET` | `/api/lookup/campaign-types` | `/campaigns` | مكتمل |
| `campaigns` | `GET` | `/api/mobile/campaigns` | `/campaigns` | مكتمل |
| `caseByCharity` | `GET` | `/api/mobile/cases/by-charity/{charityId}` | `/charities/:id/cases` | مكتمل |
| `caseById` | `GET` | `/api/mobile/cases/{id}` | `/cases/:id` | مكتمل |
| `caseCategories` | `GET` | `/api/lookup/case-categories` | `/cases` | مكتمل |
| `caseCategoryById` | `GET` | `/api/lookup/case-categories/{id}` | `/cases/:id` | مكتمل |
| `caseDonate` | `POST` | `/api/mobile/cases/{id}/donate` | `/cases/:id/donate` | مكتمل |
| `cases` | `GET` | `/api/mobile/cases` | `/cases` | مكتمل |
| `charities` | `GET` | `/api/mobile/charities` | `/charities` | مكتمل |
| `charityBenefits` | `GET` | `/api/mobile/charities/{id}/benefit-types` | `/charities/:id` | مكتمل |
| `charityById` | `GET` | `/api/mobile/charities/{id}` | `/charities/:id` | مكتمل |
| `charityCampaigns` | `GET` | `/api/mobile/charities/{id}/campaigns` | `/charities/:id` | مكتمل |
| `charityCases` | `GET` | `/api/mobile/charities/{id}/cases` | `/charities/:id` | مكتمل |
| `charityLookupBySubdomain` | `GET` | `/api/charities/lookup` | `/c/:subdomain` | مكتمل |
| `cities` | `GET` | `/api/lookup/cities` | `/profile/edit` | مكتمل |
| `complaintById` | `GET` | `/api/mobile/complaints/{id}` | `/complaints/:id` | مكتمل |
| `complaintsCreate` | `POST` | `/api/mobile/complaints` | `/charities/:id/complaint` | مكتمل |
| `complaintsMine` | `GET` | `/api/mobile/complaints` | `/complaints/my` | مكتمل |
| `countries` | `GET` | `/api/lookup/countries` | `/signup` | مكتمل |
| `donationTrace` | `GET` | `/api/mobile/donations/{id}/trace` | `/donations/:id/trace` | مكتمل |
| `donationsCreate` | `POST` | `/api/mobile/donations` | `/donate` | مكتمل |
| `donationsHistory` | `GET` | `/api/mobile/donations` | `/donations/history` | مكتمل |
| `donationsTrace` | `GET` | `/api/mobile/donations/trace` | `/donations/trace` | مكتمل |
| `forgotPassword` | `POST` | `/api/mobile/auth/forgot-password` | `/forgot-password` | مكتمل |
| `home` | `GET` | `/api/mobile/home` | `/home` | مكتمل |
| `infoFields` | `GET` | `/api/mobile/auth/info-fields` | `/signup` | مكتمل |
| `login` | `POST` | `/api/mobile/auth/login` | `/login` | مكتمل |
| `mediaByOwner` | `GET` | `/api/media` | `/media/manage` | مكتمل |
| `mediaDelete` | `DELETE` | `/api/media/{id}` | `/media/manage` | مكتمل |
| `mediaUpload` | `POST` | `/api/media` | `/media/manage` | مكتمل |
| `notificationRead` | `PATCH` | `/api/mobile/notifications/{id}/read` | `/notifications/detail` | مكتمل |
| `notificationUnreadCount` | `GET` | `/api/mobile/notifications/unread-count` | `/home` | مكتمل |
| `notifications` | `GET` | `/api/mobile/notifications` | `/notifications` | مكتمل |
| `notificationsReadAll` | `PATCH` | `/api/mobile/notifications/read-all` | `/notifications` | مكتمل |
| `profile` | `GET` | `/api/mobile/profile` | `/profile` | مكتمل |
| `profileInfoAnswerUpsert` | `PUT` | `/api/mobile/profile/info-answers` | `/profile/info-answers` | مكتمل |
| `profileInfoAnswers` | `GET` | `/api/mobile/profile/info-answers` | `/profile/info-answers` | مكتمل |
| `profilePassword` | `PUT` | `/api/mobile/profile/password` | `/profile/change-password` | مكتمل |
| `profileUpdate` | `PUT` | `/api/mobile/profile` | `/profile/edit` | مكتمل |
| `register` | `POST` | `/api/mobile/auth/register` | `/signup` | مكتمل |
| `resetPassword` | `POST` | `/api/mobile/auth/reset-password` | `/reset-password` | مكتمل |
| `version` | `GET` | `/api/version` | `/about` | مكتمل |

## نقاط لا يمكن للواجهة حسمها دون تعديل Backend

محدّث بعد إجابات الباك اند في `BACKEND_ANSWERS.md` (2026-08-23).

- **بيانات الحساب البنكي/IBAN غير موجودة إطلاقاً** في أي endpoint ولا كحقل على `Charity`؛ لذلك لا يستطيع التطبيق أن يعرض للمتبرع إلى أين يحوّل (`BACKEND_QUESTIONS_R2.md` #1).
- **لا يوجد `GET /api/mobile/donations/{id}`**؛ شاشة تفاصيل التبرع تعوّضه بمسح صفحات السجل، وهو مكلف. طُلب رسمياً (`BACKEND_QUESTIONS_R2.md` #2).
- **احتياجات الحالة (`CaseNeed`) غير موثقة** رغم أن `caseNeedId` إلزامي لكل تبرع لحالة؛ التطبيق يقرأها من `needs` داخل استجابة الحالة إن وُجدت، ويمنع التبرع إن غابت (`BACKEND_QUESTIONS_R2.md` #3).
- معنى `referenceId` لكل نوع إشعار غير موثق؛ لذلك شاشة التفاصيل آمنة ولا تنفذ deep-link تخمينيًا.
- صيغة الإجابة للحقول الديناميكية من نوع `Attachment` و`MultiOption` غير محددة (`BACKEND_QUESTIONS_R2.md` #6).
- يجب أن يعيد الخادم `401` بدل `500` عند غياب أو انتهاء JWT.

### نقاط أُغلقت

- ~~أسئلة نوع المنفعة غير موثقة~~ — صارت موثقة ضمن `GET /api/mobile/charities/{id}/benefit-types`.
- ~~البحث والفلاتر من الخادم غير موثقة~~ — صارت موثقة على `GET /api/mobile/donations`.
- ~~callback بوابات الدفع غير موثق~~ — لا توجد بوابة دفع إلكتروني أصلاً؛ كل تسوية يدوية (نقدي أو تحويل بنكي بإثبات).
- ~~تعديل صورة الملف الشخصي غير موجود~~ — `ProfileImage` موثق ضمن `PUT /api/mobile/profile`.
