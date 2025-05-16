import 'package:flutter/material.dart';

class AuthForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final String title;
  final List<Widget> fields;
  final String submitButtonText;
  final VoidCallback onSubmit;
  final Widget? alternateAction;
  final bool isLoading;

  const AuthForm({
    super.key,
    required this.formKey,
    required this.title,
    required this.fields,
    required this.submitButtonText,
    required this.onSubmit,
    this.alternateAction,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Başlık ve minik ikon
            Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Color(0xFF263B36)
                        : Color(0xFF00C3A5).withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  padding: EdgeInsets.all(16),
                  child: Icon(Icons.account_circle_rounded,
                      color: Color(0xFF00C3A5), size: 40),
                ),
                SizedBox(height: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.bold,
                    fontSize: 25,
                    color:
                        isDark ? Colors.tealAccent.shade200 : Color(0xFF00735E),
                  ),
                ),
                SizedBox(height: 12),
              ],
            ),

            // Form Card
            Material(
              borderRadius: BorderRadius.circular(22),
              color: isDark ? Color(0xFF232D2C) : Colors.white,
              elevation: 4,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
                child: Form(
                  key: formKey,
                  child: Column(
                    children: [
                      ...fields,
                      SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : onSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF00C3A5),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                          child: isLoading
                              ? CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2)
                              : Text(
                                  submitButtonText,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (alternateAction != null) ...[
              SizedBox(height: 18),
              alternateAction!,
            ],
          ],
        ),
      ),
    );
  }
}
