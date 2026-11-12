/// Pourboire pour un livreur SuperFaster.
class LivreurTip {
  const LivreurTip({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.createdAt,
    this.courierId,
    this.tipperId,
    this.percentage,
    this.thankYouMessage,
    this.paidAt,
    this.paymentMethod = 'card',
    this.orderReference,
  });

  final String id;
  final String orderId;
  final String? courierId;
  final String? tipperId;
  final double amount;
  final double? percentage;
  final String? thankYouMessage;
  final DateTime? paidAt;
  final String paymentMethod;
  final DateTime createdAt;
  final String? orderReference;

  static const List<double> predefinedPercentages = [5.0, 10.0, 15.0, 20.0];

  static const List<String> quickMessages = [
    'Super rapide ! ⚡',
    'Très aimable et souriant ! 😊',
    'Bravo et courage sous la pluie ! 🌧️',
    'Livraison parfaite, merci ! 🙌',
  ];

  factory LivreurTip.fromJson(Map<String, dynamic> json) {
    return LivreurTip(
      id: (json['id'] ?? '') as String,
      orderId: (json['orderId'] ?? json['order_id'] ?? '') as String,
      courierId: (json['courierId'] ?? json['courier_id']) as String?,
      tipperId: (json['tipperId'] ?? json['tipper_id']) as String?,
      amount: ((json['amount'] ?? 0) as num).toDouble(),
      percentage: json['percentage'] != null
          ? ((json['percentage']) as num).toDouble()
          : null,
      thankYouMessage: (json['thankYouMessage'] ?? json['thank_you_message']) as String?,
      paidAt: json['paidAt'] != null || json['paid_at'] != null
          ? DateTime.tryParse((json['paidAt'] ?? json['paid_at']).toString())
          : null,
      paymentMethod: (json['paymentMethod'] ?? json['payment_method'] ?? 'card') as String,
      createdAt: json['createdAt'] != null || json['created_at'] != null
          ? DateTime.tryParse((json['createdAt'] ?? json['created_at']).toString()) ?? DateTime.now()
          : DateTime.now(),
      orderReference: (json['orderReference'] ?? json['order_reference']) as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderId': orderId,
    if (courierId != null) 'courierId': courierId,
    'amount': amount,
    if (percentage != null) 'percentage': percentage,
    if (thankYouMessage != null) 'thankYouMessage': thankYouMessage,
    'paymentMethod': paymentMethod,
  };
}

