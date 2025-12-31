import 'package:flutter/material.dart';

class SimpleErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  final bool isCompact; // Option to make it even smaller if needed

  const SimpleErrorView({
    super.key,
    required this.onRetry,
    this.isCompact = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onRetry,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.05), // Very subtle red tint
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 20, color: Colors.red[400]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Connect to internet to view study",
                style: TextStyle(
                  color: Colors.red[900],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.refresh, size: 18, color: Colors.red[400]),
          ],
        ),
      ),
    );
  }
}
