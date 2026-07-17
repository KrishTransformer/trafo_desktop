import '../models/lom_line_item.dart';
import '../models/lom_request.dart';

abstract interface class FilesLomRepository {
  Future<List<LomLineItem>> generateLom(LomRequest request);
}
