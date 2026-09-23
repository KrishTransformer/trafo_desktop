import '../models/lom_line_item.dart';
import '../../../home/domain/models/design_summary.dart';

abstract interface class FilesDesignRepository {
  Future<DesignSummary> fetchDesign(String entityId);

  Future<void> persistLom({
    required String entityId,
    required List<LomLineItem> items,
  });
}
