import 'package:flutter/material.dart';

import '../../models/address.dart';
import '../../models/payment_method.dart';

/// Icône associée à un type d'adresse.
IconData addressIcon(AddressType type) => switch (type) {
  AddressType.home => Icons.home_rounded,
  AddressType.work => Icons.work_rounded,
  AddressType.other => Icons.place_rounded,
};

/// Icône associée à un moyen de paiement.
IconData paymentIcon(PaymentType type) => switch (type) {
  PaymentType.visa || PaymentType.mastercard => Icons.credit_card_rounded,
  PaymentType.paypal => Icons.account_balance_wallet_rounded,
  PaymentType.applePay => Icons.phone_iphone_rounded,
  PaymentType.cash => Icons.payments_rounded,
};
