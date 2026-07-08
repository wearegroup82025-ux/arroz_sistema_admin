class PaymentModel {
  final String paymentId;
  final String orderId;
  final double amount;
  final String paymentMethod;
  final String status;

  PaymentModel({
    required this.paymentId,
    required this.orderId,
    required this.amount,
    required this.paymentMethod,
    required this.status,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      paymentId: map['paymentId'] ?? '',
      orderId: map['orderId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      paymentMethod: map['paymentMethod'] ?? '',
      status: map['status'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'paymentId': paymentId,
      'orderId': orderId,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'status': status,
    };
  }
}