String? validateWeight(String? value) {
  if (value == null || value.trim().isEmpty) return 'Enter initial weight';
  final v = double.tryParse(value);
  if (v == null) return 'Enter a valid number';
  if (v <= 0) return 'Weight must be > 0';
  if (v > 5000) return 'Weight seems too large';
  return null;
}

String? validateDays(String? value) {
  if (value == null || value.trim().isEmpty) return 'Enter days grazed';
  final v = int.tryParse(value);
  if (v == null) return 'Enter a whole number';
  if (v <= 0) return 'Days must be > 0';
  if (v > 3650) return 'Days seems too large';
  return null;
}

String? validateYear(String? value) {
  if (value == null || value.trim().isEmpty) return 'Enter year';
  final v = int.tryParse(value);
  if (v == null) return 'Enter a valid year';
  if (v < 1900 || v > DateTime.now().year + 1) return 'Enter a plausible year';
  return null;
}
