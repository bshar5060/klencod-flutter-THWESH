import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JamiaApp());
}

// --- نظام التخزين المحلي البسيط باستخدام SharedPreferences ---
class LocalStorage {
  static const String _keySettings = 'settings';
  static const String _keyMembers = 'members';
  static const String _keyPayments = 'payments';

  // الإعدادات الافتراضية
  static Future<Map<String, dynamic>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString(_keySettings);
    if (data == null) {
      final defaultSettings = {
        'daily_amount': 5,
        'password': '123',
        'start_date': DateTime.now().toIso8601String().split('T')[0],
      };
      await saveSettings(defaultSettings);
      return defaultSettings;
    }
    return jsonDecode(data);
  }

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySettings, jsonEncode(settings));
  }

  // الأعضاء
  static Future<List<Map<String, dynamic>>> getMembers() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString(_keyMembers);
    if (data == null) return [];
    List decoded = jsonDecode(data);
    return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> saveMembers(List<Map<String, dynamic>> members) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMembers, jsonEncode(members));
  }

  // الدفعات
  static Future<List<Map<String, dynamic>>> getPayments() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString(_keyPayments);
    if (data == null) return [];
    List decoded = jsonDecode(data);
    return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> savePayments(List<Map<String, dynamic>> payments) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPayments, jsonEncode(payments));
  }
}

class JamiaApp extends StatelessWidget {
  const JamiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'إدارة الجمعية اليومية',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- شاشة تسجيل الدخول ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _passwordController = TextEditingController();
  bool _isLoading = true;
  String _savedPassword = '123';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final settings = await LocalStorage.getSettings();
    setState(() {
      _savedPassword = settings['password'];
      _isLoading = false;
    });
  }

  void _login() {
    if (_passwordController.text == _savedPassword) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كلمة المرور غير صحيحة')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل دخول المدير')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('أدخل كلمة المرور الخاصة بلوحة التحكم', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'كلمة المرور',
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _login,
                    child: const Text('دخول'),
                  ),
                ],
              ),
            ),
    );
  }
}

// --- الشاشة الرئيسية ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _members = [];
  Map<String, dynamic> _settings = {};
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() async {
    final members = await LocalStorage.getMembers();
    final settings = await LocalStorage.getSettings();
    final payments = await LocalStorage.getPayments();
    setState(() {
      _members = members;
      _settings = settings;
      _payments = payments;
      _isLoading = false;
    });
  }

  void _addMemberDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة عضو جديد'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'اسم العضو'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                int newId = _members.isEmpty ? 1 : (_members.last['id'] as int) + 1;
                _members.add({'id': newId, 'name': controller.text});
                await LocalStorage.saveMembers(_members);
                Navigator.pop(context);
                _refreshData();
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int dailyAmount = _settings['daily_amount'] ?? 5;
    DateTime startDate = DateTime.parse(_settings['start_date'] ?? DateTime.now().toIso8601String());
    int totalDays = DateTime.now().difference(startDate).inDays + 1;
    if (totalDays < 1) totalDays = 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الجمعية اليومية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              _refreshData();
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.indigo.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('الاشتراك اليومي'),
                          Text('$dailyAmount ج.م', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('عدد الأعضاء'),
                          Text('${_members.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _members.isEmpty
                      ? const Center(child: Text('لا يوجد أعضاء مسجلين. أضف عضوًا جديدًا.'))
                      : ListView.builder(
                          itemCount: _members.length,
                          itemBuilder: (context, index) {
                            final member = _members[index];
                            final memberPayments = _payments.where((p) => p['member_id'] == member['id']).toList();
                            int totalPaid = memberPayments.fold(0, (sum, item) => sum + (item['amount'] as int));
                            int expectedAmount = totalDays * dailyAmount;
                            int arrears = expectedAmount - totalPaid;
                            if (arrears < 0) arrears = 0;

                            return ListTile(
                              title: Text(member['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('المدفوع: $totalPaid ج.م | المتأخرات: $arrears ج.م'),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MemberDetailScreen(
                                      memberId: member['id'],
                                      memberName: member['name'],
                                      dailyAmount: dailyAmount,
                                    ),
                                  ),
                                );
                                _refreshData();
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addMemberDialog,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

// --- شاشة تفاصيل العضو والدفعات ---
class MemberDetailScreen extends StatefulWidget {
  final int memberId;
  final String memberName;
  final int dailyAmount;

  const MemberDetailScreen({
    super.key,
    required this.memberId,
    required this.memberName,
    required this.dailyAmount,
  });

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  void _loadPayments() async {
    final allPayments = await LocalStorage.getPayments();
    setState(() {
      _payments = allPayments.where((p) => p['member_id'] == widget.memberId).toList();
      _isLoading = false;
    });
  }

  void _addPaymentDialog() {
    final amountController = TextEditingController(text: widget.dailyAmount.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تسجيل دفعة لـ ${widget.memberName}'),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'المبلغ المدفوع'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              int? amount = int.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                final allPayments = await LocalStorage.getPayments();
                int newId = allPayments.isEmpty ? 1 : (allPayments.last['id'] as int) + 1;
                String date = DateTime.now().toIso8601String().split('T')[0];

                allPayments.add({
                  'id': newId,
                  'member_id': widget.memberId,
                  'amount': amount,
                  'payment_date': date,
                });

                await LocalStorage.savePayments(allPayments);
                Navigator.pop(context);
                _loadPayments();
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _deleteMember() async {
    final members = await LocalStorage.getMembers();
    members.removeWhere((m) => m['id'] == widget.memberId);
    await LocalStorage.saveMembers(members);

    final payments = await LocalStorage.getPayments();
    payments.removeWhere((p) => p['member_id'] == widget.memberId);
    await LocalStorage.savePayments(payments);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    int totalPaid = _payments.fold(0, (sum, item) => sum + (item['amount'] as int));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.memberName),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteMember,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'إجمالي ما دفعـه العضو: $totalPaid ج.م',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(),
                const Text('سجل الدفعات التاريخي:', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: _payments.isEmpty
                      ? const Center(child: Text('لا توجد دفعات مسجلة بعد'))
                      : ListView.builder(
                          itemCount: _payments.length,
                          itemBuilder: (context, index) {
                            final payment = _payments[index];
                            return ListTile(
                              title: Text('المبلغ: ${payment['amount']} ج.م'),
                              subtitle: Text('التاريخ: ${payment['payment_date']}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () async {
                                  final allPayments = await LocalStorage.getPayments();
                                  allPayments.removeWhere((p) => p['id'] == payment['id']);
                                  await LocalStorage.savePayments(allPayments);
                                  _loadPayments();
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPaymentDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- شاشة الإعدادات ---
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _passController = TextEditingController();
  int _dailyAmount = 5;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final settings = await LocalStorage.getSettings();
    setState(() {
      _dailyAmount = settings['daily_amount'];
      _passController.text = settings['password'];
      _isLoading = false;
    });
  }

  void _saveSettings() async {
    final settings = await LocalStorage.getSettings();
    settings['daily_amount'] = _dailyAmount;
    settings['password'] = _passController.text;
    await LocalStorage.saveSettings(settings);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات الجمعية')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  DropdownButtonFormField<int>(
                    value: _dailyAmount,
                    decoration: const InputDecoration(labelText: 'قيمة الاشتراك اليومي'),
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5 جنيهات')),
                      DropdownMenuItem(value: 10, child: Text('10 جنيهات')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _dailyAmount = val);
                    },
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passController,
                    decoration: const InputDecoration(labelText: 'كلمة مرور المدير'),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _saveSettings,
                    child: const Text('حفظ التعديلات'),
                  ),
                ],
              ),
            ),
    );
  }
}
