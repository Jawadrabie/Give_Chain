# خطة إعادة تصميم UX — GiveChain v3 (النسخة النظيفة)

> **الجمهور:** Cursor — ينفّذ كل شيء.
> **قاعدة ذهبية:** لا حشو. كل عنصر على الشاشة يجب أن يجيب على سؤال "لماذا هذا هنا؟" بإجابة واضحة. إذا لم تكن هناك إجابة — احذفه.
> لا تلمس `data/` و`logic/` — فقط `ui/`. احترم `AppTheme` الحالي.

---

## 1. الهيكل الجديد: 4 تبويبات، بلا حشو

| # | التبويب | ماذا يفعل | ماذا لا يفعل |
|---|---|---|---|
| 1 | 🏠 **الرئيسية** | Feed عمودي نظيف: بانر + أزرار سريعة + 3 حملات مميزة + 3 حالات مميزة + جمعيات مميزة. كل قسم فيه "عرض الكل" يفتح **صفحة كاملة منفصلة** (`/campaigns`, `/cases`, `/charities`) | لا تبويبات داخلية. لا TabBar. لا NestedScrollView. |
| 2 | ❤️ **تبرع** | نموذج تبرع فعلي من 3 خطوات | ليس قائمة روابط |
| 3 | 🔔 **الإشعارات** | كما هي | — |
| 4 | 👤 **حسابي** | ملف شخصي + سجلاتي (تبرعاتي/منافعي/شكاواي) | — |

**ما يُحذف:**
- تبويب "استكشاف" بالكامل + ملف `explore_screen.dart`
- ملف `direct_donation_screen.dart` + الروت `/donate/direct`
- كل "تصفّح الكل" / `_BrowseSection` / أي TabBar داخل الرئيسية

---

## 2. التنفيذ ملف بملف

### 2.1 `home_shell.dart` — من 5 تبويبات إلى 4

**الملف:** `lib/features/home/ui/home_shell.dart`

1. غيّر `titles`:
   ```dart
   static const titles = ['الرئيسية', 'تبرع', 'الإشعارات', 'حسابي'];
   ```

2. في `IndexedStack.children` أزل `ExploreScreen()`. النتيجة:
   ```dart
   children: [
     const DashboardScreen(),          // 0
     const QuickDonateScreen(),        // 1
     authenticated ? const NotificationsScreen(embedded: true) : const _SignInRequired(...),  // 2
     authenticated ? const ProfileScreen() : const _SignInRequired(...),  // 3
   ],
   ```

3. عدّل شروط Guest:
   ```dart
   if (!TokenStorage.hasSession && value == 2) { context.push('/notifications'); return; }
   if (!TokenStorage.hasSession && value == 3) { context.push('/profile'); return; }
   ```

4. في `NavigationBar.destinations` أزل destination "استكشاف". غيّر أيقونة "تبرع":
   ```dart
   const NavigationDestination(
     icon: Icon(Icons.favorite_outline),
     selectedIcon: Icon(Icons.favorite),
     label: 'تبرع',
   ),
   ```

5. أزل `import 'explore_screen.dart';`.

---

### 2.2 `dashboard_screen.dart` — Feed نظيف بدون تبويبات

**الملف:** `lib/features/home/ui/dashboard_screen.dart`

**الهدف:** `ListView` عمودي بسيط. مرّر للأسفل = ترى كل شيء. لا TabBar، لا NestedScrollView.

#### ما يُحذف من الملف:
- `_CharitiesSection` بالكامل (class كاملة) — سنعوضها بتصميم أبسط
- `_HomeCharityTile` بالكامل (class كاملة)
- `_HomeHelpCard` بالكامل (class كاملة) — حشو، ستُعوَّض بأزرار سريعة
- `_EmptyHint` بالكامل (class كاملة) — سنستخدم `EmptyView` المحسّنة

#### ما يُعدَّل:

**أ. `_SectionHeader`** — أبقِه كما هو لكن تأكد أنه يستخدم `route` ويوجّه إلى الصفحات الموجودة:
```dart
// يبقى كما هو — "عرض الكل" يذهب لـ context.push(route)
// route = '/campaigns' أو '/cases' أو '/charities'
// هذه صفحات كاملة موجودة فعلًا — لا تكرار
```

**ب. `_CasesSection`** — قلّص إلى 3 عناصر:
```dart
// غيّر:
items: overview?.cases ?? const []
// إلى:
items: (overview?.cases ?? const []).take(3).toList()
```
غيّر عنوان `_SectionHeader` من `'حالات حرجة'` إلى `'حالات تحتاج دعمك'`.

**ج. `_CampaignsSection`** — قلّص إلى 3 عناصر:
```dart
items: (overview?.campaigns ?? const []).take(3).toList()
```
غيّر العنوان من `'حملات موثوقة'` إلى `'حملات مختارة لك'`.

**د. أضف قسم جمعيات بسيط** (بدل `_CharitiesSection` القديمة المعقدة). فقط 3 بطاقات بسيطة بعرض كامل:

```dart
class _CharitiesPreview extends StatelessWidget {
  const _CharitiesPreview({required this.items});
  final List<Charity> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final show = items.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'جمعيات موثوقة', route: '/charities'),
        const SizedBox(height: 12),
        ...show.map((charity) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: _CharityRow(charity: charity),
        )),
      ],
    );
  }
}

class _CharityRow extends StatelessWidget {
  const _CharityRow({required this.charity});
  final Charity charity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('/charities/${charity.id}', extra: charity),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? scheme.surface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 48, height: 48,
                child: charity.logoUrl.trim().isEmpty
                  ? Icon(Icons.apartment, color: scheme.primary)
                  : NetworkOrPlaceholder(url: charity.logoUrl, height: 48, icon: Icons.apartment),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(charity.name, style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface)),
                  if (charity.categoryName.isNotEmpty)
                    Text(charity.categoryName, style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.6))),
                ],
              ),
            ),
            if (charity.isTrusted)
              Icon(Icons.verified, color: Colors.green, size: 20),
            const SizedBox(width: 4),
            Icon(Icons.arrow_back_ios_new, size: 14, color: scheme.onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}
```

**هـ. استبدل `_HomeHelpCard` بـ `_QuickActions`:**

```dart
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _action(context, Icons.favorite, 'تبرع سريع', () {
          // switch to donate tab (index 1)
          // أبسط طريقة: HomeShell يوفّر callback أو ValueNotifier
        }),
        _action(context, Icons.campaign, 'الحملات', () => context.push('/campaigns')),
        _action(context, Icons.volunteer_activism, 'الحالات', () => context.push('/cases')),
        _action(context, Icons.apartment, 'الجمعيات', () => context.push('/charities')),
      ],
    );
  }

  Widget _action(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 50, width: 50,
              decoration: BoxDecoration(
                color: AppTheme.softOf(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppTheme.primary, size: 24),
            ),
            const SizedBox(height: 6),
            Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
              textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
```

**و. الترتيب النهائي لـ `ListView.children`:**

```dart
children: [
  // 1. البانر
  const Padding(
    padding: EdgeInsets.symmetric(horizontal: 16),
    child: _HomeBanner(),
  ),
  const SizedBox(height: 16),

  // 2. أزرار سريعة (4 أيقونات)
  const Padding(
    padding: EdgeInsets.symmetric(horizontal: 16),
    child: _QuickActions(),
  ),
  const SizedBox(height: 24),

  // 3. حملات مختارة (3 بطاقات أفقية)
  _CampaignsSection(items: (overview?.campaigns ?? const []).take(3).toList()),
  const SizedBox(height: 24),

  // 4. حالات تحتاج دعمك (3 بطاقات أفقية)
  _CasesSection(items: (overview?.cases ?? const []).take(3).toList()),
  const SizedBox(height: 24),

  // 5. جمعيات موثوقة (3 صفوف عمودية بسيطة)
  _CharitiesPreview(items: (overview?.charities ?? const []).take(3).toList()),
  const SizedBox(height: 28),
],
```

**لا `_ImpactSnapshot` ولا `_GuestCta`** — كانت حشو أيضًا. المستخدم يريد يتصفح ويتبرع، مش يقرأ إحصائيات.

---

### 2.3 `quick_donate_screen.dart` — نموذج تبرع فعلي

**الملف:** `lib/features/home/ui/quick_donate_screen.dart`

**احذف كل المحتوى الحالي واستبدله:**

حوّل من `StatelessWidget` إلى `StatefulWidget`.

**المتغيرات:**
```dart
int _step = 0; // 0=وجهة, 1=مبلغ, 2=نوع
String _targetType = 'campaign'; // campaign / case
CatalogItem? _selectedTarget;
int? _selectedAmountIndex;
final _amountController = TextEditingController();
String _donationType = 'financial'; // financial / inKind / service
```

**الهيكل:**
```
┌──────────────────────────┐
│  ● ─── ● ─── ○  Stepper │  3 دوائر أفقية مخصصة
├──────────────────────────┤
│                          │
│  خطوة 1: اختر الوجهة      │  SegmentedButton: حملة / حالة
│  [اختر الهدف ▼]          │  ← BottomSheet مع بحث
│                          │
│  خطوة 2: المبلغ           │  4 Chips + حقل مخصص
│                          │
│  خطوة 3: نوع التبرع       │  3 بطاقات: مالي/عيني/خدمي
│                          │
├──────────────────────────┤
│  [══ تبرّع الآن ══]      │  زر كبير
└──────────────────────────┘
```

**تفاصيل كل خطوة:**

**الخطوة 1 — اختر الوجهة:**
```dart
// SegmentedButton لاختيار النوع
SegmentedButton<String>(
  segments: const [
    ButtonSegment(value: 'campaign', label: Text('حملة'), icon: Icon(Icons.campaign_outlined)),
    ButtonSegment(value: 'case', label: Text('حالة'), icon: Icon(Icons.volunteer_activism_outlined)),
  ],
  selected: {_targetType},
  onSelectionChanged: (v) => setState(() { _targetType = v.first; _selectedTarget = null; }),
)

// زر اختيار الهدف
ListTile(
  title: Text(_selectedTarget?.name ?? 'اختر ${_targetType == 'campaign' ? 'الحملة' : 'الحالة'}'),
  trailing: const Icon(Icons.arrow_drop_down),
  onTap: () => _showTargetPicker(context),
  // shape + border
)
```

`_showTargetPicker` يفتح `showModalBottomSheet` مع:
- `SearchBar` في الأعلى
- `FutureBuilder` على `CatalogRepository.campaigns(...)` أو `.cases(...)`
- `ListView` من العناصر — كل واحدة `ListTile` عند الضغط → `setState(() => _selectedTarget = item); Navigator.pop(context);`

**الخطوة 2 — المبلغ:**
```dart
// Chips للمبالغ السريعة
Wrap(
  spacing: 10,
  children: [10, 50, 100, 500].asMap().entries.map((e) =>
    ChoiceChip(
      label: Text('${e.value} ر.س'),
      selected: _selectedAmountIndex == e.key,
      onSelected: (_) => setState(() {
        _selectedAmountIndex = e.key;
        _amountController.text = '${e.value}';
      }),
    ),
  ).toList(),
)

// حقل مبلغ مخصص
TextField(
  controller: _amountController,
  keyboardType: TextInputType.number,
  decoration: InputDecoration(
    hintText: 'مبلغ آخر',
    suffixText: 'ر.س',
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  ),
  onChanged: (_) => setState(() => _selectedAmountIndex = null),
)
```

**الخطوة 3 — نوع التبرع:**
```dart
// 3 بطاقات اختيار
Column(
  children: [
    _typeCard('financial', Icons.payments, 'مالي', 'تحويل مبلغ مالي'),
    _typeCard('inKind', Icons.inventory_2, 'عيني', 'تبرع بأغراض ومواد'),
    _typeCard('service', Icons.engineering, 'خدمي', 'تقديم خدمة أو مهارة'),
  ],
)
```

**زر "تبرّع الآن":**
```dart
// في أسفل الشاشة (bottomNavigationBar أو آخر الـ ListView)
Padding(
  padding: const EdgeInsets.all(16),
  child: FilledButton(
    onPressed: _canSubmit ? _submit : null,
    style: FilledButton.styleFrom(
      backgroundColor: AppTheme.primary,
      foregroundColor: AppTheme.primaryForeground,
      minimumSize: const Size.fromHeight(56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    child: const Text('تبرّع الآن', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
  ),
)
```

`_canSubmit` = `_selectedTarget != null && _amountController.text.isNotEmpty`

`_submit` يوجّه لصفحة التبرع:
```dart
void _submit() {
  final target = _selectedTarget!;
  final route = _targetType == 'campaign'
      ? '/campaigns/${target.id}/donate'
      : '/cases/${target.id}/donate';
  context.push(route, extra: target);
}
```

---

### 2.4 حذف الملفات والروتات

**أ. احذف `lib/features/home/ui/explore_screen.dart`** — بالكامل.

**ب. احذف `lib/features/donations/ui/direct_donation_screen.dart`** — بالكامل.

**ج. `lib/core/router/app_router.dart`:**
- حوّل `/donate/direct` إلى redirect:
  ```dart
  GoRoute(path: '/donate/direct', redirect: (_, _) => '/home'),
  ```
- أزل import `direct_donation_screen.dart`.
- أبقِ كل الروتات الأخرى (`/campaigns`, `/cases`, `/charities`, etc.) — تُستخدم من "عرض الكل" ومن deep links.

---

### 2.5 `profile_screen.dart` — أضف السجلات الشخصية

**الملف:** `lib/features/profile/ui/profile_screen.dart`

أضف قسم "سجلاتي" **أعلى** قائمة إعدادات الحساب (بعد معلومات المستخدم مباشرة):

```dart
const SizedBox(height: 20),
Text('سجلاتي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: scheme.onSurface)),
const SizedBox(height: 10),
Card(
  child: Column(
    children: [
      ListTile(
        leading: CircleAvatar(backgroundColor: AppTheme.softOf(context), child: Icon(Icons.receipt_long, color: AppTheme.primary)),
        title: const Text('تبرعاتي', style: TextStyle(fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.arrow_back_ios_new, size: 14),
        onTap: () => context.push('/donations/history'),
      ),
      const Divider(height: 1),
      ListTile(
        leading: CircleAvatar(backgroundColor: AppTheme.softOf(context), child: Icon(Icons.card_giftcard, color: AppTheme.primary)),
        title: const Text('منافعي', style: TextStyle(fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.arrow_back_ios_new, size: 14),
        onTap: () => context.push('/benefits/my'),
      ),
      const Divider(height: 1),
      ListTile(
        leading: CircleAvatar(backgroundColor: AppTheme.softOf(context), child: Icon(Icons.support_agent, color: AppTheme.primary)),
        title: const Text('شكاواي', style: TextStyle(fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.arrow_back_ios_new, size: 14),
        onTap: () => context.push('/complaints/my'),
      ),
    ],
  ),
),
```

---

### 2.6 `catalog_detail_screen.dart` — زر تبرع واحد فقط

**الملف:** `lib/features/catalog/ui/catalog_detail_screen.dart`

1. اجعل زر "تبرع" في `Scaffold.bottomNavigationBar` فقط (sticky):
   ```dart
   bottomNavigationBar: Padding(
     padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
     child: FilledButton(
       style: FilledButton.styleFrom(
         backgroundColor: AppTheme.primary,
         foregroundColor: AppTheme.primaryForeground,
         minimumSize: const Size.fromHeight(56),
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
       ),
       onPressed: () { /* navigate to donate */ },
       child: const Text('تبرّع الآن', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
     ),
   ),
   ```
2. إذا كان هناك زر تبرع مكرر داخل الجسم — **احذفه**.

---

## 3. تحسينات (ليست حشو — كل واحدة ترفع الجودة)

### 3.1 Skeleton بدل Spinner

**أنشئ:** `lib/core/widgets/skeleton_card.dart`

```dart
class SkeletonCard extends StatefulWidget {
  const SkeletonCard({super.key, this.height = 160});
  final double height;
  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Container(
      height: widget.height,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3 + _ctrl.value * 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
}
```

**استبدل** كل `Center(child: CircularProgressIndicator())` في:
- `catalog_list_screen.dart`
- `charities_screen.dart`
- `donation_history_screen.dart`
بـ `Column(children: List.generate(4, (_) => const SkeletonCard()))`.

### 3.2 Dark Mode — ظلال

في كل الملفات التي تستخدم `Colors.black.withValues(alpha: 0.0X)`:
```dart
// استبدل:
color: Colors.black.withValues(alpha: 0.06)
// بـ:
color: isDark ? AppTheme.primary.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.06)
```

### 3.3 `donation_screen.dart` — تأكيد قبل الإرسال

قبل POST النهائي:
```dart
final ok = await showDialog<bool>(
  context: context,
  builder: (_) => AlertDialog(
    title: const Text('تأكيد التبرع'),
    content: Text('هل تريد التبرع بـ $amount ر.س؟'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع')),
      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد')),
    ],
  ),
);
if (ok != true) return;
```

---

## 4. Checklist (بالترتيب)

### المجموعة 1: الهيكل

- [ ] **A.** `home_shell.dart` — من 5 إلى 4 تبويبات (أزل استكشاف).
- [ ] **B.** احذف `explore_screen.dart`.
- [ ] **C.** احذف `direct_donation_screen.dart`.
- [ ] **D.** `app_router.dart` — `/donate/direct` → redirect `/home`.

```bash
flutter analyze
```

### المجموعة 2: الرئيسية

- [ ] **E.** `dashboard_screen.dart`:
  - احذف `_CharitiesSection`, `_HomeCharityTile`, `_HomeHelpCard`, `_EmptyHint`.
  - أضف `_QuickActions` (4 أزرار) و`_CharitiesPreview` (3 صفوف) و`_CharityRow`.
  - قلّص Campaigns/Cases إلى `.take(3)`.
  - غيّر عناوين الأقسام.
  - رتّب `ListView.children`: Banner → QuickActions → Campaigns → Cases → Charities.

```bash
flutter analyze
```

### المجموعة 3: التبرع + الحساب

- [ ] **F.** `quick_donate_screen.dart` — استبدل بالكامل بنموذج 3 خطوات.
- [ ] **G.** `profile_screen.dart` — أضف قسم "سجلاتي".
- [ ] **H.** `catalog_detail_screen.dart` — زر تبرع sticky bottom فقط.
- [ ] **I.** `donation_screen.dart` — حوار تأكيد.

```bash
flutter analyze
```

### المجموعة 4: تلميع

- [ ] **J.** أنشئ `skeleton_card.dart` واستبدل الـ spinners.
- [ ] **K.** أصلح ظلال dark mode.

```bash
flutter analyze
```

---

## 5. قواعد لـ Cursor

- لا تُنشئ features أو endpoints جديدة.
- لا تلمس `data/` و`logic/`.
- لا تحذف routes قائمة (`/campaigns`, `/cases`, `/charities`...) — تُستخدم من "عرض الكل" ومن deep links.
- `CharityDetailScreen` فيها بالفعل 4 تبويبات مدمجة — لا تلمسها.
- احترم ألوان `AppTheme` — لا ألوان حرفية.
- RTL تلقائي عبر `Locale('ar')` — لا تضف `Directionality`.
- بعد كل ملف: نظّف imports ميتة واحذف classes غير مستخدمة.
