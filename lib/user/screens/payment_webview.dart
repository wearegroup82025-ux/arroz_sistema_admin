import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentWebView extends StatefulWidget {
  final String checkoutUrl;
  final String orderId;
  final String paymentMethod;

  const PaymentWebView({
    super.key,
    required this.checkoutUrl,
    required this.orderId,
    required this.paymentMethod,
  });

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  InAppWebViewController? webViewController;
  bool _isLoading = true;
  bool _isProcessingSuccess = false; // Pigilan ang paulit-ulit na pag-process ng transaction

  Future<void> _handlePaymentSuccess() async {
    if (_isProcessingSuccess) return;
    setState(() {
      _isProcessingSuccess = true;
    });

    try {
      // Safe Firestore Transaction para sa pagbabawas ng stock online
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference orderDocRef =
            FirebaseFirestore.instance.collection("orders").doc(widget.orderId);
        DocumentSnapshot orderSnapshot = await transaction.get(orderDocRef);

        if (!orderSnapshot.exists) {
          throw Exception("Order record missing.");
        }

        final orderData = orderSnapshot.data() as Map<String, dynamic>;
        final items = orderData['items'] as List<dynamic>;

        if (items.isNotEmpty) {
          final orderedItem = items[0] as Map<String, dynamic>;
          String targetProductId = orderedItem['productId'];
          int orderedQuantity = orderedItem['quantity'] ?? 1;

          DocumentReference productRef =
              FirebaseFirestore.instance.collection("products").doc(targetProductId);
          DocumentSnapshot productSnapshot = await transaction.get(productRef);

          if (productSnapshot.exists) {
            int currentStock = productSnapshot['stock'] ?? 0;
            int updatedStock = currentStock - orderedQuantity;

            // 1. I-update ang status ng order document bilang Paid
            transaction.update(orderDocRef, {
              "isPaid": true,
              "prepareToShip": true,
              "status": "Pending",
              "paymentMethod":
                  widget.paymentMethod == "gcash" ? "GCash" : "Maya",
            });

            // 2. I-update ang stock sa products sub-collection
            transaction.update(productRef, {
              "stock": updatedStock < 0 ? 0 : updatedStock
            });
          }
        }
      });

      print("Online Payment Success: Status & Inventory updated.");
      if (mounted) {
        Navigator.pop(context, "SUCCESS");
      }
    } catch (e) {
      print("ERROR UPDATING STOCK ON ONLINE SUCCESS: $e");
      if (mounted) {
        Navigator.pop(context, "FAILED");
      }
    }
  }

  void _checkUrlForStatus(String urlString) {
    print("Checking WebView URL: $urlString");

    // Pag-check kung tagumpay o nag-cancel ang bayad
    if (urlString.contains("payment-success") ||
        urlString.contains("success.paymongo.com") ||
        urlString.contains("success")) {
      _handlePaymentSuccess();
    } else if (urlString.contains("payment-cancel") ||
        urlString.contains("cancel.paymongo.com") ||
        urlString.contains("failed")) {
      if (mounted) {
        Navigator.pop(context, "FAILED");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PayMongo Secure Payment"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, 'CANCELLED'),
        ),
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.checkoutUrl)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              useShouldOverrideUrlLoading: true,
              supportZoom: false,
              clearCache: true,
            ),
            onWebViewCreated: (controller) {
              webViewController = controller;
            },
            onLoadStart: (controller, url) {
              setState(() {
                _isLoading = true;
              });
              if (url != null) {
                _checkUrlForStatus(url.toString());
              }
            },
            onLoadStop: (controller, url) async {
              setState(() {
                _isLoading = false;
              });
              if (url != null) {
                _checkUrlForStatus(url.toString());
              }
            },
            onUpdateVisitedHistory: (controller, url, isReload) {
              if (url != null) {
                _checkUrlForStatus(url.toString());
              }
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final uri = navigationAction.request.url;
              if (uri != null) {
                _checkUrlForStatus(uri.toString());
              }
              return NavigationActionPolicy.ALLOW;
            },
            onLoadError: (controller, url, code, message) {
              setState(() {
                _isLoading = false;
              });
            },
            onLoadHttpError: (controller, url, statusCode, description) {
              setState(() {
                _isLoading = false;
              });
            },
          ),
          if (_isLoading || _isProcessingSuccess)
            const Center(
              child: CircularProgressIndicator(color: Colors.green),
            ),
        ],
      ),
    );
  }
}