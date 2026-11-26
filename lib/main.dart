import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String kSupabaseUrl = 'https://buygdjesrvrvziarkghq.supabase.co';
const String kSupabaseAnonKey = 'sb_publishable_2Ub-HpGdI9swNxaTZH50ag_4NM-Pphv';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: kSupabaseUrl,
    anonKey: kSupabaseAnonKey,
  );
  runApp(const YemenSuppliersApp());
}

final supabase = Supabase.instance.client;

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
          colorScheme: ColorScheme.fromSeed(
            seedColor: navy,
            primary: navy,
            secondary: amber,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: navy,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
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

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _supplier;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    try {
      final catsRes = await supabase.from('categories').select().order('sort_order');
      final prodsRes = await supabase
          .from('products')
          .select('*, suppliers(company_name, governorate, verification_level, is_verified)')
          .eq('moderation_status', 'approved')
          .order('created_at', ascending: false);
      final rfqsRes = await supabase
          .from('rfq_requests')
          .select()
          .eq('status', 'open')
          .order('created_at', ascending: false);

      setState(() {
        _categories = List<Map<String, dynamic>>.from(catsRes);
        _products = List<Map<String, dynamic>>.from(prodsRes);
        _rfqs = List<Map<String, dynamic>>.from(rfqsRes);
      });

      final user = supabase.auth.currentUser;
      if (user != null) {
        final prof = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
        final sup = await supabase.from('suppliers').select().eq('user_id', user.id).maybeSingle();
        final esc = await supabase.from('escrow_deals').select().order('created_at', ascending: false);
        setState(() {
          _profile = prof;
          _supplier = sup;
          _escrowDeals = List<Map<String, dynamic>>.from(esc);
        });
      } else {
        setState(() {
          _profile = null;
          _supplier = null;
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
      final sup = p['suppliers'] as Map<String, dynamic>?;
      final govOk = _selectedGov.isEmpty || (sup?['governorate'] ?? '') == _selectedGov;
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
            Text('تجارة جملة موثوقة • ضمان وسيط', style: TextStyle(fontSize: 11, color: Colors.white70)),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : screens[_currentIndex],
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
                    Text('موردون بسجل تجاري وتجار جملة • لا يُفرج عن المبلغ قبل بوليصة الشحن والاستلام', style: TextStyle(color: Colors.white, fontSize: 11)),
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
          const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('لا توجد منتجات معتمدة مطابقة حالياً.'))))
        else
          for (final p in homeItems) _buildProductCard(p),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> p) {
    final sup = p['suppliers'] as Map<String, dynamic>?;
    final verif = sup?['verification_level'] == 'commercial_verified' ? '✔ معتمد بسجل' : '🛡️ ضمان إلزامي';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.inventory_2, size: 38, color: Color(0xFF0F2342)),
        title: Text(p['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('${_fmtPrice(p['base_price'], p['currency'])} • أقل طلب: ${p['moq']} ${p['unit_type'] ?? ''}\n${sup?['company_name'] ?? 'مورد'} (${sup?['governorate'] ?? ''}) • $verif'),
        isThreeLine: true,
        onTap: () => _openProductSheet(p),
      ),
    );
  }

  void _openProductSheet(Map<String, dynamic> p) {
    final sup = p['suppliers'] as Map<String, dynamic>?;
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
            Text('السعر: ${_fmtPrice(p['base_price'], p['currency'])} / ${p['unit_type'] ?? ''} • أقل كمية: ${p['moq']}'),
            Text('المورد: ${sup?['company_name'] ?? ''} (${sup?['governorate'] ?? ''})'),
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
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await supabase.from('products').update({'reports_count': (p['reports_count'] ?? 0) + 1}).eq('id', p['id']);
                    _toast('تم إرسال البلاغ للمراجعة');
                  },
                  child: const Text('تبليغ'),
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
          const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('لا توجد طلبات تسعير مفتوحة حالياً.'))))
        else
          for (final r in _rfqs)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(r['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('الكمية: ${r['quantity']} ${r['unit_type'] ?? ''} • المحافظة: ${r['delivery_governorate'] ?? ''}'),
                trailing: _supplier != null
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
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => _currentIndex = 4);
      _toast('سجّل الدخول أولاً لنشر طلب تسعير');
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
              items: ['صنعاء', 'عدن', 'الحديدة', 'تعز', 'إب', 'حضرموت', 'مأرب']
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => gov = v ?? 'صنعاء',
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              await supabase.from('rfq_requests').insert({
                'buyer_id': user.id,
                'title': titleCtrl.text.trim(),
                'quantity': int.tryParse(qtyCtrl.text) ?? 1,
                'unit_type': unitCtrl.text.trim(),
                'delivery_governorate': gov,
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              await supabase.from('rfq_offers').insert({
                'rfq_id': rfqId,
                'supplier_id': _supplier!['id'],
                'unit_price': double.tryParse(priceCtrl.text) ?? 0,
                'notes': notesCtrl.text.trim(),
              });
              if (mounted) Navigator.pop(context);
              _toast('تم إرسال عرض السعر');
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  void _openCreateEscrowDialog(Map<String, dynamic> product) {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => _currentIndex = 4);
      _toast('سجّل الدخول أولاً لفتح صفقة ضمان');
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
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'إجمالي المبلغ')),
              DropdownButtonFormField<String>(
                value: network,
                items: ['الكريمي', 'ون كاش', 'جوالي', 'النجم', 'الامتياز']
                    .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                    .toList(),
                onChanged: (v) => network = v ?? 'الكريمي',
              ),
              TextField(controller: refCtrl, decoration: const InputDecoration(labelText: 'رقم الحوالة / المرجع')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amountCtrl.text) ?? 0;
              await supabase.from('escrow_deals').insert({
                'buyer_id': user.id,
                'supplier_id': product['supplier_id'],
                'product_title': product['title'],
                'quantity': int.tryParse(qtyCtrl.text) ?? 1,
                'total_amount': amt,
                'commission_fee': amt * 0.02,
                'currency': product['currency'] ?? 'YER',
                'payment_network': network,
                'transfer_reference': refCtrl.text.trim(),
                'status': 'payment_verifying',
              });
              if (mounted) Navigator.pop(context);
              _toast('تم إرسال حوالة الضمان للتحقق');
              setState(() => _currentIndex = 3);
              _loadAllData();
            },
            child: const Text('تأكيد الضمان'),
          ),
        ],
      ),
    );
  }

  Widget _buildEscrowTab() {
    final user = supabase.auth.currentUser;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('صفقات الضمان الوسيط (Escrow)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2342))),
        const SizedBox(height: 8),
        if (_escrowDeals.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('لا توجد صفقات ضمان حالياً.'))))
        else
          for (final d in _escrowDeals)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(d['product_title
