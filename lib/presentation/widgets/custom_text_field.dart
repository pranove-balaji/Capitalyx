import 'package:flutter/material.dart';
import 'package:startup_application/presentation/widgets/translated_text.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isObscure;
  final TextInputType keyboardType;
  final IconData? prefixIcon;
  final String? Function(String?)? validator;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.isObscure = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        label: TranslatedText(label),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        filled: true,
      ),
    );
  }
}
