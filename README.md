# GiveChain Mobile — المشروع الكامل

تطبيق Flutter عربي RTL لمنصة GiveChain، مبني وفق دليل الـMobile API الرسمي المرفق في `docs/GiveChain_Mobile_Guide.md`.

## حالة النسخة

- الإصدار: `3.0.0+10`
- عدد عمليات الـAPI الرسمية المربوطة: **49**
- عدد مسارات الواجهات: **43**
- رحلات الاستخدام الحرجة المدققة: **12**
- التصفح العام متاح دون تسجيل دخول.
- التبرع والملف الشخصي والإشعارات والمنافع والشكاوى تتطلب جلسة صالحة.
- لا توجد بيانات حساب أو Token مضمنة في السورس.

## الميزات

- التسجيل والدخول واستعادة كلمة المرور.
- صفحة رئيسية ديناميكية، قوائم حملات وحالات وجمعيات، بحث وفلترة محلية وPagination.
- تفاصيل كاملة بالـID، معرض صور ووسائط، تبويبات الجمعية ومنافعها.
- تبرع نقدي أو عيني أو خدمي، مرفقات، مراجعة، دفع إلكتروني، وتأكيد Bee/Bank.
- سجل التبرعات، تفاصيل العملية، وتتبع مسار الأموال لتبرع واحد أو لجميع التبرعات.
- طلبات المنافع والشكاوى والإشعارات.
- الملف الشخصي وتعديله، حقول المعلومات الإضافية، تغيير كلمة المرور، وتسجيل الخروج.
- إدارة الوسائط، رابط جمعية مختصر، معلومات إصدار الخادم، وشاشة تشخيص للمطور.

## المتطلبات

1. Flutter Stable حديث.
2. Android Studio أو VS Code مع Flutter/Dart.
3. Android SDK لتشغيل Android.
4. Xcode على macOS لتشغيل iOS.

تحقق من البيئة:

```bash
flutter doctor -v
```

## التشغيل السريع

```bash
flutter pub get
dart format .
flutter analyze
flutter test
flutter run
```

عنوان الخادم الافتراضي:

```text
https://givechain.runasp.net
```

ويمكن تغييره دون تعديل السورس:

```bash
flutter run \
  --dart-define=GIVECHAIN_BASE_URL=https://example.com
```

## تجهيز ملفات المنصات

ملفات Android وWeb موجودة داخل المشروع. على macOS، أو عند الرغبة في إعادة توليد ملفات المنصات وفق نسخة Flutter المثبتة لديك، شغّل:

### macOS / Linux

```bash
chmod +x tools/prepare_flutter_platforms.sh
./tools/prepare_flutter_platforms.sh
```

### Windows PowerShell

```powershell
.\tools\prepare_flutter_platforms.ps1
```

بعدها أعد تنفيذ:

```bash
flutter pub get
flutter analyze
flutter test
```

## اختبار الـAPI للقراءة فقط

الأداة التالية تسجل الدخول ثم تختبر endpoints القراءة الموثقة، ولا تنشئ تبرعًا ولا تعدّل بيانات:

```bash
export GIVECHAIN_TEST_EMAIL='test@example.com'
export GIVECHAIN_TEST_USERNAME=''
export GIVECHAIN_TEST_PASSWORD='your-test-password'
python3 tools/api_readonly_smoke.py
```

لا تضع بيانات الدخول داخل ملفات المشروع أو Git.

## تقارير التدقيق

- `FINAL_INTEGRATION_REPORT_AR.md`
- `API_UI_COVERAGE_REPORT_AR.md`
- `ROUTE_UI_AUDIT_REPORT_AR.md`
- `API_MAPPING.md`
- `RUN_ON_DEVICE_AR.md`

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

## ملاحظات مهمة

- البحث والفلترة في Explore محليان فوق الصفحات المحمّلة لأن دليل الباك اند يوثق Pagination فقط.
- أسئلة نوع المنفعة تُعرض ديناميكيًا إذا أعادها الخادم؛ لا يتم اختلاق Question IDs عند غيابها.
- لا يتم تنفيذ Deep Link من `notification.referenceId` قبل توثيق معنى المرجع لكل نوع إشعار.
- تعديل صورة الملف الشخصي بعد التسجيل غير معروض لأن `PUT /api/mobile/profile` لا يوثّق حقل صورة.
