class Employee {
  final String id;
  String name;
   String phoneNumber;
   String? position;
   String? nid;
   double? salary;
  double? amountToPay;  // New field for the amount to pay
  String? imageUrl;
  String? address;
  String? emergencyContact;

  Employee({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.position,
    this.nid,
    this.salary,
    this.amountToPay,  // Initialize the amount to pay field
    this.imageUrl,
    this.address,
    this.emergencyContact,
  });

  // Convert Employee to Map (for Firebase)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'position': position,
      'nid': nid,
      'salary': salary,
      'amountToPay': amountToPay,  // Add amountToPay here
      'imageUrl': imageUrl,
      'address': address,
      'emergencyContact': emergencyContact,
    };
  }

  // Create an Employee from a Firebase Map
  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      position: map['position'],
      nid: map['nid'],
      salary: map['salary']?.toDouble(),
      amountToPay: map['amountToPay']?.toDouble(),  // Add amountToPay here
      imageUrl: map['imageUrl'],
      address: map['address'],
      emergencyContact: map['emergencyContact'],
    );
  }
}
