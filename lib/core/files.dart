import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_exception.dart';

/// Saves a downloaded PDF to the app's temporary folder and opens it in the phone's viewer.
Future<void> openPdf(Future<List<int>> Function() download, String name) async {
  if (kIsWeb) throw ApiException('فتح الملفات متاح في تطبيق الجوال.');

  final bytes = await download();
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name.pdf');
  await file.writeAsBytes(bytes, flush: true);

  final result = await OpenFilex.open(file.path, type: 'application/pdf');
  if (result.type != ResultType.done) throw ApiException('لا يوجد تطبيق لعرض ملفات PDF على الجهاز.');
}

/// Payment pages open in the in-app browser so the renter comes straight back afterwards.
Future<void> openPaymentPage(String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
  if (!ok) throw ApiException('تعذّر فتح صفحة الدفع.');
}

Future<void> callPhone(String phone) => launchUrl(Uri(scheme: 'tel', path: phone));

Future<void> openMap(double lat, double lng) =>
    launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'), mode: LaunchMode.externalApplication);
