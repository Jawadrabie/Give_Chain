import 'package:flutter/material.dart';

abstract final class ApiEnums {
  static const userType = {
    0: 'مستخدم عام',
    1: 'مستخدم جمعية',
    2: 'مستخدم نظام',
  };
  static const userStatus = {0: 'نشط', 1: 'غير نشط', 2: 'موقوف'};
  static const charityStatus = {0: 'نشطة', 1: 'موقوفة', 2: 'محذوفة'};
  static const gender = {0: 'ذكر', 1: 'أنثى'};
  static const campaignStatus = {
    0: 'قيد التخطيط',
    1: 'نشطة',
    2: 'متوقفة مؤقتًا',
    3: 'مكتملة',
    4: 'ملغاة',
  };
  static const caseStatus = {
    0: 'مفتوحة',
    1: 'قيد التنفيذ',
    2: 'تم الحل',
    3: 'مغلقة',
  };
  static const casePriority = {0: 'منخفضة', 1: 'عادية', 2: 'عالية', 3: 'عاجلة'};
  static const goalType = {1: 'مالي', 2: 'مواد', 3: 'متطوعون', 4: 'خدمات'};
  static const donationType = {1: 'مالي', 2: 'عيني', 3: 'خدمة'};
  static const donationStatus = {
    0: 'بانتظار الدفع',
    1: 'قيد المراجعة',
    2: 'استلمته الجمعية',
    3: 'موثّق ✓',
    4: 'مرفوض',
    5: 'فشل الدفع',
    6: 'بانتظار تأكيد المركز',
    7: 'تم الاستلام في المركز',
    8: 'سُلِّم للجمعية',
  };
  static const paymentMethod = {
    0: 'نقدي',
    1: 'تحويل بنكي',
  };
  static const paymentStatus = {
    0: 'غير مطبق',
    1: 'معلق',
    2: 'قيد المعالجة',
    3: 'مكتمل',
    4: 'فاشل',
    5: 'مسترد',
  };
  static const deliveryMethod = {1: 'تسليم للمقر', 2: 'توصيل', 3: 'إلكتروني'};
  static const unit = {
    0: 'مبلغ',
    1: 'كغ',
    2: 'غرام',
    3: 'قطعة',
    4: 'صندوق',
    5: 'ليتر',
    6: 'متر',
    7: 'حزمة',
  };
  static const benefitStatus = {0: 'قيد المراجعة', 1: 'مقبول', 2: 'مرفوض'};
  static const complaintType = {
    0: 'عامة',
    1: 'مالية',
    2: 'الموظفون',
    3: 'الخدمة',
    4: 'أخرى',
  };
  static const complaintSeverity = {
    0: 'منخفضة',
    1: 'متوسطة',
    2: 'عالية',
    3: 'حرجة',
  };
  static const complaintStatus = {
    0: 'مفتوحة',
    1: 'قيد المعالجة',
    2: 'تم الحل',
    3: 'مغلقة',
  };

  static Color statusColor(int value, {String family = ''}) {
    final positive = switch (family) {
      'donation' => const {3},
      'benefit' => const {1},
      'complaint' => const {2},
      'campaign' => const {1, 3},
      'case' => const {2},
      'casePriority' => const {0, 1},
      'charity' => const {0},
      _ => const <int>{},
    };
    final warning = switch (family) {
      'donation' => const {0, 1, 2, 6, 7, 8},
      'benefit' => const {0},
      'complaint' => const {0, 1},
      'campaign' => const {0, 2},
      'case' => const {0, 1},
      'casePriority' => const {2},
      'charity' => const {1},
      _ => const <int>{},
    };
    if (positive.contains(value)) return Colors.green;
    if (warning.contains(value)) return Colors.amber.shade800;
    return Colors.red;
  }
}
