import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const CarShowroomsApp());
}

class CarShowroomsApp extends StatelessWidget {
  const CarShowroomsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'معارض السيارات السعودية',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D47A1)),
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const BuyerHomeScreen(),
    );
  }
}

// إحداثيات المناطق لحساب مسافة وتكلفة السطحة مجاناً (0 ريال بدون Google Maps API)
const Map<String, Map<String, dynamic>> kRegionsData = {
  'all': {'name': 'كل مناطق المملكة (13)', 'lat': 24.7136, 'lng': 46.6753},
  'riyadh': {'name': 'منطقة الرياض', 'lat': 24.7136, 'lng': 46.6753},
  'eastern': {'name': 'المنطقة الشرقية', 'lat': 26.4207, 'lng': 50.0888},
  'makkah': {'name': 'منطقة مكة المكرمة', 'lat': 21.4858, 'lng': 39.1925},
  'madinah': {'name': 'منطقة المدينة المنورة', 'lat': 24.5247, 'lng': 39.5692},
  'qassim': {'name': 'منطقة القصيم', 'lat': 26.3260, 'lng': 43.9750},
  'asir': {'name': 'منطقة عسير', 'lat': 18.2465, 'lng': 42.5117},
  'tabuk': {'name': 'منطقة تبوك', 'lat': 28.3835, 'lng': 36.5662},
  'hail': {'name': 'منطقة حائل', 'lat': 27.5114, 'lng': 41.7208},
  'northern': {'name': 'الحدود الشمالية', 'lat': 30.9753, 'lng': 41.0381},
  'jazan': {'name': 'منطقة جازان', 'lat': 16.8894, 'lng': 42.5706},
  'najran': {'name': 'منطقة نجران', 'lat': 17.4924, 'lng': 44.1277},
  'bahah': {'name': 'منطقة الباحة', 'lat': 20.0129, 'lng': 41.4677},
  'jouf': {'name': 'منطقة الجوف', 'lat': 29.9697, 'lng': 40.2064},
};

// دالة مجانية لحساب المسافة بالكيلومتر وتكلفة السطحة الواصلة لباب البيت
Map<String, int> calculateTowCost(String fromRegion, String toRegion, {bool isBackhaul = false}) {
  if (fromRegion == toRegion) {
    return {'km': 25, 'cost': 150}; // سطحة داخل نفس المنطقة
  }
  final r1 = kRegionsData[fromRegion] ?? kRegionsData['riyadh']!;
  final r2 = kRegionsData[toRegion] ?? kRegionsData['eastern']!;

  const p = 0.017453292519943295;
  final a = 0.5 -
      cos((r2['lat'] - r1['lat']) * p) / 2 +
      cos(r1['lat'] * p) * cos(r2['lat'] * p) * (1 - cos((r2['lng'] - r1['lng']) * p)) / 2;
  final directKm = 12742 * asin(sqrt(a));
  final roadKm = (directKm * 1.25).round(); // معامل الطرق البرية
  int baseCost = (150 + (roadKm * 1.2)).round(); // تسعيرة السطحة الأساسية
  if (isBackhaul) {
    baseCost = (baseCost * 0.70).round(); // خصم 30% لميزة صيدة خط الرجعة
  }
  return {'km': roadKm, 'cost': baseCost};
}

class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  String _selectedFilterRegion = 'all'; // المنطقة التي يتصفحها
  String _buyerCityRegion = 'eastern'; // مدينة المشتري لحساب الشحن لباب بيته
  String _selectedCondition = 'all'; // all, new, used
  String _selectedSpec = 'all'; // all, saudi, gulf, us, korean

  // زر إضافة سيارات تجريبية لاختبار الواجهة فوراً
  Future<void> _seedSampleCars() async {
    final db = FirebaseFirestore.instance;
    final sampleCars = [
      {
        'make': 'تويوتا',
        'model': 'كامري قراندي V6',
        'year': 2026,
        'price': 142000,
        'condition': 'new',
        'mileage': 0,
        'body_condition': 'أصفار وكالة - على الشرط',
        'spec_type': 'saudi',
        'region_id': 'riyadh',
        'city_hub': 'معارض القادسية - الرياض',
        'showroom_name': 'معرض الصقر للسيارات',
        'is_showroom_verified': true,
        'status': 'available',
        'is_featured': true,
        'has_backhaul_tow': true, // تتوفر سطحة خط رجعة بخصم 30%
        'created_at': FieldValue.serverTimestamp(),
      },
      {
        'make': 'هيونداي',
        'model': 'أزيرا فل كامل',
        'year': 2025,
        'price': 128000,
        'condition': 'used',
        'mileage': 18500,
        'body_condition': 'بودي وكالة خالي من الرش',
        'spec_type': 'korean',
        'region_id': 'eastern',
        'city_hub': 'معارض الدمام (ضاحية الملك فهد)',
        'showroom_name': 'معرض النخبة الشرقية',
        'is_showroom_verified': true,
        'status': 'available',
        'is_featured': true,
        'has_backhaul_tow': false,
        'created_at': FieldValue.serverTimestamp(),
      },
      {
        'make': 'فورد',
        'model': 'تورس تيتانيوم',
        'year': 2024,
        'price': 105000,
        'condition': 'used',
        'mileage': 34000,
        'body_condition': 'رش تجميلي رفرف خلفي فقط',
        'spec_type': 'us',
        'region_id': 'makkah',
        'city_hub': 'معارض الجوهرة - جدة',
        'showroom_name': 'معرض الغربية للسيارات',
        'is_showroom_verified': true,
        'status': 'available',
        'is_featured': false,
        'has_backhaul_tow': true,
        'created_at': FieldValue.serverTimestamp(),
      },
      {
        'make': 'نيسان',
        'model': 'باترول بلاتينيوم',
        'year': 2026,
        'price': 315000,
        'condition': 'new',
        'mileage': 0,
        'body_condition': 'أصفار بطاقة جمركية',
        'spec_type': 'gulf',
        'region_id': 'qassim',
        'city_hub': 'معارض بريدة - القصيم',
        'showroom_name': 'معرض نجد للسيارات',
        'is_showroom_verified': true,
        'status': 'available',
        'is_featured': false,
        'has_backhaul_tow': false,
        'created_at': FieldValue.serverTimestamp(),
      },
    ];

    for (var car in sampleCars) {
      await db.collection('cars').add(car);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة 4 سيارات تجريبية بنجاح!')),
      );
    }
  }

  String _specNameAr(String spec) {
    switch (spec) {
      case 'saudi':
        return 'وارد سعودي (وكيل)';
      case 'gulf':
        return 'وارد خليجي';
      case 'us':
        return 'وارد أمريكي';
      case 'korean':
        return 'وارد كوري';
      default:
        return spec;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D47A1),
          foregroundColor: Colors.white,
          title: const Text('منصة معارض المملكة والسطحات', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            TextButton.icon(
              onPressed: _seedSampleCars,
              icon: const Icon(Icons.add_circle, color: Colors.amber),
              label: const Text('إضافة سيارات تجريبية', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: Column(
          children: [
            // 1. شريط تحديد مدينة المشتري لحاسبة "التكلفة الواصلة لباب بيتك"
            Container(
              color: const Color(0xFF1565C0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.amber, size: 22),
                  const SizedBox(width: 8),
                  const Text('مدينتك لحساب الشحن لباب بيتك:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _buyerCityRegion,
                          isExpanded: true,
                          items: kRegionsData.entries
                              .where((e) => e.key != 'all')
                              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value['name'])))
                              .toList(),
                          onChanged: (val) => setState(() => _buyerCityRegion = val!),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. شريط الفلاتر الذكية (المنطقة، الحالة: جديدة/مستعملة، ونوع الوارد)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('تصفح معارض:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedFilterRegion,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          items: kRegionsData.entries
                              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value['name'])))
                              .toList(),
                          onChanged: (val) => setState(() => _selectedFilterRegion = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // فلتر جديدة / مستعملة
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildChoiceChip('الكل', 'all', _selectedCondition, (v) => setState(() => _selectedCondition = v)),
                        const SizedBox(width: 8),
                        _buildChoiceChip('جديدة (أصفار)', 'new', _selectedCondition, (v) => setState(() => _selectedCondition = v)),
                        const SizedBox(width: 8),
                        _buildChoiceChip('مستعملة مفحوصة', 'used', _selectedCondition, (v) => setState(() => _selectedCondition = v)),
                        const VerticalDivider(width: 24),
                        _buildChoiceChip('كل الوارد', 'all', _selectedSpec, (v) => setState(() => _selectedSpec = v)),
                        const SizedBox(width: 8),
                        _buildChoiceChip('سعودي', 'saudi', _selectedSpec, (v) => setState(() => _selectedSpec = v)),
                        const SizedBox(width: 8),
                        _buildChoiceChip('خليجي', 'gulf', _selectedSpec, (v) => setState(() => _selectedSpec = v)),
                        const SizedBox(width: 8),
                        _buildChoiceChip('أمريكي', 'us', _selectedSpec, (v) => setState(() => _selectedSpec = v)),
                        const SizedBox(width: 8),
                        _buildChoiceChip('كوري', 'korean', _selectedSpec, (v) => setState(() => _selectedSpec = v)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3. قائمة السيارات مع التحميل المتدرج (Pagination limit 15) لمنع التعليق
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('cars').limit(15).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.directions_car_outlined, size: 70, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text('لا توجد سيارات معروضة حالياً', style: TextStyle(fontSize: 18)),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _seedSampleCars,
                            icon: const Icon(Icons.add),
                            label: const Text('اضغط لإضافة 4 سيارات تجريبية الآن'),
                          ),
                        ],
                      ),
                    );
                  }

                  // تطبيق الفلاتر
                  final docs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    if (_selectedFilterRegion != 'all' && data['region_id'] != _selectedFilterRegion) return false;
                    if (_selectedCondition != 'all' && data['condition'] != _selectedCondition) return false;
                    if (_selectedSpec != 'all' && data['spec_type'] != _selectedSpec) return false;
                    return true;
                  }).toList();

                  if (docs.isEmpty) {
                    return const Center(child: Text('لا توجد سيارات تطابق هذا الفلتر'));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final carDoc = docs[index];
                      final car = carDoc.data() as Map<String, dynamic>;
                      final isNew = car['condition'] == 'new';
                      final hasBackhaul = car['has_backhaul_tow'] == true;
                      final towInfo = calculateTowCost(
                        car['region_id'] ?? 'riyadh',
                        _buyerCityRegion,
                        isBackhaul: hasBackhaul,
                      );
                      final int carPrice = car['price'] ?? 0;
                      final int deliveredPrice = carPrice + towInfo['cost']!;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CarDetailsScreen(
                                carId: carDoc.id,
                                car: car,
                                buyerRegion: _buyerCityRegion,
                                towCost: towInfo['cost']!,
                                distanceKm: towInfo['km']!,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // شريط علوي: حالة السيارة + إعلان مميز + صيدة خط الرجعة
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: car['is_featured'] == true ? Colors.amber[100] : Colors.blueGrey[50],
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isNew ? Colors.green[700] : Colors.blue[800],
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isNew ? 'جديدة (أصفار)' : 'مستعملة (${car['mileage']} كم)',
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(_specNameAr(car['spec_type'] ?? 'saudi'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    const Spacer(),
                                    if (hasBackhaul)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.teal[700], borderRadius: BorderRadius.circular(6)),
                                        child: const Text('سطحة خط رجعة (-30%)', style: TextStyle(color: Colors.white, fontSize: 11)),
                                      ),
                                  ],
                                ),
                              ),

                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 90,
                                      height: 75,
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.directions_car, size: 48, color: Color(0xFF0D47A1)),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${car['make']} ${car['model']} ${car['year']}',
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.verified, size: 16, color: Colors.blue),
                                              const SizedBox(width: 4),
                                              Text('${car['showroom_name']} • ${car['city_hub']}', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'سعر المعرض: $carPrice ريال',
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // شريط الميزة التنافسية: حاسبة التكلفة الواصلة لباب بيتك
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                                  border: Border(top: BorderSide(color: Colors.green[200]!)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.local_shipping, size: 20, color: Colors.green[800]),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'شحن سطحة لمدينتك (${towInfo['km']} كم): ${towInfo['cost']} ريال  |  واصلة لباب بيتك: $deliveredPrice ريال',
                                        style: TextStyle(color: Colors.green[900], fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.green),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip(String label, String val, String groupVal, Function(String) onSelect) {
    final isSelected = val == groupVal;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelect(val),
      selectedColor: const Color(0xFF0D47A1),
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
    );
  }
}

// صفحة تفاصيل السيارة والأزرار الاستثمارية الأربعة (حجز 99 ريال، فحص 199 ريال، سطحة مع رسوم الخدمة)
class CarDetailsScreen extends StatelessWidget {
  final String carId;
  final Map<String, dynamic> car;
  final String buyerRegion;
  final int towCost;
  final int distanceKm;

  const CarDetailsScreen({
    super.key,
    required this.carId,
    required this.car,
    required this.buyerRegion,
    required this.towCost,
    required this.distanceKm,
  });

  // معادلة رسوم الخدمة لتغطية بوابة الدفع والضريبة 100%: (2.5% + 2 ريال)
  int _calcServiceFee(int amount) => ((amount * 0.025) + 2).ceil();

  Future<void> _createTransaction(BuildContext context, {required String type, required String title, required int baseAmount, required double partnerPct}) async {
    final serviceFee = _calcServiceFee(baseAmount);
    final totalPaid = baseAmount + serviceFee;
    final partnerShare = (baseAmount * partnerPct).round();
    final appCommission = baseAmount - partnerShare;
    final otp = (1000 + Random().nextInt(9000)).toString();

    await FirebaseFirestore.instance.collection('transactions').add({
      'type': type,
      'title': title,
      'car_id': carId,
      'car_title': '${car['make']} ${car['model']} ${car['year']}',
      'gross_amount': totalPaid,
      'base_amount': baseAmount,
      'partner_share': partnerShare,
      'app_commission': appCommission,
      'service_fee': serviceFee,
      'delivery_otp': otp,
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    });

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 30),
                const SizedBox(width: 8),
                Expanded(child: Text('تم تسجيل العملية: $title')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• قيمة الخدمة الأساسية: $baseAmount ريال'),
                Text('• رسوم الخدمة (تغطية مدى/فيزا): $serviceFee ريال'),
                const Divider(),
                Text('• الإجمالي المدفوع من العميل: $totalPaid ريال', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('• حصة الشريك (تحويل آلي): $partnerShare ريال', style: const TextStyle(color: Colors.blueGrey)),
                Text('• صافي ربح تطبيقك: $appCommission ريال (صافي 100%)', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.amber[100], borderRadius: BorderRadius.circular(8)),
                  child: Text('رمز الأمان والتسليم (OTP): $otp\n(لا تُصرف دفعة الشريك إلا بعد إدخال هذا الرمز)', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = car['condition'] == 'new';
    final int carPrice = car['price'] ?? 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D47A1),
          foregroundColor: Colors.white,
          title: Text('${car['make']} ${car['model']} ${car['year']}'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // بطاقة السعر والحالة
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${car['make']} ${car['model']} ${car['year']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('سعر السيارة: $carPrice ريال', style: const TextStyle(fontSize: 20, color: Color(0xFF0D47A1), fontWeight: FontWeight.bold)),
                    const Divider(height: 24),
                    Text('• الحالة: ${isNew ? "جديدة (أصفار)" : "مستعملة - الممشى: ${car['mileage']} كم"}', style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 6),
                    Text('• حالة البودي والفحص: ${car['body_condition']}', style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 6),
                    Text('• المعرض المعلن: ${car['showroom_name']} (${car['city_hub']}) ✓ معرض موثق', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text('الخدمات الفورية (محمية بنظام الدفع المعلق ورمز OTP):', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // الزر 1: حجز السيارة بجدية (99 ريالاً - 100% للتطبيق)
              _buildActionCard(
                icon: Icons.lock_clock,
                color: Colors.indigo,
                title: 'حجز السيارة بجدية لمدة 4 ساعات (99 ريالاً)',
                subtitle: 'تُقفل السيارة باسمك وتُخصم من قيمة السيارة عند الشراء (+${_calcServiceFee(99)} ريال رسوم خدمة)',
                onTap: () => _createTransaction(
                  context,
                  type: 'car_booking',
                  title: 'تذكرة جدية حجز سيارة (4 ساعات)',
                  baseAmount: 99,
                  partnerPct: 0.0, // 100% إيراد للمنصة
                ),
              ),

              // الزر 2: طلب فحص على الماشي عن بُعد (199 ريالاً - 80% للفاحص و20% للتطبيق)
              _buildActionCard(
                icon: Icons.fact_check,
                color: Colors.orange[800]!,
                title: 'طلب "فحص على الماشي" بالنيابة عنك (199 ريالاً)',
                subtitle: 'يتوجه فاحص معتمد في المعرض لتصوير السيارة فيديو وفحص البوية والكمبيوتر (+${_calcServiceFee(199)} ريال رسوم خدمة)',
                onTap: () => _createTransaction(
                  context,
                  type: 'car_inspection',
                  title: 'فحص شامل وتصوير فيديو عن بُعد',
                  baseAmount: 199,
                  partnerPct: 0.80, // 160 للفاحص و 39 ريال صافي للتطبيق
                ),
              ),

              // الزر 3: طلب سطحة توصيل لباب البيت (90% للسطحة و10% للتطبيق)
              _buildActionCard(
                icon: Icons.local_shipping,
                color: Colors.green[700]!,
                title: 'طلب سطحة توصيل لمدينتك ($distanceKm كم - $towCost ريال)',
                subtitle: car['has_backhaul_tow'] == true
                    ? 'شامل خصم 30% (صيدة خط الرجعة)! (+${_calcServiceFee(towCost)} ريال رسوم خدمة)'
                    : 'توصيل آمن مع رمز تسليم OTP (+${_calcServiceFee(towCost)} ريال رسوم خدمة)',
                onTap: () => _createTransaction(
                  context,
                  type: 'tow_trip',
                  title: 'مشوار سطحة توصيل سيارة ($distanceKm كم)',
                  baseAmount: towCost,
                  partnerPct: 0.90, // 90% للسائق و 10% عمولة ثابتة للتطبيق
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(backgroundColor: color, radius: 26, child: Icon(icon, color: Colors.white, size: 28)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(subtitle),
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
          onPressed: onTap,
          child: const Text('اطلب الآن'),
        ),
      ),
    );
  }
}
