import 'package:hive/hive.dart';
import 'order.dart';

class RefundModel {
  final String id;
  final String originalOrderId;
  final double amountRefunded;
  final DateTime date;
  final String staffName;
  final String reason;

  RefundModel({
    required this.id,
    required this.originalOrderId,
    required this.amountRefunded,
    required this.date,
    required this.staffName,
    required this.reason,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'originalOrderId': originalOrderId,
      'amountRefunded': amountRefunded,
      'date': date.toIso8601String(),
      'staffName': staffName,
      'reason': reason,
    };
  }

  factory RefundModel.fromMap(Map<String, dynamic> map) {
    return RefundModel(
      id: map['id'] ?? '',
      originalOrderId: map['originalOrderId'] ?? '',
      amountRefunded: (map['amountRefunded'] ?? 0.0).toDouble(),
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
      staffName: map['staffName'] ?? '',
      reason: map['reason'] ?? '');
  }
}

class RefundModelAdapter extends TypeAdapter<RefundModel> {
  @override
  final int typeId = 5;

  @override
  RefundModel read(BinaryReader reader) {
    return RefundModel(
      id: reader.read(),
      originalOrderId: reader.read(),
      amountRefunded: reader.read(),
      date: reader.read(),
      staffName: reader.read(),
      reason: reader.read());
  }

  @override
  void write(BinaryWriter writer, RefundModel obj) {
    writer.write(obj.id);
    writer.write(obj.originalOrderId);
    writer.write(obj.amountRefunded);
    writer.write(obj.date);
    writer.write(obj.staffName);
    writer.write(obj.reason);
  }
}
