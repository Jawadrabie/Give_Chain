<p align="center">
  <img src="assets/images/givechain_logo.svg" alt="GiveChain" width="120" />
</p>

<h1 align="center">GiveChain Mobile</h1>

<p align="center">
  تطبيق Flutter عربي (RTL) لمنصة GiveChain للتبرعات — يربط المتبرعين بالجمعيات الخيرية والحالات والحملات، مع تتبّع كامل لمسار كل تبرع.
</p>

<p align="center">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-Stable-02569B?logo=flutter&logoColor=white">
  <img alt="Version" src="https://img.shields.io/badge/version-3.0.0%2B10-informational">
  <img alt="Platform" src="https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Web-lightgrey">
  <img alt="License" src="https://img.shields.io/badge/license-Proprietary-red">
</p>

<p align="center">
  <a href="#نظرة-عامة">نظرة عامة</a> ·
  <a href="#الميزات">الميزات</a> ·
  <a href="#التقنيات-المستخدمة">التقنيات</a> ·
  <a href="#البدء-السريع">البدء السريع</a> ·
  <a href="#بنية-المشروع">البنية</a> ·
  <a href="#الاختبار-والتدقيق">الاختبار</a> ·
  <a href="#المساهمة">المساهمة</a>
</p>

---

## نظرة عامة

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

## الميزات

- **الحساب**: تسجيل، دخول، واستعادة كلمة مرور.
- **الاستكشاف**: صفحة رئيسية ديناميكية، قوائم حملات وحالات وجمعيات، بحث وفلترة محلية مع Pagination.
- **التفاصيل**: صفحات تفصيلية بالمعرّف (ID)، معرض صور ووسائط، تبويبات الجمعية ومنافعها.
- **التبرع**: تبرع نقدي أو عيني أو بخدمة، إرفاق مستندات، مراجعة الطلب، دفع إلكتروني، وتأكيد عبر Bee/Bank.
- **التتبّع**: سجل التبرعات، تفاصيل كل عملية، ومسار الأموال لتبرع واحد أو لكل التبرعات.
- **الخدمات**: طلبات الاستفادة من المنافع، الشكاوى، والإشعارات.
- **الملف الشخصي**: تعديل البيانات، الحقول الإضافية، تغيير كلمة المرور، وتسجيل الخروج.
- **أدوات مساندة**: إدارة الوسائط، رابط مختصر لكل جمعية، معلومات إصدار الخادم، وشاشة تشخيص للمطورين.

## التقنيات المستخدمة

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

## البدء السريع

### المتطلبات

1. Flutter Stable (أحدث إصدار).
2. Android Studio أو VS Code مع إضافات Flutter/Dart.
3. Android SDK لتشغيل تطبيق Android.
4. Xcode على macOS لتشغيل تطبيق iOS.

تحقق من جاهزية البيئة:

```bash
flutter doctor -v
```

### التثبيت والتشغيل

```bash
git clone https://github.com/Jawadrabie/give-chain.git
cd give-chain

flutter pub get
dart format .
flutter analyze
flutter test
flutter run
```

### إعداد عنوان الخادم

العنوان الافتراضي:

```text
https://givechain.runasp.net
```

يمكن تغييره دون تعديل السورس عبر `--dart-define`:

```bash
flutter run --dart-define=GIVECHAIN_BASE_URL=https://example.com
```

### تجهيز ملفات المنصات

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

## بنية المشروع

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

## الاختبار والتدقيق

### اختبارات الوحدة والواجهة

```bash
flutter test
```

### اختبار الـ API للقراءة فقط

أداة تسجّل الدخول ثم تختبر مسارات القراءة الموثقة فقط، دون إنشاء تبرع أو تعديل بيانات:

```bash
export GIVECHAIN_TEST_EMAIL='test@example.com'
export GIVECHAIN_TEST_USERNAME=''
export GIVECHAIN_TEST_PASSWORD='your-test-password'
python3 tools/api_readonly_smoke.py
```

> لا تضع بيانات الدخول داخل ملفات المشروع أو Git.

### تقارير التدقيق

| التقرير | الوصف |
|---|---|
| [`FINAL_INTEGRATION_REPORT_AR.md`](FINAL_INTEGRATION_REPORT_AR.md) | تقرير التكامل النهائي |
| [`API_UI_COVERAGE_REPORT_AR.md`](API_UI_COVERAGE_REPORT_AR.md) | تغطية الـ API بالواجهات |
| [`ROUTE_UI_AUDIT_REPORT_AR.md`](ROUTE_UI_AUDIT_REPORT_AR.md) | تدقيق مسارات الواجهات |
| [`API_MAPPING.md`](API_MAPPING.md) | خريطة ربط الـ API |
| [`RUN_ON_DEVICE_AR.md`](RUN_ON_DEVICE_AR.md) | تشغيل التطبيق على جهاز فعلي |

## ملاحظات مهمة

- البحث والفلترة في Explore محليان فوق الصفحات المحمّلة، لأن دليل الباك-إند يوثّق Pagination فقط.
- أسئلة نوع المنفعة تُعرض ديناميكيًا إذا أعادها الخادم؛ لا يتم اختلاق Question IDs عند غيابها.
- لا يُنفَّذ Deep Link من `notification.referenceId` قبل توثيق معنى المرجع لكل نوع إشعار.
- تعديل صورة الملف الشخصي بعد التسجيل غير معروض، لأن `PUT /api/mobile/profile` لا يوثّق حقل صورة.

## المساهمة

المساهمات مرحّب بها. قبل فتح Pull Request:

```bash
dart format .
flutter analyze
flutter test
```

يشغّل CI ([`flutter_ci.yml`](.github/workflows/flutter_ci.yml)) نفس هذه الفحوصات تلقائيًا مع تدقيق تغطية الـ API والمسارات على كل Push وPull Request.

## الترخيص

جميع الحقوق محفوظة © GiveChain، إلا إذا نُصّ على خلاف ذلك.
