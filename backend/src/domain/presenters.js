/** Forme JSON exacte de `User.toJson()` / `Courier.toJson()` / `Address.toJson()`. */

function publicUser(user) {
  return {
    id: user.id,
    firstName: user.firstName,
    lastName: user.lastName,
    email: user.email,
    phone: user.phone ?? '',
    role: user.role,
    status: user.status,
    avatarUrl: user.avatarUrl ?? null,
    restaurantId: user.restaurantId ?? null,
    loyaltyPoints: user.loyaltyPoints ?? 0,
    createdAt: user.createdAt,
    lastLoginAt: user.lastLoginAt ?? null,
  };
}

function publicCourier(courier) {
  return {
    id: courier.id,
    userId: courier.userId,
    firstName: courier.firstName,
    lastName: courier.lastName,
    phone: courier.phone ?? '',
    avatarUrl: courier.avatarUrl ?? null,
    vehicle: courier.vehicle,
    plateNumber: courier.plateNumber ?? null,
    status: courier.status,
    documents: (courier.documents || []).map((doc) => ({
      type: doc.type,
      status: doc.status,
      uploadedAt: doc.uploadedAt,
      imageData: doc.imageData || null,
    })),
    rating: courier.rating,
    completedDeliveries: courier.completedDeliveries,
    totalEarnings: courier.totalEarnings,
    zone: courier.zone,
    latitude: courier.latitude,
    longitude: courier.longitude,
    joinedAt: courier.joinedAt,
  };
}

function publicAddress(address) {
  return {
    id: address.id,
    userId: address.userId,
    label: address.label,
    street: address.street,
    postalCode: address.postalCode,
    city: address.city,
    type: address.type,
    instructions: address.instructions ?? null,
    isDefault: Boolean(address.isDefault),
    latitude: address.latitude,
    longitude: address.longitude,
  };
}

module.exports = { publicUser, publicCourier, publicAddress };
