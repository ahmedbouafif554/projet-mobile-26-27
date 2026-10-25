import '../../models/app_notification.dart';
import '../base/crud_repository.dart';

/// Campagnes de notifications envoyées à tous (Module 5, back office).
abstract interface class CampaignRepository
    implements CrudRepository<NotificationCampaign> {
  /// Envoie la campagne immédiatement.
  Future<NotificationCampaign> send(String id);
}
