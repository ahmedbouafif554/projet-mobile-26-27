import 'json_utils.dart';

enum DeliveryStatus {
  waiting('À assigner'),
  assigned('Assignée'),
  pickedUp('Récupérée'),
  inTransit('En route'),
  delivered('Livrée'),
  cancelled('Annulée');

  const DeliveryStatus(this.label);
  final String label;

  bool get isActive => index >= assigned.index && index <= inTransit.index;
}

/// Course d'un livreur : du restaurant (retrait) au client (dépôt).
class Delivery {
  const Delivery({
    required this.id,
    required this.orderId,
    required this.orderReference,
    this.courierId,
    this.status = DeliveryStatus.waiting,
    required this.pickupName,
    required this.pickupAddress,
    required this.customerName,
    required this.dropoffAddress,
    this.distanceKm = 2,
    this.fee = 4.5,
    this.tip = 0,
    this.estimatedMinutes = 25,
    required this.createdAt,
    this.assignedAt,
    this.pickedUpAt,
    this.deliveredAt,
  });

  final String id;
  final String orderId;
  final String orderReference;
  final String? courierId;
  final DeliveryStatus status;

  /// Restaurant où récupérer la commande.
  final String pickupName;
  final String pickupAddress;
  final String customerName;
  final String dropoffAddress;
  final double distanceKm;

  /// Rémunération du livreur pour la course (hors pourboire).
  final double fee;
  final double tip;
  final int estimatedMinutes;
  final DateTime createdAt;
  final DateTime? assignedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;

  double get earnings => fee + tip;

  factory Delivery.fromJson(Map<String, dynamic> json) => Delivery(
    id: json['id'] as String,
    orderId: json['orderId'] as String,
    orderReference: json['orderReference'] as String? ?? '',
    courierId: json['courierId'] as String?,
    status: parseEnum(
      DeliveryStatus.values,
      json['status'],
      DeliveryStatus.waiting,
    ),
    pickupName: json['pickupName'] as String? ?? '',
    pickupAddress: json['pickupAddress'] as String? ?? '',
    customerName: json['customerName'] as String? ?? '',
    dropoffAddress: json['dropoffAddress'] as String? ?? '',
    distanceKm: parseDouble(json['distanceKm'], 2),
    fee: parseDouble(json['fee'], 4.5),
    tip: parseDouble(json['tip']),
    estimatedMinutes: parseInt(json['estimatedMinutes'], 25),
    createdAt: parseDate(json['createdAt']),
    assignedAt: parseDateOrNull(json['assignedAt']),
    pickedUpAt: parseDateOrNull(json['pickedUpAt']),
    deliveredAt: parseDateOrNull(json['deliveredAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderId': orderId,
    'orderReference': orderReference,
    'courierId': courierId,
    'status': status.name,
    'pickupName': pickupName,
    'pickupAddress': pickupAddress,
    'customerName': customerName,
    'dropoffAddress': dropoffAddress,
    'distanceKm': distanceKm,
    'fee': fee,
    'tip': tip,
    'estimatedMinutes': estimatedMinutes,
    'createdAt': createdAt.toIso8601String(),
    'assignedAt': assignedAt?.toIso8601String(),
    'pickedUpAt': pickedUpAt?.toIso8601String(),
    'deliveredAt': deliveredAt?.toIso8601String(),
  };

  Delivery copyWith({
    String? id,
    String? orderId,
    String? orderReference,
    Object? courierId = keep,
    DeliveryStatus? status,
    String? pickupName,
    String? pickupAddress,
    String? customerName,
    String? dropoffAddress,
    double? distanceKm,
    double? fee,
    double? tip,
    int? estimatedMinutes,
    DateTime? createdAt,
    Object? assignedAt = keep,
    Object? pickedUpAt = keep,
    Object? deliveredAt = keep,
  }) => Delivery(
    id: id ?? this.id,
    orderId: orderId ?? this.orderId,
    orderReference: orderReference ?? this.orderReference,
    courierId: courierId == keep ? this.courierId : courierId as String?,
    status: status ?? this.status,
    pickupName: pickupName ?? this.pickupName,
    pickupAddress: pickupAddress ?? this.pickupAddress,
    customerName: customerName ?? this.customerName,
    dropoffAddress: dropoffAddress ?? this.dropoffAddress,
    distanceKm: distanceKm ?? this.distanceKm,
    fee: fee ?? this.fee,
    tip: tip ?? this.tip,
    estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
    createdAt: createdAt ?? this.createdAt,
    assignedAt: assignedAt == keep ? this.assignedAt : assignedAt as DateTime?,
    pickedUpAt: pickedUpAt == keep ? this.pickedUpAt : pickedUpAt as DateTime?,
    deliveredAt: deliveredAt == keep
        ? this.deliveredAt
        : deliveredAt as DateTime?,
  );
}
