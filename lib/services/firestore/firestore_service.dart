import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get Products
  Stream<QuerySnapshot> getProducts() {
    return _firestore.collection('productsU').snapshots();
  }

  // Get User
  Future<DocumentSnapshot> getUser(String uid) {
    return _firestore.collection('usersU').doc(uid).get();
  }

  // Save Order
  Future<void> addOrder(Map<String, dynamic> order) {
    return _firestore.collection('ordersU').add(order);
  }

  // Save Payment
  Future<void> addPayment(Map<String, dynamic> payment) {
    return _firestore.collection('paymentsU').add(payment);
  }
}