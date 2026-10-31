import 'dart:math';
import 'dart:convert';
import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_id/android_id.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String baseUrl = 'http://10.0.2.2:8000';
  static const String adminPhone = '777000000';
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

// ==================== بصمة الجهاز + الرقم المميز ====================
class DeviceFingerprint {
  final String deviceId;
  final String brand;
  final String model;
  final String osVersion;
  final String kernel;

  const DeviceFingerprint({
    required this.deviceId,
    required this.brand,
    required this.model,
    required this.osVersion,
    required this.kernel,
  });

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'device_brand': brand,
        'device_model': model,
        'os_version': osVersion,
        'kernel': kernel,
        'app_version': '1.0.0',
      };

  String summary() => '$brand $model • $osVersion • نواة: ${kernel.length > 25 ? kernel.substring(0, 25) : kernel}';

  static Future<DeviceFingerprint> collect() async {
    final info = DeviceInfoPlugin();
    String id = '', brand = '', model = '', os = '', kernel = 'unknown';
    try {
      if (!kIsWeb && io.Platform.isAndroid) {
        try {
          final v = await io.File('/proc/version').readAsString();
          kernel = v.split('\n').first.trim();
        } catch (_) {}
      }
      if (!kIsWeb && io.Platform.isAndroid) {
        final a = await info.androidInfo;
        id = (await const AndroidId().getId()) ?? '';
        brand = a.brand;
        model = a.model;
        os = 'Android ${a.version.release} (SDK ${a.version.sdkInt})';
      } else if (!kIsWeb && io.Platform.isIOS) {
        final i = await info.iosInfo;
        id = i.identifierForVendor ?? '';
        brand = 'Apple';
        model = i.model ?? '';
        os = 'iOS ${i.systemVersion}';
        kernel = 'Darwin';
      } else {
        final w = await info.webBrowserInfo;
        id = w.userAgent ?? 'web';
        brand = w.browserName.name;
        os = 'Web';
      }
    } catch (_) {}
    return DeviceFingerprint(
        deviceId: id, brand: brand, model: model, osVersion: os, kernel: kernel);
  }
}

enum AuthStatus { newUser, sameDevice, otherDevice, offline }

class AuthResult {
  final AuthStatus status;
  final String uniqueCode;
  final bool isAdmin;
  final String error;
  const AuthResult({required this.status, this.uniqueCode = '', this.isAdmin = false, this.error = ''});
}

class AuthService {
  static Future<AuthResult> registerWithFingerprint(String phone) async {
    try {
      final fp = await DeviceFingerprint.collect();
      final res = await http
          .post(Uri.parse('${AppConfig.baseUrl}/auth/register'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'phone': phone, ...fp.toJson()}))
          .timeout(const Duration(seconds: 6));
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 403) {
        return AuthResult(status: AuthStatus.otherDevice, error: j['error'] ?? 'الرقم مسجل على جهاز آخر');
      }
      await LocalAuthStore.save(phone, j['unique_code'] ?? '');
      return AuthResult(
          status: j['status'] == 'new_user' ? AuthStatus.newUser : AuthStatus.sameDevice,
          uniqueCode: j['unique_code'] ?? '',
          isAdmin: phone == AppConfig.adminPhone);
    } catch (_) {
      return const AuthResult(status: AuthStatus.offline);
    }
  }

  static Future<AuthResult> loginWithCode(String phone, String code) async {
    try {
      final res = await http
          .post(Uri.parse('${AppConfig.baseUrl}/auth/login'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'phone': phone, 'unique_code': code}))
          .timeout(const Duration(seconds: 6));
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200 && j['ok'] == true) {
        await LocalAuthStore.save(phone, code);
        return AuthResult(status: AuthStatus.sameDevice, uniqueCode: code, isAdmin: j['is_admin'] == true);
      }
      return AuthResult(status: AuthStatus.otherDevice, error: j['error'] ?? 'بيانات الدخول غير صحيحة');
    } catch (_) {
      final cached = await LocalAuthStore.load();
      if (cached.$1 == phone && cached.$2 == code) {
        return AuthResult(status: AuthStatus.offline, uniqueCode: code, isAdmin: phone == AppConfig.adminPhone);
      }
      return const AuthResult(status: AuthStatus.otherDevice, error: 'لا يوجد اتصال بالسيرفر للتحقق');
    }
  }

  static Future<AuthResult?> tryAutoLogin() async {
    final (phone, code) = await LocalAuthStore.load();
    if (phone.isEmpty || code.isEmpty) return null;
    final r = await loginWithCode(phone, code);
    if (r.status == AuthStatus.sameDevice || r.status == AuthStatus.offline) return r;
    await LocalAuthStore.clear();
    return null;
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

// ==================== 1) شاشة تسجيل/الدخول مع بصمة الجهاز ====================
class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});
  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phone = TextEditingController();
  bool _busy = false;
  DeviceFingerprint? _fp;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _fp = await DeviceFingerprint.collect();
    final r = await AuthService.tryAutoLogin();
    if (!mounted) return;
    if (r != null && r.uniqueCode.isNotEmpty) {
      _enterApp(r.uniqueCode, r.isAdmin);
    }
  }

  void _enterApp(String phone, bool isAdmin) {
    final state = AppState()
      ..userPhone = phone
      ..isAdmin = isAdmin;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
      builder: (_) => isAdmin ? AdminDashboard(state: state) : MainShell(state: state)),
      (_) => false);
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _sendUniqueCode() async {
    final phone = _phone.text.trim();
    if (phone.length < 9) {
      _snack('الرجاء إدخال رقم جوال يمني صحيح (مثال: 77XXXXXXX)');
      return;
    }
    setState(() => _busy = true);
    final r = await AuthService.registerWithFingerprint(phone);
    if (!mounted) return;
    setState(() => _busy = false);

    switch (r.status) {
      case AuthStatus.otherDevice:
        _snack(r.error);
        return;
      case AuthStatus.offline:
        _snack('لا يوجد اتصال بالسيرفر — تأكد من تشغيل الباك اند');
        return;
      case AuthStatus.newUser:
      case AuthStatus.sameDevice:
        break;
    }

    final isNew = r.status == AuthStatus.newUser;
    final full = phone.startsWith('967') ? phone : '967$phone';
    final msg = isNew
        ? 'مرحباً بك في مسكني اليمن Pro 🏢\nتم إنشاء حسابك بنجاح!\nرقمك المميز الدائم: *${r.uniqueCode}*\nاحفظه — ستدخل به في أي وقت من أي مكان، وهو مرتب برقم جوالك وجهازك فقط.'
        : 'مرحباً بعودتك إلى مسكني اليمن Pro 🏢\nرقمك المميز الدائم: *${r.uniqueCode}*\nأدخله في التطبيق للدخول مباشرة.';
    final url = Uri.parse('https://wa.me/$full?text=${Uri.encodeComponent(msg)}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => OtpVerifyScreen(phone: phone, uniqueCode: r.uniqueCode, isNew: isNew)));
      } else {
        _snack('تعذر فتح الواتساب في جهازك');
      }
    } catch (e) {
      _snack('حدث خطأ: $e');
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
                  boxShadow: [BoxShadow(color: Colors.teal.shade200, blurRadius: 30, offset: const Offset(0, 12))],
                ),
                child: const Icon(Icons.apartment_rounded, size: 70, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text('مسكني اليمن Pro', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('حساب واحد لكل جوال — رقم مميز دائم لدخولك 💬',
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
                onPressed: _busy ? null : _sendUniqueCode,
                icon: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(_busy ? 'جارٍ التحقق من الجهاز...' : 'إرسال رقمي المميز 📲',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LoginWithCodeScreen())),
                icon: const Icon(Icons.key_rounded),
                label: const Text('لدي رقم مميز — دخول سريع ⚡'),
              ),
              if (_fp != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Icon(Icons.phonelink_lock_rounded, size: 18, color: Colors.teal.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('بصمة جهازك: ${_fp!.summary()}',
                          style: TextStyle(fontSize: 11, color: Colors.teal.shade800)),
                    ),
                  ]),
                ),
                const SizedBox(height: 4),
                Text('تُحفظ هذه البصمة مرة واحدة لمنع إنشاء أكثر من حساب بنفس الجوال 🔒',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              ],
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

// ==================== 2) تأكيد الرقم المميز (أول مرة) ====================
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
    if (_otp.text.trim() == widget.uniqueCode) {
      _enter();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرقم المميز غير صحيح — تحقق من رسالة الواتساب')));
    }
  }

  void _enter() {
    final state = AppState()
      ..userPhone = widget.phone
      ..isAdmin = widget.phone == AppConfig.adminPhone;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
      builder: (_) => state.isAdmin
          ? AdminDashboard(state: state)
          : MainShell(state: state)), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isNew ? 'تفعيل حسابك' : 'تأكيد الرقم المميز')),
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Icon(widget.isNew ? Icons.verified_user_rounded : Icons.key_rounded,
                size: 60, color: const Color(0xFF0F766E)),
            const SizedBox(height: 16),
            Text(
              widget.isNew
                  ? 'تم إنشاء حسابك بنجاح 🎉\nأرسلنا رقمك المميز الدائم إلى واتساب +967 ${widget.phone}\nأدخله هنا للتفعيل:'
                  : 'أدخل رقمك المميز الدائم\nالمرسل إلى واتساب +967 ${widget.phone}:',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
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
              child: Text(widget.isNew ? 'تفعيل ودخول 🚀' : 'دخول 🚀',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Text(
                '🔑 هذا الرقم مميز دائم: احفظه في مكان آمن. ستستخدمه للدخول في أي وقت بدون رسائل جديدة، وهو مرتب بجهازك ورقمك ولا يعمل على غيرهما.',
                style: TextStyle(fontSize: 12, height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 2ب) دخول سريع بأي وقت: جوال + رقم مميز ====================
class LoginWithCodeScreen extends StatefulWidget {
  const LoginWithCodeScreen({super.key});
  @override
  State<LoginWithCodeScreen> createState() => _LoginWithCodeScreenState();
}

class _LoginWithCodeScreenState extends State<LoginWithCodeScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;

  Future<void> _login() async {
    final phone = _phone.text.trim();
    final code = _code.text.trim();
    if (phone.length < 9 || code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أدخل رقم الجوال والرقم المميز المكوّن من 6 أرقام')));
      return;
    }
    setState(() => _busy = true);
    final r = await AuthService.loginWithCode(phone, code);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.status == AuthStatus.sameDevice || r.status == AuthStatus.offline) {
      final state = AppState()
        ..userPhone = phone
        ..isAdmin = r.isAdmin;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
        builder: (_) => r.isAdmin ? AdminDashboard(state: state) : MainShell(state: state)),
        (_) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.error)));
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
            const SizedBox(height: 20),
            const Icon(Icons.key_rounded, size: 60, color: Color(0xFF0F766E)),
            const SizedBox(height: 16),
            const Text('أدخل رقم جوالك ورقمك المميز الدائم\nللدخول مباشرة بدون رسائل واتساب:',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
            const SizedBox(height: 30),
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
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(hintText: '• • • • • •', counterText: '', border: OutlineInputBorder()),
              onChanged: (v) { if (v.length == 6) _login(); },
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
              onPressed: _busy ? null : _login,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('دخول 🚀', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('نسيت رقمي المميز؟ أرسله مجدداً عبر واتساب'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 3) الهيكل الرئيسي (MainShell) ====================
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
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'استكشف'),
          NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'المفضلة'),
          NavigationDestination(icon: Icon(Icons.add_box_outlined), selectedIcon: Icon(Icons.add_box), label: 'إعلاناتي'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'حسابي'),
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
      appBar: AppBar(title: const Text('مسكني اليمن Pro 🏢', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.home_work_outlined, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('لا توجد عقارات معروضة حالياً', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('كن أول من يضيف عقاراً حقيقياً للمنصة!', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPropertyScreen())),
                icon: const Icon(Icons.add),
                label: const Text('إضافة عقار جديد'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FavoritesTab extends StatelessWidget {
  const FavoritesTab({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('قائمة المفضلة فارغة')));
}

class MyAdsTab extends StatelessWidget {
  const MyAdsTab({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('ليس لديك أي إعلانات مضافة')));
}

class ProfileTab extends StatelessWidget {
  final AppState state;
  const ProfileTab({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
          const SizedBox(height: 12),
          Text('+967 ${state.userPhone}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          const Text('مستخدم موثق عبر الجهاز والواتساب ✅', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
          const Divider(height: 40),
          ListTile(
            leading: const Icon(Icons.gavel),
            title: const Text('الشروط والأحكام وسياسة العمولة 5%'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red)),
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

// ==================== 4) إضافة عقار جديد ====================
class AddPropertyScreen extends StatelessWidget {
  const AddPropertyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة إعلان عقاري')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TextField(decoration: InputDecoration(labelText: 'عنوان العقار (مثال: شقة للإيجار في تعز)', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            const TextField(keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'السعر', border: OutlineInputBorder())),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال العقار للأدمن للمراجعة والتفعيل!')));
                Navigator.pop(context);
              },
              child: const Text('نشر العقار للمراجعة 🚀', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 5) لوحة تحكم الأدمن ====================
class AdminDashboard extends StatelessWidget {
  final AppState state;
  const AdminDashboard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم الأدمن المركزية 👑'),
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: const Color(0xFF0F766E),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: const [
                    Text('أنت مدير النظام بصلاحيات كاملة 👑', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('التحكم بالمستخدمين والعقارات ومراقبة الاحتيال', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('الطلبات المعلقة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Expanded(
              child: Center(child: Text('لا توجد طلبات معلقة حالياً ✅', style: TextStyle(color: Colors.grey))),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                await LocalAuthStore.clear();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(context,
                      MaterialPageRoute(builder: (_) => const PhoneAuthScreen()), (_) => false);
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('تسجيل الخروج من الأدمن'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 6) الشروط والأحكام ====================
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الشروط والأحكام الصارمة')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Text(
          'اتفاقية استخدام تطبيق مسكني اليمن Pro:\n\n'
          '0. حساب واحد فقط لكل جوال: يتم ربط الحساب ببصمة الجهاز، وإنشاء أكثر من حساب بنفس الجوال يعرضها للحظر.\n\n'
          '1. الالتزام التام برفع بيانات عقارية حقيقية ومطابقة للواقع، وأي إعلان وهمي يعرض الحساب للحظر النهائي.\n\n'
          '2. عمولة المنصة: يلتزم الطرفان بدفع عمولة المنصة المقررة بـ 5% عند إتمام أي صفقة عقارية بنجاح عبر التطبيق.',
          style: TextStyle(fontSize: 15, height: 1.6),
        ),
      ),
    );
  }
}
