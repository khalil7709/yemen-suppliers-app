import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const YemenSuppliersApp());
}

final FirebaseAuth auth = FirebaseAuth.instance;
final FirebaseFirestore db = FirebaseFirestore.instance;

class YemenSuppliersApp extends StatelessWidget {
  const YemenSuppliersApp({super.key});
  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0F2342);
    const amber = Color(0xFFF59E0B);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: MaterialApp(
        title: 'سوق موردي اليمن',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          primaryColor: navy,
          scaffoldBackgroundColor: const Color(0xFFF3F5F8),
          colorScheme: ColorScheme.fromSeed(seedColor: navy, primary: navy, secondary: amber),
          appBarTheme: const AppBarTheme(backgroundColor: navy, foregroundColor: Colors.white, elevation: 0),
        ),
        home: const MainShellScreen(),
      ),
    );
  }
}

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});
  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;
  String _searchQuery = '';
  String _selectedGov = '';
  String _currency = 'YER';
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _rfqs = [];
  List<Map<String, dynamic>> _escrowDeals = [];
  Map<String, dynamic> _profile = {};
  Map<String, dynamic> _supplier = {};
  bool _hasSupplier = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    try {
      final catsSnap = await db.collection('categories').get();
      final prodsSnap = await db.collection('products').where('moderation_status', isEqualTo: 'approved').get();
      final rfqsSnap = await db.collection('rfq_requests').where('status', isEqualTo: 'open').get();

      setState(() {
        _categories = catsSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
        _products = prodsSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
        _rfqs = rfqsSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      });

      final user = auth.currentUser;
      if (user != null) {
        final profDoc = await db.collection('profiles').doc(user.uid).get();
        final supQuery = await db.collection('suppliers').where('user_id', isEqualTo: user.uid).get();
        final escSnap = await db.collection('escrow_deals').where('buyer_id', isEqualTo: user.uid).get();

        setState(() {
          _profile = profDoc.exists ? profDoc.data()! : {};
          _supplier = supQuery.docs.isNotEmpty ? {'id': supQuery.docs.first.id, ...supQuery.docs.first.data()} : {};
          _hasSupplier = supQuery.docs.isNotEmpty;
          _escrowDeals = escSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
        });
      } else {
        setState(() {
          _profile = {};
          _supplier = {};
          _hasSupplier = false;
          _escrowDeals = [];
        });
      }
    } catch (e) {
      _toast('تعذر تحميل البيانات: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmtPrice(dynamic amount, String? curr) {
    final c = curr ?? _currency;
    final sym = c == 'USD' ? '\$' : c == 'SAR' ? 'ر.س' : 'ر.ي';
    return '${amount ?? 0} $sym';
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _products.where((p) {
      final govOk = _selectedGov.isEmpty || (p['governorate'] ?? '') == _selectedGov;
      final q = _searchQuery.toLowerCase();
      final title = (p['title'] ?? '').toString().toLowerCase();
      final desc = (p['description'] ?? '').toString().toLowerCase();
      final qOk = q.isEmpty || title.contains(q) || desc.contains(q);
      return govOk && qOk;
    }).toList();

    final screens = [
      _buildHomeTab(filteredProducts),
      _buildCategoriesTab(),
      _buildRfqTab(),
      _buildEscrowTab(),
      _buildAccountTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('سوق موردي اليمن', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('تجارة جملة موثوقة - ضمان وسيط', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          DropdownButton<String>(
            value: _currency,
            dropdownColor: const Color(0xFF0F2342),
            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'YER', child: Text('ر.ي')),
              DropdownMenuItem(value: 'USD', child: Text('\$')),
              DropdownMenuItem(value: 'SAR', child: Text('ر.س')),
            ],
            onChanged: (v) => setState(() => _currency = v ?? 'YER'),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllData),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF0F2342),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'الأقسام'),
          BottomNavigationBarItem(icon: Icon(Icons.request_quote), label: 'طلبات RFQ'),
          BottomNavigationBarItem(icon: Icon(Icons.shield), label: 'الضمان'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'حسابي'),
        ],
      ),
    );
  }

  Widget _buildHomeTab(List<Map<String, dynamic>> homeItems) {
    final govs = ['', 'صنعاء', 'عدن', 'الحديدة', 'تعز', 'إب', 'حضرموت', 'مأرب'];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'ابحث عن منتج، صنف، أو مورد في اليمن...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
          onChanged: (v) => setState(() => _searchQuery = v.trim()),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: govs.map((g) {
              return Padding(
                padding: const EdgeInsets.only(left: 6),
                child: ChoiceChip(
                  label: Text(g.isEmpty ? 'كل المحافظات' : g),
                  selected: _selectedGov == g,
                  onSelected: (_) => setState(() => _selectedGov = g),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF0F2342), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الضمان التجاري الوسيط (Escrow)', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 4),
                    Text('موردون بسجل تجاري وتجار جملة - لا يفرج عن المبلغ قبل بوليصة الشحن والاستلام', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: const Color(0xFF09162B)),
                onPressed: () => setState(() => _currentIndex = 2),
                child: const Text('طلب RFQ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('عروض الجملة المعتمدة (${homeItems.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2342))),
        const SizedBox(height: 8),
        if (homeItems.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('لا توجد منتجات معتمدة مطابقة حاليا.'))))
        else
          for (final p in homeItems) _buildProductCard(p),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> p) {
    final verif = p['verification_level'] == 'commercial_verified' ? 'معتمد بسجل' : 'ضمان الزامي';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.inventory_2, size: 38, color: Color(0xFF0F2342)),
        title: Text(p['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('${_fmtPrice(p['base_price'], p['currency'])} - اقل طلب: ${p['moq']} ${p['unit_type'] ?? ''}\n${p['company_name'] ?? 'مورد'} (${p['governorate'] ?? ''}) - $verif'),
        isThreeLine: true,
        onTap: () => _openProductSheet(p),
      ),
    );
  }

  void _openProductSheet(Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(p['title'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F2342))),
            const SizedBox(height: 6),
            Text('السعر: ${_fmtPrice(p['base_price'], p['currency'])} / ${p['unit_type'] ?? ''} - اقل كمية: ${p['moq']}'),
            Text('المورد: ${p['company_name'] ?? ''} (${p['governorate'] ?? ''})'),
            if ((p['description'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(p['description']),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    icon: const Icon(Icons.shield),
                    label: const Text('فتح صفقة ضمان'),
                    onPressed: () {
                      Navigator.pop(context);
                      _openCreateEscrowDialog(p);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesTab() {
    final mains = _categories.where((c) => c['parent_id'] == null).toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final m in mains)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ExpansionTile(
              title: Text(m['name_ar'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F2342))),
              children: [
                for (final s in _categories.where((item) => item['parent_id'] == m['id']))
                  ListTile(title: Text(s['name_ar'] ?? '')),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRfqTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('طلبات التسعير المفتوحة (RFQ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2342))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: const Color(0xFF09162B)),
              onPressed: _openCreateRfqDialog,
              child: const Text('+ طلب جديد', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_rfqs.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('لا توجد طلبات تسعير مفتوحة حاليا.'))))
        else
          for (final r in _rfqs)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(r['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('الكمية: ${r['quantity']} ${r['unit_type'] ?? ''} - المحافظة: ${r['delivery_governorate'] ?? ''}'),
                trailing: _hasSupplier
                    ? TextButton(
                        onPressed: () => _openRfqOfferDialog(r['id']),
                        child: const Text('تقديم عرض'),
                      )
                    : null,
              ),
            ),
      ],
    );
  }

  void _openCreateRfqDialog() {
    final user = auth.currentUser;
    if (user == null) {
      setState(() => _currentIndex = 4);
      _toast('سجل الدخول اولا لنشر طلب تسعير');
      return;
    }
    final titleCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '50');
    final unitCtrl = TextEditingController(text: 'كرتون');
    String gov = 'صنعاء';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('نشر طلب تسعير RFQ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'المنتج المطلوب')),
            TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية')),
            TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'الوحدة')),
            DropdownButtonFormField<String>(
              value: gov,
              items: ['صنعاء', 'عدن', 'الحديدة', 'تعز', 'إب', 'حضرموت', 'مأرب'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (v) => gov = v ?? 'صنعاء',
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('الغاء')),
          ElevatedButton(
            onPressed: () async {
              await db.collection('rfq_requests').add({
                'buyer_id': user.uid,
                'title': titleCtrl.text.trim(),
                'quantity': int.tryParse(qtyCtrl.text) ?? 1,
                'unit_type': unitCtrl.text.trim(),
                'delivery_governorate': gov,
                'status': 'open',
                'created_at': FieldValue.serverTimestamp(),
              });
              if (mounted) Navigator.pop(context);
              _toast('تم نشر طلب التسعير');
              _loadAllData();
            },
            child: const Text('نشر'),
          ),
        ],
      ),
    );
  }

  void _openRfqOfferDialog(String rfqId) {
    final priceCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تقديم عرض سعر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر الوحدة')),
            TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'ملاحظات الشحن والتسليم')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('الغاء')),
          ElevatedButton(
            onPressed: () async {
              await db.collection('rfq_offers').add({
                'rfq_id': rfqId,
                'supplier_id': _supplier['id'],
                'unit_price': double.tryParse(priceCtrl.text) ?? 0,
                'notes': notesCtrl.text.trim(),
                'created_at': FieldValue.serverTimestamp(),
              });
              if (mounted) Navigator.pop(context);
              _toast('تم ارسال عرض السعر');
            },
            child: const Text('ارسال'),
          ),
        ],
      ),
    );
  }

  void _openCreateEscrowDialog(Map<String, dynamic> product) {
    final user = auth.currentUser;
    if (user == null) {
      setState(() => _currentIndex = 4);
      _toast('سجل الدخول اولا لفتح صفقة ضمان');
      return;
    }
    final qtyCtrl = TextEditingController(text: (product['moq'] ?? 10).toString());
    final amountCtrl = TextEditingController(text: (product['base_price'] ?? 0).toString());
    final refCtrl = TextEditingController();
    String network = 'الكريمي';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('فتح صفقة ضمان وسيط'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية')),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'اجمالي المبلغ')),
              DropdownButtonFormField<String>(
                value: network,
                items: ['الكريمي', 'ون كاش', 'جوالي', 'النجم', 'الامتياز'].map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                onChanged: (v) => network = v ?? 'الكريمي',
              ),
              TextField(controller: refCtrl, decoration: const InputDecoration(labelText: 'رقم الحوالة / المرجع')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('الغاء')),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amountCtrl.text) ?? 0;
              await db.collection('escrow_deals').add({
                'buyer_id': user.uid,
                'supplier_id': product['supplier_id'],
                'product_title': product['title'],
                'quantity': int.tryParse(qtyCtrl.text) ?? 1,
                'total_amount': amt,
                'commission_fee': amt * 0.02,
                'currency': product['currency'] ?? 'YER',
                'payment_network': network,
                'transfer_reference': refCtrl.text.trim(),
                'status': 'payment_verifying',
                'created_at': FieldValue.serverTimestamp(),
              });
              if (mounted) Navigator.pop(context);
              _toast('تم ارسال حوالة الضمان للتحقق');
              setState(() => _currentIndex = 3);
              _loadAllData();
            },
            child: const Text('تاكيد الضمان'),
          ),
        ],
      ),
    );
  }

  Widget _buildEscrowTab() {
    final user = auth.currentUser;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('صفقات الضمان الوسيط (Escrow)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2342))),
        const SizedBox(height: 8),
        if (_escrowDeals.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('لا توجد صفقات ضمان حاليا.'))))
        else
          for (final d in _escrowDeals)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(d['product_title'] ?? 'صفقة ضمان', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('المبلغ: ${_fmtPrice(d['total_amount'], d['currency'])} - الحالة: ${d['status'] ?? ''}'),
                trailing: (user != null && d['buyer_id'] == user.uid && d['status'] == 'shipped')
                    ? ElevatedButton(
                        onPressed: () async {
                          await db.collection('escrow_deals').doc(d['id']).update({'status': 'delivered_released'});
                          _toast('تم تاكيد الاستلام وتحرير المبلغ');
                          _loadAllData();
                        },
                        child: const Text('تاكيد الاستلام'),
                      )
                    : null,
              ),
            ),
      ],
    );
  }

  Widget _buildAccountTab() {
    final user = auth.currentUser;
    if (user == null) {
      return _AuthView(onSuccess: _loadAllData, onToast: _toast);
    }
    final role = _profile['role'] ?? 'buyer';
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.verified_user, color: Color(0xFF0F2342)),
            title: Text(_profile['full_name'] ?? user.email ?? 'حساب نشط', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('الدور: $role - المحافظة: ${_profile['governorate'] ?? 'اليمن'}'),
            trailing: TextButton(
              onPressed: () async {
                await auth.signOut();
                await _loadAllData();
              },
              child: const Text('خروج'),
            ),
          ),
        ),
        if (_hasSupplier) ...[
          const SizedBox(height: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: const Color(0xFF09162B)),
            icon: const Icon(Icons.add_box),
            label: const Text('اضافة منتج جملة جديد'),
            onPressed: _openAddProductDialog,
          ),
        ],
      ],
    );
  }

  void _openAddProductDialog() {
    final titleCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final moqCtrl = TextEditingController(text: '10');
    final unitCtrl = TextEditingController(text: 'كرتون');
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('اضافة منتج جملة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'اسم المنتج')),
              TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر')),
              TextField(controller: moqCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'اقل كمية MOQ')),
              TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'الوحدة')),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'الوصف')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('الغاء')),
          ElevatedButton(
            onPressed: () async {
              await db.collection('products').add({
                'supplier_id': _supplier['id'],
                'title': titleCtrl.text.trim(),
                'base_price': double.tryParse(priceCtrl.text) ?? 0,
                'moq': int.tryParse(moqCtrl.text) ?? 1,
                'unit_type': unitCtrl.text.trim(),
                'description': descCtrl.text.trim(),
                'moderation_status': 'pending',
                'company_name': _supplier['company_name'] ?? '',
                'governorate': _supplier['governorate'] ?? '',
                'verification_level': _supplier['verification_level'] ?? '',
                'created_at': FieldValue.serverTimestamp(),
              });
              if (mounted) Navigator.pop(context);
              _toast('تم ارسال المنتج للمراجعة قبل النشر');
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

class _AuthView extends StatefulWidget {
  final VoidCallback onSuccess;
  final void Function(String) onToast;
  const _AuthView({required this.onSuccess, required this.onToast});
  @override
  State<_AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<_AuthView> {
  bool _isSignup = false;
  String _role = 'buyer';
  String _gov = 'صنعاء';
  String _verifLevel = 'commercial_verified';
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_isSignup ? 'انشاء حساب جديد' : 'تسجيل الدخول', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F2342))),
                const SizedBox(height: 10),
                if (_isSignup) ...[
                  TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'الاسم الكامل')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _role,
                    decoration: const InputDecoration(labelText: 'نوع الحساب'),
                    items: const [
                      DropdownMenuItem(value: 'buyer', child: Text('مشتري / صاحب محل')),
                      DropdownMenuItem(value: 'supplier', child: Text('مورد / تاجر جملة')),
                    ],
                    onChanged: (v) => setState(() => _role = v ?? 'buyer'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _gov,
                    decoration: const InputDecoration(labelText: 'المحافظة'),
                    items: ['صنعاء', 'عدن', 'الحديدة', 'تعز', 'إب', 'حضرموت', 'مأرب'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (v) => setState(() => _gov = v ?? 'صنعاء'),
                  ),
                  TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الجوال (سري للادارة)')),
                  if (_role == 'supplier') ...[
                    TextField(controller: _companyCtrl, decoration: const InputDecoration(labelText: 'اسم الشركة او المتجر')),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _verifLevel,
                      decoration: const InputDecoration(labelText: 'مستوى التوثيق'),
                      items: const [
                        DropdownMenuItem(value: 'commercial_verified', child: Text('مورد معتمد بسجل تجاري')),
                        DropdownMenuItem(value: 'independent_trader', child: Text('تاجر جملة / متجر نشط (ضمان الزامي)')),
                      ],
                      onChanged: (v) => setState(() => _verifLevel = v ?? 'commercial_verified'),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
                TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'البريد الالكتروني')),
                const SizedBox(height: 8),
                TextField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور')),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F2342), foregroundColor: Colors.white),
                  onPressed: _submit,
                  child: Text(_isSignup ? 'انشاء الحساب' : 'دخول'),
                ),
                TextButton(
                  onPressed: () => setState(() => _isSignup = !_isSignup),
                  child: Text(_isSignup ? 'لدي حساب بالفعل؟ سجل دخولك' : 'ليس لديك حساب؟ انشئ حسابا جديدا'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    try {
      if (!_isSignup) {
        await auth.signInWithEmailAndPassword(email: _emailCtrl.text.trim(), password: _passCtrl.text);
        widget.onToast('تم تسجيل الدخول');
      } else {
        final cred = await auth.createUserWithEmailAndPassword(email: _emailCtrl.text.trim(), password: _passCtrl.text);
        final uid = cred.user?.uid;
        if (uid != null) {
          await db.collection('profiles').doc(uid).set({
            'email': _emailCtrl.text.trim(),
            'full_name': _nameCtrl.text.trim(),
            'role': _role,
            'governorate': _gov,
            'private_phone': _phoneCtrl.text.trim(),
          });
          if (_role == 'supplier') {
            await db.collection('suppliers').add({
              'user_id': uid,
              'company_name': _companyCtrl.text.trim().isEmpty ? _nameCtrl.text.trim() : _companyCtrl.text.trim(),
              'governorate': _gov,
              'verification_level': _verifLevel,
              'approval_status': 'pending',
            });
          }
        }
        widget.onToast('تم انشاء الحساب بنجاح');
      }
      widget.onSuccess();
    } catch (e) {
      widget.onToast('خطأ: $e');
    }
  }
}
