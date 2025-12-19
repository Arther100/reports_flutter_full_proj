import 'package:flutter/material.dart';
import 'shimmer_widgets.dart';

/// Fast-loading shimmer effect for PowerBI Report Screen
/// Displays instantly without waiting for data
class PowerBIShimmerLoading extends StatelessWidget {
  final bool isMobile;

  const PowerBIShimmerLoading({super.key, this.isMobile = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7FA),
      child: Column(
        children: [
          // Shimmer AppBar
          _buildShimmerAppBar(),

          // Shimmer Body
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // Shimmer Summary Cards
                  _buildShimmerSummaryCards(),

                  const SizedBox(height: 20),

                  // Shimmer Chart
                  _buildShimmerChart(),

                  const SizedBox(height: 20),

                  // Shimmer Data Table
                  _buildShimmerDataTable(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerAppBar() {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Title shimmer
              Expanded(
                child: MinimalShimmer(
                  width: isMobile ? 120 : 180,
                  height: isMobile ? 20 : 24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              // Database selector shimmer
              MinimalShimmer(
                width: isMobile ? 100 : 140,
                height: isMobile ? 32 : 36,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Filter chips row
          Row(
            children: List.generate(
              isMobile ? 3 : 5,
              (index) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: MinimalShimmer(
                  width: isMobile ? 70 : 90,
                  height: isMobile ? 28 : 32,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerSummaryCards() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: isMobile ? 2 : 4,
        childAspectRatio: isMobile ? 1.5 : 1.8,
        crossAxisSpacing: isMobile ? 10 : 16,
        mainAxisSpacing: isMobile ? 10 : 16,
        children: List.generate(
          4,
          (index) => Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    MinimalShimmer(
                      width: isMobile ? 30 : 40,
                      height: isMobile ? 30 : 40,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    MinimalShimmer(
                      width: isMobile ? 40 : 50,
                      height: isMobile ? 16 : 18,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
                const Spacer(),
                MinimalShimmer(
                  width: isMobile ? 60 : 80,
                  height: isMobile ? 24 : 28,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                MinimalShimmer(
                  width: double.infinity,
                  height: isMobile ? 12 : 14,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerChart() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              MinimalShimmer(
                width: isMobile ? 100 : 140,
                height: isMobile ? 16 : 18,
                borderRadius: BorderRadius.circular(4),
              ),
              MinimalShimmer(
                width: isMobile ? 60 : 80,
                height: isMobile ? 28 : 32,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Chart bars shimmer
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(isMobile ? 5 : 8, (index) {
              final heights = [
                80.0,
                120.0,
                100.0,
                140.0,
                90.0,
                110.0,
                130.0,
                95.0,
              ];
              return MinimalShimmer(
                width: isMobile ? 24 : 32,
                height: heights[index % heights.length],
                borderRadius: BorderRadius.circular(4),
              );
            }),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildShimmerDataTable() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table header
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F7FA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                MinimalShimmer(
                  width: isMobile ? 80 : 120,
                  height: isMobile ? 14 : 16,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),

          // Table rows
          ...List.generate(
            isMobile ? 5 : 8,
            (index) => Container(
              padding: EdgeInsets.all(isMobile ? 10 : 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  MinimalShimmer(
                    width: isMobile ? 24 : 32,
                    height: isMobile ? 24 : 32,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MinimalShimmer(
                          width: double.infinity,
                          height: isMobile ? 12 : 14,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 6),
                        MinimalShimmer(
                          width: isMobile ? 60 : 80,
                          height: isMobile ? 10 : 12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),
                  MinimalShimmer(
                    width: isMobile ? 50 : 70,
                    height: isMobile ? 16 : 18,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
