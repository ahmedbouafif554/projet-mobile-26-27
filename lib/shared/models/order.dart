import 'address.dart';
import 'cart_item.dart';
import 'json_utils.dart';

/// Statuts d'une commande, du point de vue du client et du restaurant.
enum OrderStatus {
  pending('Nouvelle'),
  accepted('Acceptée'),
  preparing('En préparation'),
  ready('Prête'),
  delivering('En livraison'),
  delivered('Livrée'),
  cancelled('Annulée'),
  refunded('Remboursée');

  const OrderStatus(this.label);
  final String label;

  /// Commande encore en cours (suivi en temps réel).
  bool get isActive => index <= OrderStatus.delivering.index;

  /// Plus aucun changement possible.
  bool get isFinal =>
      this == delivered || this == cancelled || this == refunded;
}

enum PaymentMethod {
  card('Carte bancaire'),
  applePay('Apple Pay'),
  cash('Espèces');

  const PaymentMethod(this.label);
  final String label;
}

enum PaymentStatus {
  pending('En attente'),
  paid('Payée'),
  refunded('Remboursée');

  const PaymentStatus(this.label);
  final String label;
}

/// Étape de l'historique d'une commande (suivi, back office).
class OrderStatusEvent {
  const OrderStatusEvent({required this.status, required this.at, this.note});

  final OrderStatus status;
  final DateTime at;
  final String? note;

  factory OrderStatusEvent.fromJson(Map<String, dynamic> json) =>
      OrderStatusEvent(
        status: parseEnum(
          OrderStatus.values,
          json['status'],
          OrderStatus.pending,
        ),
        at: parseDate(json['at']),
        note: json['note'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'at': at.toIso8601String(),
    'note': note,
  };
}

/// Commande passée par un client auprès d'un restaurant.
class Order {
  const Order({
    required this.id,
    required this.reference,
    required this.userId,
    required this.customerName,
    required this.restaurantId,
    required this.restaurantName,
    required this.items,
    required this.deliveryAddress,
    this.deliveryFee = 0,
    this.serviceFee = 0,
    this.discount = 0,
    this.status = OrderStatus.pending,
    this.paymentMethod = PaymentMethod.card,
    this.paymentStatus = PaymentStatus.paid,
    this.courierId,
    this.note,
    this.promoCode,
    this.cancelReason,
    this.history = const [],
    required this.createdAt,
  });

  final String id;

  /// Numéro affiché (« SF1046 »).
  final String reference;
  final String userId;
  final String customerName;
  final String restaurantId;
  final String restaurantName;
  final List<CartItem> items;
  final Address deliveryAddress;
  final double deliveryFee;
  final double serviceFee;
  final double discount;
  final OrderStatus status;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final String? courierId;
  final String? note;
  final String? promoCode;
  final String? cancelReason;
  final List<OrderStatusEvent> history;
  final DateTime createdAt;

  double get subtotal => items.fold(0, (sum, i) => sum + i.totalPrice);

  double get total => (subtotal + deliveryFee + serviceFee - discount).clamp(
    0,
    double.infinity,
  );

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  /// « 2 × Classic Cheeseburger, 1 × Frites maison »
  String get summary =>
      [for (final i in items) '${i.quantity} × ${i.product.name}'].join(', ');

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    id: json['id'] as String,
    reference: json['reference'] as String,
    userId: json['userId'] as String,
    customerName: json['customerName'] as String? ?? '',
    restaurantId: json['restaurantId'] as String,
    restaurantName: json['restaurantName'] as String? ?? '',
    items: parseList(json['items'], CartItem.fromJson),
    deliveryAddress: Address.fromJson(
      json['deliveryAddress'] as Map<String, dynamic>,
    ),
    deliveryFee: parseDouble(json['deliveryFee']),
    serviceFee: parseDouble(json['serviceFee']),
    discount: parseDouble(json['discount']),
    status: parseEnum(OrderStatus.values, json['status'], OrderStatus.pending),
    paymentMethod: parseEnum(
      PaymentMethod.values,
      json['paymentMethod'],
      PaymentMethod.card,
    ),
    paymentStatus: parseEnum(
      PaymentStatus.values,
      json['paymentStatus'],
      PaymentStatus.pending,
    ),
    courierId: json['courierId'] as String?,
    note: json['note'] as String?,
    promoCode: json['promoCode'] as String?,
    cancelReason: json['cancelReason'] as String?,
    history: parseList(json['history'], OrderStatusEvent.fromJson),
    createdAt: parseDate(json['createdAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'reference': reference,
    'userId': userId,
    'customerName': customerName,
    'restaurantId': restaurantId,
    'restaurantName': restaurantName,
    'items': [for (final i in items) i.toJson()],
    'deliveryAddress': deliveryAddress.toJson(),
    'deliveryFee': deliveryFee,
    'serviceFee': serviceFee,
    'discount': discount,
    'status': status.name,
    'paymentMethod': paymentMethod.name,
    'paymentStatus': paymentStatus.name,
    'courierId': courierId,
    'note': note,
    'promoCode': promoCode,
    'cancelReason': cancelReason,
    'history': [for (final e in history) e.toJson()],
    'createdAt': createdAt.toIso8601String(),
  };

  Order copyWith({
    String? id,
    String? reference,
    String? userId,
    String? customerName,
    String? restaurantId,
    String? restaurantName,
    List<CartItem>? items,
    Address? deliveryAddress,
    double? deliveryFee,
    double? serviceFee,
    double? discount,
    OrderStatus? status,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    Object? courierId = keep,
    Object? note = keep,
    Object? promoCode = keep,
    Object? cancelReason = keep,
    List<OrderStatusEvent>? history,
    DateTime? createdAt,
  }) => Order(
    id: id ?? this.id,
    reference: reference ?? this.reference,
    userId: userId ?? this.userId,
    customerName: customerName ?? this.customerName,
    restaurantId: restaurantId ?? this.restaurantId,
    restaurantName: restaurantName ?? this.restaurantName,
    items: items ?? this.items,
    deliveryAddress: deliveryAddress ?? this.deliveryAddress,
    deliveryFee: deliveryFee ?? this.deliveryFee,
    serviceFee: serviceFee ?? this.serviceFee,
    discount: discount ?? this.discount,
    status: status ?? this.status,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    courierId: courierId == keep ? this.courierId : courierId as String?,
    note: note == keep ? this.note : note as String?,
    promoCode: promoCode == keep ? this.promoCode : promoCode as String?,
    cancelReason: cancelReason == keep
        ? this.cancelReason
        : cancelReason as String?,
    history: history ?? this.history,
    createdAt: createdAt ?? this.createdAt,
  );

  /// Nouveau statut ajouté à l'historique.
  Order withStatus(OrderStatus newStatus, {DateTime? at, String? note}) =>
      copyWith(
        status: newStatus,
        history: [
          ...history,
          OrderStatusEvent(
            status: newStatus,
            at: at ?? DateTime.now(),
            note: note,
          ),
        ],
      );
}
