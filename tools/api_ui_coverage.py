#!/usr/bin/env python3
"""Verify and report API -> repository -> UI coverage for GiveChain."""
from __future__ import annotations

from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"
CONTRACT = json.loads((ROOT / "assets/config/givechain_api_contract.json").read_text(encoding="utf-8"))
OPERATIONS: dict[str, dict] = CONTRACT["confirmedOperations"]

# name: (repository/source file, source needle, UI file, UI needle, user route)
COVERAGE: dict[str, tuple[str, str, str, str, str]] = {
    "login": ("features/auth/data/auth_repository.dart", "ApiPaths.login", "features/login/ui/login_screen.dart", ".login(", "/login"),
    "register": ("features/auth/data/auth_repository.dart", "ApiPaths.signup", "features/auth/ui/signup_screen.dart", "SignUpRequest", "/signup"),
    "forgotPassword": ("features/auth/data/auth_repository.dart", "ApiPaths.forgotPassword", "features/auth/ui/forgot_password_screen.dart", "ForgotPasswordCubit", "/forgot-password"),
    "resetPassword": ("features/auth/data/auth_repository.dart", "ApiPaths.resetPassword", "features/auth/ui/reset_password_screen.dart", "ResetPasswordCubit", "/reset-password"),
    "infoFields": ("features/auth/data/auth_repository.dart", "ApiPaths.infoFields", "features/auth/ui/signup_screen.dart", "PersonInfoField", "/signup"),
    "home": ("features/home/data/home_repository.dart", "ApiPaths.home", "features/home/ui/dashboard_screen.dart", "HomeOverviewCubit", "/home"),
    "charities": ("features/catalog/data/catalog_repository.dart", "ApiPaths.charities", "features/charities/ui/charities_screen.dart", "PagedCatalogCubit<Charity>", "/charities"),
    "charityById": ("features/catalog/data/catalog_repository.dart", "ApiPaths.charity(id)", "features/charities/ui/charity_detail_screen.dart", "DetailCubit<Charity>", "/charities/:id"),
    "charityCampaigns": ("features/catalog/data/catalog_repository.dart", "ApiPaths.charityCampaigns", "features/charities/ui/charity_detail_screen.dart", "repository.charityCampaigns", "/charities/:id"),
    "charityCases": ("features/catalog/data/catalog_repository.dart", "ApiPaths.charityCases", "features/charities/ui/charity_detail_screen.dart", "repository.charityCases", "/charities/:id"),
    "charityBenefits": ("features/benefits/data/benefit_repository.dart", "ApiPaths.charityBenefitTypes", "features/charities/ui/charity_detail_screen.dart", "_CharityBenefits", "/charities/:id"),
    "campaigns": ("features/catalog/data/catalog_repository.dart", "ApiPaths.campaigns", "features/catalog/ui/catalog_list_screen.dart", "CatalogKind.campaigns", "/campaigns"),
    "campaignByCharity": ("features/catalog/data/catalog_repository.dart", "ApiPaths.campaignsByCharity", "features/charities/ui/charity_catalog_screen.dart", "repository.campaignsByCharity", "/charities/:id/campaigns"),
    "campaignById": ("features/catalog/data/catalog_repository.dart", "ApiPaths.campaign(id)", "features/catalog/ui/catalog_detail_screen.dart", "repository.campaign", "/campaigns/:id"),
    "campaignDonate": ("features/donations/data/donation_repository.dart", "ApiPaths.campaignDonation", "features/donations/ui/donation_screen.dart", "DonationEntryScreen", "/campaigns/:id/donate"),
    "cases": ("features/catalog/data/catalog_repository.dart", "ApiPaths.cases", "features/catalog/ui/catalog_list_screen.dart", "CatalogKind.cases", "/cases"),
    "caseByCharity": ("features/catalog/data/catalog_repository.dart", "ApiPaths.casesByCharity", "features/charities/ui/charity_catalog_screen.dart", "repository.casesByCharity", "/charities/:id/cases"),
    "caseById": ("features/catalog/data/catalog_repository.dart", "ApiPaths.caseById", "features/catalog/ui/catalog_detail_screen.dart", "repository.caseById", "/cases/:id"),
    "caseDonate": ("features/donations/data/donation_repository.dart", "ApiPaths.caseDonation", "features/donations/ui/donation_screen.dart", "DonationEntryScreen", "/cases/:id/donate"),
    "donationsCreate": ("features/donations/data/donation_repository.dart", "ApiPaths.donations", "features/charities/ui/charity_detail_screen.dart", "useGeneralEndpoint: true", "/donate"),
    "donationsHistory": ("features/donations/data/donation_repository.dart", "query: {'page': page", "features/donations/ui/donation_history_screen.dart", "DonationHistoryScreen", "/donations/history"),
    "donationsTrace": ("features/donations/data/donation_repository.dart", "ApiPaths.donationTraceAll", "features/donations/ui/donation_screen.dart", "repository.traceAll", "/donations/trace"),
    "donationTrace": ("features/donations/data/donation_repository.dart", "ApiPaths.donationTrace(donationId)", "features/donations/ui/donation_screen.dart", "repository.traceDonation", "/donations/:id/trace"),
    "benefitsCreate": ("features/benefits/data/benefit_repository.dart", "ApiPaths.benefits", "features/benefits/ui/benefit_screens.dart", "BenefitApplicationScreen", "/charities/:charityId/benefits/:benefitTypeId/apply"),
    "benefitsMine": ("features/benefits/data/benefit_repository.dart", "query: {'page': page", "features/benefits/ui/benefit_screens.dart", "MyBenefitsScreen", "/benefits/my"),
    "complaintsCreate": ("features/complaints/data/complaint_repository.dart", "multipart(", "features/complaints/ui/complaint_screens.dart", "CreateComplaintScreen", "/charities/:id/complaint"),
    "complaintsMine": ("features/complaints/data/complaint_repository.dart", "query: {'page': page", "features/complaints/ui/complaint_screens.dart", "MyComplaintsScreen", "/complaints/my"),
    "complaintById": ("features/complaints/data/complaint_repository.dart", "ApiPaths.complaint(id)", "features/complaints/ui/complaint_screens.dart", "ComplaintDetailScreen", "/complaints/:id"),
    "notifications": ("features/notifications/data/notification_repository.dart", "ApiPaths.notifications", "features/notifications/ui/notifications_screen.dart", "NotificationsScreen", "/notifications"),
    "notificationUnreadCount": ("features/notifications/data/notification_repository.dart", "ApiPaths.notificationUnreadCount", "features/home/ui/home_shell.dart", "unreadCount", "/home"),
    "notificationRead": ("features/notifications/data/notification_repository.dart", "ApiPaths.notificationRead", "features/notifications/ui/notifications_screen.dart", "markRead", "/notifications/detail"),
    "notificationsReadAll": ("features/notifications/data/notification_repository.dart", "ApiPaths.notificationReadAll", "features/notifications/ui/notifications_screen.dart", "markAllRead", "/notifications"),
    "profile": ("features/profile/data/profile_repository.dart", "ApiPaths.profile", "features/profile/ui/profile_screen.dart", "DetailCubit<UserProfile>", "/profile"),
    "profileUpdate": ("features/profile/data/profile_repository.dart", "_client.put(ApiPaths.profile", "features/profile/ui/edit_profile_screen.dart", "UpdateProfileRequest", "/profile/edit"),
    "profileInfoAnswers": ("features/profile/data/profile_repository.dart", "_client.get(ApiPaths.profileInfoAnswers", "features/profile/ui/info_answers_screen.dart", "InfoAnswersScreen", "/profile/info-answers"),
    "profileInfoAnswerUpsert": ("features/profile/data/profile_repository.dart", "ApiPaths.profileInfoAnswers", "features/profile/ui/info_answers_screen.dart", ".upsertInfoAnswer", "/profile/info-answers"),
    "profilePassword": ("features/profile/data/profile_repository.dart", "ApiPaths.profilePassword", "features/profile/ui/change_password_screen.dart", "ChangePasswordRequest", "/profile/change-password"),
    "countries": ("features/auth/data/registration_lookup_repository.dart", "ApiPaths.countries", "features/auth/ui/signup_screen.dart", "RegistrationLookupCubit", "/signup"),
    "cities": ("features/auth/data/registration_lookup_repository.dart", "ApiPaths.citiesPath", "features/profile/ui/edit_profile_screen.dart", "RegistrationLookupRepository", "/profile/edit"),
    "caseCategories": ("features/auth/data/registration_lookup_repository.dart", "ApiPaths.caseCategories", "features/catalog/ui/catalog_list_screen.dart", "caseCategories", "/cases"),
    "caseCategoryById": ("features/catalog/data/catalog_repository.dart", "ApiPaths.caseCategory", "features/catalog/ui/catalog_detail_screen.dart", "item.typeName", "/cases/:id"),
    "campaignTypes": ("features/auth/data/registration_lookup_repository.dart", "ApiPaths.campaignTypes", "features/catalog/ui/catalog_list_screen.dart", "campaignTypes", "/campaigns"),
    "campaignTypeById": ("features/catalog/data/catalog_repository.dart", "ApiPaths.campaignType", "features/catalog/ui/catalog_detail_screen.dart", "item.typeName", "/campaigns/:id"),
    "charityLookupBySubdomain": ("features/system/data/system_repository.dart", "ApiPaths.charityLookupBySubdomain", "features/system/ui/charity_subdomain_screen.dart", "charityIdBySubdomain", "/c/:subdomain"),
    "version": ("features/system/data/system_repository.dart", "ApiPaths.version", "features/system/ui/about_screen.dart", "backendVersion", "/about"),
    "mediaUpload": ("features/media/data/media_repository.dart", "fileField: 'files'", "features/media/ui/media_manager_screen.dart", ".upload(", "/media/manage"),
    "mediaByOwner": ("features/media/data/media_repository.dart", "ownerType': ownerType", "features/media/ui/media_manager_screen.dart", ".byOwner(", "/media/manage"),
    "mediaDelete": ("features/media/data/media_repository.dart", "ApiPaths.mediaDelete", "features/media/ui/media_manager_screen.dart", ".delete(", "/media/manage"),
}

errors: list[str] = []
if set(COVERAGE) != set(OPERATIONS):
    missing = sorted(set(OPERATIONS) - set(COVERAGE))
    extra = sorted(set(COVERAGE) - set(OPERATIONS))
    if missing:
        errors.append(f"Operations missing from coverage map: {missing}")
    if extra:
        errors.append(f"Unknown coverage operations: {extra}")

rows = []
for name in sorted(OPERATIONS):
    operation = OPERATIONS[name]
    source_file, source_needle, ui_file, ui_needle, route = COVERAGE[name]
    source_path = LIB / source_file
    ui_path = LIB / ui_file
    source_ok = source_path.exists() and source_needle in source_path.read_text(encoding="utf-8")
    ui_ok = ui_path.exists() and ui_needle in ui_path.read_text(encoding="utf-8")
    if not source_ok:
        errors.append(f"{name}: missing data binding {source_file} :: {source_needle}")
    if not ui_ok:
        errors.append(f"{name}: missing UI binding {ui_file} :: {ui_needle}")
    rows.append((
        name,
        operation["method"],
        operation["path"],
        route,
        "مكتمل" if source_ok and ui_ok else "ناقص",
    ))

report = [
    "# تقرير تغطية API ↔ الواجهات",
    "",
    f"عدد العمليات الرسمية: **{len(OPERATIONS)}**.",
    "",
    "| العملية | Method | Endpoint | الشاشة/المسار | الحالة |",
    "|---|---|---|---|---|",
]
for name, method, path, route, status in rows:
    report.append(f"| `{name}` | `{method}` | `{path}` | `{route}` | {status} |")
report.extend([
    "",
    "## نقاط لا يمكن للواجهة حسمها دون تعديل Backend",
    "",
    "محدّث بعد إجابات الباك اند في `BACKEND_ANSWERS.md` (2026-08-23).",
    "",
    "- **بيانات الحساب البنكي/IBAN غير موجودة إطلاقاً** في أي endpoint ولا كحقل على"
    " `Charity`؛ لذلك لا يستطيع التطبيق أن يعرض للمتبرع إلى أين يحوّل"
    " (`BACKEND_QUESTIONS_R2.md` #1).",
    "- **لا يوجد `GET /api/mobile/donations/{id}`**؛ شاشة تفاصيل التبرع تعوّضه بمسح"
    " صفحات السجل، وهو مكلف. طُلب رسمياً (`BACKEND_QUESTIONS_R2.md` #2).",
    "- **احتياجات الحالة (`CaseNeed`) غير موثقة** رغم أن `caseNeedId` إلزامي لكل تبرع"
    " لحالة؛ التطبيق يقرأها من `needs` داخل استجابة الحالة إن وُجدت، ويمنع التبرع"
    " إن غابت (`BACKEND_QUESTIONS_R2.md` #3).",
    "- معنى `referenceId` لكل نوع إشعار غير موثق؛ لذلك شاشة التفاصيل آمنة ولا تنفذ"
    " deep-link تخمينيًا.",
    "- صيغة الإجابة للحقول الديناميكية من نوع `Attachment` و`MultiOption` غير محددة"
    " (`BACKEND_QUESTIONS_R2.md` #6).",
    "- يجب أن يعيد الخادم `401` بدل `500` عند غياب أو انتهاء JWT.",
    "",
    "### نقاط أُغلقت",
    "",
    "- ~~أسئلة نوع المنفعة غير موثقة~~ — صارت موثقة ضمن"
    " `GET /api/mobile/charities/{id}/benefit-types`.",
    "- ~~البحث والفلاتر من الخادم غير موثقة~~ — صارت موثقة على"
    " `GET /api/mobile/donations`.",
    "- ~~callback بوابات الدفع غير موثق~~ — لا توجد بوابة دفع إلكتروني أصلاً؛"
    " كل تسوية يدوية (نقدي أو تحويل بنكي بإثبات).",
    "- ~~تعديل صورة الملف الشخصي غير موجود~~ — `ProfileImage` موثق ضمن"
    " `PUT /api/mobile/profile`.",
])
(ROOT / "API_UI_COVERAGE_REPORT_AR.md").write_text("\n".join(report) + "\n", encoding="utf-8")

if errors:
    print("FAIL: API/UI coverage")
    for error in errors:
        print("-", error)
    sys.exit(1)
print(f"PASS: {len(OPERATIONS)} official API operations have data and UI bindings.")
print("PASS: API_UI_COVERAGE_REPORT_AR.md generated.")
