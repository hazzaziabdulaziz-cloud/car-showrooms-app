import 'package:flutter/material.dart';
import '../../core/luxury_theme.dart';
import 'inspection_report_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/app_core.dart';
import '../../core/iban_validator.dart';
import '../../core/admin_config.dart';
import '../../data/showroom_repository.dart';

class PartnersPortalScreen extends StatefulWidget {
  final ShowroomRepository repository;
  const PartnersPortalScreen({super.key, required this.repository});

  @override
  State<PartnersPortalScreen> createState() => _PartnersPortalScreenState();
}

class _PartnersPortalScreenState extends State<PartnersPortalScreen> {
  final _authKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoginMode = true;
  bool _authLoading = false;

  int _roleTab = 0;
  String? _adminSelectedShowroomId;

  final _showroomKey = GlobalKey<FormState>();
  final _srNameCtrl = TextEditingController();
  final _srCrCtrl = TextEditingController();
  final _srAddressCtrl = TextEditingController();
  final _srPhoneCtrl = TextEditingController();
  final _srCustomHubCtrl = TextEditingController();
  final _srBankCtrl = TextEditingController(text: 'مصرف الراجحي');
  final _srIbanCtrl = TextEditingController();
  String _srRegionId = 'riyadh';
  String _srHub = 'معارض القادسية';
  int _locationMode = 0;
  bool _savingShowroom = false;

  final _carKey = GlobalKey<FormState>();
  final _makeCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController(text: '2026');
  final _priceCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController(text: 'بودي وكالة بالكامل');
  String _carCondition = 'new';
  String _carSpec = 'saudi';
  bool _savingCar = false;

  final _towKey = GlobalKey<FormState>();
  final _towNameCtrl = TextEditingController();
  final _towPhoneCtrl = TextEditingController();
  final _towBankCtrl = TextEditingController(text: 'مصرف الراجحي');
  final _towIbanCtrl = TextEditingController();
  String _towType = 'hydraulic';
  String _towRegionId = 'eastern';
  bool _acceptsBackhaul = true;
  bool _savingTow = false;
  final Set<String> _busyDocIds = {};
  String _towCurrentRegion = 'riyadh';
  bool _updatingTowLoc = false;

  final _inspKey = GlobalKey<FormState>();
  final _inspNameCtrl = TextEditingController();
  final _inspPhoneCtrl = TextEditingController();
  final _inspLicenseCtrl = TextEditingController();
  final _inspBankCtrl = TextEditingController(text: 'مصرف الراجحي');
  final _inspIbanCtrl = TextEditingController();
  String _inspRegionId = 'riyadh';
  String _inspSpecialty = 'فحص شامل (كمبيوتر + بودي + شاصي)';
  bool _savingInsp = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _srNameCtrl.dispose();
    _srCrCtrl.dispose();
    _srAddressCtrl.dispose();
    _srPhoneCtrl.dispose();
    _srCustomHubCtrl.dispose();
    _srBankCtrl.dispose();
    _srIbanCtrl.dispose();
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _priceCtrl.dispose();
    _bodyCtrl.dispose();
    _towNameCtrl.dispose();
    _towPhoneCtrl.dispose();
    _towBankCtrl.dispose();
    _towIbanCtrl.dispose();
    _inspNameCtrl.dispose();
    _inspPhoneCtrl.dispose();
    _inspLicenseCtrl.dispose();
    _inspBankCtrl.dispose();
    _inspIbanCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (!_authKey.currentState!.validate()) return;
    setState(() => _authLoading = true);
    try {
      if (_isLoginMode) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'user-not-found' || e.code == 'invalid-credential'
          ? 'البريد الإلكتروني أو كلمة المرور غير صحيحة.'
          : e.code == 'email-already-in-use'
              ? 'هذا البريد مسجل مسبقاً. اختر تسجيل الدخول.'
              : 'تعذر إتمام المصادقة: ${e.message ?? e.code}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _authLoading = false);
    }
  }

  Future<void> _submitShowroom() async {
    if (!_showroomKey.currentState!.validate()) return;
    setState(() => _savingShowroom = true);
    try {
      final finalHub = _locationMode == 0 ? _srHub : _srCustomHubCtrl.text.trim();
      await widget.repository.registerShowroom(
        commercialName: _srNameCtrl.text,
        crNumber: _srCrCtrl.text,
        regionId: _srRegionId,
        cityHub: finalHub,
        nationalAddress: _srAddressCtrl.text,
        contactPhone: _srPhoneCtrl.text,
        bankName: _srBankCtrl.text,
        iban: _srIbanCtrl.text,
      );
      if (!mounted) return;
      _srNameCtrl.clear();
      _srCrCtrl.clear();
      _srAddressCtrl.clear();
      _srPhoneCtrl.clear();
      _srCustomHubCtrl.clear();
      _srIbanCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم توثيق المعرض بنجاح. يمكنك الآن إضافة السيارات.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SafeErrorMapper.toUserMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _savingShowroom = false);
    }
  }

  Future<void> _submitCar(ShowroomModel myShowroom) async {
    if (!_carKey.currentState!.validate()) return;
    setState(() => _savingCar = true);
    try {
      await widget.repository.addCarToInventory(
        showroomId: myShowroom.id,
        showroomName: myShowroom.commercialName,
        regionId: myShowroom.regionId,
        cityHub: myShowroom.cityHub,
        make: _makeCtrl.text,
        model: _modelCtrl.text,
        year: int.parse(_yearCtrl.text.trim()),
        price: int.parse(_priceCtrl.text.trim()),
        condition: _carCondition,
        mileage: 0,
        bodyCondition: _bodyCtrl.text,
        specType: _carSpec,
        hasBackhaulTow: false,
      );
      if (!mounted) return;
      _makeCtrl.clear();
      _modelCtrl.clear();
      _priceCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم نشر السيارة داخل ${myShowroom.commercialName} بنجاح.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SafeErrorMapper.toUserMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _savingCar = false);
    }
  }

  Future<void> _submitTowDriver() async {
    if (!_towKey.currentState!.validate()) return;
    setState(() => _savingTow = true);
    try {
      await widget.repository.registerTowDriver(
        driverName: _towNameCtrl.text,
        phone: _towPhoneCtrl.text,
        truckType: _towType,
        primaryRegionId: _towRegionId,
        acceptsBackhaul: _acceptsBackhaul,
        bankName: _towBankCtrl.text,
        iban: _towIbanCtrl.text,
      );
      if (!mounted) return;
      _towNameCtrl.clear();
      _towPhoneCtrl.clear();
      _towIbanCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تفعيل حساب السطحة وربط الآيبان بنجاح.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SafeErrorMapper.toUserMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _savingTow = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final user = authSnap.data;
        if (user == null) {
          return _buildAuthView();
        }
        return _buildAuthenticatedPortal(user);
      },
    );
  }

  Widget _buildAuthView() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Form(
                key: _authKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLoginMode ? 'تسجيل دخول الشركاء' : 'إنشاء حساب شريك جديد',
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'حسابك يضمن خصوصية معرضك وعدم قدرة أي طرف آخر على التعديل أو الإضافة باسمك.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'البريد الإلكتروني الرسمي'),
                      validator: (v) => (v == null || !v.contains('@')) ? 'يرجى إدخال بريد إلكتروني صحيح.' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'كلمة المرور (6 خانات فأكثر)'),
                      validator: (v) => (v == null || v.length < 6) ? 'كلمة المرور يجب ألا تقل عن 6 أحرف.' : null,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                        onPressed: _authLoading ? null : _handleAuth,
                        child: Text(_authLoading
                            ? 'جاري التحقق...'
                            : (_isLoginMode ? 'دخول إلى لوحتي' : 'إنشاء الحساب والمتابعة')),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() => _isLoginMode = !_isLoginMode),
                        child: Text(_isLoginMode
                            ? 'ليس لديك حساب شريك؟ أنشئ حساباً جديداً'
                            : 'لديك حساب بالفعل؟ سجّل الدخول'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthenticatedPortal(User user) {
    final isAdmin = isAdminEmail(user.email);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text('الحساب النشط: ${user.email}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      if (isAdmin) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                          child: const Text('مدير النظام', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    icon: const Icon(Icons.logout, size: 16, color: AppColors.danger),
                    label: const Text('تسجيل الخروج', style: TextStyle(color: AppColors.danger)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _roleButton(0, isAdmin ? 'تسجيل معرض جديد' : 'إدارة معرضي'),
                  if (isAdmin) _roleButton(2, 'إضافة سيارة (لأي معرض)'),
                  _roleButton(3, 'صندوق الحجوزات'),
                  _roleButton(4, 'الفاحص المعتمد (تسجيل وطلبات)'),
                  _roleButton(1, 'حساب كابتن السطحة'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildLiveAlertsBar(),
            if (_roleTab == 0)
              isAdmin
                  ? _buildRegisterShowroomCard()
                  : StreamBuilder<ShowroomModel?>(
                      stream: widget.repository.watchMyShowroom(user.uid),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                          return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
                        }
                        final myShowroom = snap.data;
                        if (myShowroom == null) {
                          return _buildRegisterShowroomCard();
                        }
                        return _buildMyShowroomDashboard(myShowroom);
                      },
                    )
            else if (_roleTab == 2 && isAdmin)
              StreamBuilder<List<ShowroomModel>>(
                stream: widget.repository.watchShowrooms(),
                builder: (context, snap) {
                  final list = snap.data ?? const <ShowroomModel>[];
                  if (list.isEmpty) {
                    return const Center(child: Text('سجّل معرضاً أولاً من تبويب تسجيل معرض جديد.'));
                  }
                  if (_adminSelectedShowroomId == null || !list.any((e) => e.id == _adminSelectedShowroomId)) {
                    _adminSelectedShowroomId = list.first.id;
                  }
                  final selected = list.firstWhere((e) => e.id == _adminSelectedShowroomId);
                  return Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _adminSelectedShowroomId,
                        decoration: const InputDecoration(labelText: 'اختر أي معرض للتجربة (صلاحية المدير)'),
                        items: list
                            .map((sr) => DropdownMenuItem(
                                  value: sr.id,
                                  child: Text('${sr.commercialName} (${findRegion(sr.regionId).nameAr})'),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _adminSelectedShowroomId = v),
                      ),
                      const SizedBox(height: 16),
                      _buildMyShowroomDashboard(selected),
                    ],
                  );
                },
              )
            else if (_roleTab == 3)
              _buildOrdersInbox(isAdmin)
            else if (_roleTab == 4)
              _buildInspectorSection(isAdmin)
            else
              Column(children: [_buildTowLocationSwitchCard(), const SizedBox(height: 14), _buildTowTasksList(), const SizedBox(height: 18), _buildRegisterTowCard()]),
          ],
        ),
      ),
    );
  }

  Widget _roleButton(int index, String label) {
    final isSelected = _roleTab == index;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _roleTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.onPrimary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterShowroomCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Form(
        key: _showroomKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الخطوة 1: تسجيل وتوثيق معرضك', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('بعد التوثيق ستفتح لك لوحة إضافة سيارات معرضك تلقائياً.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _srNameCtrl,
                    decoration: const InputDecoration(labelText: 'الاسم التجاري للمعرض (اسم اللوحة)'),
                    validator: (v) => SecurityGuard.validateRequiredText(v, 'اسم المعرض'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _srCrCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'السجل التجاري أو الرقم الموحد (700)'),
                    validator: SecurityGuard.validateCrNumber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _srRegionId,
                    decoration: const InputDecoration(labelText: 'المنطقة'),
                    items: kSaudiRegions.map((r) => DropdownMenuItem(value: r.id, child: Text(r.nameAr))).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _srRegionId = v;
                          _srHub = findRegion(v).defaultHub;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _srAddressCtrl,
                    decoration: const InputDecoration(labelText: 'العنوان الوطني المختصر'),
                    validator: (v) => SecurityGuard.validateRequiredText(v, 'العنوان الوطني', min: 4, max: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _modeChip(0, 'الطريقة 1: اختيار من التقسيمات')),
                const SizedBox(width: 8),
                Expanded(child: _modeChip(1, 'الطريقة 2: إدخال المدينة/الحي يدوياً')),
              ],
            ),
            const SizedBox(height: 12),
            if (_locationMode == 0)
              DropdownButtonFormField<String>(
                key: ValueKey(_srRegionId),
                initialValue: _srHub,
                decoration: const InputDecoration(labelText: 'التجمع / المدينة المحددة'),
                items: findRegion(_srRegionId).hubs.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _srHub = v);
                },
              )
            else
              TextFormField(
                controller: _srCustomHubCtrl,
                decoration: const InputDecoration(labelText: 'اكتب المدينة أو الحي'),
                validator: (v) => SecurityGuard.validateRequiredText(v, 'المدينة أو الحي'),
              ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _srPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'رقم الجوال الرسمي للمعرض'),
              validator: (v) => SecurityGuard.validateRequiredText(v, 'رقم الجوال', min: 9, max: 15),
            ),
            const Divider(height: 28),
            const Text('بيانات الحساب البنكي الرسمي للمعرض (لتحويل المستحقات)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _srBankCtrl,
                    decoration: const InputDecoration(labelText: 'اسم البنك'),
                    validator: (v) => SecurityGuard.validateRequiredText(v, 'اسم البنك'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _srIbanCtrl,
                    decoration: const InputDecoration(labelText: 'رقم الآيبان الرسمي (SA + 22 رقماً)'),
                    validator: IbanValidator.validateSaudiIban,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: _savingShowroom ? null : _submitShowroom,
                child: Text(_savingShowroom ? 'جاري التوثيق...' : 'توثيق المعرض والانتقال لإضافة السيارات'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyShowroomDashboard(ShowroomModel myShowroom) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Form(
        key: _carKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(myShowroom.commercialName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    Text('${findRegion(myShowroom.regionId).nameAr} · ${myShowroom.cityHub}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(6)),
                  child: const Text('معرضك الموثق', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
                ),
              ],
            ),
            const Divider(height: 24),
            const Text('إضافة سيارة جديدة إلى صالة معرضك', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _makeCtrl,
                    decoration: const InputDecoration(labelText: 'الشركة (مثلاً: تويوتا)'),
                    validator: (v) => SecurityGuard.validateRequiredText(v, 'الشركة'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _modelCtrl,
                    decoration: const InputDecoration(labelText: 'الطراز (مثلاً: لاندكروزر GXR)'),
                    validator: (v) => SecurityGuard.validateRequiredText(v, 'الطراز'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _yearCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'سنة الصنع'),
                    validator: SecurityGuard.validateYear,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'السعر (ر.س)'),
                    validator: (v) => SecurityGuard.validatePositiveInt(v, 'السعر', min: 5000),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _carCondition,
                    decoration: const InputDecoration(labelText: 'الحالة'),
                    items: const [
                      DropdownMenuItem(value: 'new', child: Text('جديدة (أصفار)')),
                      DropdownMenuItem(value: 'used', child: Text('مستعملة')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _carCondition = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _carSpec,
                    decoration: const InputDecoration(labelText: 'الوارد'),
                    items: const [
                      DropdownMenuItem(value: 'saudi', child: Text('وارد سعودي')),
                      DropdownMenuItem(value: 'gulf', child: Text('وارد خليجي')),
                      DropdownMenuItem(value: 'us', child: Text('وارد أمريكي')),
                      DropdownMenuItem(value: 'korean', child: Text('وارد كوري')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _carSpec = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _bodyCtrl,
              decoration: const InputDecoration(labelText: 'حالة البودي المعلنة'),
              validator: (v) => SecurityGuard.validateRequiredText(v, 'حالة البودي'),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: _savingCar ? null : () => _submitCar(myShowroom),
                child: Text(_savingCar ? 'جاري النشر...' : 'نشر السيارة في معرضي وتوليد QR'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeChip(int mode, String label) {
    final isSelected = _locationMode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _locationMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }



  Widget _luxuryCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LuxuryColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LuxuryColors.border),
        boxShadow: [
          BoxShadow(
            color: LuxuryColors.navy.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }


  Widget _buildSubscriptionAndPolicyBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LuxuryColors.navy,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LuxuryColors.gold.withValues(alpha: 0.5)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium, color: LuxuryColors.gold, size: 20),
              SizedBox(width: 8),
              Text('باقة اشتراك المعرض وسياسة الأولوية', style: TextStyle(color: LuxuryColors.gold, fontWeight: FontWeight.w800, fontSize: 14)),
            ],
          ),
          SizedBox(height: 6),
          Text(
            '• الباقة الأساسية: 499 ر.س/شهرياً (حتى 25 سيارة) · الاحترافية: 999 ر.س/شهرياً (غير محدود + تثبيت).',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
          SizedBox(height: 4),
          Text(
            '• تنبيه مهم: يرجى تحديث مخزون سياراتك أولاً بأول؛ لأن كثرة رفض الطلبات أو التأخر عن مهلة الساعتين يخفض ترتيب ظهور معرضك أمام العملاء.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }


  Future _runSafeDocAction(String docId, Future Function() action) async {
    if (_busyDocIds.contains(docId)) return;
    setState(() => _busyDocIds.add(docId));
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تنفيذ العملية: $e')));
      }
    } finally {
      if (mounted) setState(() => _busyDocIds.remove(docId));
    }
  }

  Widget _buildLiveAlertsBar() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        int waitingShowroom = 0;
        int waitingInspector = 0;
        int waitingTow = 0;
        for (final d in docs) {
          final m = d.data();
          if (m['status'] == 'paid_waiting_showroom') waitingShowroom++;
          if (m['inspection_status'] == 'pending_inspector') waitingInspector++;
          if (m['shipping_status'] == 'pending_tow') waitingTow++;
        }
        if (waitingShowroom == 0 && waitingInspector == 0 && waitingTow == 0) {
          return const SizedBox.shrink();
        }
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: LuxuryColors.danger.withValues(alpha: 0.45)),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.notifications_active, color: LuxuryColors.danger, size: 20),
              const Text('تنبيهات فورية:', style: TextStyle(fontWeight: FontWeight.w800, color: LuxuryColors.navy, fontSize: 13)),
              if (waitingShowroom > 0)
                ActionChip(
                  backgroundColor: LuxuryColors.navy,
                  label: Text('حجوزات جديدة ($waitingShowroom)', style: const TextStyle(color: LuxuryColors.gold, fontWeight: FontWeight.w800, fontSize: 12)),
                  onPressed: () => setState(() => _roleTab = 3),
                ),
              if (waitingInspector > 0)
                ActionChip(
                  backgroundColor: LuxuryColors.gold,
                  label: Text('طلبات فحص فوري ($waitingInspector)', style: const TextStyle(color: LuxuryColors.navy, fontWeight: FontWeight.w800, fontSize: 12)),
                  onPressed: () => setState(() => _roleTab = 4),
                ),
              if (waitingTow > 0)
                ActionChip(
                  backgroundColor: LuxuryColors.success,
                  label: Text('طلبات سطحة جديدة ($waitingTow)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                  onPressed: () => setState(() => _roleTab = 1),
                ),
            ],
          ),
        );
      },
    );
  }


  static const _saudiBanks = [
    'مصرف الراجحي', 'البنك الأهلي السعودي (SNB)', 'بنك الرياض',
    'مصرف الإنماء', 'بنك البلاد', 'البنك السعودي الأول (SAB)',
    'البنك السعودي الفرنسي (BSF)', 'البنك العربي الوطني (ANB)',
    'بنك الجزيرة', 'البنك السعودي للاستثمار (SAIB)', 'بنك الخليج الدولي (ميم)',
    'بنك STC (stc bank)', 'بنك D360', 'بنك فيجن (Vision Bank)', 'بنك آخر',
  ];

  Widget _bankDropdown(TextEditingController ctrl, String label) {
    final current = _saudiBanks.contains(ctrl.text) ? ctrl.text : _saudiBanks.first;
    if (ctrl.text.isEmpty) ctrl.text = current;
    return DropdownButtonFormField<String>(
      initialValue: current,
      isExpanded: true,
      decoration: luxuryInput(label, icon: Icons.account_balance_outlined),
      items: _saudiBanks
          .map((b) => DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => ctrl.text = v);
      },
    );
  }

  Widget _buildOrdersInbox(bool isAdmin) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').orderBy('created_at', descending: true).limit(30).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
        }
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return _luxuryCard(
            child: const Center(
              child: Text('لا توجد حجوزات مدفوعة حالياً. جرّب حجز سيارة من الشاشة الرئيسية لتظهر هنا فوراً.', style: TextStyle(color: LuxuryColors.textSecondary)),
            ),
          );
        }
        return Column(
          children: [
            _buildSubscriptionAndPolicyBanner(),
            ...docs.map((doc) {
            final d = (doc.data() as Map?) ?? {};
            final status = (d['status'] ?? 'paid_waiting_showroom').toString();
            final isConfirmed = status == 'confirmed';
            final isCompleted = status == 'completed';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _luxuryCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${d['order_code'] ?? ''} · ${d['car_title'] ?? ''}', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCompleted ? LuxuryColors.successBg : (isConfirmed ? LuxuryColors.goldSoft : const Color(0xFFFEF3F2)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isCompleted ? 'مكتمل (تم التسليم)' : (status == 'sold_in_showroom_refunded' ? 'انباعت في الصالة (استُرجع العربون)' : (isConfirmed ? 'تم تأكيد التوفر' : 'بانتظار رد المعرض (مهلة ساعتين)')),
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: isCompleted ? LuxuryColors.success : LuxuryColors.navy),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('المشتري: ${d['buyer_name']} · الجوال: ${d['buyer_phone']} · المدينة: ${d['buyer_city']}', style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('المعرض: ${d['showroom_name']} · الدفع: ${d['payment_method']} · العربون المدفوع في الضمان: ${d['total_paid']} ر.س', style: const TextStyle(fontSize: 12.5, color: LuxuryColors.textSecondary)),
                    if (isAdmin) ...[
                      const SizedBox(height: 4),
                      Text('كود التسليم السري (للمدير للتجربة): ${d['handover_pin'] ?? '---'}', style: const TextStyle(fontSize: 12, color: LuxuryColors.gold, fontWeight: FontWeight.w700)),
                    ],
                    const Divider(height: 20),
                    Row(
                      children: [
                        if (status == 'paid_waiting_showroom') ...[
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: LuxuryColors.navy),
                            onPressed: _busyDocIds.contains(doc.id) ? null : () => _runSafeDocAction(doc.id, () => doc.reference.update({'status': 'confirmed'})),
                            child: const Text('تأكيد التوفر وتجميد السيارة'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(foregroundColor: LuxuryColors.danger, side: const BorderSide(color: LuxuryColors.danger)),
                            onPressed: _busyDocIds.contains(doc.id) ? null : () => _runSafeDocAction(doc.id, () => doc.reference.update({'status': 'sold_in_showroom_refunded'})),
                            child: const Text('انباعت في الصالة (استرجاع العربون)'),
                          ),
                        ],
                        if ((isConfirmed || status == 'path_selected') && d['invoice_issued'] != true && !isCompleted) ...[
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(foregroundColor: LuxuryColors.navy, side: const BorderSide(color: LuxuryColors.navy)),
                            onPressed: () {
                              final price = (d['car_price'] is num) ? (d['car_price'] as num).round() : 0;
                              final dep = (d['reservation_fee'] is num) ? (d['reservation_fee'] as num).round() : 0;
                              doc.reference.update({
                                'invoice_issued': true,
                                'remaining_amount': price > dep ? (price - dep) : price,
                                'showroom_bank': 'الحساب التجاري المعتمد للمعرض',
                                'showroom_iban': 'SA-REGISTERED-SHOWROOM-IBAN',
                              });
                            },
                            child: const Text('إصدار فاتورة المبايعة (بالآيبان المسجل)'),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if ((isConfirmed || status == 'path_selected') && !isCompleted) ...[
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: LuxuryColors.gold, foregroundColor: LuxuryColors.navy),
                            onPressed: () => _promptPinAndComplete(doc.reference, (d['handover_pin'] ?? '').toString()),
                            child: const Text('إدخال كود التسليم وإغلاق الصفقة', style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          ],
        );
      },
    );
  }

  Future<void> _promptPinAndComplete(DocumentReference ref, String expectedPin) async {
    final pinCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد التسليم وإطلاق الضمان'),
        content: TextField(
          controller: pinCtrl,
          keyboardType: TextInputType.number,
          decoration: luxuryInput('أدخل كود التسليم (4 أرقام) من العميل'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: LuxuryColors.navy),
            onPressed: () => Navigator.pop(ctx, pinCtrl.text.trim() == expectedPin),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.update({'status': 'completed'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: LuxuryColors.success, content: Text('تم التحقق من الكود وإغلاق الصفقة بنجاح.')),
        );
      }
    } else if (ok == false && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كود التسليم غير صحيح.')),
      );
    }
  }


  Future<void> _submitInspector() async {
    if (!_inspKey.currentState!.validate()) return;
    setState(() => _savingInsp = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      await FirebaseFirestore.instance.collection('inspectors').add({
        'owner_uid': uid,
        'full_name': _inspNameCtrl.text.trim(),
        'phone': _inspPhoneCtrl.text.trim(),
        'license_or_id': _inspLicenseCtrl.text.trim(),
        'region_id': _inspRegionId,
        'specialty': _inspSpecialty,
        'bank_name': _inspBankCtrl.text.trim(),
        'iban': _inspIbanCtrl.text.trim().toUpperCase(),
        'is_verified': false,
        'status': 'pending_review',
        'created_at': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      _inspNameCtrl.clear();
      _inspPhoneCtrl.clear();
      _inspLicenseCtrl.clear();
      _inspIbanCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: LuxuryColors.success, content: Text('تم إرسال طلب تسجيل الفاحص للمراجعة والتوثيق بنجاح.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر التسجيل: $e')));
    } finally {
      if (mounted) setState(() => _savingInsp = false);
    }
  }

  Widget _buildInspectorSection(bool isAdmin) {
    return Column(
      children: [
        _luxuryCard(
          child: Form(
            key: _inspKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('تسجيل فاحص سيارات مستقل ومعتمد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
                const SizedBox(height: 4),
                const Text('يخضع كل فاحص لمراجعة وتوثيق إدارة معرضي قبل استقبال طلبات الفحص المدفوعة.', style: TextStyle(fontSize: 12.5, color: LuxuryColors.textSecondary)),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _inspNameCtrl, decoration: luxuryInput('الاسم الكامل / اسم المركز'), validator: (v) => SecurityGuard.validateRequiredText(v, 'الاسم'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _inspPhoneCtrl, keyboardType: TextInputType.phone, decoration: luxuryInput('رقم الجوال الرسمي'), validator: (v) => SecurityGuard.validateRequiredText(v, 'رقم الجوال', min: 9, max: 15))),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _inspLicenseCtrl, decoration: luxuryInput('رقم رخصة العمل الحر / السجل / الشهادة'), validator: (v) => SecurityGuard.validateRequiredText(v, 'رقم الرخصة أو الشهادة', min: 4, max: 20))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _inspRegionId,
                        decoration: luxuryInput('منطقة التغطية'),
                        items: kSaudiRegions.map((r) => DropdownMenuItem(value: r.id, child: Text(r.nameAr))).toList(),
                        onChanged: (v) { if (v != null) setState(() => _inspRegionId = v); },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _inspSpecialty,
                  decoration: luxuryInput('تخصص الفحص'),
                  items: const [
                    DropdownMenuItem(value: 'فحص شامل (كمبيوتر + بودي + شاصي)', child: Text('فحص شامل (كمبيوتر + بودي + شاصي)')),
                    DropdownMenuItem(value: 'فحص سيارات فاخرة وأوروبية', child: Text('فحص سيارات فاخرة وأوروبية')),
                    DropdownMenuItem(value: 'فحص ميداني متنقل داخل المعارض', child: Text('فحص ميداني متنقل داخل المعارض')),
                  ],
                  onChanged: (v) { if (v != null) setState(() => _inspSpecialty = v); },
                ),
                const Divider(height: 28),
                Row(
                  children: [
                    Expanded(child: _bankDropdown(_inspBankCtrl, 'اسم البنك')),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: TextFormField(controller: _inspIbanCtrl, decoration: luxuryInput('الآيبان لتحويل أتعاب الفحص (SA + 22 رقماً)'), validator: IbanValidator.validateSaudiIban)),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: LuxuryColors.navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: _savingInsp ? null : _submitInspector,
                    child: Text(_savingInsp ? 'جاري الإرسال...' : 'إرسال طلب التوثيق كفاحص معتمد', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildInspectorTasksList(),
        if (isAdmin) ...[
          const SizedBox(height: 20),
          _buildAdminInspectorsVerificationList(),
        ],
      ],
    );
  }


  Widget _buildInspectorTasksList() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('orders').where('inspection_status', isEqualTo: 'pending_inspector').snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        return _luxuryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('مهام الفحص الواردة (حصة الفاحص: 200 ر.س · حصة معرضي: 50 ر.س)', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
              const Divider(height: 20),
              if (docs.isEmpty)
                const Text('لا توجد طلبات فحص بانتظار التقرير حالياً.', style: TextStyle(color: LuxuryColors.textSecondary))
              else
                ...docs.map((doc) {
                  final d = doc.data();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: LuxuryColors.background, borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${d['order_code']} · ${d['car_title']}', style: const TextStyle(fontWeight: FontWeight.w800, color: LuxuryColors.navy, fontSize: 14.5)),
                        const SizedBox(height: 4),
                        Text('المعرض: ${d['showroom_name'] ?? '-'} · المنطقة: ${findRegion((d['region_id'] ?? 'riyadh').toString()).nameAr}', style: const TextStyle(fontSize: 12.5, color: LuxuryColors.textSecondary)),
                        Text('المشتري: ${d['buyer_name'] ?? '-'} · الجوال: ${d['buyer_phone'] ?? '-'} · حصة الفاحص: 200 ر.س (تُحجز 48 ساعة)', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: LuxuryColors.navy)),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: LuxuryColors.navy, foregroundColor: LuxuryColors.gold),
                          onPressed: () => InspectionReportSheet.show(
                            context,
                            orderRef: doc.reference,
                            orderCode: (d['order_code'] ?? '').toString(),
                            carTitle: (d['car_title'] ?? '').toString(),
                          ),
                          icon: const Icon(Icons.assignment_outlined, size: 18),
                          label: const Text('فتح نموذج التقرير الرسمي + تعهد الأمانة', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdminInspectorsVerificationList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('inspectors').orderBy('created_at', descending: true).limit(30).snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        return _luxuryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('لوحة المدير: التحقق وتوثيق الفاحصين', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
              const SizedBox(height: 4),
              const Text('راجع رخصة الفاحص واضغط اعتماد لتفعيل حسابه في النظام.', style: TextStyle(fontSize: 12.5, color: LuxuryColors.textSecondary)),
              const Divider(height: 22),
              if (docs.isEmpty)
                const Text('لا يوجد فاحصون مسجلون حالياً.', style: TextStyle(color: LuxuryColors.textSecondary))
              else
                ...docs.map((doc) {
                  final d = (doc.data() as Map?) ?? {};
                  final verified = d['is_verified'] == true;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: LuxuryColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: verified ? LuxuryColors.success.withValues(alpha: 0.4) : LuxuryColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${d['full_name'] ?? ''} · ${d['phone'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
                              const SizedBox(height: 2),
                              Text('الرخصة/السجل: ${d['license_or_id'] ?? ''} · ${d['specialty'] ?? ''}', style: const TextStyle(fontSize: 12, color: LuxuryColors.textSecondary)),
                            ],
                          ),
                        ),
                        if (verified)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: LuxuryColors.successBg, borderRadius: BorderRadius.circular(8)),
                            child: const Text('فاحص موثق ✓', style: TextStyle(color: LuxuryColors.success, fontWeight: FontWeight.w800, fontSize: 12)),
                          )
                        else
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: LuxuryColors.gold, foregroundColor: LuxuryColors.navy),
                            onPressed: _busyDocIds.contains(doc.id) ? null : () => _runSafeDocAction(doc.id, () => doc.reference.update({'is_verified': true, 'status': 'verified'})),
                            child: const Text('اعتماد وتوثيق', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                          ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }


  Future _acceptTowWithPledge(DocumentReference orderRef, String orderCode, String carTitle) async {
    bool agreed = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تعهد سلامة النقل والمسؤولية', style: TextStyle(fontWeight: FontWeight.w800, color: LuxuryColors.navy, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الطلب: $orderCode · $carTitle', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: LuxuryColors.goldSoft, borderRadius: BorderRadius.circular(10)),
                child: CheckboxListTile(
                  value: agreed,
                  activeColor: LuxuryColors.navy,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'أتعهد أمام الله ثم أمام منصة «معرضي» بمعاينة السيارة وتصويرها 4 صور واضحة (أمام، خلف، يمين، يسار) قبل التحميل، وأقرّ بأن «معرضي» وسيط تقني فقط، وأتحمل كامل المسؤولية النظامية والمالية عن أي ضرر أو خدش أو حادث يحدث للسيارة أثناء التحميل والنقل وحتى تسليمها للمشتري.',
                    style: TextStyle(fontSize: 12, height: 1.45, fontWeight: FontWeight.w600),
                  ),
                  onChanged: (v) => setDlgState(() => agreed = v ?? false),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: LuxuryColors.navy),
              onPressed: agreed ? () => Navigator.pop(ctx, true) : null,
              child: const Text('أوافق وأقبل الرحلة'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await orderRef.update({
        'shipping_status': 'in_transit',
        'tow_pledge_accepted': true,
        'tow_pledge_text': 'تعهد صاحب السطحة بتحمل كامل المسؤولية عن أي ضرر أثناء التحميل والنقل.',
        'tow_pledge_at': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: LuxuryColors.success, content: Text('تم قبول الرحلة وتقييد تعهد سلامة النقل بنجاح.')),
        );
      }
    }
  }


  Future _updateTowCurrentLocation() async {
    setState(() => _updatingTowLoc = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'demo_tow';
      await FirebaseFirestore.instance.collection('tow_drivers').doc(uid).set({
        'owner_uid': uid,
        'current_region_id': _towCurrentRegion,
        'current_region_name': findRegion(_towCurrentRegion).nameAr,
        'is_available': true,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: LuxuryColors.success, content: Text('تم تحديث موقعك الحالي إلى: ${findRegion(_towCurrentRegion).nameAr} (جاهز لاستقبال الطلبات)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر التحديث: $e')));
    } finally {
      if (mounted) setState(() => _updatingTowLoc = false);
    }
  }

  Widget _buildTowLocationSwitchCard() {
    return _luxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.my_location, color: LuxuryColors.gold, size: 20),
              SizedBox(width: 8),
              Text('مدينتك / منطقتك الحالية لاستقبال الطلبات', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('حدّد المنطقة التي تتواجد فيها الآن، ويمكنك تغييرها في كل مرة تدخل فيها للتطبيق.', style: TextStyle(fontSize: 12, color: LuxuryColors.textSecondary)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _towCurrentRegion,
                  decoration: luxuryInput('المنطقة الحالية'),
                  items: kSaudiRegions.map((r) => DropdownMenuItem(value: r.id, child: Text(r.nameAr))).toList(),
                  onChanged: (v) { if (v != null) setState(() => _towCurrentRegion = v); },
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: LuxuryColors.navy, foregroundColor: LuxuryColors.gold, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16)),
                onPressed: _updatingTowLoc ? null : _updateTowCurrentLocation,
                child: Text(_updatingTowLoc ? 'جاري التحديث...' : 'تحديث موقعي', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTowTasksList() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('orders').where('shipping_status', whereIn: ['pending_tow', 'in_transit']).snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        return _luxuryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('رحلات الشحن الواردة (حصة السطحة 90% · حصة معرضي 10%)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
              const Divider(height: 18),
              if (docs.isEmpty)
                const Text('لا توجد رحلات شحن جديدة حالياً.', style: TextStyle(color: LuxuryColors.textSecondary))
              else
                ...docs.map((doc) {
                  final d = doc.data();
                  final st = (d['shipping_status'] ?? '').toString();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: LuxuryColors.background, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${d['order_code']} · ${d['car_title']}', style: const TextStyle(fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
                              Text('التحميل من: ${d['showroom_name'] ?? '-'} (${findRegion((d['region_id'] ?? 'riyadh').toString()).nameAr}) ← التسليم إلى: ${d['buyer_city'] ?? '-'}', style: const TextStyle(fontSize: 12.5, color: LuxuryColors.textSecondary)),
                              Text('المشتري: ${d['buyer_name'] ?? '-'} · الجوال: ${d['buyer_phone'] ?? '-'} · حصتك (90%): ${d['tow_driver_share'] ?? 585} ر.س', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: LuxuryColors.navy)),
                            ],
                          ),
                        ),
                        if (st == 'pending_tow')
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: LuxuryColors.navy, foregroundColor: LuxuryColors.gold),
                            onPressed: () => _acceptTowWithPledge(doc.reference, (d['order_code'] ?? '').toString(), (d['car_title'] ?? '').toString()),
                            child: const Text('قبول الرحلة + التعهد', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          )
                        else
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: LuxuryColors.success),
                            onPressed: _busyDocIds.contains(doc.id) ? null : () => _runSafeDocAction(doc.id, () => doc.reference.update({'shipping_status': 'delivered'})),
                            child: const Text('تأكيد التسليم ✓', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRegisterTowCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Form(
        key: _towKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تسجيل كابتن سطحة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('التسجيل مجاني — عمولة المنصة 10% فقط لكل رحلة.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _towNameCtrl,
                    decoration: const InputDecoration(labelText: 'الاسم الكامل'),
                    validator: (v) => SecurityGuard.validateRequiredText(v, 'الاسم'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _towPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'رقم الجوال'),
                    validator: (v) => SecurityGuard.validateRequiredText(v, 'رقم الجوال', min: 9, max: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _towType,
                    decoration: const InputDecoration(labelText: 'نوع السطحة'),
                    items: const [
                      DropdownMenuItem(value: 'hydraulic', child: Text('سطحة هيدروليك')),
                      DropdownMenuItem(value: 'standard', child: Text('سطحة عادية')),
                      DropdownMenuItem(value: 'enclosed', child: Text('سطحة مغلقة (فاخرة)')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _towType = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _towRegionId,
                    decoration: const InputDecoration(labelText: 'المنطقة الأساسية'),
                    items: kSaudiRegions.map((r) => DropdownMenuItem(value: r.id, child: Text(r.nameAr))).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _towRegionId = v);
                    },
                  ),
                ),
              ],
            ),
            const Divider(height: 26),
            Row(
              children: [
                Expanded(
                  child: _bankDropdown(_towBankCtrl, 'اسم البنك'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _towIbanCtrl,
                    decoration: const InputDecoration(labelText: 'رقم الآيبان الرسمي (SA + 22 رقماً)'),
                    validator: IbanValidator.validateSaudiIban,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _acceptsBackhaul,
              onChanged: (v) => setState(() => _acceptsBackhaul = v ?? true),
              title: const Text('استقبال طلبات خط الرجعة (خصم 30% للعميل بدلاً من العودة فارغاً)'),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: _savingTow ? null : _submitTowDriver,
                child: Text(_savingTow ? 'جاري التسجيل...' : 'تفعيل حساب السطحة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}