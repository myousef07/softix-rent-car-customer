import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_exception.dart';

/// Downloads a PDF and shows it inside the app, with print and share buttons, so it works
/// on phones without a PDF viewer installed.
Future<void> openPdf(
  BuildContext context,
  Future<List<int>> Function() download,
  String name,
) async {
  final bytes = Uint8List.fromList(await download());
  if (!context.mounted) return;

  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(name, textDirection: TextDirection.ltr)),
        body: PdfPreview(
          build: (_) => bytes,
          pdfFileName: '$name.pdf',
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          allowPrinting: true,
          allowSharing: true,
          loadingWidget: const CircularProgressIndicator(),
        ),
      ),
    ),
  );
}

/// Payment pages open in the in-app browser so the renter comes straight back afterwards.
Future<void> openPaymentPage(String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
  if (!ok) throw ApiException('تعذّر فتح صفحة الدفع.');
}

Future<void> callPhone(String phone) =>
    launchUrl(Uri(scheme: 'tel', path: phone));

Future<void> openMap(double lat, double lng) => launchUrl(
  Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
  mode: LaunchMode.externalApplication,
);
