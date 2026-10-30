import '../models/game_history.dart';
import 'api_service.dart';

class HistoryService {
  HistoryService._();
  static final instance = HistoryService._();

  /// 서버가 한 번에 줄 수 있는 최대치(100)만큼 최근 판을 가져온다.
  static const pageSize = 100;

  Future<HistorySummary> fetchMine() async {
    final data = await ApiService.instance.get('/history/me?limit=$pageSize')
        as Map<String, dynamic>;
    return HistorySummary.fromJson(data);
  }
}
