import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

/// Turns a nested map into multipart fields in the "a[b][0]" form Laravel reads,
/// adding photo files under [fileKey].
Future<FormData> toFormData(Map<String, dynamic> body, {String? fileKey, List<XFile> files = const []}) async {
  final form = FormData();

  void add(String key, Object? value) {
    if (value == null) return;
    if (value is Map) {
      value.forEach((k, v) => add('$key[$k]', v));
    } else if (value is List) {
      for (var i = 0; i < value.length; i++) {
        add('$key[$i]', value[i]);
      }
    } else if (value is bool) {
      form.fields.add(MapEntry(key, value ? '1' : '0'));
    } else {
      form.fields.add(MapEntry(key, value.toString()));
    }
  }

  body.forEach(add);

  for (var i = 0; i < files.length; i++) {
    final file = files[i];
    form.files.add(MapEntry('$fileKey[$i]', MultipartFile.fromBytes(await file.readAsBytes(), filename: file.name)));
  }

  return form;
}
