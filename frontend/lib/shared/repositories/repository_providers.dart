import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../mock/mock_catalog.dart';
import '../mock/mock_communication.dart';
import '../mock/mock_delivery.dart';
import '../mock/mock_orders.dart';
import '../mock/mock_users.dart';
import 'addresses/address_repository.dart';
import 'addresses/api_address_repository.dart';
import 'addresses/mock_address_repository.dart';
import 'campaigns/api_campaign_repository.dart';
import 'campaigns/campaign_repository.dart';
import 'campaigns/mock_campaign_repository.dart';
import 'cart/api_cart_repository.dart';
import 'cart/cart_repository.dart';
import 'cart/mock_cart_repository.dart';
import 'categories/api_category_repository.dart';
import 'categories/category_repository.dart';
import 'categories/mock_category_repository.dart';
import 'chats/api_chat_repository.dart';
import 'chats/chat_repository.dart';
import 'chats/mock_chat_repository.dart';
import 'couriers/api_courier_repository.dart';
import 'couriers/courier_repository.dart';
import 'couriers/mock_courier_repository.dart';
import 'deliveries/api_delivery_repository.dart';
import 'deliveries/delivery_repository.dart';
import 'deliveries/mock_delivery_repository.dart';
import 'favorites/api_favorite_repository.dart';
import 'favorites/favorite_repository.dart';
import 'favorites/mock_favorite_repository.dart';
import 'messages/api_message_repository.dart';
import 'messages/message_repository.dart';
import 'messages/mock_message_repository.dart';
import 'notifications/api_notification_repository.dart';
import 'notifications/mock_notification_repository.dart';
import 'notifications/notification_repository.dart';
import 'orders/api_order_repository.dart';
import 'orders/mock_order_repository.dart';
import 'orders/order_repository.dart';
import 'products/api_product_repository.dart';
import 'products/mock_product_repository.dart';
import 'products/product_repository.dart';
import 'restaurants/api_restaurant_repository.dart';
import 'restaurants/mock_restaurant_repository.dart';
import 'restaurants/restaurant_repository.dart';
import 'reviews/api_review_repository.dart';
import 'reviews/mock_review_repository.dart';
import 'reviews/review_repository.dart';
import 'users/api_user_repository.dart';
import 'users/mock_user_repository.dart';
import 'users/user_repository.dart';

// =============================================================================
// Un provider par dépôt : version mock (par défaut) ou API selon AppConfig.
// Les écrans et contrôleurs ne dépendent que des interfaces.
// Dans les tests : ProviderScope(overrides: [userRepositoryProvider
//   .overrideWithValue(MonFauxDepot())]).
// =============================================================================

const bool _mock = AppConfig.useMockData;

// --- Module 1 : utilisateurs ---------------------------------------------------
final userRepositoryProvider = Provider<UserRepository>(
  (ref) => _mock
      ? MockUserRepository(MockUsers.users)
      : ApiUserRepository(ref.watch(dioProvider)),
);

final addressRepositoryProvider = Provider<AddressRepository>(
  (ref) => _mock
      ? MockAddressRepository(MockUsers.addresses)
      : ApiAddressRepository(ref.watch(dioProvider)),
);

// --- Module 2 : catalogue -------------------------------------------------------
final restaurantRepositoryProvider = Provider<RestaurantRepository>(
  (ref) => _mock
      ? MockRestaurantRepository(MockCatalog.restaurants)
      : ApiRestaurantRepository(ref.watch(dioProvider)),
);

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => _mock
      ? MockCategoryRepository(MockCatalog.categories)
      : ApiCategoryRepository(ref.watch(dioProvider)),
);

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => _mock
      ? MockProductRepository(MockCatalog.products)
      : ApiProductRepository(ref.watch(dioProvider)),
);

final favoriteRepositoryProvider = Provider<FavoriteRepository>(
  (ref) => _mock
      ? MockFavoriteRepository(MockCatalog.favorites)
      : ApiFavoriteRepository(ref.watch(dioProvider)),
);

// --- Module 3 : panier et commandes -----------------------------------------------
final cartRepositoryProvider = Provider<CartRepository>(
  (ref) =>
      _mock ? MockCartRepository() : ApiCartRepository(ref.watch(dioProvider)),
);

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => _mock
      ? MockOrderRepository(MockOrders.orders)
      : ApiOrderRepository(ref.watch(dioProvider)),
);

// --- Module 4 : livraison -----------------------------------------------------------
final courierRepositoryProvider = Provider<CourierRepository>(
  (ref) => _mock
      ? MockCourierRepository(MockDelivery.couriers)
      : ApiCourierRepository(ref.watch(dioProvider)),
);

final deliveryRepositoryProvider = Provider<DeliveryRepository>(
  (ref) => _mock
      ? MockDeliveryRepository(MockDelivery.deliveries)
      : ApiDeliveryRepository(ref.watch(dioProvider)),
);

// --- Module 5 : avis, notifications et messagerie --------------------------------------
final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => _mock
      ? MockReviewRepository(MockCommunication.reviews)
      : ApiReviewRepository(ref.watch(dioProvider)),
);

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => _mock
      ? MockNotificationRepository(MockCommunication.notifications)
      : ApiNotificationRepository(ref.watch(dioProvider)),
);

final campaignRepositoryProvider = Provider<CampaignRepository>(
  (ref) => _mock
      ? MockCampaignRepository(MockCommunication.campaigns)
      : ApiCampaignRepository(ref.watch(dioProvider)),
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => _mock
      ? MockChatRepository(MockCommunication.chats)
      : ApiChatRepository(ref.watch(dioProvider)),
);

final messageRepositoryProvider = Provider<MessageRepository>(
  (ref) => _mock
      ? MockMessageRepository(MockCommunication.messages)
      : ApiMessageRepository(ref.watch(dioProvider)),
);
