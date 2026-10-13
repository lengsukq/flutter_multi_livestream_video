import 'classroom_material.dart';

/// Optional upload integration owned by the host application. The SDK never
/// chooses storage or uploads files to a vendor account on its own.
abstract interface class ClassroomMaterialUploader {
  Future<ClassroomMaterial> upload({
    required String filename,
    required List<int> bytes,
    required String contentType,
  });
}
