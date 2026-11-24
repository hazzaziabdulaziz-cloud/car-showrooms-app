import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'core/app_core.dart';
import 'core/luxury_theme.dart';
import 'data/showroom_repository.dart';
import 'features/buyer/virtual_mall_screens.dart';
import 'features/partners/partners_portal_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ShowroomPlatformApp());
}

class ShowroomPlatformApp extends StatefulWidget {
  const ShowroomPlatformApp({super.key});

  @override
  State<ShowroomPlatformApp> createState() => _ShowroomPlatformAppState();
}

class _ShowroomPlatformAppState extends State<ShowroomPlatformApp> {
  int _currentTab = 0;
  final ShowroomRepository _repository = ShowroomRepository();

  Widget _buildNavSwitcher() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _navTabItem(index: 0, label: 'المناطق والمعارض'),
          const SizedBox(width: 4),
          _navTabItem(index: 1, label: 'بوابة الشركاء'),
        ],
      ),
    );
  }

  Widget _navTabItem({required int index, required String label}) {
    final isSelected = _currentTab == index;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => setState(() => _currentTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.onPrimary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = GoogleFonts.ibmPlexSansArabic().fontFamily;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'معرضي',
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: fontFamily,
        scaffoldBackgroundColor: LuxuryColors.background,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          secondary: AppColors.textSecondary,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          error: AppColors.danger,
        ),
        appBarTheme: const AppBarTheme(
          toolbarHeight: 60,
          backgroundColor: LuxuryColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          shape: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), errorMaxLines: 3,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('معرضي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          actions: [_buildNavSwitcher()],
        ),
        body: _currentTab == 0
            ? RegionsHomeScreen(
                repository: _repository,
                onOpenPartnerPortal: () => setState(() => _currentTab = 1),
              )
            : PartnersPortalScreen(repository: _repository),
      ),
    );
  }
}
