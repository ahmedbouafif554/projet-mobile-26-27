/// Livreur assigné à une commande.
class Courier {
  const Courier({
    required this.name,
    required this.photoUrl,
    required this.rating,
    required this.vehicle,
    required this.plate,
    required this.deliveries,
  });

  final String name;
  final String photoUrl;
  final double rating;
  final String vehicle;
  final String plate;
  final int deliveries;
}
