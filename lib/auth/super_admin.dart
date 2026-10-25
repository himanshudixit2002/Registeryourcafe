const String superAdminEmail = 'himanshudixit2406@gmail.com';
// Super admin password is managed in Firebase Console -- never store in source.

bool isSuperAdmin(String? email) {
  if (email == null || email.isEmpty) return false;
  return email.trim().toLowerCase() == superAdminEmail;
}
