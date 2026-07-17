import '../models/lom_line_item.dart';

abstract interface class FilesDesignRepository {
  Future<void> persistLom({
    required String entityId,
    required List<LomLineItem> items,
  });
}
