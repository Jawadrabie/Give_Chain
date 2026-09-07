# iOS platform bootstrap

ملفات التطبيق وإعدادات الخصوصية والأيقونات موجودة. لإنشاء ملفات Xcode الخاصة
بنسخة Flutter المثبتة على جهاز macOS شغّل من جذر المشروع:

```bash
./tools/prepare_flutter_platforms.sh
```

الأمر الرسمي `flutter create . --platforms=android,ios,web` يعيد توليد ملفات
المنصات دون استبدال ملفات `lib/` الموجودة.
