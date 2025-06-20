// importは省略しています
import 'package:almost_zenly/components/auth_modal/components/animated_error_message.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'auth_modal_image.dart';
import 'auth_text_form_field.dart';
import 'submit_button.dart';

class SignInForm extends StatefulWidget {
  const SignInForm({super.key});

  @override
  State<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<SignInForm> {
  
  bool isLoading = false;
  String errorMessage = '';
// ---------  StateChanges ---------
  void _setErrorMessage(String message) {
    setState(() {
      errorMessage = message;
    });
  }

  void _setIsLoading(bool value) {
    setState(() {
      isLoading = value;
    });
  }

  void _clearErrorMessage() {
    setState(() {
      errorMessage = '';
    });
  }

 // ---------  Sign In ---------
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _setIsLoading(true);
      return await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _setErrorMessage('No user found for that email.');
      } else if (e.code == 'wrong-password') {
        _setErrorMessage('Wrong password provided for that user.');
      } else {
        _setErrorMessage('Unidentified error occurred while signing in.');
      }
    } finally {
      _setIsLoading(false);
    }
    return null;
  }


  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter some text';
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter some text';
    }
    return null;
  }

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          const Text(
          'Sign In',
          style: TextStyle(
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16.0),
        const AuthModalImage(),
        AnimatedErrorMessage(errorMessage: errorMessage),
        const SizedBox(height: 16.0),
        AuthTextFormField(
          controller: _emailController,
          validator: validateEmail,
          labelText: 'Email',
        ),
        const SizedBox(height: 16.0),
        AuthTextFormField(
          controller: _passwordController,
          obscureText: true,
          validator: validatePassword,
          labelText: 'Password',
        ),
        const SizedBox(height: 16.0),
        SubmitButton(
          labelName: 'サインイン',
          isLoading: isLoading,
          onTap: () => _submit(context)
        ),
        ],
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      // サインイン処理
      final UserCredential? user = await signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // 画面が破棄されている場合、後続処理を行わない
      if (!mounted) return;

      // 500ミリ秒待って、モーダルを閉じる
      if (user != null) {
        Future.delayed(
          const Duration(milliseconds: 500),
          Navigator.of(context).pop,
        );
      }
    }
  }

}