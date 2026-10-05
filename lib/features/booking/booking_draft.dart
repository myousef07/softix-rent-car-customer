import '../../core/format.dart';
import '../../models/models.dart';

/// Where and when the renter wants a car, carried from the search to the results.
class SearchDraft {
  const SearchDraft({required this.branch, required this.pickup, required this.returnAt});

  final Branch branch;

  /// Wall-clock times in Riyadh.
  final DateTime pickup;
  final DateTime returnAt;

  String get pickupApi => Fmt.toApi(pickup);
  String get returnApi => Fmt.toApi(returnAt);
}

/// The chosen category on top of the search, carried to the confirmation screen.
class CheckoutDraft {
  const CheckoutDraft({required this.search, required this.offer});

  final SearchDraft search;
  final Offer offer;
}
