class Address {
  final String fullName;
  final String phone;
  final String houseFlat;
  final String streetArea;
  final String city;
  final String state;
  final String pinCode;

  const Address({
    required this.fullName,
    required this.phone,
    required this.houseFlat,
    required this.streetArea,
    required this.city,
    required this.state,
    required this.pinCode,
  });

  String get fullAddress => '$houseFlat, $streetArea, $city, $state - $pinCode';

  Map<String, dynamic> toMap() => {
        'fullName': fullName,
        'phone': phone,
        'houseFlat': houseFlat,
        'streetArea': streetArea,
        'city': city,
        'state': state,
        'pinCode': pinCode,
      };

  factory Address.fromMap(Map<String, dynamic> map) => Address(
        fullName: map['fullName'] ?? '',
        phone: map['phone'] ?? '',
        houseFlat: map['houseFlat'] ?? '',
        streetArea: map['streetArea'] ?? '',
        city: map['city'] ?? '',
        state: map['state'] ?? '',
        pinCode: map['pinCode'] ?? '',
      );
}
