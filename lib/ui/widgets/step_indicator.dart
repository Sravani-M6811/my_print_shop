import 'package:flutter/material.dart';

/// A compact horizontal progress indicator that communicates MY_PRINT_SHOP's
/// product-first journey:
///
///   1. Base Product   2. Design   3. Customize   4. Preview   5. Checkout
///
/// Shows the current step highlighted, completed steps with a check, and
/// upcoming steps dimmed. Powered by a plain list of step labels plus the index
/// of the active step, so it adapts with zero per-screen code.
class StepIndicator extends StatelessWidget {
  final List<String> steps;
  final int currentIndex;

  const StepIndicator({
    super.key,
    required this.steps,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: i <= currentIndex
                      ? const Color(0xFF6C5CE7)
                      : Colors.grey.shade300,
                ),
              ),
            _Step(
              label: steps[i],
              active: i == currentIndex,
              done: i < currentIndex,
            ),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String label;
  final bool active;
  final bool done;

  const _Step({
    required this.label,
    required this.active,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final Color dotColor = done || active
        ? const Color(0xFF6C5CE7)
        : Colors.grey.shade300;
    final Color labelColor = active
        ? const Color(0xFF6C5CE7)
        : Colors.grey.shade600;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    (label.isEmpty ? '' : _initial),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: labelColor,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  String get _initial => label.isNotEmpty ? label[0] : '';
}
