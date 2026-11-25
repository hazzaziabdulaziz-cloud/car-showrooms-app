import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'core/analytics_and_accounting_service.dart';
import 'core/app_error_shield.dart';
import 'core/luxury_theme.dart';
import 'data/showroom_repository.dart';
import 'features/buyer/virtual_mall_screens.dart';
import 'features/partners/partners_portal_screen.dart';
import 'features/shared/legal_and_privacy_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  AppErrorShield.init();
  AnalyticsAndAccountingService.trackEvent(AnalyticsAndAccountingService.evAppOpen);
  runApp(const ShowroomPlatformApp());
}

class ShowroomPlatformApp extends StatefulWidget {
  const ShowroomPlatformApp({super.key});

  @override
  State<ShowroomPlatformApp> createState() => _ShowroomPlatformAppState();
}

class _ShowroomPlatformAppState extends State<ShowroomPlatformApp> {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  final ShowroomRepository _repository = ShowroomRepository();
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _handleInitialDeepLink();
  }

  Future<void> _handleInitialDeepLink() async {
    final segs = Uri.base.pathSegments;
    if (segs.length >= 2 && segs[0] == 'c' && segs[1].isNotEmpty) {
      final carId = segs[1];
      try {
        final doc = await FirebaseFirestore.instance.collection('cars').doc(carId).get();
        if (doc.exists && mounted) {
          final car = CarListingModel.fromDoc(doc);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _navKey.currentState?.push(MaterialPageRoute(builder: (_) => CarDetailsScreen(car: car)));
          });
        }
      } catch (_) {}
    }
  }

  Widget _buildNavSwitcher() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: LuxuryColors.navyLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LuxuryColors.gold.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _navTabItem(index: 0, label: 'المعارض'),
          const SizedBox(width: 4),
          _navTabItem(index: 1, label: 'الشركاء'),
        ],
      ),
    );
  }

  Widget _navTabItem({required int index, required String label}) {
    final isSelected = _currentTab == index;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _currentTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? LuxuryColors.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: isSelected ? LuxuryColors.navy : Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = GoogleFonts.ibmPlexSansArabic().fontFamily;

    return MaterialApp(
      navigatorKey: _navKey,
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
          primary: LuxuryColors.navy,
          onPrimary: Colors.white,
          secondary: LuxuryColors.gold,
          surface: LuxuryColors.surface,
          onSurface: LuxuryColors.textPrimary,
          error: LuxuryColors.danger,
        ),
        appBarTheme: const AppBarTheme(
          toolbarHeight: 62,
          backgroundColor: LuxuryColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: LuxuryColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          errorMaxLines: 3,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: LuxuryColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: LuxuryColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: LuxuryColors.gold, width: 1.5)),
        ),
      ),
      home: Builder(
        builder: (homeCtx) => Scaffold(
          appBar: AppBar(
            centerTitle: true,
            leading: IconButton(
              tooltip: 'الشروط وسياسة الخصوصية (PDPL)',
              icon: const Icon(Icons.policy_outlined, color: LuxuryColors.gold),
              onPressed: () => Navigator.of(homeCtx).push(
                MaterialPageRoute(builder: (_) => const LegalAndPrivacyScreen()),
              ),
            ),
            title: const Text('معرضي', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: LuxuryColors.gold)),
            actions: [_buildNavSwitcher()],
          ),
          body: _currentTab == 0
              ? RegionsHomeScreen(
                  repository: _repository,
                  onOpenPartnerPortal: () => setState(() => _currentTab = 1),
                )
              : PartnersPortalScreen(repository: _repository),
        ),
      ),
    );
  }
}
