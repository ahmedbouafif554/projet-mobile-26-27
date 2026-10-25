import '../../models/app_notification.dart';
import '../base/mock_crud_repository.dart';
import 'campaign_repository.dart';

class MockCampaignRepository extends MockCrudRepository<NotificationCampaign>
    implements CampaignRepository {
  MockCampaignRepository(super.seed, {this.audienceSize = _defaultSizes})
    : super(idPrefix: 'camp');

  /// Nombre de destinataires simulé par audience.
  final Map<CampaignAudience, int> audienceSize;

  static const _defaultSizes = {
    CampaignAudience.all: 12480,
    CampaignAudience.clients: 11320,
    CampaignAudience.couriers: 412,
    CampaignAudience.restaurants: 748,
  };

  @override
  String idOf(NotificationCampaign item) => item.id;

  @override
  NotificationCampaign withId(NotificationCampaign item, String id) =>
      item.copyWith(id: id);

  @override
  Future<NotificationCampaign> send(String id) => mutate(
    id,
    (c) => c.copyWith(
      status: CampaignStatus.sent,
      sentAt: DateTime.now(),
      recipientCount: audienceSize[c.audience] ?? 0,
    ),
  );
}
