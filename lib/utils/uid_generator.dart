class UidGenerator {
  static String generateUid() {
    final now = DateTime.now();
    final yyyy = now.year.toString().padLeft(4, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    final ms = (now.millisecond ~/ 10).toString().padLeft(2, '0');
    
    return '$yyyy$mm$dd$hh$min$ss$ms';
  }
}
