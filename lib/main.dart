import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MaskaniApp());
}

class MaskaniApp extends StatelessWidget {
  const MaskaniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مسكني اليمن',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E293B),
          primary: const Color(0xFF0F172A),
          secondary: const Color(0xFF25D366), // لون الواتساب الأخضر المميز
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

// 1. شاشة إدخال رقم الجوال وطلب الكود عبر الواتساب
class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController();

  // دالة لتوليد كود عشوائي من 4 أرقام وفتح الواتساب لإرساله
  Future<void> _sendOtpViaWhatsApp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال رقم جوال صحيح (مثال: 77XXXXXXX)')),
      );
      return;
    }

    // إذا كان رقم الأدمن الخاص بك، نثبت كود خاص أو نولد كود عشوائي
    String generatedCode = (phone == "777000000") ? "0000" : (1000 + Random().nextInt(9000)).toString();

    // تجهيز نص رسالة الواتساب
    String message = "مرحباً بك في تطبيق مسكني اليمن 🏢.\nرمز التحقق الخاص بك هو: *$generatedCode*\nلا تقم بمشاركة الكود مع أي شخص.";
    
    // تنسيق رقم الهاتف (تأكد من إضافة رمز الدولة اليمنية 967 تلقائياً إذا لم يكتبه المستخدم)
    String formattedPhone = phone.startsWith('967') ? phone : '967$phone';

    // رابط الواتساب الرسمي المباشر
    final whatsappUrl = Uri.parse("https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}");

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
        
        // الانتقال لصفحة إدخال الكود بعد فتح الواتساب
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerifyScreen(phoneNumber: phone, expectedCode: generatedCode),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح تطبيق الواتساب في جهازك')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Icon(Icons.house_siding_rounded, size: 70, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              const Text(
                'مسكني اليمن',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              const Text(
                'التحقق الآمن والمجاني عبر الواتساب 💬',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 50),
              const Text('أدخل رقم جوالك لتلقي كود التحقق:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '77XXXXXXX',
                  prefixIcon: const Icon(Icons.phone_android_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _sendOtpViaWhatsApp,
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text('إرسال الكود عبر الواتساب 📲', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const TermsAndConditionsScreen()));
                },
                child: const Text('شروط وأحكام الاستخدام والسياسة الصارمة', style: TextStyle(decoration: TextDecoration.underline)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 2. شاشة تأكيد الكود الذي وصل عبر الواتساب
class OtpVerifyScreen extends StatefulWidget {
  final String phoneNumber;
  final String expectedCode;
  const OtpVerifyScreen({super.key, required this.phoneNumber, required this.expectedCode});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _otpController = TextEditingController();

  void _verifyCode() {
    // إذا كان رقم الأدمن الخاص بك
    if (widget.phoneNumber == "777000000" && _otpController.text == "0000") {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AdminMainDashboard()),
        (route) => false,
      );
      return;
    }

    if (_otpController.text == widget.expectedCode) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigationShell()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كود التحقق غير صحيح، تأكد من الرسالة في الواتساب')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تأكيد الكود')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('تم تحويلك للواتساب لإرسال الكود إلى الرقم:\n${widget.phoneNumber}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 30),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 4,
              style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: '0 0 0 0',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _verifyCode,
              child: const Text('تحقق ودخول التطبيق 🚀', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// 3. الشاشة الرئيسية الفارغة والتفاعلية
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  final List> _realProperties = []; // فارغ تماماً

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مسكني اليمن 🏢', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildExploreTab(),
          _buildSavedTab(),
          _buildMyAdsTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'استكشف'),
          NavigationDestination(icon: Icon(Icons.favorite_border), label: 'المفضلة'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'إعلاناتي'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'حسابي'),
        ],
      ),
    );
  }

  Widget _buildExploreTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.house_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('لا توجد عقارات معروضة حالياً', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('كن أول من يضيف عقاراً حقيقياً في المنصة!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AddRealPropertyScreen()));
              },
              icon: const Icon(Icons.add),
              label: const Text('إضافة عقار جديد'),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSavedTab() => const Center(child: Text('المفضلة فارغة'));
  Widget _buildMyAdsTab() => const Center(child: Text('ليس لديك إعلانات مضافة'));
  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
        const SizedBox(height: 12),
        const Text('مستخدم موثق', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const Divider(height: 40),
        ListTile(
          leading: const Icon(Icons.gavel),
          title: const Text('الشروط والأحكام الصارمة'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TermsAndConditionsScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red)),
          onTap: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const PhoneAuthScreen()), (r) => false),
        ),
      ],
    );
  }
}

// 4. شاشة إضافة عقار
class AddRealPropertyScreen extends StatelessWidget {
  const AddRealPropertyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة عقار جديد')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TextField(decoration: InputDecoration(labelText: 'عنوان العقار')),
            const SizedBox(height: 16),
            const TextField(keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'السعر')),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, padding: const EdgeInsets.all(16)),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال العقار للأدمن للمراجعة بنجاح!')));
                Navigator.pop(context);
              },
              child: const Text('نشر العقار 🚀', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}

// 5. لوحة تحكم الأدمن
class AdminMainDashboard extends StatelessWidget {
  const AdminMainDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة تحكم الأدمن 👑'), backgroundColor: Colors.red[900], foregroundColor: Colors.white),
      body: const Center(child: Text('أنت الآن تحكم المنصة بصلاحيات كاملة ✅')),
    );
  }
}

// 6. الشروط والأحكام
class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الشروط والأحكام الصارمة')),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'اتفاقية الاستخدام:\n1. الالتزام برفع بيانات حقيقية مطابقة للواقع.\n2. منع أي إعلانات وهمية تعرض الحساب للحظر النهائي.\n3. عمولة التطبيق هي 5% من قيمة العقار عند إتمام البيع أو الإيجار.',
          style: TextStyle(fontSize: 16, height: 1.5),
        ),
      ),
    );
  }
}
