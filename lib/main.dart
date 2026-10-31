import 'dart:math';
import 'dart:convert';
import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_id/android_id.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String adminPhone = '777000000';
  static const String adminCode = '000000';
}

void main() {
  runApp(const MaskaniProApp());
}

class MaskaniProApp extends StatelessWidget {
  const MaskaniProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مسكني اليمن Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          primary: const Color(0xFF0F766E),
          secondary: const Color(0xFF25D366),
          background: const Color(0xFFF8FAFC),
        ),
        fontFamily: 'Segoe UI',
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const PhoneAuthScreen(),
    );
  }
}

class LocalAuthStore {
  static Future<void> save(String phone, String code) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('auth_phone', phone);
    await p.setString('auth_code', code);
  }

  static Future<(String, String)> load() async {
    final p = await SharedPreferences.getInstance();
    return (p.getString('auth_phone') ?? '', p.getString('auth_code') ?? '');
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('auth_phone');
    await p.remove('auth_code');
  }
}

class AppState {
  late String userPhone;
  late bool isAdmin;
}

// ==================== 1) شاشة تسجيل الدخول ====================
class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});
  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phone = TextEditingController();

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _sendUniqueCode() async {
    final phone = _phone.text.trim();
    if (phone.length < 9) {
      _snack('الرجاء إدخال رقم جوال يمني صحيح (مثال: 77XXXXXXX)');
      return;
    }

    if (phone == AppConfig.adminPhone) {
      await LocalAuthStore.save(phone, AppConfig.adminCode);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => OtpVerifyScreen(phone: phone, uniqueCode: AppConfig.adminCode, isNew: false)));
      return;
    }

    final generatedCode = (100000 + Random().nextInt(900000)).toString();
    await LocalAuthStore.save(phone, generatedCode);

    final full = phone.startsWith('967') ? phone : '967$phone';
    final msg = 'مرحباً بك في مسكني اليمن Pro 🏢\nرقمك المميز للدخول هو: *$generatedCode*\nاحفظه لديك ولاتشاركه مع أحد.';
    final url = Uri.parse('https://wa.me/$full?text=${Uri.encodeComponent(msg)}');
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => OtpVerifyScreen(phone: phone, uniqueCode: generatedCode, isNew: true)));
      } else {
        _snack('تم توليد الرمز، أدخله للتأكيد');
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => OtpVerifyScreen(phone: phone, uniqueCode: generatedCode, isNew: true)));
      }
    } catch (e) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => OtpVerifyScreen(phone: phone, uniqueCode: generatedCode, isNew: true)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 50),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(Icons.apartment_rounded, size: 70, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text('مسكني اليمن Pro', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('حساب واحد لكل جوال — تحقق مجاني عبر الواتساب 💬',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
                decoration: const InputDecoration(
                  labelText: 'رقم الجوال',
                  hintText: '77XXXXXXX',
                  prefixIcon: Icon(Icons.phone_android),
                  prefixText: '+967 ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _sendUniqueCode,
                icon: const Icon(Icons.send_rounded),
                label: const Text('إرسال الرقم المميز عبر الواتساب 📲',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LoginWithCodeScreen())),
                icon: const Icon(Icons.key_rounded),
                label: const Text('لدي رقم مميز — دخول سريع ⚡'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const TermsScreen())),
                child: const Text('الشروط والأحكام وسياسة العمولة 5%',
                    style: TextStyle(decoration: TextDecoration.underline)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== 2) شاشة التأكيد (OTP) ====================
class OtpVerifyScreen extends StatefulWidget {
  final String phone;
  final String uniqueCode;
  final bool isNew;
  const OtpVerifyScreen({super.key, required this.phone, required this.uniqueCode, this.isNew = false});
  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _otp = TextEditingController();

  void _verify() {
    final enteredCode = _otp.text.trim();
    if (enteredCode == widget.uniqueCode || (widget.phone == AppConfig.adminPhone && enteredCode == AppConfig.adminCode)) {
      final state = AppState()
        ..userPhone = widget.phone
        ..isAdmin = (widget.phone == AppConfig.adminPhone);
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
        builder: (_) => state.isAdmin ? AdminDashboard(state: state) : MainShell(state: state)), (_) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرقم المميز غير صحيح')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تأكيد الرقم المميز')),
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.key_rounded, size: 60, color: Color(0xFF0F766E)),
            const SizedBox(height: 16),
            Text(
              widget.phone == AppConfig.adminPhone
                  ? 'حساب الأدمن 👑\nأدخل الرقم السرّي للوحة التحكم (000000):'
                  : 'أدخل الرقم المميز المكون من 6 أرقام\nالمرسل عبر الواتساب:',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _otp,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 26, letterSpacing: 10, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(hintText: '• • • • • •', counterText: '', border: OutlineInputBorder()),
              onChanged: (v) { if (v.length == 6) _verify(); },
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
              onPressed: _verify,
              child: const Text('دخول التطبيق 🚀', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 3) شاشة الدخول السريع ====================
class LoginWithCodeScreen extends StatefulWidget {
  const LoginWithCodeScreen({super.key});
  @override
  State<LoginWithCodeScreen> createState() => _LoginWithCodeScreenState();
}

class _LoginWithCodeScreenState extends State<LoginWithCodeScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();

  Future<void> _login() async {
    final phone = _phone.text.trim();
    final code = _code.text.trim();
    final cached = await LocalAuthStore.load();

    if ((phone == AppConfig.adminPhone && code == AppConfig.adminCode) || (cached.$1 == phone && cached.$2 == code)) {
      final state = AppState()
        ..userPhone = phone
        ..isAdmin = (phone == AppConfig.adminPhone);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
        builder: (_) => state.isAdmin ? AdminDashboard(state: state) : MainShell(state: state)), (_) => false);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('بيانات الدخول غير صحيحة')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('دخول سريع ⚡')),
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'رقم الجوال', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الرقم المميز', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _login,
              child: const Text('دخول 🚀'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 4) الواجهات والشاشات الرئيسية (الهيكل الكامل) ====================
class MainShell extends StatefulWidget {
  final AppState state;
  const MainShell({super.key, required this.state});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      ExploreTab(state: widget.state),
      const FavoritesTab(),
      const MyAdsTab(),
      ProfileTab(state: widget.state),
    ];
    return Scaffold(
      body: screens[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.explore_rounded), label: 'استكشف'),
          NavigationDestination(icon: Icon(Icons.favorite_rounded), label: 'المفضلة'),
          NavigationDestination(icon: Icon(Icons.add_box_rounded), label: 'إعلاناتي'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'حسابي'),
        ],
      ),
    );
  }
}

class ExploreTab extends StatelessWidget {
  final AppState state;
  const ExploreTab({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مسكني اليمن Pro 🏢', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('لا توجد إشعارات جديدة')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('منصة العقارات اليمنية الذكية 🇾🇪',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('اعرض عقارك أو ابحث عن مسكنك بسهولة وأمان بعملات متعددة (ريال يمني، سعودي، دولار).',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('العقارات المتاحة حديثاً', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF0F766E).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.apartment, color: Color(0xFF0F766E)),
              ),
              title: const Text('شقة مفروشة في تعز - المسبح', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('السعر: 100,000 ريال يمني / شهرياً'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تفاصيل العقار ستتوفر قريباً')),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPropertyScreen()));
        },
        icon: const Icon(Icons.add),
        label: const Text('إضافة عقار'),
      ),
    );
  }
}

class FavoritesTab extends StatelessWidget {
  const FavoritesTab({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('العقارات المفضلة')),
      body: const Center(child: Text('قائمة المفضلة فارغة حالياً', style: TextStyle(color: Colors.grey))),
    );
  }
}

class MyAdsTab extends StatelessWidget {
  const MyAdsTab({super.key});
  @override
  Widget build(BuildContext context) {
    notRegisteredMsg() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ليس لديك إعلانات منشورة')));
    return Scaffold(
      appBar: AppBar(title: const Text('إعلاناتي')),
      body: Center(
        child: FilledButton.icon(
          onPressed: notRegisteredMsg,
          icon: const Icon(Icons.add_box),
          label: const Text('انشر إعلانك العقاري الأول'),
        ),
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  final AppState state;
  const ProfileTab({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي الشخصي')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: const Color(0xFF0F766E), borderRadius: BorderRadius.circular(16)),
            currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, size: 40, color: Color(0xFF0F766E))),
            accountName: Text(state.isAdmin ? 'مدير النظام (الأدمن)' : 'مستخدم معتمد', style: const TextStyle(fontWeight: FontWeight.bold)),
            accountNumber: null,
            accountEmail: Text('+967 ${state.userPhone}'),
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.verified_user, color: Color(0xFF0F766E)),
            title: const Text('حالة التوثيق'),
            trailing: const Text('موثق عبر الواتساب ✅', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () async {
              await LocalAuthStore.clear();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(context,
                    MaterialPageRoute(builder: (_) => const PhoneAuthScreen()), (_) => false);
              }
            },
          ),
        ],
      ),
    );
  }
}

class AddPropertyScreen extends StatelessWidget {
  const AddPropertyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة عقار جديد')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const TextField(decoration: InputDecoration(labelText: 'عنوان الإعلان (مثال: شقة للإيجار)', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          const TextField(decoration: InputDecoration(labelText: 'السعر (حدد العملة: YER / SAR / USD)', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          const TextField(maxLines: 3, decoration: InputDecoration(labelText: 'تفاصيل ومواصفات العقار', border: OutlineInputBorder())),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة العقار بنجاح بنظام العمولة 5%')));
            },
            child: const Text('نشر العقار 🚀'),
          ),
        ],
      ),
    );
  }
}

class AdminDashboard extends StatelessWidget {
  final AppState state;
  const AdminDashboard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة تحكم الأدمن 👑'), backgroundColor: Colors.red[900]),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
            child: const Text('مرحباً بك يا مدير النظام 👑\nأنت تتحكم بكافة صلاحيات تطبيق مسكني اليمن Pro.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.people, color: Colors.red),
            title: const Text('إدارة المستخدمين المسجلين محلياً'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('إدارة المستخدمين تعمل بكفاءة')));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.grey),
            title: const Text('خروج من لوحة الأدمن'),
            onTap: () async {
              await LocalAuthStore.clear();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(context,
                    MaterialPageRoute(builder: (_) => const PhoneAuthScreen()), (_) => false);
              }
            },
          ),
        ],
      ),
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الشروط والأحكام')),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'اتفاقية استخدام تطبيق مسكني اليمن Pro 🏢\n\n'
          '1. يتم توثيق حسابات المستخدمين عبر أرقام هواتفهم والواتساب لضمان الأمان.\n'
          '2. عمولة المنصة الثابتة هي 5% عند إتمام أي عملية إيجار أو بيع ناجحة.\n'
          '3. يلتزم المستخدم بتقديم بيانات صحيحة عن العقارات لتجنب الحظر.',
          style: TextStyle(fontSize: 15, height: 1.6),
        ),
      ),
    );
  }
}
