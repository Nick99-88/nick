class PhoneNormalization {
  static String normalize(String phone) {
    if (phone.isEmpty) return phone;
    
    phone = phone.trim();
    
    if (phone.startsWith('+')) return phone;
    
    if (phone.startsWith('0') && phone.length >= 10) {
      return '+92${phone.substring(1)}';
    }
    
    if (phone.startsWith('92') && phone.length == 12) {
      return '+$phone';
    }
    
    if (phone.length == 10 && phone.startsWith('3')) {
      return '+92$phone';
    }
    
    return phone;
  }

  static bool matches(String phone1, String phone2) {
    final normalized1 = normalize(phone1);
    final normalized2 = normalize(phone2);
    return normalized1 == normalized2;
  }

  static String formatForDisplay(String phone) {
    if (phone.startsWith('+92') && phone.length == 13) {
      return '0${phone.substring(3)}';
    }
    return phone;
  }
}
