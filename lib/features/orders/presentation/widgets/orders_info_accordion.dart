import 'package:flutter/material.dart';

/// Accordion widget for the help dialog. Only one panel open at a time.
class InfoAccordion extends StatefulWidget {
  const InfoAccordion({super.key, required this.entries});

  final List<({IconData icon, String title, String subtitle})> entries;

  @override
  State<InfoAccordion> createState() => _InfoAccordionState();
}

class _InfoAccordionState extends State<InfoAccordion> {
  int _expandedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListView.separated(
      shrinkWrap: true,
      itemCount: widget.entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final e = widget.entries[index];
        final isExpanded = _expandedIndex == index;
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: isExpanded
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ExpansionTile(
              key: ValueKey(index),
              leading: Icon(e.icon, color: colorScheme.primary),
              title: Text(
                e.title,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              shape: const Border(),
              collapsedShape: const Border(),
              initiallyExpanded: isExpanded,
              onExpansionChanged: (expanded) {
                setState(() {
                  _expandedIndex = expanded ? index : -1;
                });
              },
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    e.subtitle,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
