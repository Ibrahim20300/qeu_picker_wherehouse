class PickRecord {
  final String productId;
  final String barcode;
  final String location;
  final int quantity;
  final DateTime timestamp;

  PickRecord({
    required this.productId,
    required this.barcode,
    required this.location,
    required this.quantity,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'barcode': barcode,
      'location': location,
      'quantity': quantity,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
