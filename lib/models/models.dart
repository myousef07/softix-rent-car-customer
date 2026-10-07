/// Shapes of the customer API responses. Amounts stay strings ("1035.00") as the API sends
/// them, so nothing is lost to floating point before it is shown.
library;

Map<String, dynamic> _map(Object? value) => Map<String, dynamic>.from(value as Map);

List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) item) => (value as List? ?? const []).map((e) => item(_map(e))).toList();

class Address {
  Address({this.city, this.district, this.street, this.buildingNumber, this.postalCode});

  final String? city;
  final String? district;
  final String? street;
  final String? buildingNumber;
  final String? postalCode;

  bool get isEmpty => [city, district, street, buildingNumber, postalCode].every((v) => v == null || v.isEmpty);

  String get line => [street, district, city].whereType<String>().where((s) => s.isNotEmpty).join('، ');

  factory Address.fromJson(Map<String, dynamic>? json) => Address(
    city: json?['city'] as String?,
    district: json?['district'] as String?,
    street: json?['street'] as String?,
    buildingNumber: json?['building_number'] as String?,
    postalCode: json?['postal_code'] as String?,
  );
}

class Profile {
  Profile({
    required this.id,
    required this.name,
    required this.firstName,
    required this.mobile,
    this.lastName = '',
    this.email,
    this.idNumber,
    this.licenseExpiry,
    required this.status,
    Address? address,
  }) : address = address ?? Address();

  final int id;
  final String name;
  final String firstName;
  final String lastName;
  final String mobile;
  final String? email;
  final String? idNumber;
  final String? licenseExpiry;
  final String status;
  final Address address;

  bool get isBlacklisted => status == 'blacklisted';

  /// The licence runs out within 30 days (or already has): worth a reminder before booking.
  bool get licenseExpiringSoon {
    final expiry = licenseExpiry == null ? null : DateTime.tryParse(licenseExpiry!);
    return expiry != null && expiry.isBefore(DateTime.now().add(const Duration(days: 30)));
  }

  /// +9665XXXXXXXX shown the way people write it: 05XXXXXXXX.
  String get localMobile => mobile.startsWith('+966') ? '0${mobile.substring(4)}' : mobile;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    firstName: json['first_name'] as String? ?? '',
    lastName: json['last_name'] as String? ?? '',
    mobile: json['mobile'] as String? ?? '',
    email: json['email'] as String?,
    idNumber: json['id_number'] as String?,
    licenseExpiry: json['license_expiry_date'] as String?,
    status: json['status'] as String? ?? 'active',
    address: Address.fromJson(json['address'] is Map ? _map(json['address']) : null),
  );
}

class Branch {
  Branch({required this.id, required this.name, this.city, this.district, this.address, this.phone, this.latitude, this.longitude});

  final int id;
  final String name;
  final String? city;
  final String? district;
  final String? address;
  final String? phone;
  final double? latitude;
  final double? longitude;

  String get place => [district, city].whereType<String>().where((s) => s.isNotEmpty).join('، ');

  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
    id: json['id'] as int,
    name: json['name'] as String,
    city: json['city'] as String?,
    district: json['district'] as String?,
    address: json['address'] as String?,
    phone: json['phone'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
  );
}

class Category {
  Category({required this.id, required this.name, this.description, this.imageUrl});

  final int id;
  final String name;
  final String? description;

  /// A photo of a car in this category, uploaded by the company (or its catalogue model).
  final String? imageUrl;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as int,
    name: json['name'] as String,
    description: json['description'] as String?,
    imageUrl: json['image_url'] as String?,
  );
}

class Extra {
  Extra({required this.id, required this.name, required this.pricingType, required this.price, required this.maxQuantity});

  final int id;
  final String name;
  final String pricingType;
  final String price;
  final int maxQuantity;

  String get unit => pricingType == 'per_day' ? 'لليوم' : 'للحجز';

  factory Extra.fromJson(Map<String, dynamic> json) => Extra(
    id: json['id'] as int,
    name: json['name'] as String,
    pricingType: json['pricing_type'] as String,
    price: json['price'].toString(),
    maxQuantity: (json['max_quantity'] as int?) ?? 1,
  );
}

class QuoteLine {
  QuoteLine({required this.type, required this.description, required this.amount, required this.discount});

  final String type;
  final String description;
  final String amount;
  final String discount;

  factory QuoteLine.fromJson(Map<String, dynamic> json) => QuoteLine(
    type: json['type'] as String,
    description: json['description'] as String,
    amount: json['amount'].toString(),
    discount: json['discount'].toString(),
  );
}

class Quote {
  Quote({
    required this.days,
    required this.subtotal,
    required this.discount,
    required this.vat,
    required this.total,
    required this.deposit,
    this.includedKm,
    this.lines = const [],
  });

  final int days;
  final String subtotal;
  final String discount;
  final String vat;
  final String total;
  final String deposit;
  final int? includedKm;
  final List<QuoteLine> lines;

  bool get hasDiscount => (double.tryParse(discount) ?? 0) > 0;

  /// Average rental price per day before VAT (weekly and monthly rates make it lower).
  double get perDay {
    final rental = lines.where((l) => l.type == 'rental').fold<double>(0, (sum, l) => sum + (double.tryParse(l.amount) ?? 0));
    return days == 0 ? 0 : rental / days;
  }

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
    days: json['days'] as int,
    subtotal: json['subtotal'].toString(),
    discount: json['discount'].toString(),
    vat: json['vat'].toString(),
    total: json['total'].toString(),
    deposit: json['deposit'].toString(),
    includedKm: json['included_km'] as int?,
    lines: _list(json['lines'], QuoteLine.fromJson),
  );
}

/// One category offered at a branch for the searched period.
class Offer {
  Offer({required this.category, required this.models, required this.available, required this.quote, this.seats});

  final Category category;
  final List<String> models;
  final bool available;
  final Quote quote;
  final int? seats;

  String get modelsLine => models.isEmpty ? '' : '${models.join(' أو ')} أو مماثل';

  factory Offer.fromJson(Map<String, dynamic> json) => Offer(
    category: Category.fromJson(_map(json['category'])),
    models: List<String>.from(json['models'] as List? ?? const []),
    available: json['available'] as bool? ?? false,
    quote: Quote.fromJson(_map(json['quote'])),
    seats: json['seats'] as int?,
  );
}

class ReservationExtra {
  ReservationExtra({required this.name, required this.quantity});

  final String name;
  final int quantity;

  factory ReservationExtra.fromJson(Map<String, dynamic> json) =>
      ReservationExtra(name: json['name'] as String? ?? '', quantity: json['quantity'] as int? ?? 1);
}

class Reservation {
  Reservation({
    required this.id,
    required this.number,
    required this.status,
    required this.statusLabel,
    required this.pickupAt,
    required this.returnAt,
    required this.days,
    required this.subtotal,
    required this.discount,
    required this.vat,
    required this.total,
    required this.deposit,
    this.category,
    this.branch,
    this.returnBranch,
    this.extras = const [],
    this.contractId,
  });

  final int id;
  final String number;
  final String status;
  final String statusLabel;
  final String pickupAt;
  final String returnAt;
  final int days;
  final String subtotal;
  final String discount;
  final String vat;
  final String total;
  final String deposit;
  final Category? category;
  final Branch? branch;
  final Branch? returnBranch;
  final List<ReservationExtra> extras;
  final int? contractId;

  bool get isActive => status == 'pending' || status == 'confirmed';

  factory Reservation.fromJson(Map<String, dynamic> json) => Reservation(
    id: json['id'] as int,
    number: json['number'] as String,
    status: json['status'] as String,
    statusLabel: json['status_label'] as String,
    pickupAt: json['pickup_at'] as String,
    returnAt: json['return_at'] as String,
    days: json['days'] as int? ?? 0,
    subtotal: json['subtotal'].toString(),
    discount: json['discount'].toString(),
    vat: json['vat'].toString(),
    total: json['total'].toString(),
    deposit: json['deposit_amount'].toString(),
    category: json['category'] is Map ? Category.fromJson(_map(json['category'])) : null,
    branch: json['branch'] is Map ? Branch.fromJson(_map(json['branch'])) : null,
    returnBranch: json['return_branch'] is Map ? Branch.fromJson(_map(json['return_branch'])) : null,
    extras: _list(json['extras'], ReservationExtra.fromJson),
    contractId: json['contract_id'] as int?,
  );
}

class ContractCharge {
  ContractCharge({required this.description, required this.amount, required this.vat});

  final String description;
  final String amount;
  final String vat;

  factory ContractCharge.fromJson(Map<String, dynamic> json) =>
      ContractCharge(description: json['description'] as String, amount: json['amount'].toString(), vat: json['vat'].toString());
}

class Balance {
  Balance({required this.invoiced, required this.paid, required this.due});

  final String invoiced;
  final String paid;
  final String due;

  bool get hasDue => (double.tryParse(due) ?? 0) > 0;

  factory Balance.fromJson(Map<String, dynamic> json) =>
      Balance(invoiced: json['invoiced'].toString(), paid: json['paid'].toString(), due: json['due'].toString());
}

class Contract {
  Contract({
    required this.id,
    required this.number,
    required this.status,
    required this.statusLabel,
    required this.isOverdue,
    required this.startAt,
    required this.expectedReturnAt,
    required this.days,
    required this.total,
    required this.vat,
    this.actualReturnAt,
    this.includedKm,
    this.car,
    this.plate,
    this.branch,
    this.returnBranch,
    this.charges = const [],
    this.balance,
  });

  final int id;
  final String number;
  final String status;
  final String statusLabel;
  final bool isOverdue;
  final String startAt;
  final String expectedReturnAt;
  final String? actualReturnAt;
  final int days;
  final String total;
  final String vat;
  final int? includedKm;
  final String? car;
  final String? plate;
  final Branch? branch;
  final Branch? returnBranch;
  final List<ContractCharge> charges;
  final Balance? balance;

  bool get isOpen => status == 'open';

  factory Contract.fromJson(Map<String, dynamic> json) {
    final vehicle = json['vehicle'] is Map ? _map(json['vehicle']) : null;
    final car = vehicle == null ? null : [vehicle['make'], vehicle['model'], vehicle['model_year']].whereType<Object>().join(' ').trim();

    return Contract(
      id: json['id'] as int,
      number: json['number'] as String,
      status: json['status'] as String,
      statusLabel: json['status_label'] as String,
      isOverdue: json['is_overdue'] as bool? ?? false,
      startAt: json['start_at'] as String,
      expectedReturnAt: json['expected_return_at'] as String,
      actualReturnAt: json['actual_return_at'] as String?,
      days: json['days'] as int,
      total: json['total'].toString(),
      vat: json['vat'].toString(),
      includedKm: json['included_km'] as int?,
      car: car,
      plate: vehicle?['plate'] as String?,
      branch: json['branch'] is Map ? Branch.fromJson(_map(json['branch'])) : null,
      returnBranch: json['return_branch'] is Map ? Branch.fromJson(_map(json['return_branch'])) : null,
      charges: _list(json['charges'], ContractCharge.fromJson),
      balance: json['balance'] is Map ? Balance.fromJson(_map(json['balance'])) : null,
    );
  }
}

class Invoice {
  Invoice({
    required this.id,
    required this.number,
    required this.status,
    required this.statusLabel,
    required this.issuedAt,
    required this.total,
    required this.due,
    this.contractNumber,
    required this.isCreditNote,
  });

  final int id;
  final String number;
  final String status;
  final String statusLabel;
  final String? issuedAt;
  final String total;
  final String due;
  final String? contractNumber;
  final bool isCreditNote;

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
    id: json['id'] as int,
    number: json['number'] as String,
    status: json['status'] as String,
    statusLabel: json['status_label'] as String,
    issuedAt: json['issued_at'] as String?,
    total: json['total'].toString(),
    due: json['due'].toString(),
    contractNumber: json['contract_number'] as String?,
    isCreditNote: json['document_type'] == 'credit_note',
  );
}

class PaymentPage {
  PaymentPage({required this.url, required this.amount});

  final String url;
  final String amount;

  factory PaymentPage.fromJson(Map<String, dynamic> json) => PaymentPage(url: json['url'] as String, amount: json['amount'].toString());
}
