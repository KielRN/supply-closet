import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/procedure.dart';
import '../../providers/procedure_provider.dart';

class ProcedureDetailScreen extends StatefulWidget {
  final String procedureId;
  const ProcedureDetailScreen({super.key, required this.procedureId});

  @override
  State<ProcedureDetailScreen> createState() => _ProcedureDetailScreenState();
}

class _ProcedureDetailScreenState extends State<ProcedureDetailScreen> {
  final Set<int> _checked = {};

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProcedureProvider>();
    final procedure = provider.getById(widget.procedureId);

    if (procedure == null) {
      return const Scaffold(
        body: Center(child: Text('Procedure not found')),
      );
    }

    final progress =
        procedure.supplies.isEmpty ? 0.0 : _checked.length / procedure.supplies.length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(procedure.name),
      ),
      body: Column(
        children: [
          // Progress header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_checked.length} of ${procedure.supplies.length} gathered',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: SupplyClosetColors.teal),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            SupplyClosetColors.tealLight,
                            SupplyClosetColors.teal
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: procedure.supplies.length,
              itemBuilder: (context, i) {
                final s = procedure.supplies[i];
                final checked = _checked.contains(i);
                return _SupplyCheckTile(
                  supply: s,
                  checked: checked,
                  onTap: () => setState(() {
                    if (checked) {
                      _checked.remove(i);
                    } else {
                      _checked.add(i);
                    }
                  }),
                );
              },
            ),
          ),
          // Find in supply room CTA
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton.icon(
              onPressed: () => context.go('/find'),
              icon: const Icon(Icons.center_focus_strong_rounded),
              label: const Text('Find in supply room'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplyCheckTile extends StatelessWidget {
  final ProcedureSupply supply;
  final bool checked;
  final VoidCallback onTap;

  const _SupplyCheckTile({
    required this.supply,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: checked
                    ? SupplyClosetColors.successDark
                    : Colors.grey.shade200,
                width: checked ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: checked
                        ? SupplyClosetColors.successDark
                        : Colors.transparent,
                    border: Border.all(
                      color: checked
                          ? SupplyClosetColors.successDark
                          : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: checked
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 18)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    supply.displayName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      decoration: checked
                          ? TextDecoration.lineThrough
                          : null,
                      color: checked
                          ? SupplyClosetColors.textSecondary
                          : SupplyClosetColors.charcoal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
