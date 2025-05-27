import 'package:flutter/material.dart';

class ErrorFeedback {
  static void showSnackbar(BuildContext context, String message,
      {bool isError = false}) {
    if (!context.mounted) return; // Check if context is still valid

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.errorContainer
            : Colors.green.shade700, // Use a success color
        behavior: SnackBarBehavior.floating, // M3 style
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        duration: const Duration(seconds: 3), // Adjust duration
      ),
    );
  }

  static void showErrorSnackbar(BuildContext context, String message) {
    showSnackbar(context, message, isError: true);
  }

  static void showSuccessSnackbar(BuildContext context, String message) {
    showSnackbar(context, message, isError: false);
  }

  // TODO: Implement animated Toast if needed
}
