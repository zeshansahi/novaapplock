import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../../services/providers.dart';
import '../../../services/purchase_service.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  bool _isLoading = false;
  List<ProductDetails> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final purchaseService = ref.read(purchaseServiceProvider);
      final products = await purchaseService.getProducts();
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _purchaseProduct(ProductDetails product) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final purchaseService = ref.read(purchaseServiceProvider);
      final success = await purchaseService.purchaseProduct(product);
      
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase successful! Premium features are now enabled.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium Features'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.star,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Unlock Premium',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Get unlimited app locking and advanced features',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Premium Features',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
              context,
              Icons.lock_open,
              'Unlimited App Locking',
              'Lock as many apps as you want',
            ),
            _buildFeatureItem(
              context,
              Icons.fingerprint,
              'Biometric Unlock',
              'Use fingerprint or face to unlock apps',
            ),
            _buildFeatureItem(
              context,
              Icons.schedule,
              'Lock Schedules',
              'Lock apps based on time schedules',
            ),
            _buildFeatureItem(
              context,
              Icons.camera_alt,
              'Intruder Selfie',
              'Capture photos after failed unlock attempts',
            ),
            _buildFeatureItem(
              context,
              Icons.bug_report,
              'Fake Crash Screen',
              'Show fake crash after multiple failed attempts',
            ),
            const SizedBox(height: 32),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_products.isEmpty)
              const Center(
                child: Text('No products available. Please check your configuration.'),
              )
            else
              ..._products.map((product) => _buildProductCard(context, product)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () async {
                final purchaseService = ref.read(purchaseServiceProvider);
                final success = await purchaseService.restorePurchases();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Purchases restored successfully'
                            : 'No purchases found to restore',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Restore Purchases'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, ProductDetails product) {
    final isMonthly = product.id.contains('monthly');
    final price = product.price;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: _isLoading ? null : () => _purchaseProduct(product),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMonthly ? 'Monthly Premium' : 'Yearly Premium',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      price,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    if (!isMonthly) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Save 50% compared to monthly',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.green,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : () => _purchaseProduct(product),
                child: const Text('Subscribe'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

