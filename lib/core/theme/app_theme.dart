import 'package:flutter/material.dart';

/// ألوان وواجهة GiveChain حسب ملف التصميم (GiveChain UI.txt).
abstract final class AppTheme {
  static const primary = Color(0xFF2B90EC);
  static const primaryLight = Color(0xFF58A8F0);
  static const primaryDark = Color(0xFF1477D8);
  static const primaryForeground = Color(0xFFFAFAF7);

  static const background = Color(0xFFFFFFFF);
  static const darkBackground = Color(0xFF020817);
  static const text = Color(0xFF020817);
  static const darkText = Color(0xFFF8FAFC);
  static const border = Color(0xFFE4E8EE);
  static const darkBorder = Color(0xFF1F2933);

  /// سطح ثانوي فاتح مشتق من الـ Primary.
  static const soft = Color(0xFFE8F3FC);
  static const darkSoft = Color(0xFF10213A);
  static const darkSurface = Color(0xFF0F172A);
  static const darkSurfaceHighest = Color(0xFF172033);
  static const darkInput = Color(0xFF111827);

  static const danger = Color(0xFFDC2626);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF0EA5E9);

  /// توافق مع الشاشات القديمة التي كانت تستخدم لون تبرع منفصل.
  static const donate = primaryDark;

  static const radius = 8.0;

  /// نصف قطر حواف القوائم المنسدلة (أنعم من حقول الإدخال).
  static const menuRadius = 14.0;

  static Color softOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSoft : soft;

  static Color warningSurfaceOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF3A2E0A)
      : const Color(0xFFFFFBEB);

  static Color successSurfaceOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF0F2A1A)
      : const Color(0xFFF0FDF4);

  static Color campaignOf(BuildContext context, Color lightPastel) {
    if (Theme.of(context).brightness != Brightness.dark) return lightPastel;
    return Color.alphaBlend(
      lightPastel.withValues(alpha: 0.14),
      darkSurface,
    );
  }

  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: primary,
      onPrimary: primaryForeground,
      primaryContainer: soft,
      onPrimaryContainer: text,
      surface: background,
      onSurface: text,
      outline: border,
      secondaryContainer: soft,
      onSecondaryContainer: text,
      surfaceContainerHighest: Color(0xFFF1F5F9),
      error: danger,
    );
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Cairo',
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        toolbarHeight: 52,
        titleSpacing: 16,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: background,
        foregroundColor: text,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          fontFamily: 'Cairo',
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: danger),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 44),
          backgroundColor: primary,
          foregroundColor: primaryForeground,
          disabledBackgroundColor: border,
          disabledForegroundColor: text.withValues(alpha: 0.38),
          shape: rounded,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 44),
          foregroundColor: primary,
          shape: rounded,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(
        color: background,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: soft,
        selectedColor: primary.withValues(alpha: 0.16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        side: BorderSide.none,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: text),
        secondaryLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 62,
        backgroundColor: background,
        indicatorColor: soft,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 10,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w900
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? primary
                : text.withValues(alpha: 0.62),
          ),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: text,
        indicatorColor: primary,
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontSize: 12),
        labelPadding: EdgeInsets.symmetric(horizontal: 8),
        indicatorSize: TabBarIndicatorSize.label,
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(background),
          elevation: const WidgetStatePropertyAll(8),
          shadowColor: WidgetStatePropertyAll(
            Colors.black.withValues(alpha: 0.14),
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(menuRadius),
              side: const BorderSide(color: border),
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 6),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: background,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.14),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(menuRadius),
          side: const BorderSide(color: border),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(background),
          elevation: const WidgetStatePropertyAll(8),
          shadowColor: WidgetStatePropertyAll(
            Colors.black.withValues(alpha: 0.14),
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(menuRadius),
              side: const BorderSide(color: border),
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 6),
          ),
        ),
      ),
    );
  }

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: primaryLight,
      onPrimary: darkBackground,
      primaryContainer: darkSoft,
      onPrimaryContainer: darkText,
      surface: darkSurface,
      onSurface: darkText,
      outline: darkBorder,
      secondaryContainer: darkSoft,
      onSecondaryContainer: darkText,
      surfaceContainerHighest: darkSurfaceHighest,
      error: danger,
    );
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: darkBackground,
      fontFamily: 'Cairo',
      appBarTheme: const AppBarTheme(
        toolbarHeight: 52,
        titleSpacing: 16,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: darkBackground,
        foregroundColor: darkText,
        titleTextStyle: TextStyle(
          color: darkText,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          fontFamily: 'Cairo',
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkInput,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: primaryLight, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: danger),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 44),
          backgroundColor: primary,
          foregroundColor: primaryForeground,
          disabledBackgroundColor: darkBorder,
          disabledForegroundColor: darkText.withValues(alpha: 0.38),
          shape: rounded,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 44),
          foregroundColor: primaryLight,
          shape: rounded,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryLight,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSoft,
        selectedColor: primary.withValues(alpha: 0.24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        side: BorderSide.none,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          color: darkText,
        ),
        secondaryLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          color: darkText,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 62,
        backgroundColor: darkSurface,
        indicatorColor: primary.withValues(alpha: 0.24),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 10,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w900
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? primaryLight
                : darkText.withValues(alpha: 0.72),
          ),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: primaryLight,
        unselectedLabelColor: darkText,
        indicatorColor: primaryLight,
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontSize: 12),
        labelPadding: EdgeInsets.symmetric(horizontal: 8),
        indicatorSize: TabBarIndicatorSize.label,
      ),
      dividerTheme: const DividerThemeData(color: darkBorder, thickness: 1),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(darkSurface),
          elevation: const WidgetStatePropertyAll(8),
          shadowColor: WidgetStatePropertyAll(
            Colors.black.withValues(alpha: 0.45),
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(menuRadius),
              side: const BorderSide(color: darkBorder),
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 6),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: darkSurface,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.45),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(menuRadius),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(darkSurface),
          elevation: const WidgetStatePropertyAll(8),
          shadowColor: WidgetStatePropertyAll(
            Colors.black.withValues(alpha: 0.45),
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(menuRadius),
              side: const BorderSide(color: darkBorder),
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 6),
          ),
        ),
      ),
    );
  }
}
