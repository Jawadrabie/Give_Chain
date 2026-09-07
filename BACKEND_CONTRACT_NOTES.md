# ملاحظات عقد الباك اند

## قواعد مطبقة في التطبيق

- كل الاستجابات تمر عبر `ApiResponse<T>` ويُفحص `isSuccess` حتى لو كان HTTP 200.
- القوائم تقرأ `PagedResult<T>`: `items`, `page`, `pageSize`, `totalPages`, `totalCount`.
- endpoints الشخصية ترسل `Authorization: Bearer <token>`.
- عمليات الكتابة لا تُعاد تلقائيًا لتجنب تكرار التبرع أو الطلب.
- استجابات JSON تحت `text/plain` مدعومة.
- 401 يمسح الجلسة ويعيد المستخدم إلى Login.

## نقاط تحتاج قرارًا من الباك اند

1. endpoint/shape أسئلة Benefit Type.
2. معنى `referenceId` حسب Notification Type.
3. Search/filters من الخادم.
4. تحديث صورة Profile بعد التسجيل.
5. Callback/deep link الخاص ببوابات الدفع.
6. تفعيل `[Authorize]` وإرجاع 401 بدل 500.
7. ضمان أن روابط Media مطلقة في جميع البيئات.
