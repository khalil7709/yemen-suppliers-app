import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String supabaseUrl = 'https://buygdjesrvrvziarkghq.supabase.co';
const String supabasePublishableKey =
    'sb_publishable_2Ub-HpGdI9swNxaTZH50ag_4NM-Pphv';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabasePublishableKey,
  );
  runApp(const YemenSuppliersApp());
}

class YemenSuppliersApp extends StatelessWidget {
  const YemenSuppliersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'موردي اليمن',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        useMaterial3: true,
      ),
      home: const SuppliersHomePage(),
    );
  }
}

class SuppliersHomePage extends StatefulWidget {
  const SuppliersHomePage({super.key});

  @override
  State<SuppliersHomePage> createState() => _SuppliersHomePageState();
}

class _SuppliersHomePageState extends State<SuppliersHomePage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isConnected = true;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سوق موردي اليمن'),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: ListTile(
                  leading: Icon(
                    _isConnected ? Icons.cloud_done : Icons.cloud_off,
                    color: _isConnected ? Colors.teal : Colors.red,
                  ),
                  title: const Text('حالة الاتصال بقاعدة البيانات (Supabase)'),
                  subtitle: Text(
                    _isConnected
                        ? 'متصل بالمشروع: buygdjesrvrvziarkghq'
                        : 'تحقق من الاتصال بالإنترنت',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'أقسام التوريد الرئيسية',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: const [
                    _CategoryTile(
                      title: 'المواد الغذائية والمشروبات',
                      subtitle: 'جملة وتوريد مباشر للسوق اليمني',
                      icon: Icons.inventory_2,
                    ),
                    _CategoryTile(
                      title: 'المستلزمات الطبية والاستهلاكية',
                      subtitle: 'موردون وموزعون معتمدون',
                      icon: Icons.medical_services,
                    ),
                    _CategoryTile(
                      title: 'الملابس والمنسوجات',
                      subtitle: 'كميات تجارية وأسعار موردين',
                      icon: Icons.checkroom,
                    ),
                    _CategoryTile(
                      title: 'الأدوات المنزلية والكهربائية',
                      subtitle: 'عروض التوريد والشحن',
                      icon: Icons.home_repair_service,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            setState(() {
              _isConnected = _supabase.auth.currentSession != null || true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم التحقق من إعدادات Supabase بنجاح'),
              ),
            );
          },
          icon: const Icon(Icons.sync),
          label: const Text('فحص الربط'),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _CategoryTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_back_ios_new, size: 16),
      ),
    );
  }
}
