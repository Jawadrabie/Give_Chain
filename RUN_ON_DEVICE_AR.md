# تشغيل GiveChain على جهازك

## 1. فك الضغط

ضع المشروع في مسار قصير ويفضل ألا يحتوي على رموز خاصة.

## 2. تثبيت الحزم

```bash
flutter clean
flutter pub get
```

## 3. الفحص

```bash
dart format .
flutter analyze
flutter test
python3 verify_source.py
```

## 4. Android

شغّل Emulator أو صِل هاتفًا مع USB debugging:

```bash
flutter devices
flutter run -d <device-id>
```

لإنشاء APK تجريبي:

```bash
flutter build apk --debug
```

للنشر يجب إعداد signing داخل Android وفق حسابك.

## 5. Web

```bash
flutter run -d chrome
```

أو:

```bash
flutter build web
```

## 6. iOS

على macOS:

```bash
./tools/prepare_flutter_platforms.sh
open ios/Runner.xcworkspace
flutter run -d <ios-device-id>
```

اختر Team وSigning الخاصين بك من Xcode.

## 7. تغيير عنوان الخادم

```bash
flutter run --dart-define=GIVECHAIN_BASE_URL=https://givechain.runasp.net
```

## 8. اختبار سيناريوهات أساسية

1. التصفح كزائر ثم فتح حملة وحالة وجمعية.
2. الضغط على تبرع كزائر ثم تسجيل الدخول والعودة إلى نفس الهدف.
3. إنشاء حساب واختيار الدولة والمدينة والجنس والصورة.
4. تبرع نقدي Cash، ثم Stripe/ShamCash إن كانت بوابة الاختبار متاحة.
5. تبرع عيني وخدمي مع مرفقات.
6. تأكيد مرجع Bee/Bank.
7. فتح سجل التبرعات والتفاصيل والتتبع.
8. تقديم منفعة عند توفر الأسئلة.
9. تقديم شكوى بمرفقات.
10. فتح الإشعارات وتحديث المقروء.
11. تعديل الملف الشخصي وتغيير كلمة المرور.
12. قتل التطبيق وإعادة فتحه مع تفعيل/تعطيل «تذكر هذا الجهاز».
