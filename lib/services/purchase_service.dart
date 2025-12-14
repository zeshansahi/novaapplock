import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PurchaseService {
  static const String _isPremiumKey = 'is_premium';
  static const String _premiumTypeKey = 'premium_type';
  
  // Product IDs - Replace with your actual product IDs from Google Play Console
  static const String monthlyProductId = 'monthly_premium';
  static const String yearlyProductId = 'yearly_premium';
  
  static const Set<String> _productIds = {monthlyProductId, yearlyProductId};
  
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];

  PurchaseService() {
    _initialize();
  }

  Future<void> _initialize() async {
    final isAvailable = await _inAppPurchase.isAvailable();
    
    if (isAvailable) {
      _subscription = _inAppPurchase.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => _subscription?.cancel(),
        onError: (error) => _subscription?.cancel(),
      );
      
      _loadProducts();
    }
  }

  Future<bool> _isAvailable() async {
    return await _inAppPurchase.isAvailable();
  }

  Future<void> _loadProducts() async {
    final isAvailable = await _isAvailable();
    if (!isAvailable) return;
    
    try {
      final response = await _inAppPurchase.queryProductDetails(_productIds);
      _products = response.productDetails;
    } catch (e) {
      // Handle error
    }
  }

  Future<List<ProductDetails>> getProducts() async {
    if (_products.isEmpty) {
      await _loadProducts();
    }
    return _products;
  }

  Future<bool> purchaseProduct(ProductDetails product) async {
    final isAvailable = await _isAvailable();
    if (!isAvailable) return false;
    
    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      return await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      return false;
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (var purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _handlePurchaseSuccess(purchase);
      } else if (purchase.status == PurchaseStatus.error) {
        // Handle error
      }
      
      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }
    }
  }

  Future<void> _handlePurchaseSuccess(PurchaseDetails purchase) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isPremiumKey, true);
    
    String premiumType = 'monthly';
    if (purchase.productID == yearlyProductId) {
      premiumType = 'yearly';
    }
    await prefs.setString(_premiumTypeKey, premiumType);
  }

  Future<bool> isPremium() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isPremiumKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getPremiumType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_premiumTypeKey);
    } catch (e) {
      return null;
    }
  }

  Future<bool> restorePurchases() async {
    final isAvailable = await _isAvailable();
    if (!isAvailable) return false;
    
    try {
      await _inAppPurchase.restorePurchases();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<int> getLockedAppsLimit() async {
    final isPremium = await this.isPremium();
    return isPremium ? 999 : 3; // Free: 3 apps, Premium: unlimited
  }

  void dispose() {
    _subscription?.cancel();
  }
}

