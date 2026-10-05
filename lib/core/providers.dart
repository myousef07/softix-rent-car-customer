import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../models/paged_result.dart';
import 'api_client.dart';
import 'config.dart';
import 'session.dart';

/// Overridden in main() with the real instance.
final sessionProvider = Provider<Session>((ref) => throw UnimplementedError());

final apiProvider = Provider<ApiClient>((ref) => ref.watch(sessionProvider).api);

final repositoryProvider = Provider<Repository>((ref) => Repository(ref.watch(apiProvider)));

final branchesProvider = FutureProvider<List<Branch>>((ref) => ref.watch(repositoryProvider).branches());

final extrasProvider = FutureProvider<List<Extra>>((ref) => ref.watch(repositoryProvider).extras());

/// The renter's next pickup and current rental, for the home screen.
final upcomingReservationsProvider = FutureProvider.autoDispose<List<Reservation>>(
  (ref) async => (await ref.watch(repositoryProvider).reservations(scope: 'upcoming')).items,
);

final openContractsProvider = FutureProvider.autoDispose<List<Contract>>((ref) async => (await ref.watch(repositoryProvider).contracts(scope: 'open')).items);

/// Every API call the app makes, in one place.
class Repository {
  Repository(this.api);

  final ApiClient api;

  Map<String, dynamic> _data(Map<String, dynamic> json) => Map<String, dynamic>.from(json['data']);

  List<T> _items<T>(Map<String, dynamic> json, T Function(Map<String, dynamic>) item) =>
      (json['data'] as List).map((e) => item(Map<String, dynamic>.from(e))).toList();

  Future<List<Branch>> branches() async => _items(await api.get('/branches'), Branch.fromJson);

  Future<List<Extra>> extras() async => _items(await api.get('/extras'), Extra.fromJson);

  Future<List<Offer>> search({required int branchId, required String pickupAt, required String returnAt}) async =>
      _items(await api.get('/search', query: {'branch_id': branchId, 'pickup_at': pickupAt, 'return_at': returnAt}), Offer.fromJson);

  Future<Quote> quote(Map<String, dynamic> booking) async => Quote.fromJson(_data(await api.post('/quotes', data: booking)));

  Future<Reservation> book(Map<String, dynamic> booking) async => Reservation.fromJson(_data(await api.post('/reservations', data: booking)));

  Future<PagedResult<Reservation>> reservations({required String scope, String? cursor}) async =>
      PagedResult.fromJson(await api.get('/reservations', query: {'scope': scope, 'cursor': cursor}), Reservation.fromJson);

  Future<Reservation> reservation(int id) async => Reservation.fromJson(_data(await api.get('/reservations/$id')));

  Future<Reservation> cancelReservation(int id, String? reason) async =>
      Reservation.fromJson(_data(await api.post('/reservations/$id/cancel', data: {'reason': reason})));

  Future<PagedResult<Contract>> contracts({required String scope, String? cursor}) async =>
      PagedResult.fromJson(await api.get('/contracts', query: {'scope': scope, 'cursor': cursor}), Contract.fromJson);

  Future<Contract> contract(int id) async => Contract.fromJson(_data(await api.get('/contracts/$id')));

  Future<PaymentPage> payContract(int id) async => PaymentPage.fromJson(_data(await api.post('/contracts/$id/pay')));

  Future<PagedResult<Invoice>> invoices({String? cursor}) async =>
      PagedResult.fromJson(await api.get('/invoices', query: {'cursor': cursor}), Invoice.fromJson);

  Future<List<int>> contractPdf(int id) => api.bytes('/contracts/$id/pdf');

  Future<List<int>> invoicePdf(int id) => api.bytes('/invoices/$id/pdf');

  Future<Profile> updateProfile(Map<String, dynamic> changes) async => Profile.fromJson(_data(await api.patch('/me', data: changes)));

  /// «Call me back / send me a quote», before or without signing in. Returns the reference.
  Future<String> requestCallback(Map<String, dynamic> lead) async {
    final response = await api.post('/leads', data: {...lead, 'company_id': AppConfig.companyId, 'source': 'app'});
    return '${response['reference'] ?? ''}';
  }
}
