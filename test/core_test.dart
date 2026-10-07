import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:softix_customer/core/api_exception.dart';
import 'package:softix_customer/core/format.dart';
import 'package:softix_customer/core/push.dart';
import 'package:softix_customer/models/models.dart';
import 'package:softix_customer/widgets/common.dart';

import 'fake_api.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  group('Fmt', () {
    test('money uses western digits and the riyal', () {
      expect(Fmt.money('1035'), '1,035.00 ر.س');
      expect(Fmt.money(null), '0.00 ر.س');
    });

    test('UTC from the API is shown in Riyadh time, picked times go back with +03:00', () {
      expect(Fmt.dateTime('2026-09-20T21:30:00Z'), '21/09/2026 00:30');
      expect(Fmt.toApi(DateTime(2026, 9, 21, 9, 5)), '2026-09-21T09:05:00+03:00');
      expect(Fmt.dayTime(DateTime(2026, 10, 6, 10)), 'الثلاثاء 6/10 · 10:00');
    });
  });

  group('input', () {
    test('Saudi mobiles in every way people type them', () {
      expect(saudiMobile('0551234567'), '0551234567');
      expect(saudiMobile('+966 55 123 4567'), '0551234567');
      expect(saudiMobile('00966551234567'), '0551234567');
      expect(saudiMobile('551234567'), '0551234567');
      expect(saudiMobile('٠٥٥١٢٣٤٥٦٧'), '0551234567');
      expect(saudiMobile('0451234567'), isNull);
      expect(saudiMobile('055123'), isNull);
    });

    test('Arabic-Indic digits become western', () => expect(westernDigits('رمز ١٢٣٤٥٦'), 'رمز 123456'));

    test('server field errors are found by field', () {
      final error = ApiException(
        'x',
        statusCode: 422,
        fieldErrors: {
          'id_number': ['رقم الهوية مسجل'],
        },
      );
      expect(fieldError(error, 'id_number'), 'رقم الهوية مسجل');
      expect(fieldError(error, 'email'), isNull);
      expect(fieldError('not an api error', 'email'), isNull);
    });
  });

  group('ApiException', () {
    DioException failure(int status, Object data) {
      final options = RequestOptions(path: '/x');
      return DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: status, data: data),
      );
    }

    test('validation shows the first field message', () {
      final e = ApiException.from(
        failure(422, {
          'message': 'invalid',
          'errors': {
            'code': ['الرمز غير صحيح'],
          },
        }),
      );
      expect(e.message, 'الرمز غير صحيح');
      expect(e.fieldErrors['code'], ['الرمز غير صحيح']);
    });

    test('rate limits and lost connections read well', () {
      expect(ApiException.from(failure(429, '')).message, contains('طلبات كثيرة'));
      expect(ApiException.from(DioException(requestOptions: RequestOptions(path: '/x'))).message, contains('تعذّر الاتصال'));
      expect(ApiException.from(failure(401, '')).isUnauthorized, isTrue);
    });
  });

  group('models', () {
    test('category picture is optional', () {
      expect(Category.fromJson({'id': 1, 'name': 'اقتصادية'}).imageUrl, isNull);
      expect(Category.fromJson({'id': 1, 'name': 'اقتصادية', 'image_url': 'https://x.sa/storage/eco.png'}).imageUrl, 'https://x.sa/storage/eco.png');
    });

    test('profile with address and licence warning', () {
      final p = Profile.fromJson({...customer, 'license_expiry_date': DateTime.now().add(const Duration(days: 10)).toIso8601String().substring(0, 10)});
      expect(p.localMobile, '0551234567');
      expect(p.address.city, 'الرياض');
      expect(p.licenseExpiringSoon, isTrue);
      expect(Profile.fromJson(customer).licenseExpiringSoon, isFalse);
    });

    test('contract with car, balance and charges', () {
      final c = Contract.fromJson(contract);
      expect(c.car, 'هيونداي أكسنت 2022');
      expect(c.plate, 'ا ك ك 8297');
      expect(c.balance!.hasDue, isTrue);
      expect(c.charges.single.amount, '360.00');
      expect(c.isOpen, isTrue);
    });

    test('quote per day and reservation', () {
      expect(Quote.fromJson(quote()).perDay, 120);
      final r = Reservation.fromJson(reservation());
      expect(r.isActive, isTrue);
      expect(r.deposit, '500.00');
      expect(Reservation.fromJson(reservation(status: 'cancelled', label: 'ملغي')).isActive, isFalse);
    });
  });

  test('notifications open the contract or the invoices', () {
    expect(routeForPush({'type': 'rental_contract', 'id': '19'}), '/contracts/19');
    expect(routeForPush({'type': 'invoice', 'id': '4'}), '/invoices');
    expect(routeForPush({'event': 'campaign'}), isNull);
  });
}
