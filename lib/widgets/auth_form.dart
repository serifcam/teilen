import 'package:flutter/material.dart';

class AuthForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final String title;
  final List<Widget> fields;
  final String submitButtonText;
  final VoidCallback onSubmit;
  final Widget? alternateAction;

  const AuthForm({
    Key? key,
    required this.formKey,
    required this.title,
    required this.fields,
    required this.submitButtonText,
    required this.onSubmit,
    this.alternateAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF303030),
              const Color.fromARGB(255, 74, 75, 75),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ...fields,
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(submitButtonText,
                      style: const TextStyle(fontSize: 18)),
                ),
                if (alternateAction != null) alternateAction!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
