import 'json_utils.dart';

enum VehicleType {
  bike('Vélo'),
  scooter('Scooter'),
  car('Voiture');

  const VehicleType(this.label);
  final String label;
}

enum CourierStatus {
  offline('Hors ligne'),
  available('Disponible'),
  busy('En livraison');

  const CourierStatus(this.label);
  final String label;

  bool get isOnline => this != offline;
}

enum DocumentStatus {
  pending('À vérifier'),
  approved('Validé'),
  rejected('Refusé');

  const DocumentStatus(this.label);
  final String label;
}

enum DocumentType {
  idCard("Pièce d'identité"),
  license('Permis de conduire'),
  insurance('Assurance');

  const DocumentType(this.label);
  final String label;
}

/// Justificatif envoyé par un livreur, vérifié dans le back office.
class CourierDocument {
  const CourierDocument({
    required this.type,
    this.status = DocumentStatus.pending,
    this.imageData,
    required this.uploadedAt,
  });

  final DocumentType type;
  final DocumentStatus status;

  /// Photo envoyée à l'inscription (`data:image/...;base64,...`).
  final String? imageData;
  final DateTime uploadedAt;

  factory CourierDocument.fromJson(Map<String, dynamic> json) =>
      CourierDocument(
        type: parseEnum(DocumentType.values, json['type'], DocumentType.idCard),
        status: parseEnum(
          DocumentStatus.values,
          json['status'],
          DocumentStatus.pending,
        ),
        imageData: json['imageData'] as String?,
        uploadedAt: parseDate(json['uploadedAt']),
      );

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'status': status.name,
    'imageData': imageData,
    'uploadedAt': uploadedAt.toIso8601String(),
  };

  CourierDocument copyWith({DocumentStatus? status, String? imageData}) =>
      CourierDocument(
        type: type,
        status: status ?? this.status,
        imageData: imageData ?? this.imageData,
        uploadedAt: uploadedAt,
      );
}

/// Livreur partenaire.
class Courier {
  const Courier({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.avatarUrl,
    this.vehicle = VehicleType.scooter,
    this.plateNumber,
    this.status = CourierStatus.offline,
    this.documents = const [],
    this.rating = 5,
    this.completedDeliveries = 0,
    this.totalEarnings = 0,
    this.zone = 'Paris',
    this.latitude = 48.8566,
    this.longitude = 2.3522,
    required this.joinedAt,
  });

  final String id;

  /// Compte utilisateur associé (rôle livreur).
  final String userId;
  final String firstName;
  final String lastName;
  final String phone;
  final String? avatarUrl;
  final VehicleType vehicle;
  final String? plateNumber;
  final CourierStatus status;
  final List<CourierDocument> documents;
  final double rating;
  final int completedDeliveries;
  final double totalEarnings;
  final String zone;
  final double latitude;
  final double longitude;
  final DateTime joinedAt;

  String get fullName => '$firstName $lastName';

  /// Statut global des justificatifs : refusé si l'un l'est, validé si tous
  /// le sont, à vérifier sinon.
  DocumentStatus get documentStatus {
    if (documents.isEmpty) return DocumentStatus.pending;
    if (documents.any((d) => d.status == DocumentStatus.rejected)) {
      return DocumentStatus.rejected;
    }
    return documents.every((d) => d.status == DocumentStatus.approved)
        ? DocumentStatus.approved
        : DocumentStatus.pending;
  }

  factory Courier.fromJson(Map<String, dynamic> json) => Courier(
    id: json['id'] as String,
    userId: json['userId'] as String,
    firstName: json['firstName'] as String,
    lastName: json['lastName'] as String,
    phone: json['phone'] as String? ?? '',
    avatarUrl: json['avatarUrl'] as String?,
    vehicle: parseEnum(
      VehicleType.values,
      json['vehicle'],
      VehicleType.scooter,
    ),
    plateNumber: json['plateNumber'] as String?,
    status: parseEnum(
      CourierStatus.values,
      json['status'],
      CourierStatus.offline,
    ),
    documents: parseList(json['documents'], CourierDocument.fromJson),
    rating: parseDouble(json['rating'], 5),
    completedDeliveries: parseInt(json['completedDeliveries']),
    totalEarnings: parseDouble(json['totalEarnings']),
    zone: json['zone'] as String? ?? 'Paris',
    latitude: parseDouble(json['latitude'], 48.8566),
    longitude: parseDouble(json['longitude'], 2.3522),
    joinedAt: parseDate(json['joinedAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'firstName': firstName,
    'lastName': lastName,
    'phone': phone,
    'avatarUrl': avatarUrl,
    'vehicle': vehicle.name,
    'plateNumber': plateNumber,
    'status': status.name,
    'documents': [for (final d in documents) d.toJson()],
    'rating': rating,
    'completedDeliveries': completedDeliveries,
    'totalEarnings': totalEarnings,
    'zone': zone,
    'latitude': latitude,
    'longitude': longitude,
    'joinedAt': joinedAt.toIso8601String(),
  };

  Courier copyWith({
    String? id,
    String? userId,
    String? firstName,
    String? lastName,
    String? phone,
    Object? avatarUrl = keep,
    VehicleType? vehicle,
    Object? plateNumber = keep,
    CourierStatus? status,
    List<CourierDocument>? documents,
    double? rating,
    int? completedDeliveries,
    double? totalEarnings,
    String? zone,
    double? latitude,
    double? longitude,
    DateTime? joinedAt,
  }) => Courier(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    phone: phone ?? this.phone,
    avatarUrl: avatarUrl == keep ? this.avatarUrl : avatarUrl as String?,
    vehicle: vehicle ?? this.vehicle,
    plateNumber: plateNumber == keep
        ? this.plateNumber
        : plateNumber as String?,
    status: status ?? this.status,
    documents: documents ?? this.documents,
    rating: rating ?? this.rating,
    completedDeliveries: completedDeliveries ?? this.completedDeliveries,
    totalEarnings: totalEarnings ?? this.totalEarnings,
    zone: zone ?? this.zone,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    joinedAt: joinedAt ?? this.joinedAt,
  );
}

/// Contrôle des pièces envoyées à l'inscription. Réservé à l'administrateur.
/// Les champs viennent de la saisie du livreur et du fichier reçu :
/// le texte imprimé sur la photo n'est pas deviné.
class CourierIdentityScan {
  const CourierIdentityScan({
    required this.courierId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.documents,
    this.scannedAt,
  });

  final String courierId;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final DateTime? scannedAt;
  final List<ScannedDocument> documents;

  factory CourierIdentityScan.fromJson(Map<String, dynamic> json) {
    final declared = json['declared'] is Map
        ? Map<String, dynamic>.from(json['declared'] as Map)
        : json;
    return CourierIdentityScan(
      courierId: json['courierId'] as String? ?? '',
      firstName: declared['firstName'] as String? ?? '',
      lastName: declared['lastName'] as String? ?? '',
      email: declared['email'] as String? ?? '',
      phone: declared['phone'] as String? ?? '',
      scannedAt: parseDateOrNull(json['scannedAt']),
      documents: parseList(json['documents'], ScannedDocument.fromJson),
    );
  }
}

class ScannedDocument {
  const ScannedDocument({
    required this.type,
    required this.label,
    required this.received,
    required this.bytes,
    required this.status,
    this.format,
    this.uploadedAt,
    this.imageData,
    this.text = '',
  });

  final DocumentType type;
  final String label;
  final bool received;
  final String? format;
  final int bytes;
  final DocumentStatus status;
  final DateTime? uploadedAt;
  final String? imageData;
  final String text;

  factory ScannedDocument.fromJson(Map<String, dynamic> json) {
    return ScannedDocument(
      type: parseEnum(DocumentType.values, json['type'], DocumentType.idCard),
      label: json['label'] as String? ?? '',
      received: json['received'] == true,
      format: json['format']?.toString(),
      bytes: parseInt(json['bytes']),
      status: parseEnum(
        DocumentStatus.values,
        json['status'],
        DocumentStatus.pending,
      ),
      uploadedAt: parseDateOrNull(json['uploadedAt']),
      imageData: json['imageData']?.toString(),
      text: json['text'] as String? ?? '',
    );
  }
}
