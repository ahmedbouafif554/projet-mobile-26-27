import 'package:flutter/foundation.dart';

import '../../data/profile_mock_data.dart';
import '../../models/address.dart';
import '../../models/payment_method.dart';
import '../../models/user_profile.dart';

/// État du profil : informations, adresses, paiements et préférences.
class ProfileController extends ChangeNotifier {
  ProfileController._();
  static final ProfileController instance = ProfileController._();

  UserProfile _user = ProfileMockData.user;
  final List<Address> _addresses = [...ProfileMockData.addresses];
  final List<PaymentMethod> _payments = [...ProfileMockData.paymentMethods];
  String _selectedAddressId = ProfileMockData.addresses.first.id;
  String _selectedPaymentId = ProfileMockData.paymentMethods.first.id;
  String _languageCode = 'fr';

  UserProfile get user => _user;
  List<Address> get addresses => List.unmodifiable(_addresses);
  List<PaymentMethod> get payments => List.unmodifiable(_payments);
  String get languageCode => _languageCode;

  Address get selectedAddress => _addresses.firstWhere(
    (a) => a.id == _selectedAddressId,
    orElse: () => _addresses.first,
  );

  PaymentMethod get selectedPayment => _payments.firstWhere(
    (p) => p.id == _selectedPaymentId,
    orElse: () => _payments.first,
  );

  void updateUser(UserProfile user) {
    _user = user;
    notifyListeners();
  }

  void selectAddress(String id) {
    _selectedAddressId = id;
    notifyListeners();
  }

  void addAddress(Address address) {
    _addresses.add(address);
    _selectedAddressId = address.id;
    notifyListeners();
  }

  /// Supprime une adresse (on en garde toujours au moins une).
  bool removeAddress(String id) {
    if (_addresses.length <= 1) return false;
    _addresses.removeWhere((a) => a.id == id);
    if (_selectedAddressId == id) _selectedAddressId = _addresses.first.id;
    notifyListeners();
    return true;
  }

  void selectPayment(String id) {
    _selectedPaymentId = id;
    notifyListeners();
  }

  void addPayment(PaymentMethod method) {
    _payments.insert(0, method);
    _selectedPaymentId = method.id;
    notifyListeners();
  }

  void setLanguage(String code) {
    _languageCode = code;
    notifyListeners();
  }
}
