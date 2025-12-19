import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/powerbi_models.dart';

// Optimized helper classes for virtualized list with subcategory support
enum _RowType { category, subcategory, item }

class _TableRow {
  final _RowType type;
  final String id;
  final String displayName;
  final Map<String, double> storeSales;
  final double totalSales;
  final int level;
  final VoidCallback? onTap;
  final bool isExpanded;

  _TableRow({
    required this.type,
    required this.id,
    required this.displayName,
    required this.storeSales,
    required this.totalSales,
    required this.level,
    this.onTap,
    this.isExpanded = false,
  });
}

class HierarchicalDataTable extends StatefulWidget {
  final List<PowerBICategory> categories;
  final List<PowerBIStore> stores;
  final Function(String categoryId)? onCategoryExpand;
  final bool isLoading;
  final bool showGrandTotal;

  const HierarchicalDataTable({
    super.key,
    required this.categories,
    required this.stores,
    this.onCategoryExpand,
    this.isLoading = false,
    this.showGrandTotal = true,
  });

  @override
  State<HierarchicalDataTable> createState() => _HierarchicalDataTableState();
}

class _HierarchicalDataTableState extends State<HierarchicalDataTable>
    with SingleTickerProviderStateMixin {
  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '\$',
    decimalDigits: 2,
  );
  final ScrollController _horizontalScroll = ScrollController();
  final ScrollController _verticalScroll = ScrollController();

  // Track expansion state for subcategories (category:subcategory)
  final Set<String> _expandedSubcategories = {};

  // Track which categories are currently loading
  final Set<String> _loadingCategories = {};

  // Animation controller for shimmer effect
  AnimationController? _shimmerController;

  @override
  void initState() {
    super.initState();
    _initShimmerController();
  }

  void _initShimmerController() {
    if (widget.isLoading && _shimmerController == null) {
      _shimmerController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      )..repeat();
    }
  }

  @override
  void didUpdateWidget(HierarchicalDataTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      _initShimmerController();
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _shimmerController?.stop();
      _shimmerController?.dispose();
      _shimmerController = null;
    }
  }

  @override
  void dispose() {
    _shimmerController?.dispose();
    _horizontalScroll.dispose();
    _verticalScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return _buildLoadingState();
    }

    if (widget.categories.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTableHeader(),
          Divider(height: 1, color: Colors.grey[300]),
          Expanded(
            child: Scrollbar(
              controller: _verticalScroll,
              thumbVisibility: true,
              child: Scrollbar(
                controller: _horizontalScroll,
                thumbVisibility: true,
                notificationPredicate: (notification) =>
                    notification.depth == 1,
                child: SingleChildScrollView(
                  controller: _horizontalScroll,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: _calculateTotalWidth(),
                    child: Column(
                      children: [
                        _buildHeaderRow(),
                        const Divider(height: 1),
                        Expanded(child: _buildVirtualizedList()),
                        // Grand Total Row inside scrollable area (scrolls with table)
                        if (widget.showGrandTotal) ...[
                          const Divider(height: 1),
                          _buildGrandTotalRow(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateTotalWidth() {
    return 250.0 + (widget.stores.length * 150.0) + 150.0;
  }

  Widget _buildGrandTotalRow() {
    // Calculate grand totals
    final storeTotals = <String, double>{};
    double grandTotal = 0;

    for (final store in widget.stores) {
      double storeTotal = 0;
      for (final category in widget.categories) {
        storeTotal += category.storeSales[store.storeId] ?? 0;
      }
      storeTotals[store.storeId] = storeTotal;
      grandTotal += storeTotal;
    }

    return Container(
      height: 60,
      decoration: BoxDecoration(color: Colors.blue[700]),
      child: Row(
        children: [
          // Category column
          Container(
            width: 250,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Row(
              children: [
                Icon(Icons.functions, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'GRAND TOTAL',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Store totals
          ...widget.stores.map((store) {
            final total = storeTotals[store.storeId] ?? 0;
            return Container(
              width: 150,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  _currencyFormat.format(total),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          }),
          // Grand total
          Container(
            width: 150,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _currencyFormat.format(grandTotal),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVirtualizedList() {
    // Flatten the hierarchical data: Category → Subcategory → Items
    final flattenedRows = <_TableRow>[];

    for (final category in widget.categories) {
      // Group items by subcategory (using itemName patterns or first word)
      final subcategories = <String, List<PowerBICategoryItem>>{};
      final directItems = <PowerBICategoryItem>[];

      for (final item in category.items) {
        // Try to detect subcategory from item name
        // e.g., "Strawberry Banana Smoothie" → subcategory: "Smoothie"
        final parts = item.itemName.split(' ');
        if (parts.length > 1) {
          final potentialSubcat = parts.last;
          // Common subcategory indicators
          if (potentialSubcat.length > 3 &&
              (potentialSubcat[0] == potentialSubcat[0].toUpperCase() ||
                  [
                    'Tea',
                    'Coffee',
                    'Smoothie',
                    'Juice',
                    'Shake',
                    'Latte',
                    'Burger',
                    'Pizza',
                    'Sandwich',
                    'Salad',
                    'Bowl',
                  ].any((s) => potentialSubcat.contains(s)))) {
            subcategories.putIfAbsent(potentialSubcat, () => []).add(item);
          } else {
            directItems.add(item);
          }
        } else {
          directItems.add(item);
        }
      }

      // Add category row - use category's own storeSales, not calculated from items
      // (items may not be loaded yet until category is expanded)
      final isLoading = _loadingCategories.contains(category.categoryId);

      flattenedRows.add(
        _TableRow(
          type: _RowType.category,
          id: category.categoryId,
          displayName: category.categoryName,
          storeSales: category.storeSales, // Use category's own data
          totalSales: category.totalSales, // Use category's own total
          level: 0,
          isExpanded: category.isExpanded,
          onTap: () {
            setState(() {
              category.isExpanded = !category.isExpanded;
              if (category.isExpanded && category.items.isEmpty) {
                _loadingCategories.add(category.categoryId);
              } else if (!category.isExpanded) {
                // Clear loading when collapsing
                _loadingCategories.remove(category.categoryId);
              }
            });
            // Call parent to load items - shimmer will show until items are loaded
            if (category.isExpanded && widget.onCategoryExpand != null) {
              widget.onCategoryExpand!(category.categoryId);
            }
          },
        ),
      );

      // Show shimmer loading rows if category is expanded and has no items yet
      final showShimmer = category.isExpanded && category.items.isEmpty;
      if (showShimmer) {
        for (int i = 0; i < 3; i++) {
          flattenedRows.add(
            _TableRow(
              type: _RowType.item,
              id: 'shimmer_${category.categoryId}_$i',
              displayName: 'loading',
              storeSales: {},
              totalSales: 0,
              level: 1,
            ),
          );
        }
      }

      // If category is expanded and has items loaded, show subcategories and items
      if (category.isExpanded && category.items.isNotEmpty) {
        // Add subcategory rows
        subcategories.forEach((subcatName, items) {
          final subcatKey = '${category.categoryId}:$subcatName';
          final subcatTotals = _calculateStoreTotals(items);
          final isExpanded = _expandedSubcategories.contains(subcatKey);

          flattenedRows.add(
            _TableRow(
              type: _RowType.subcategory,
              id: subcatKey,
              displayName: subcatName,
              storeSales: subcatTotals,
              totalSales: subcatTotals.values.fold(
                0.0,
                (sum, val) => sum + val,
              ),
              level: 1,
              isExpanded: isExpanded,
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedSubcategories.remove(subcatKey);
                  } else {
                    _expandedSubcategories.add(subcatKey);
                  }
                });
              },
            ),
          );

          // If subcategory is expanded, show its items
          if (isExpanded) {
            for (final item in items) {
              flattenedRows.add(
                _TableRow(
                  type: _RowType.item,
                  id: item.itemId,
                  displayName: item.itemName,
                  storeSales: item.storeSales,
                  totalSales: item.totalSales,
                  level: 2,
                ),
              );
            }
          }
        });

        // Add direct items (no subcategory)
        for (final item in directItems) {
          flattenedRows.add(
            _TableRow(
              type: _RowType.item,
              id: item.itemId,
              displayName: item.itemName,
              storeSales: item.storeSales,
              totalSales: item.totalSales,
              level: 1,
            ),
          );
        }
      }
    }

    return ListView.builder(
      controller: _verticalScroll,
      itemCount: flattenedRows.length,
      itemExtent: 50, // Fixed height for optimal performance
      itemBuilder: (context, index) {
        final row = flattenedRows[index];
        return _buildRow(row, index);
      },
    );
  }

  // Calculate store totals from a list of items
  Map<String, double> _calculateStoreTotals(List<PowerBICategoryItem> items) {
    final totals = <String, double>{};
    for (final store in widget.stores) {
      totals[store.storeId] = items.fold(
        0.0,
        (sum, item) => sum + (item.storeSales[store.storeId] ?? 0.0),
      );
    }
    return totals;
  }

  Widget _buildRow(_TableRow row, int index) {
    // Light grey background for all rows
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[50], // Minimal grey background
        border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      child: Row(
        children: [
          _buildCategoryCell(row),
          ...widget.stores.map((store) => _buildStoreCell(row, store)),
          _buildTotalCell(row),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[700],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(Icons.table_chart, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Text(
            'Category - Store Wise Sales',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue[700]),
            const SizedBox(height: 16),
            Text(
              'Loading data...',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.black),
            const SizedBox(height: 16),
            Text(
              'No data available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or date range',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3), // Blue header
        border: Border(bottom: BorderSide(color: Colors.blue[700]!, width: 2)),
      ),
      child: Row(
        children: [
          Container(
            width: 250,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.blue[400]!)),
            ),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Category',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          ...widget.stores.map((store) {
            return Container(
              width: 150,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Colors.blue[400]!)),
              ),
              child: Center(
                child: Text(
                  store.storeName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }),
          Container(
            width: 150,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: const Center(
              child: Text(
                'Total',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCell(_TableRow row) {
    // Check if this is a shimmer loading row
    if (row.displayName == 'loading') {
      return Container(
        width: 250,
        padding: EdgeInsets.only(left: 16.0 + (row.level * 24.0), right: 8),
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.grey[200]!)),
        ),
        child: _buildShimmerBox(width: 150, height: 16),
      );
    }

    Color textColor;
    FontWeight fontWeight;
    double fontSize;

    switch (row.type) {
      case _RowType.category:
        textColor = Colors.black;
        fontWeight = FontWeight.bold;
        fontSize = 14;
        break;
      case _RowType.subcategory:
        textColor = Colors.black;
        fontWeight = FontWeight.w600;
        fontSize = 14;
        break;
      case _RowType.item:
        textColor = const Color(0xFF1976D2); // Dark blue for items
        fontWeight = FontWeight.w700; // Slightly bold
        fontSize = 14;
        break;
    }

    return Container(
      width: 250,
      padding: EdgeInsets.only(left: 16.0 + (row.level * 24.0), right: 8),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey[200]!)),
      ),
      child: InkWell(
        onTap: row.onTap,
        child: Row(
          children: [
            if (row.type != _RowType.item)
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Icon(
                    row.isExpanded ? Icons.remove : Icons.add,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            if (row.type != _RowType.item) const SizedBox(width: 8),
            Expanded(
              child: Text(
                row.displayName,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreCell(_TableRow row, PowerBIStore store) {
    // Check if this is a shimmer loading row
    if (row.displayName == 'loading') {
      return Container(
        width: 150,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Center(child: _buildShimmerBox(width: 80, height: 16)),
      );
    }

    final sales = row.storeSales[store.storeId] ?? 0.0;

    // Different styling based on row type
    FontWeight fontWeight;
    Color textColor;

    switch (row.type) {
      case _RowType.category:
        fontWeight = FontWeight.bold;
        textColor = Colors.black87;
        break;
      case _RowType.subcategory:
        fontWeight = FontWeight.w600;
        textColor = Colors.black87;
        break;
      case _RowType.item:
        fontWeight = FontWeight.w600; // Slightly bold
        textColor = const Color(0xFF1976D2); // Dark blue for item values
        break;
    }

    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Center(
        child: Text(
          _currencyFormat.format(sales),
          style: TextStyle(
            fontSize: 14,
            fontWeight: fontWeight,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildTotalCell(_TableRow row) {
    // Check if this is a shimmer loading row
    if (row.displayName == 'loading') {
      return Container(
        width: 150,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Center(child: _buildShimmerBox(width: 80, height: 16)),
      );
    }

    FontWeight fontWeight;
    Color textColor;

    switch (row.type) {
      case _RowType.category:
        fontWeight = FontWeight.bold;
        textColor = Colors.black87;
        break;
      case _RowType.subcategory:
        fontWeight = FontWeight.w600;
        textColor = Colors.black87;
        break;
      case _RowType.item:
        fontWeight = FontWeight.w600; // Slightly bold
        textColor = const Color(0xFF1976D2); // Dark blue for item values
        break;
    }

    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Center(
        child: Text(
          _currencyFormat.format(row.totalSales),
          style: TextStyle(
            fontSize: 14,
            fontWeight: fontWeight,
            color: textColor,
          ),
        ),
      ),
    );
  }

  // Shimmer effect widget for loading state
  Widget _buildShimmerBox({required double width, required double height}) {
    final controller = _shimmerController;
    if (controller == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: Colors.grey[300],
        ),
      );
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2 * controller.value, 0),
              end: Alignment(-0.5 + 2 * controller.value, 0),
              colors: [Colors.grey[300]!, Colors.grey[100]!, Colors.grey[300]!],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
