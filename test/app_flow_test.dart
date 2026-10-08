import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:softix_customer/app.dart';
import 'package:softix_customer/core/api_client.dart';
import 'package:softix_customer/core/i18n.dart';
import 'package:softix_customer/core/providers.dart';
import 'package:softix_customer/core/session.dart';

import 'fake_api.dart';

/// The screen's main list (text fields have scrollables of their own).
final _page = find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)).first;

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  late FakeApi api;
  late bool newNumber;

  tearDown(() => AppLanguage.current.value = 'ar');

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    newNumber = false;
    var cancelled = false;
    api = FakeApi({
      'POST /auth/otp': (_, _) => (200, {'message': 'أرسلنا رمز التحقق إلى جوالك.', 'expires_in': 300}),
      'POST /auth/verify': (body, _) => body['code'] != '123456'
          ? (
              422,
              {
                'message': 'x',
                'errors': {
                  'code': ['الرمز غير صحيح أو منتهي.'],
                },
              },
            )
          : newNumber
          ? (200, {'is_new': true, 'registration_token': 'claim-1'})
          : (200, {'is_new': false, 'token': '1|abc', 'customer': customer}),
      'POST /auth/register': (_, _) => (201, {'is_new': false, 'token': '1|new', 'customer': customer}),
      'GET /me': (_, _) => (200, {'data': customer}),
      'GET /branches': (_, _) => (
        200,
        {
          'data': [branch],
        },
      ),
      'GET /extras': (_, _) => (
        200,
        {
          'data': [
            {'id': 3, 'name': 'كرسي أطفال', 'pricing_type': 'per_day', 'price': '15.00', 'max_quantity': 1},
          ],
        },
      ),
      'GET /contracts': (_, query) => (200, page(query['scope'] == 'closed' ? [] : [contract])),
      'GET /contracts/19': (_, _) => (200, {'data': contract}),
      'GET /contracts/19/self-return': (_, _) => (
        200,
        {
          'data': {'available': true, 'reason': null, 'pending': null, 'last_rejected': null, 'min_photos': 4},
        },
      ),
      'GET /reservations': (_, query) => (200, page(query['scope'] == 'upcoming' && !cancelled ? [reservation()] : [])),
      'GET /search': (_, _) => (
        200,
        {
          'data': [
            {
              'category': {'id': 1, 'name': 'اقتصادية'},
              'models': ['هيونداي أكسنت'],
              'seats': 5,
              'available': true,
              'quote': quote(),
            },
            {
              'category': {'id': 2, 'name': 'فاخرة'},
              'models': [],
              'seats': 5,
              'available': false,
              'quote': quote(total: '1500.00'),
            },
          ],
        },
      ),
      'POST /quotes': (body, _) => body['promo_code'] == 'BAD'
          ? (
              422,
              {
                'message': 'x',
                'errors': {
                  'promo_code': ['رمز الخصم غير صالح.'],
                },
              },
            )
          : (200, {'data': quote(total: body['promo_code'] == 'SAVE10' ? '372.60' : '414.00', discount: body['promo_code'] == 'SAVE10' ? '36.00' : '0.00')}),
      'POST /reservations': (_, _) => (201, {'data': reservation()}),
      'GET /reservations/7': (_, _) => (200, {'data': cancelled ? reservation(status: 'cancelled', label: 'ملغي') : reservation()}),
      'POST /reservations/7/cancel': (_, _) {
        cancelled = true;
        return (200, {'data': reservation(status: 'cancelled', label: 'ملغي')});
      },
    });
  });

  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    late final Session session;
    session = Session(ApiClient(adapter: api, onUnauthorized: () => session.expire()));
    await session.restore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWithValue(session)],
        child: CustomerApp(session: session),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> signIn(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('mobile')), '٠٥٥١٢٣٤٥٦٧');
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pumpAndSettle();
    expect(api.sent('POST /auth/otp')['mobile'], '0551234567');

    await tester.enterText(find.byKey(const Key('code')), '999999');
    await tester.pumpAndSettle();
    expect(find.text('الرمز غير صحيح أو منتهي.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('code')), '123456');
    await tester.pumpAndSettle();
  }

  testWidgets('a known renter signs in with the SMS code and sees the car they have now', (tester) async {
    await start(tester);
    expect(find.byKey(const Key('mobile')), findsOneWidget);

    await signIn(tester);

    expect(find.textContaining('أهلاً فهد'), findsOneWidget);
    expect(find.text('سيارتك الحالية'), findsOneWidget);
    expect(find.textContaining('حجزك القادم'), findsOneWidget);

    await tester.tap(find.text('سيارتك الحالية'));
    await tester.pumpAndSettle();
    expect(find.text('RC-RUH-000019'), findsOneWidget);
    expect(find.textContaining('214.00'), findsWidgets);
    expect(find.byKey(const Key('pay')), findsOneWidget);
  });

  testWidgets('the renter switches to English and back; the app asks the server in that language', (tester) async {
    await start(tester);
    await tester.tap(find.byKey(const Key('language')));
    await tester.pumpAndSettle();

    expect(find.text('Mobile number'), findsOneWidget);
    expect(find.text('Book your car and follow your contracts and invoices from your phone'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byKey(const Key('mobile')))), TextDirection.ltr);
    expect(find.text('العربية'), findsOneWidget);

    await signIn(tester);
    expect(api.language, 'en');
    expect(find.text('Hello فهد'), findsOneWidget);
    expect(find.text('Your current car'), findsOneWidget);

    await tester.tap(find.text('My account'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('language')), 200, scrollable: _page);
    await tester.tap(find.byKey(const Key('language')));
    await tester.pumpAndSettle();

    expect(find.text('حسابي'), findsWidgets);
    expect(Directionality.of(tester.element(find.text('حسابي').first)), TextDirection.rtl);
    expect(await const FlutterSecureStorage().read(key: 'app_language'), 'ar');
  });

  testWidgets('a renter on a rental can return the car from the app, which asks for the photos first', (tester) async {
    await start(tester);
    await signIn(tester);

    await tester.tap(find.text('سيارتك الحالية'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('سلّم السيارة الآن'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('سلّم السيارة الآن'));
    await tester.pumpAndSettle();

    expect(find.text('تسليم السيارة'), findsOneWidget);
    expect(find.textContaining('التالية: الأمام'), findsOneWidget);
    expect(find.text('التوقيع'), findsNothing, reason: 'the signature is for pickup only');

    await tester.enterText(find.widgetWithText(TextFormField, 'قراءة العداد'), '25600');
    await tester.ensureVisible(find.text('إرسال طلب التسليم'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إرسال طلب التسليم'));
    await tester.pumpAndSettle();
    expect(find.textContaining('صوّر السيارة من الجهات الأربع'), findsOneWidget);
    expect(api.called('POST /contracts/19/self-return'), isFalse);
  });

  testWidgets('a renter books a car with an extra and a promo code, then cancels it', (tester) async {
    await start(tester);
    await signIn(tester);

    await tester.tap(find.byKey(const Key('search')));
    await tester.pumpAndSettle();
    expect(find.text('اقتصادية'), findsOneWidget);
    expect(find.text('غير متاحة في هذه الفترة'), findsOneWidget);

    await tester.tap(find.text('اقتصادية'));
    await tester.pumpAndSettle();
    expect(find.text('تأكيد الحجز'), findsWidgets);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(api.sent('POST /quotes')['extras'], [
      {'id': 3, 'quantity': 1},
    ]);

    await tester.enterText(find.byKey(const Key('promo')), 'bad');
    await tester.tap(find.text('تطبيق'));
    await tester.pumpAndSettle();
    expect(find.text('رمز الخصم غير صالح.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('promo')), 'save10');
    await tester.tap(find.text('تطبيق'));
    await tester.pumpAndSettle();
    expect(find.text('تم تطبيق الخصم ✓'), findsOneWidget);
    expect(find.textContaining('372.60'), findsWidgets);

    await tester.scrollUntilVisible(find.byKey(const Key('confirm-booking')), 300, scrollable: _page);
    await tester.tap(find.byKey(const Key('confirm-booking')));
    await tester.pumpAndSettle();
    final booking = api.sent('POST /reservations');
    expect(booking['category_id'], 1);
    expect(booking['promo_code'], 'SAVE10');
    expect(booking['pickup_at'], endsWith('+03:00'));
    expect(find.text('تم تأكيد حجزك'), findsOneWidget);

    await tester.tap(find.text('عرض الحجز'));
    await tester.pumpAndSettle();
    expect(find.text('RS-RUH-000007'), findsOneWidget);

    await tester.scrollUntilVisible(find.byKey(const Key('cancel-reservation')), 300, scrollable: _page);
    await tester.tap(find.byKey(const Key('cancel-reservation')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'إلغاء الحجز'));
    await tester.pumpAndSettle();
    expect(api.called('POST /reservations/7/cancel'), isTrue);
    expect(find.text('تم إلغاء الحجز.'), findsOneWidget);
    expect(find.byKey(const Key('cancel-reservation')), findsNothing, reason: 'a cancelled booking cannot be cancelled again');
    await tester.scrollUntilVisible(find.text('ملغي'), -300, scrollable: _page);

    // Back goes home, not out of the app.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search')), findsOneWidget);
  });

  testWidgets('a new number registers with identity and licence', (tester) async {
    newNumber = true;
    await start(tester);
    await signIn(tester);

    expect(find.text('حساب جديد'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('first_name')), 'فهد');
    await tester.enterText(find.byKey(const Key('last_name')), 'العتيبي');
    await tester.enterText(find.byKey(const Key('id_number')), '1000000008');
    await tester.enterText(find.byKey(const Key('license_number')), 'L12345');

    await tester.scrollUntilVisible(find.byKey(const Key('register')), 300, scrollable: _page);
    await tester.tap(find.byKey(const Key('register')));
    await tester.pumpAndSettle();
    expect(find.text('مطلوب'), findsNWidgets(2), reason: 'both dates are required');
    expect(api.called('POST /auth/register'), isFalse);

    await tester.scrollUntilVisible(find.byKey(const Key('birth')), -300, scrollable: _page);
    await tester.tap(find.byKey(const Key('birth')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حسنًا'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('license_expiry')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حسنًا'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.byKey(const Key('register')), 300, scrollable: _page);
    await tester.tap(find.byKey(const Key('register')));
    await tester.pumpAndSettle();

    final sent = api.sent('POST /auth/register');
    expect(sent['registration_token'], 'claim-1');
    expect(sent['id_type'], 'national_id');
    expect(sent['nationality'], 'SA');
    expect(sent['license_number'], 'L12345');
    expect(find.textContaining('أهلاً فهد'), findsOneWidget);
  });
}
