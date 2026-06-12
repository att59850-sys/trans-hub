import 'package:flutter/material.dart';
import '../services/data_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'shell.dart';

final _ds = DataService.instance;

/// Account tab: shows auth when logged out, profile when logged in.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final u = _ds.currentUser;
    if (u == null) return const AuthScreen(embedded: true);

    return Scaffold(
      appBar: const BrandAppBar(title: 'Account'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.blue50,
                child: Text(_initials(u.name),
                    style: const TextStyle(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w800,
                        fontSize: 20))),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(u.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  Text(u.email,
                      style: const TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                        color: AppColors.blue50,
                        borderRadius: BorderRadius.circular(999)),
                    child: Text(
                        u.role == UserRole.company ? 'Provider' : 'Customer',
                        style: const TextStyle(
                            color: AppColors.blue,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ),
                ])),
          ]),
        ),
        const SizedBox(height: 16),
        _tile(Icons.location_on, 'Location',
            _ds.location.isEmpty ? 'Not set' : _ds.location),
        _tile(Icons.favorite, 'Saved providers',
            '${_ds.favorites.length} saved'),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Reset demo data?'),
                content: const Text(
                    'This clears all local data and restores the original seed providers, bookings and reviews.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Reset')),
                ],
              ),
            );
            if (ok == true) {
              await _ds.resetAll();
              if (context.mounted) showToast(context, 'Demo data reset');
            }
          },
          icon: const Icon(Icons.restart_alt),
          label: const Text('Reset demo data'),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              _ds.logout();
              showToast(context, 'Logged out');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
        ),
      ]),
    );
  }

  Widget _tile(IconData icon, String label, String value) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(icon, color: AppColors.blue),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(value, style: const TextStyle(color: AppColors.muted)),
        ]),
      );

  String _initials(String n) {
    final parts = n.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
  }
}

/// Combined login / signup screen.
class AuthScreen extends StatefulWidget {
  final bool embedded; // shown inside a tab (no back button)
  final bool startAsCompany;
  const AuthScreen({this.embedded = false, this.startAsCompany = false, super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  late UserRole _role;
  final _name = TextEditingController();
  final _company = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _role = widget.startAsCompany ? UserRole.company : UserRole.customer;
    if (widget.startAsCompany) _isLogin = false;
  }

  void _submit() {
    setState(() => _error = null);
    try {
      if (_isLogin) {
        final u = _ds.login(
            email: _email.text.trim(), password: _password.text);
        if (!widget.embedded && mounted) Navigator.pop(context);
        showToast(context, 'Welcome back, ${u.name.split(' ').first}');
      } else {
        if (_name.text.trim().isEmpty) {
          setState(() => _error = 'Please enter your name.');
          return;
        }
        _ds.signup(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          role: _role,
          companyName: _company.text.trim(),
        );
        if (!widget.embedded && mounted) Navigator.pop(context);
        showToast(context, 'Account created — welcome!');
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
          Icon(Icons.local_shipping, color: AppColors.blue, size: 30),
          SizedBox(width: 8),
          Text('TransportHub',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_isLogin ? 'Welcome back' : 'Create your account',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
                _isLogin
                    ? 'Log in to book services or manage your business.'
                    : 'Join TransportHub in seconds.',
                style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            if (!_isLogin) ...[
              _roleToggle(),
              const SizedBox(height: 14),
              TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Full name')),
              const SizedBox(height: 12),
              if (_role == UserRole.company) ...[
                TextField(
                    controller: _company,
                    decoration:
                        const InputDecoration(labelText: 'Company name')),
                const SizedBox(height: 12),
              ],
            ],
            TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password')),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: Icon(_isLogin ? Icons.login : Icons.person_add),
                label: Text(_isLogin ? 'Log in' : 'Create account'),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => setState(() {
                  _isLogin = !_isLogin;
                  _error = null;
                }),
                child: Text(_isLogin
                    ? "No account? Sign up"
                    : 'Already have an account? Log in'),
              ),
            ),
          ]),
        ),
        if (_isLogin) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppColors.blue50,
                border: Border.all(color: const Color(0xFFCFE0FB)),
                borderRadius: BorderRadius.circular(14)),
            child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Demo logins',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 6),
                  Text('Customer → customer@demo.com / demo123',
                      style: TextStyle(fontSize: 13, color: AppColors.ink2)),
                  Text('Provider → admin@transglobalfreight.com / demo123',
                      style: TextStyle(fontSize: 13, color: AppColors.ink2)),
                ]),
          ),
        ],
      ],
    );

    if (widget.embedded) {
      return Scaffold(
          appBar: const BrandAppBar(title: 'Account'), body: body);
    }
    return Scaffold(appBar: AppBar(title: const Text('Account')), body: body);
  }

  Widget _roleToggle() {
    Widget btn(UserRole role, IconData icon, String label) {
      final active = _role == role;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _role = role),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: active ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: active
                    ? const [
                        BoxShadow(color: Color(0x14102E3E), blurRadius: 4)
                      ]
                    : null),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon,
                  size: 18,
                  color: active ? AppColors.blue : AppColors.ink2),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: active ? AppColors.blue : AppColors.ink2)),
            ]),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
          color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        btn(UserRole.customer, Icons.person, "I'm a customer"),
        const SizedBox(width: 8),
        btn(UserRole.company, Icons.store, "I'm a provider"),
      ]),
    );
  }
}
