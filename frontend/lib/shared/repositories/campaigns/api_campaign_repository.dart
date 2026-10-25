import '../../models/app_notification.dart';
import '../base/api_crud_repository.dart';
import 'campaign_repository.dart';

class ApiCampaignRepository extends ApiCrudRepository<NotificationCampaign>
    implements CampaignRepository {
  ApiCampaignRepository(super.dio) : super(path: '/campaigns');

  @override
  NotificationCampaign fromJson(Map<String, dynamic> json) =>
      NotificationCampaign.fromJson(json);

  @override
  Map<String, dynamic> toJson(NotificationCampaign item) => item.toJson();

  @override
  String idOf(NotificationCampaign item) => item.id;

  @override
  Future<NotificationCampaign> send(String id) => patch(id, 'send');
}
