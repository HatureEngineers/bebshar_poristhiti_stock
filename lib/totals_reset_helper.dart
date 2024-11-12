import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TotalsResetHelper {
  // Check and reset totals if needed
  static Future<void> checkAndResetTotals() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    DateTime now = DateTime.now();
    DocumentReference totalsDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('total')
        .doc('totals');

    DocumentSnapshot snapshot = await totalsDoc.get();

    if (snapshot.exists) {
      Map<String, dynamic> totalsData = snapshot.data() as Map<String, dynamic>;

      // Check and reset each field group (due, expense, cashbox, sale, purchase)
      await _resetIfNeeded(totalsDoc, totalsData, 'due', now);
      await _resetIfNeeded(totalsDoc, totalsData, 'expense', now);
      await _resetIfNeeded(totalsDoc, totalsData, 'cashbox', now);
      await _resetIfNeeded(totalsDoc, totalsData, 'sale', now);
      await _resetIfNeeded(totalsDoc, totalsData, 'purchase', now);
    }
  }

  static Future<void> _resetIfNeeded(
      DocumentReference totalsDoc, Map<String, dynamic> totalsData, String fieldPrefix, DateTime now) async {

    Map<String, dynamic> updates = {};

    if (_isNewDay(now, totalsData['last_${fieldPrefix}_daily_reset'])) {
      updates['${fieldPrefix}_daily'] = 0;
      updates['last_${fieldPrefix}_daily_reset'] = Timestamp.fromDate(now);
    }

    if (_isNewWeek(now, totalsData['last_${fieldPrefix}_weekly_reset'])) {
      updates['${fieldPrefix}_weekly'] = 0;
      updates['last_${fieldPrefix}_weekly_reset'] = Timestamp.fromDate(now);
    }

    if (_isNewMonth(now, totalsData['last_${fieldPrefix}_monthly_reset'])) {
      updates['${fieldPrefix}_monthly'] = 0;
      updates['last_${fieldPrefix}_monthly_reset'] = Timestamp.fromDate(now);
    }

    if (_isNewYear(now, totalsData['last_${fieldPrefix}_yearly_reset'])) {
      updates['${fieldPrefix}_yearly'] = 0;
      updates['last_${fieldPrefix}_yearly_reset'] = Timestamp.fromDate(now);
    }

    if (updates.isNotEmpty) {
      await totalsDoc.update(updates);
    }
  }

  static bool _isNewDay(DateTime now, Timestamp? lastReset) {
    if (lastReset == null) return true;
    DateTime lastResetDate = lastReset.toDate();
    return now.day != lastResetDate.day || now.month != lastResetDate.month || now.year != lastResetDate.year;
  }

  static bool _isNewWeek(DateTime now, Timestamp? lastReset) {
    if (lastReset == null) return true;
    DateTime lastResetDate = lastReset.toDate();
    return now.weekday == DateTime.monday && now.isAfter(lastResetDate.add(Duration(days: 7)));
  }

  static bool _isNewMonth(DateTime now, Timestamp? lastReset) {
    if (lastReset == null) return true;
    DateTime lastResetDate = lastReset.toDate();
    return now.month != lastResetDate.month || now.year != lastResetDate.year;
  }

  static bool _isNewYear(DateTime now, Timestamp? lastReset) {
    if (lastReset == null) return true;
    DateTime lastResetDate = lastReset.toDate();
    return now.year != lastResetDate.year;
  }
}
