import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Answers API calls from canned JSON and records what the app sent.
class FakeApi implements HttpClientAdapter {
  FakeApi(this.routes);

  /// "METHOD /path" → (request body) → (status, json).
  final Map<String, (int, Object?) Function(Map<String, dynamic> body, Map<String, dynamic> query)> routes;
  final calls = <(String, Map<String, dynamic>)>[];

  /// The Accept-Language of the last request.
  String? language;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final key = '${options.method} ${options.path}';
    final body = options.data is Map ? Map<String, dynamic>.from(options.data as Map) : <String, dynamic>{};
    calls.add((key, body));
    language = options.headers['Accept-Language'] as String?;

    final handler = routes[key];
    final (status, json) = handler == null ? (404, {'message': 'not faked: $key'}) : handler(body, options.queryParameters);

    return ResponseBody.fromString(
      jsonEncode(json),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  bool called(String key) => calls.any((c) => c.$1 == key);

  Map<String, dynamic> sent(String key) => calls.lastWhere((c) => c.$1 == key).$2;

  @override
  void close({bool force = false}) {}
}

const branch = {
  'id': 1,
  'code': 'RUH',
  'name': 'الرياض — العليا',
  'city': 'الرياض',
  'district': 'العليا',
  'address': null,
  'phone': '+966112345678',
  'latitude': 24.7,
  'longitude': 46.6,
};

const customer = {
  'id': 61,
  'type': 'individual',
  'name': 'فهد العتيبي',
  'first_name': 'فهد',
  'last_name': 'العتيبي',
  'id_type': 'national_id',
  'id_number': '10••••••39',
  'nationality': 'SA',
  'mobile': '+966551234567',
  'email': null,
  'license_number': null,
  'license_expiry_date': '2031-01-01',
  'status': 'active',
  'address': {'city': 'الرياض', 'district': null, 'street': null, 'building_number': null, 'postal_code': null},
};

Map<String, Object?> quote({String total = '414.00', String discount = '0.00'}) => {
  'days': 3,
  'subtotal': '360.00',
  'discount': discount,
  'vat': '54.00',
  'total': total,
  'deposit': '500.00',
  'included_km': 750,
  'lines': [
    {'type': 'rental', 'description': 'إيجار 3 أيام', 'amount': '360.00', 'discount': discount, 'vat': '54.00'},
  ],
};

Map<String, Object?> reservation({String status = 'confirmed', String label = 'مؤكد'}) => {
  'id': 7,
  'number': 'RS-RUH-000007',
  'status': status,
  'status_label': label,
  'pickup_at': '2030-01-02T07:00:00Z',
  'return_at': '2030-01-05T07:00:00Z',
  'days': 3,
  'subtotal': '360.00',
  'discount': '0.00',
  'vat': '54.00',
  'total': '414.00',
  'deposit_amount': '500.00',
  'category': {'id': 1, 'name': 'اقتصادية', 'image_url': 'https://rent.example.sa/storage/vehicle-categories/eco.png'},
  'branch': branch,
  'return_branch': branch,
  'extras': [],
  'contract_id': null,
};

const contract = {
  'id': 19,
  'number': 'RC-RUH-000019',
  'status': 'open',
  'status_label': 'ساري',
  'is_overdue': false,
  'vehicle': {'make': 'هيونداي', 'model': 'أكسنت', 'model_year': 2022, 'plate': 'ا ك ك 8297'},
  'branch': branch,
  'return_branch': branch,
  'start_at': '2030-01-02T07:00:00Z',
  'expected_return_at': '2030-01-05T07:00:00Z',
  'actual_return_at': null,
  'days': 3,
  'included_km': 750,
  'total': '414.00',
  'vat': '54.00',
  'charges': [
    {'type': 'rental', 'description': 'إيجار 3 أيام', 'amount': '360.00', 'discount': '0.00', 'vat': '54.00'},
  ],
  'balance': {'invoiced': '414.00', 'paid': '200.00', 'due': '214.00'},
};

Map<String, Object?> page(List<Object?> items) => {
  'data': items,
  'meta': {'next_cursor': null},
};
