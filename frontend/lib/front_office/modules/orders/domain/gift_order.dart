import 'package:flutter/material.dart';

/// Thèmes de carte cadeau numérique.
enum GiftCardDesign {
  festive(
    id: 'festive',
    label: 'Fête & Célébration',
    emoji: '🎉',
    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
    icon: Icons.celebration_rounded,
  ),
  birthday(
    id: 'birthday',
    label: 'Joyeux Anniversaire',
    emoji: '🎂',
    colors: [Color(0xFF845EC2), Color(0xFFD65DB1)],
    icon: Icons.cake_rounded,
  ),
  gourmet(
    id: 'gourmet',
    label: 'Festin Gourmand',
    emoji: '🍔',
    colors: [Color(0xFFFF9671), Color(0xFFFFC75F)],
    icon: Icons.restaurant_rounded,
  ),
  love(
    id: 'love',
    label: 'Avec Amour',
    emoji: '❤️',
    colors: [Color(0xFFFF5E7E), Color(0xFFFF9999)],
    icon: Icons.favorite_rounded,
  ),
  thankYou(
    id: 'thank_you',
    label: 'Mille Mercis',
    emoji: '🙏',
    colors: [Color(0xFF00C9A7), Color(0xFF4D8076)],
    icon: Icons.volunteer_activism_rounded,
  );

  const GiftCardDesign({
    required this.id,
    required this.label,
    required this.emoji,
    required this.colors,
    required this.icon,
  });

  final String id;
  final String label;
  final String emoji;
  final List<Color> colors;
  final IconData icon;

  static GiftCardDesign fromId(String? id) {
    return GiftCardDesign.values.firstWhere(
      (e) => e.id == id,
      orElse: () => GiftCardDesign.festive,
    );
  }
}

/// Modèle d'une commande envoyée en cadeau.
class GiftOrder {
  const GiftOrder({
    required this.orderId,
    required this.recipientName,
    this.id,
    this.recipientPhone,
    this.recipientEmail,
    this.senderName,
    this.isAnonymous = false,
    this.message,
    this.giftCardDesign = GiftCardDesign.festive,
    this.scheduledAt,
    this.qrCode,
    this.revealed = false,
    this.createdAt,
  });

  final String? id;
  final String orderId;
  final String recipientName;
  final String? recipientPhone;
  final String? recipientEmail;
  final String? senderName;
  final bool isAnonymous;
  final String? message;
  final GiftCardDesign giftCardDesign;
  final DateTime? scheduledAt;
  final String? qrCode;
  final bool revealed;
  final DateTime? createdAt;

  String get effectiveSender =>
      isAnonymous ? 'Un ami mystère 🤫' : (senderName?.isNotEmpty == true ? senderName! : 'Un proche');

  factory GiftOrder.fromJson(Map<String, dynamic> json) {
    return GiftOrder(
      id: json['id'] as String?,
      orderId: (json['orderId'] ?? json['order_id'] ?? '') as String,
      recipientName: (json['recipientName'] ?? json['recipient_name'] ?? '') as String,
      recipientPhone: (json['recipientPhone'] ?? json['recipient_phone']) as String?,
      recipientEmail: (json['recipientEmail'] ?? json['recipient_email']) as String?,
      senderName: (json['senderName'] ?? json['sender_name']) as String?,
      isAnonymous: json['isAnonymous'] == true || json['is_anonymous'] == 1,
      message: json['message'] as String?,
      giftCardDesign: GiftCardDesign.fromId(
        (json['giftCardDesign'] ?? json['gift_card_design']) as String?,
      ),
      scheduledAt: json['scheduledAt'] != null || json['scheduled_at'] != null
          ? DateTime.tryParse(
              (json['scheduledAt'] ?? json['scheduled_at']).toString(),
            )
          : null,
      qrCode: (json['qrCode'] ?? json['qr_code']) as String?,
      revealed: json['revealed'] == true || json['revealed'] == 1,
      createdAt: json['createdAt'] != null || json['created_at'] != null
          ? DateTime.tryParse(
              (json['createdAt'] ?? json['created_at']).toString(),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'recipientName': recipientName,
    if (recipientPhone != null) 'recipientPhone': recipientPhone,
    if (recipientEmail != null) 'recipientEmail': recipientEmail,
    if (!isAnonymous && senderName != null) 'senderName': senderName,
    'isAnonymous': isAnonymous,
    if (message != null) 'message': message,
    'giftCardDesign': giftCardDesign.id,
    if (scheduledAt != null) 'scheduledAt': scheduledAt!.toIso8601String(),
    if (qrCode != null) 'qrCode': qrCode,
  };
}

