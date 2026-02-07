import '../helpers/image_helper.dart';

class ProductModel {
  final String id;
  final String barcode;
  final String name;
  final String location;
  final int quantity;
  final String? imageUrl;

  ProductModel({
    required this.id,
    required this.barcode,
    required this.name,
    required this.location,
    required this.quantity,
    this.imageUrl,
  });

  ProductModel copyWith({
    String? id,
    String? barcode,
    String? name,
    String? location,
    int? quantity,
    String? imageUrl,
  }) {
    return ProductModel(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      location: location ?? this.location,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'barcode': barcode,
      'name': name,
      'location': location,
      'quantity': quantity,
      'imageUrl': imageUrl,
    };
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'],
      barcode: json['barcode'],
      name: json['name'],
      location: json['location'],
      quantity: json['quantity'],
      imageUrl: json['imageUrl'] != null
          ? ImageHelper.buildImageUrl(json['imageUrl'], height: 600, quality: 90)
          : null,
    );
  }
}
