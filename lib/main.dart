import 'package:flutter/material.dart';

void main() {
  runApp(MaskaniApp());
}

class MaskaniApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مسكني اليمن - النسخة النهائية المضمونة',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        fontFamily: 'Segoe UI',
      ),
      debugShowCheckedModeBanner: false,
      home: LoginScreen(),
    );
  }
}

// ==========================================
// 1. شاشة تسجيل الدخول المزدوجة (عميل / وكيل / أدمن)
// ==========================================
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String userType = 'client'; // client أو agent أو admin
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phone2Controller = TextEditingController(); 
  bool agreedToStrictTerms = false;

  void _handleLogin() {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('الرجاء إدخال الاسم ورقم الجوال الأساسي')),
      );
      return;
    }

    // دخول الأدمن (صاحب التطبيق) برقم خاص
    if (_phoneController.text == "777000000" && userType == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AdminDashboardScreen()),
      );
      return;
    }

    if (userType == 'agent' && !agreedToStrictTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يجب الموافقة على الشروط الصارمة وعمولة التطبيق 5%')),
      );
      return;
    }

    if (userType == 'agent') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('تم إرسال طلبك للأدمن ⏳'),
          content: Text('حسابك قيد المراجعة. لن تستطيع إضافة عقارات حتى يوافق صاحب التطبيق يدوياً لضمان الأمان.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => HomeScreen(userType: 'agent_pending', userName: _nameController.text)),
                );
              },
              child: Text('حسناً'),
            )
          ],
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen(userType: 'client', userName: _nameController.text)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تسجيل الدخول - مسكني اليمن 🔒')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('اختر صففتك في التطبيق:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: Text('عميل (مستأجر)'),
                    value: 'client',
                    groupValue: userType,
                    onChanged: (val) => setState(() => userType = val!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: Text('وكيل / سمسار'),
                    value: 'agent',
                    groupValue: userType,
                    onChanged: (val) => setState(() => userType = val!),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => setState(() => userType = 'admin'),
              child: Text('دخول صاحب التطبيق (الأدمن) 🔑', style: TextStyle(color: Colors.red)),
            ),
            Divider(),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: userType == 'agent' ? 'الاسم الرباعي الكامل (مطابق للبطاقة)' : 'الاسم الثلاثي',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            SizedBox(height: 15),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: userType == 'admin' ? 'رقم الأدمن الخاص' : 'رقم الجوال اليمني الأساسي',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            
            if (userType == 'agent') ...[
              SizedBox(height: 15),
              TextField(
                controller: _phone2Controller,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'أرقام تواصل إضافية (تضاف لصفحتك)',
                  prefixIcon: Icon(Icons.phone_android),
                ),
              ),
              SizedBox(height: 15),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red[50], border: Border.all(color: Colors.red)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('⚠️ شروط الأمان الصارمة للوكلاء:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    Text('1. لا يُقبل الوكيل إلا بموافقة شخصية من "صاحب التطبيق".'),
                    Text('2. رفع صورة سيلفي واضحة مع البطاقة الشخصية.'),
                    Text('3. الالتزام بدفع عمولة التطبيق (5%) من كل صفقة تتم داخله.'),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: Icon(Icons.camera_alt),
                label: Text('التقاط صورة سيلفي مع البطاقة الشخصية 📸'),
              ),
              CheckboxListTile(
                title: Text('أتعهد بدفع 5% عمولة للتطبيق وأقبل بالحظر الفوري في حال التحايل', style: TextStyle(fontSize: 11)),
                value: agreedToStrictTerms,
                onChanged: (val) => setState(() => agreedToStrictTerms = val!),
              ),
            ],

            if (userType == 'client') ...[
              SizedBox(height: 15),
              OutlinedButton.icon(
                onPressed: () {},
                icon: Icon(Icons.qr_code_scanner),
                label: Text('تصوير كود (باركود) البطاقة الشخصية للتحقق السريع 🪪'),
              ),
            ],

            SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(padding: EdgeInsets.all(15), backgroundColor: userType == 'admin' ? Colors.red : Colors.indigo),
              onPressed: _handleLogin,
              child: Text(userType == 'admin' ? 'دخول لوحة تحكم الأدمن' : 'تسجيل وإرسال الطلب', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. لوحة تحكم الأدمن (صاحب التطبيق - السيطرة الكاملة)
// ==========================================
class AdminDashboardScreen extends StatefulWidget {
  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<String> pendingAgents = ["أحمد محمد (بانتظار موافقتك)", "خالد عبد الله (بانتظار موافقتك)"];
  List<String> pendingProperties = ["شقة مفروشة في الحوبان - 500 سعودي", "دور مستقل في المسبح - 800 دولار"];
  List<String> reports = ["بلاغ ضد إعلان وهمي رقم #102", "بلاغ عن وكيل حاول التحايل خارج التطبيق"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('لوحة تحكم الأدمن (صاحب التطبيق) 🛡️'),
        backgroundColor: Colors.red[900],
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen())),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📊 إحصائيات التطبيق:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Card(child: Padding(padding: EdgeInsets.all(16), child: Text('العمولات المحصلة:\n1,450', textAlign: TextAlign.center))),
                Card(child: Padding(padding: EdgeInsets.all(16), child: Text('العقارات النشطة:\n52 عقار', textAlign: TextAlign.center))),
              ],
            ),
            Divider(height: 30),

            // موافقة الوكلاء
            Text('👥 طلبات انضمام الوكلاء (بحاجة لموافقتك):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: pendingAgents.length,
              itemBuilder: (context, index) {
                return Card(
                  child: ListTile(
                    leading: Icon(Icons.person_add, color: Colors.orange),
                    title: Text(pendingAgents[index]),
                    subtitle: Text('تم رفع السيلفي + البطاقة + الاسم الرباعي'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.check, color: Colors.green),
                          onPressed: () {
                            setState(() => pendingAgents.removeAt(index));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تمت الموافقة على الوكيل وتفعيل حسابه!')));
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            setState(() => pendingAgents.removeAt(index));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم رفض وحظر الوكيل!')));
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (pendingAgents.isEmpty) Text('لا توجد طلبات وكلاء معلقة ✅', style: TextStyle(color: Colors.grey)),

            Divider(height: 30),

            // مراجعة العقارات
            Text('🏠 عقارات بانتظار مراجعتك ونشرها:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: pendingProperties.length,
              itemBuilder: (context, index) {
                return Card(
                  child: ListTile(
                    leading: Icon(Icons.home, color: Colors.blue),
                    title: Text(pendingProperties[index]),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: () {
                        setState(() => pendingProperties.removeAt(index));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم اعتماد نشر العقار!')));
                      },
                      child: Text('موافقة ونشر'),
                    ),
                  ),
                );
              },
            ),
            if (pendingProperties.isEmpty) Text('جميع العقارات تم مراجعتها ونشرها ✅', style: TextStyle(color: Colors.grey)),

            Divider(height: 30),

            // مركز البلاغات (ضد النصب)
            Text('🚨 مركز البلاغات ضد النصب والاحتيال:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red[700])),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                return Card(
                  color: Colors.red[50],
                  child: ListTile(
                    leading: Icon(Icons.warning, color: Colors.red),
                    title: Text(reports[index]),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () {
                        setState(() => reports.removeAt(index));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم اتخاذ إجراء وحظر المخالف بنجاح!')));
                      },
                      child: Text('اتخاذ إجراء وحظر'),
                    ),
                  ),
                );
              },
            ),
            if (reports.isEmpty) Text('لا توجد بلاغات نصب حالياً 🎉', style: TextStyle(color: Colors.green)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. الشاشة الرئيسية وإضافة عقار (تحديد GPS + عملات + 5% عمولة)
// ==========================================
class HomeScreen extends StatelessWidget {
  final String userType;
  final String userName;

  HomeScreen({required this.userType, required this.userName});

  @override
  Widget build(BuildContext context) {
    bool isPendingAgent = userType == 'agent_pending';

    return Scaffold(
      appBar: AppBar(
        title: Text('مسكني اليمن - مرحباً $userName'),
        actions: [
          IconButton(
            icon: Icon(Icons.chat),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen())),
          )
        ],
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isPendingAgent) ...[
                Icon(Icons.hourglass_empty, size: 60, color: Colors.orange),
                SizedBox(height: 15),
                Text('حسابك قيد المراجعة من قِبل "الأدمن" (صاحب التطبيق)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                SizedBox(height: 10),
                Text('لن تستطيع إضافة عقارات حتى يوافق عليك صاحب التطبيق يدوياً.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              ] else ...[
                Text('مرحباً بك في منصة مسكني الآمنة 🏡', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: Icon(Icons.add_home),
                  label: Text('إضافة عقار جديد (GPS + العملات الثلاث)'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddPropertyScreen())),
                ),
                SizedBox(height: 15),
                ElevatedButton.icon(
                  icon: Icon(Icons.message),
                  label: Text('فتح الدردشة المباشرة والعقود 💬'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen())),
                ),
              ],
              SizedBox(height: 30),
              TextButton(
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen())),
                child: Text('تسجيل الخروج', style: TextStyle(color: Colors.red)),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// شاشة إضافة العقار
class AddPropertyScreen extends StatefulWidget {
  @override
  _AddPropertyScreenState createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _priceController = TextEditingController();
  String _selectedCurrency = 'SAR';
  double yerRate = 1400.0;
  double usdRate = 0.265;
  String locationText = 'لم يتم تحديد الموقع';
  bool isLocating = false;
  String propertyStatus = 'متاح للإيجار 🟢'; // متاح أو تم الإيجار

  void _getAutoLocation() async {
    setState(() => isLocating = true);
    await Future.delayed(Duration(seconds: 1));
    setState(() {
      locationText = 'تم تحديد الموقع بدقة عبر الـ GPS 📍 (تعز)';
      isLocating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    double inputVal = double.tryParse(_priceController.text) ?? 0.0;
    double inSAR = _selectedCurrency == 'SAR' ? inputVal : (_selectedCurrency == 'YER' ? inputVal / yerRate : inputVal / usdRate);
    double inYER = inSAR * yerRate;
    double inUSD = inSAR * usdRate;
    double commission = inSAR * 0.05; // 5% عمولة التطبيق

    return Scaffold(
      appBar: AppBar(title: Text('إضافة عقار - نظام الوكيل الموثق')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(decoration: InputDecoration(labelText: 'عنوان العقار ووصفه (مثال: شقة في المسبح دور ثاني)')),
            SizedBox(height: 15),
            
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: _getAutoLocation,
              icon: Icon(Icons.my_location),
              label: Text(isLocating ? 'جاري التقاط الموقع...' : 'مشاركة موقعي الحالي تلقائياً (GPS 📍)'),
            ),
            Text(locationText, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)),
            SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'قيمة الإيجار'),
                    onChanged: (val) => setState(() {}),
                  ),
                ),
                SizedBox(width: 10),
                DropdownButton<String>(
                  value: _selectedCurrency,
                  items: ['SAR', 'YER', 'USD'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) => setState(() => _selectedCurrency = val!),
                ),
              ],
            ),
            SizedBox(height: 15),

            // صندوق العملات والعمولة
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الأسعار المحسوبة تلقائياً للعملاء:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('🇸🇦 بالسعودي: ${inSAR.toStringAsFixed(1)} SAR'),
                  Text('🇾🇪 باليمني: ${inYER.toStringAsFixed(0)} YER'),
                  Text('🇺🇸 بالدولار: ${inUSD.toStringAsFixed(1)} USD'),
                  Divider(),
                  Text('عمولة التطبيق المحفوظة (5%): ${commission.toStringAsFixed(1)} SAR', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            SizedBox(height: 15),

            // اختيار حالة العقار
            DropdownButtonFormField<String>(
              value: propertyStatus,
              items: ['متاح للإيجار 🟢', 'تم الإيجار 🔴'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) => setState(() => propertyStatus = val!),
              decoration: InputDecoration(labelText: 'حالة العقار الحالية'),
            ),
            SizedBox(height: 25),

            ElevatedButton(
              style: ElevatedButton.styleFrom(padding: EdgeInsets.all(15)),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم رفع العقار وإرساله للأدمن للمراجعة!')));
                Navigator.pop(context);
              },
              child: Text('نشر العقار للمراجعة 🚀'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 4. شاشة الدردشة الآمنة، زر البلاغ، وعقد العمولة
// ==========================================
class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<String> messages = [
    "السلام عليكم، هل الشقة لا تزال متاحة؟",
    "وعليكم السلام، نعم متاحة وتواصلنا تحت إشراف المنصة."
  ];
  final _msgController = TextEditingController();
  bool contractAgreed = false;
  bool isRated = false;

  void _sendMessage() {
    if (_msgController.text.isNotEmpty) {
      setState(() {
        messages.add(_msgController.text);
        _msgController.clear();
      });
    }
  }

  // نافذة الإبلاغ عن النصب
  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🚨 الإبلاغ عن إعلان وهمي أو نصب'),
        content: Text('هل تشك أن هذا الإعلان وهمي أو أن الطرف الآخر يحاول النصب؟ سيصل البلاغ مباشرة للوحة تحكم الأدمن لحظر الحساب فوراً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إرسال البلاغ للأدمن بنجاح. شكراً لحرصك!')));
            },
            child: Text('تأكيد وإرسال للأدمن'),
          ),
        ],
      ),
    );
  }

  // نافذة تقييم الوكيل
  void _showRatingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('⭐ تقييم الوكيل والخدمة'),
        content: Text('كيف كانت تجربتك في التعامل مع هذا الوكيل؟ تقييمك يساعد في بناء سمعة المنصة.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() => isRated = true);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('شكراً لتقييمك! تم حفظه في سجل الوكيل.')));
            },
            child: Text('تقييم 5 نجوم 🌟'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الدردشة الآمنة وعقد العمولة'),
        actions: [
          IconButton(
            icon: Icon(Icons.report_problem, color: Colors.amberAccent),
            onPressed: _showReportDialog,
            tooltip: 'إبلاغ عن نصب',
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            color: contractAgreed ? Colors.green[100] : Colors.amber[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(contractAgreed ? '✅ العقد مفعل (عمولة 5% محفوظة للأدمن)' : '⚠️ اضغط موافقة عند إتمام الاتفاق'),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: contractAgreed ? Colors.green : Colors.indigo),
                  onPressed: () {
                    setState(() => contractAgreed = !contractAgreed);
                    if (contractAgreed) _showRatingDialog(); // إظهار التييم بعد الاتفاق
                  },
                  child: Text(contractAgreed ? 'العقد مفعل 🤝' : 'موافق وإبرام العقد'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(10),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return Align(
                  alignment: index % 2 == 0 ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: index % 2 == 0 ? Colors.indigo[50] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(messages[index]),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: InputDecoration(hintText: 'اكتب رسالتك... (المحادثة مراقبة لضمان الأمان)'),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.indigo),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
