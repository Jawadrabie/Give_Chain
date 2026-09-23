# GiveChain Mobile

Official Flutter mobile app for **GiveChain**, a donation platform that connects donors with charities, campaigns, and cases — with full transparency into where every donation goes.

![Flutter](https://img.shields.io/badge/Flutter-Stable-02569B?logo=flutter&logoColor=white)
![Version](https://img.shields.io/badge/version-3.0.0%2B10-informational)
![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Web-lightgrey)
![License](https://img.shields.io/badge/license-Proprietary-red)

---

## English

### Overview

GiveChain lets users browse charities, campaigns, and cases, and donate cash, in-kind items, or services — with transparent tracking of each donation from payment to disbursement. This repository contains the platform's official mobile app, built end-to-end against the Mobile API guide documented in [`docs/GiveChain_Mobile_Guide.md`](docs/GiveChain_Mobile_Guide.md).

| | |
|---|---|
| **Version** | `3.0.0+10` |
| **API operations wired** | 49 |
| **UI routes** | 43 |
| **Audited critical flows** | 12 |
| **Public browsing** | No login required |
| **Donations / profile / notifications / benefits / complaints** | Require a valid session |
| **Credentials or tokens in source** | None |

### Features

- **Account**: sign up, log in, password recovery.
- **Discovery**: dynamic home feed, campaign/case/charity listings, local search and filtering with pagination.
- **Details**: full item pages by ID, media galleries, charity tabs and benefits.
- **Donations**: cash, in-kind, or service donations, attachments, review, online payment, and Bee/Bank confirmation.
- **Tracking**: donation history, per-transaction detail, and fund-tracking for a single donation or all donations.
- **Services**: benefit requests, complaints, and notifications.
- **Profile**: edit info, extra fields, change password, logout.
- **Utilities**: media management, per-charity short links, server version info, and a developer diagnostics screen.

### Tech stack

| Layer | Tools |
|---|---|
| Framework | Flutter (Dart) |
| State management | `flutter_bloc` / Cubit |
| Dependency injection | `get_it` |
| Networking | `dio` |
| Routing | `go_router` |
| Storage | `shared_preferences`, `flutter_secure_storage` |
| Testing | `flutter_test`, `bloc_test`, `mocktail` |
| CI | GitHub Actions ([`flutter_ci.yml`](.github/workflows/flutter_ci.yml)) |

### Getting started

**Prerequisites**

1. A recent Flutter stable release.
2. Android Studio or VS Code with the Flutter/Dart plugins.
3. Android SDK for Android builds.
4. Xcode on macOS for iOS builds.

Check your environment:

```bash
flutter doctor -v
```

**Install and run**

```bash
git clone https://github.com/Jawadrabie/Give_Chain.git
cd Give_Chain

flutter pub get
dart format .
flutter analyze
flutter test
flutter run
```

**Backend URL**

Default:

```text
https://givechain.runasp.net
```

Override without touching source, via `--dart-define`:

```bash
flutter run --dart-define=GIVECHAIN_BASE_URL=https://example.com
```

**Regenerating platform files**

Android and Web platform files are checked in. To regenerate them for your local Flutter version (e.g. on macOS):

```bash
# macOS / Linux
chmod +x tools/prepare_flutter_platforms.sh
./tools/prepare_flutter_platforms.sh
```

```powershell
# Windows PowerShell
.\tools\prepare_flutter_platforms.ps1
```

Then re-run:

```bash
flutter pub get
flutter analyze
flutter test
```

### Project structure

```text
lib/
├── core/                 # networking, session, storage, routing, theme
└── features/
    ├── auth & login      # sign up, log in, password recovery
    ├── home              # home feed and bottom navigation
    ├── catalog           # campaigns and cases
    ├── charities         # charities, their content, and benefits
    ├── donations         # donations, payment, and tracking
    ├── benefits          # benefit requests
    ├── complaints        # complaints
    ├── notifications     # notifications
    ├── profile           # profile and settings
    ├── media             # media viewing and management
    └── system            # server version and short links
```

### Testing & auditing

**Unit and widget tests**

```bash
flutter test
```

**Read-only API smoke test**

Logs in and exercises documented read endpoints only — it never creates a donation or mutates data:

```bash
export GIVECHAIN_TEST_EMAIL='test@example.com'
export GIVECHAIN_TEST_USERNAME=''
export GIVECHAIN_TEST_PASSWORD='your-test-password'
python3 tools/api_readonly_smoke.py
```

> Never commit credentials to the project or to Git.

**Audit reports**

| Report | Description |
|---|---|
| [`FINAL_INTEGRATION_REPORT_AR.md`](FINAL_INTEGRATION_REPORT_AR.md) | Final integration report |
| [`API_UI_COVERAGE_REPORT_AR.md`](API_UI_COVERAGE_REPORT_AR.md) | API-to-UI coverage |
| [`ROUTE_UI_AUDIT_REPORT_AR.md`](ROUTE_UI_AUDIT_REPORT_AR.md) | UI route audit |
| [`API_MAPPING.md`](API_MAPPING.md) | API mapping |
| [`RUN_ON_DEVICE_AR.md`](RUN_ON_DEVICE_AR.md) | Running on a physical device |

### Notes

- Search and filtering in Explore are local, over already-loaded pages, since the backend guide only documents pagination.
- Benefit-type questions render dynamically only when the server returns them; question IDs are never fabricated.
- Deep links from `notification.referenceId` are not implemented until each notification type's reference meaning is documented.
- Editing the profile picture after signup isn't exposed, since `PUT /api/mobile/profile` doesn't document an image field.

### Contributing

Contributions are welcome. Before opening a pull request:

```bash
dart format .
flutter analyze
flutter test
```

CI ([`flutter_ci.yml`](.github/workflows/flutter_ci.yml)) runs the same checks automatically, plus API/route coverage audits, on every push and pull request.

### License

All rights reserved © GiveChain, unless stated otherwise.

---

## العربية

### نظرة عامة

**GiveChain** منصة تبرعات تتيح للمستخدمين تصفح الجمعيات الخيرية والحملات والحالات، والتبرع نقدًا أو عينًا أو بخدمة، مع تتبّع شفاف لمسار كل تبرع من لحظة الدفع حتى الصرف الفعلي. هذا المستودع يحتوي تطبيق الجوال (Flutter) الرسمي للمنصة، وهو مبني بالكامل وفق دليل الـ Mobile API الموثّق في [`docs/GiveChain_Mobile_Guide.md`](docs/GiveChain_Mobile_Guide.md).

| | |
|---|---|
| **الإصدار** | `3.0.0+10` |
| **عمليات الـ API المربوطة** | 49 |
| **مسارات الواجهات** | 43 |
| **رحلات الاستخدام المدقّقة** | 12 |
| **التصفح العام** | متاح دون تسجيل دخول |
| **التبرع / الملف الشخصي / الإشعارات / المنافع / الشكاوى** | تتطلب جلسة مصادقة صالحة |
| **بيانات حساب أو Tokens في السورس** | لا يوجد |

### الميزات

- **الحساب**: تسجيل، دخول، واستعادة كلمة مرور.
- **الاستكشاف**: صفحة رئيسية ديناميكية، قوائم حملات وحالات وجمعيات، بحث وفلترة محلية مع Pagination.
- **التفاصيل**: صفحات تفصيلية بالمعرّف (ID)، معرض صور ووسائط، تبويبات الجمعية ومنافعها.
- **التبرع**: تبرع نقدي أو عيني أو بخدمة، إرفاق مستندات، مراجعة الطلب، دفع إلكتروني، وتأكيد عبر Bee/Bank.
- **التتبّع**: سجل التبرعات، تفاصيل كل عملية، ومسار الأموال لتبرع واحد أو لكل التبرعات.
- **الخدمات**: طلبات الاستفادة من المنافع، الشكاوى، والإشعارات.
- **الملف الشخصي**: تعديل البيانات، الحقول الإضافية، تغيير كلمة المرور، وتسجيل الخروج.
- **أدوات مساندة**: إدارة الوسائط، رابط مختصر لكل جمعية، معلومات إصدار الخادم، وشاشة تشخيص للمطورين.

### التقنيات المستخدمة

| الطبقة | الأدوات |
|---|---|
| اللغة/الإطار | Flutter (Dart) |
| إدارة الحالة | `flutter_bloc` / Cubit |
| حقن الاعتمادات | `get_it` |
| الشبكة | `dio` |
| التوجيه | `go_router` |
| التخزين | `shared_preferences`, `flutter_secure_storage` |
| الاختبارات | `flutter_test`, `bloc_test`, `mocktail` |
| CI | GitHub Actions ([`flutter_ci.yml`](.github/workflows/flutter_ci.yml)) |

### البدء السريع

**المتطلبات**

1. Flutter Stable (أحدث إصدار).
2. Android Studio أو VS Code مع إضافات Flutter/Dart.
3. Android SDK لتشغيل تطبيق Android.
4. Xcode على macOS لتشغيل تطبيق iOS.

تحقق من جاهزية البيئة:

```bash
flutter doctor -v
```

**التثبيت والتشغيل**

```bash
git clone https://github.com/Jawadrabie/Give_Chain.git
cd Give_Chain

flutter pub get
dart format .
flutter analyze
flutter test
flutter run
```

**إعداد عنوان الخادم**

العنوان الافتراضي:

```text
https://givechain.runasp.net
```

يمكن تغييره دون تعديل السورس عبر `--dart-define`:

```bash
flutter run --dart-define=GIVECHAIN_BASE_URL=https://example.com
```

**تجهيز ملفات المنصات**

ملفات Android وWeb متوفرة داخل المشروع. لإعادة توليدها وفق نسخة Flutter المثبتة لديك (مثلًا على macOS):

```bash
# macOS / Linux
chmod +x tools/prepare_flutter_platforms.sh
./tools/prepare_flutter_platforms.sh
```

```powershell
# Windows PowerShell
.\tools\prepare_flutter_platforms.ps1
```

ثم أعد تنفيذ:

```bash
flutter pub get
flutter analyze
flutter test
```

### بنية المشروع

```text
lib/
├── core/                 # الشبكة، الجلسة، التخزين، المسارات، الثيم
└── features/
    ├── auth & login      # التسجيل والدخول والاستعادة
    ├── home              # الصفحة الرئيسية والتنقل السفلي
    ├── catalog           # الحملات والحالات
    ├── charities         # الجمعيات ومحتواها والمنافع
    ├── donations         # التبرعات والدفع والتتبع
    ├── benefits          # طلبات الاستفادة
    ├── complaints        # الشكاوى
    ├── notifications     # الإشعارات
    ├── profile           # الملف الشخصي والإعدادات
    ├── media             # عرض وإدارة الوسائط
    └── system            # الإصدار والروابط المختصرة
```

### الاختبار والتدقيق

**اختبارات الوحدة والواجهة**

```bash
flutter test
```

**اختبار الـ API للقراءة فقط**

أداة تسجّل الدخول ثم تختبر مسارات القراءة الموثقة فقط، دون إنشاء تبرع أو تعديل بيانات:

```bash
export GIVECHAIN_TEST_EMAIL='test@example.com'
export GIVECHAIN_TEST_USERNAME=''
export GIVECHAIN_TEST_PASSWORD='your-test-password'
python3 tools/api_readonly_smoke.py
```

> لا تضع بيانات الدخول داخل ملفات المشروع أو Git.

**تقارير التدقيق**

| التقرير | الوصف |
|---|---|
| [`FINAL_INTEGRATION_REPORT_AR.md`](FINAL_INTEGRATION_REPORT_AR.md) | تقرير التكامل النهائي |
| [`API_UI_COVERAGE_REPORT_AR.md`](API_UI_COVERAGE_REPORT_AR.md) | تغطية الـ API بالواجهات |
| [`ROUTE_UI_AUDIT_REPORT_AR.md`](ROUTE_UI_AUDIT_REPORT_AR.md) | تدقيق مسارات الواجهات |
| [`API_MAPPING.md`](API_MAPPING.md) | خريطة ربط الـ API |
| [`RUN_ON_DEVICE_AR.md`](RUN_ON_DEVICE_AR.md) | تشغيل التطبيق على جهاز فعلي |

### ملاحظات مهمة

- البحث والفلترة في Explore محليان فوق الصفحات المحمّلة، لأن دليل الباك-إند يوثّق Pagination فقط.
- أسئلة نوع المنفعة تُعرض ديناميكيًا إذا أعادها الخادم؛ لا يتم اختلاق Question IDs عند غيابها.
- لا يُنفَّذ Deep Link من `notification.referenceId` قبل توثيق معنى المرجع لكل نوع إشعار.
- تعديل صورة الملف الشخصي بعد التسجيل غير معروض، لأن `PUT /api/mobile/profile` لا يوثّق حقل صورة.

### المساهمة

المساهمات مرحّب بها. قبل فتح Pull Request:

```bash
dart format .
flutter analyze
flutter test
```

يشغّل CI ([`flutter_ci.yml`](.github/workflows/flutter_ci.yml)) نفس هذه الفحوصات تلقائيًا مع تدقيق تغطية الـ API والمسارات على كل Push وPull Request.

### الترخيص

جميع الحقوق محفوظة © GiveChain، إلا إذا نُصّ على خلاف ذلك.
