class PasswordPolicy {
  static const int minLength = 8;

  static String? validate(String? password) {
    final p = (password ?? '').trim();
    if (p.length < minLength) {
      return 'كلمة المرور يجب أن تكون $minLength أحرف على الأقل';
    }
    if (!RegExp(r'[A-Z]').hasMatch(p)) {
      return 'يجب أن تحتوي كلمة المرور على حرف إنجليزي كبير (A-Z)';
    }
    if (!RegExp(r'[a-z]').hasMatch(p)) {
      return 'يجب أن تحتوي كلمة المرور على حرف إنجليزي صغير (a-z)';
    }
    if (!RegExp(r'[0-9]').hasMatch(p)) {
      return 'يجب أن تحتوي كلمة المرور على رقم واحد على الأقل (0-9)';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\[\]]').hasMatch(p)) {
      return 'يجب أن تحتوي كلمة المرور على رمز خاص واحد على الأقل (مثل @ # \$ !)';
    }
    return null;
  }

  /// يعيد درجة القوة من 0 إلى 5 لعرض مؤشر بصري للمستخدم
  static int strengthScore(String password) {
    int score = 0;
    if (password.length >= minLength) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\[\]]').hasMatch(password)) score++;
    return score;
  }
}
