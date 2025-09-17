// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';


class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _repasswordController = TextEditingController();
  bool _isLoading = false;

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      await Provider.of<AuthProvider>(context, listen: false).register(
        _usernameController.text,
        _emailController.text,
        _passwordController.text,
        _repasswordController.text,
      );
      // اگر موفق بود، به صفحه اصلی برو
      // ignore: use_build_context_synchronously
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      debugPrint('Registration Error: $e');
      // خطا را نمایش بده (مثلاً با SnackBar)
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در ثبت‌نام: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ثبت‌نام')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'نام کاربری'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'لطفاً نام کاربری را وارد کنید';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'ایمیل'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'لطفاً ایمیل را وارد کنید';
                  }
                  if (!value.contains('@')) {
                    return 'ایمیل معتبر نیست';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'رمز عبور'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'لطفاً رمز عبور را وارد کنید';
                  }
                  if (value.length < 6) {
                    return 'رمز عبور باید حداقل ۶ کاراکتر باشد';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _repasswordController,
                decoration: const InputDecoration(labelText: 'تکرار رمز عبور'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'لطفاً رمز عبور را وارد کنید';
                  }
                  if (value.length < 6) {
                    return 'رمز عبور باید حداقل ۶ کاراکتر باشد';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _submitForm,
                      child: const Text('ثبت‌نام'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}