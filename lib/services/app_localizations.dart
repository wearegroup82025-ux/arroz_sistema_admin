import '../providers/language_provider.dart';

class AppLocalizations {
  final AppLanguage language;
  AppLocalizations(this.language);

  String get home => language == AppLanguage.english ? "Home" : "Tahanan";
  String get products => language == AppLanguage.english ? "Products" : "Mga Produkto";
  String get cart => language == AppLanguage.english ? "Cart" : "Kariton";
  String get orders => language == AppLanguage.english ? "Orders" : "Mga Order";
  String get profile => language == AppLanguage.english ? "Profile" : "Profile";

  String get welcome => language == AppLanguage.english ? "Welcome back" : "Maligayang pagbabalik";
  String get specsTitle => language == AppLanguage.english ? "Product Specifications" : "Tungkol sa Ating Palay";
  String get specsDesc => language == AppLanguage.english
      ? "Our premium palay is directly sourced and harvested from the rich agricultural fields of Capalangan, Pampanga."
      : "Ang ating de-kalidad na palay ay direktang nagmula at inani sa mayayamang sakahan ng Capalangan, Pampanga.";

  String get bestSeller => language == AppLanguage.english ? "Best Sellers" : "Pinakamabenta";
  String get recommended => language == AppLanguage.english ? "Recommended for You" : "Rekomendado sa Iyo";
  String get viewAll => language == AppLanguage.english ? "See All" : "Tingnan Lahat";
  String get noItems => language == AppLanguage.english ? "No items posted yet" : "Wala pang naka-post";

  String get activeOrders => language == AppLanguage.english ? "Active Orders" : "Mga Aktibong Order";
  String get myCart => language == AppLanguage.english ? "My Cart" : "Aking Kariton";
  String get favorites => language == AppLanguage.english ? "Favorites" : "Mga Paborito";
  String get availableProducts => language == AppLanguage.english ? "Available Products" : "Mga Produktong Abot-kaya";

  String get notifTitle => language == AppLanguage.english ? "Notifications" : "Mga Abiso";
  String get noNotif => language == AppLanguage.english ? "No new updates right now." : "Walang bagong balita sa ngayon.";

  String get chatTitle => language == AppLanguage.english ? "Chat Support / Admin" : "Sulat sa Admin";
  String get chatHint => language == AppLanguage.english ? "Ask about your order or product..." : "Magtanong tungkol sa order o produkto...";
  String get send => language == AppLanguage.english ? "Send" : "Ipadala";

  String get orderNow => language == AppLanguage.english ? "Order Now" : "Bumili Na";
  String get actionDesc => language == AppLanguage.english
      ? "Ready to secure your high-recovery palay supply? Tap below to start browsing."
      : "Handa nang kumuha ng de-kalidad na supply ng palay? Pindutin sa ibaba para makapili.";

  String get emptyCart => language == AppLanguage.english
      ? "Your cart is empty."
      : "Walang laman ang iyong cart.";

  String get all =>
      language == AppLanguage.english ? "All" : "Lahat";

  String get toPay =>
      language == AppLanguage.english ? "To Pay" : "Babayaran";

  String get toShip =>
      language == AppLanguage.english ? "To Ship" : "Ipapadala";

  String get toReceive =>
      language == AppLanguage.english ? "To Receive" : "Tatanggapin";

  String get completed =>
      language == AppLanguage.english ? "Completed" : "Nakumpleto";

  String get cancelled =>
      language == AppLanguage.english ? "Cancelled" : "Kinansela";

  // =======================
// CART
// =======================

  String get checkoutCart =>
      language == AppLanguage.english
          ? "Checkout Cart"
          : "I-checkout ang Cart";

  String get selectItemFirst =>
      language == AppLanguage.english
          ? "Please select an item first."
          : "Pumili muna ng item.";

  String get delete =>
      language == AppLanguage.english
          ? "Delete"
          : "Tanggalin";

  String get total =>
      language == AppLanguage.english
          ? "Total"
          : "Kabuuan";

  String get quantity =>
      language == AppLanguage.english
          ? "Quantity"
          : "Dami";

  // =======================
// ORDER ACTIONS
// =======================

  String get cancelOrder =>
      language == AppLanguage.english
          ? "Cancel Order"
          : "Kanselahin ang Order";

  String get confirmCancel =>
      language == AppLanguage.english
          ? "Confirm Cancel"
          : "Kumpirmahin ang Pagkansela";

  String get close =>
      language == AppLanguage.english
          ? "Close"
          : "Isara";

  String get selectReason =>
      language == AppLanguage.english
          ? "Select a cancellation reason"
          : "Pumili ng dahilan ng pagkansela";

  String get other =>
      language == AppLanguage.english
          ? "Other"
          : "Iba pa";

  String get enterReason =>
      language == AppLanguage.english
          ? "Enter your reason"
          : "Ilagay ang iyong dahilan";
}