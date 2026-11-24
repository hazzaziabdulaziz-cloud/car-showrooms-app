const String kAdminEmail = 'hazzazi.abdulaziz@gmail.com';

bool isAdminEmail(String? email) {
  if (email == null) return false;
  return email.trim().toLowerCase() == kAdminEmail.trim().toLowerCase();
}
