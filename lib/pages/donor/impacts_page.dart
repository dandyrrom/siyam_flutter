import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../models/donation_impact.dart';
import '../../models/inventory_item.dart';
import '../../models/pet.dart';
import '../../services/impact_service.dart';
import '../../state/auth_state.dart';
import '../../widgets/stat_card.dart';

/// Donor-facing view of what happened to what they gave.
///
/// Built on [ImpactService], a FIFO-based read model -- see
/// [DonationImpactLine] for the assumption behind it: the system has no
/// per-unit/per-bottle tracking, so it can't know which physical bottle a
/// treatment or stock-out actually drew from. It assumes stock is consumed
/// in the order it arrived (oldest batch first, across every purchase and
/// donation of that item) and attributes outcomes on that basis.
class ImpactsPage extends StatefulWidget {
  const ImpactsPage({super.key});

  @override
  State<ImpactsPage> createState() => _ImpactsPageState();
}

class _ImpactsPageState extends State<ImpactsPage> {
  final ImpactService _service = ImpactService();

  List<DonationImpactLine> _lines = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final donorId = context.read<AuthController>().profile?.userId;
    if (donorId == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lines = await _service.fetchDonorImpact(donorId);
      if (!mounted) return;
      setState(() {
        _lines = lines;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your impact: $e';
        _loading = false;
      });
    }
  }

  IconData _speciesIcon(PetSpecies species) =>
      species == PetSpecies.dog ? Icons.pets : Icons.pets_outlined;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.mutedForeground)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final treatmentCount =
        _lines.expand((l) => l.contributions).map((c) => c.treatmentId).toSet().length;
    final animalsHelped =
        _lines.expand((l) => l.contributions).map((c) => c.petId).toSet().length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('My Impact', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text(
          'See how your donations have helped animals in our care.',
          style: TextStyle(color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 20),
        StatCardRow(cards: [
          StatCard(
            label: 'Items Donated',
            value: '${_lines.length}',
            icon: Icons.volunteer_activism_outlined,
            accent: AppColors.roleDonor,
          ),
          StatCard(
            label: 'Treatments Helped',
            value: '$treatmentCount',
            icon: Icons.medical_services_outlined,
            accent: AppColors.primary,
          ),
          StatCard(
            label: 'Animals Helped',
            value: '$animalsHelped',
            icon: Icons.pets_outlined,
            accent: AppColors.roleStaff,
          ),
        ]),
        const SizedBox(height: 20),
        if (_lines.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 56),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.volunteer_activism_outlined,
                      size: 36, color: AppColors.mutedForeground),
                  SizedBox(height: 10),
                  Text('No donations yet', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('Once you donate items, their impact will show up here.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.mutedForeground)),
                ],
              ),
            ),
          )
        else
          for (final line in _lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ImpactCard(line: line, speciesIcon: _speciesIcon),
            ),
      ],
    );
  }
}

class _ImpactCard extends StatelessWidget {
  final DonationImpactLine line;
  final IconData Function(PetSpecies) speciesIcon;

  const _ImpactCard({required this.line, required this.speciesIcon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(line.itemName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
              ),
              Text(_formatDate(line.receivedDate),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.mutedForeground)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Donated ${formatQty(line.donatedQty)} ${line.itemUom}',
              style: const TextStyle(fontSize: 12.5, color: AppColors.mutedForeground)),
          const SizedBox(height: 14),
          if (line.isQuantityPrecise) ...[
            _ImpactBar(line: line),
            const SizedBox(height: 10),
          ],
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              if (line.isQuantityPrecise)
                _StatLine(
                    label: 'Used',
                    value: '${formatQty(line.usedQty)} ${line.itemUom}',
                    color: AppColors.primary),
              if (line.discardedQty > 0)
                _StatLine(
                    label: 'No longer in stock',
                    value: '${formatQty(line.discardedQty)} ${line.itemUom}',
                    color: AppColors.mutedForeground),
              _StatLine(
                  label: 'Still in stock',
                  value: '${formatQty(line.remainingQty)} ${line.itemUom}',
                  color: AppColors.stockInStock),
            ],
          ),
          if (line.contributions.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              line.isQuantityPrecise
                  ? 'Helped treat'
                  : 'Helped treat (exact amount used per treatment isn\'t tracked for this item)',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final c in line.contributions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(speciesIcon(c.petSpecies), size: 16, color: AppColors.mutedForeground),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: const TextStyle(fontSize: 13),
                          children: [
                            TextSpan(
                                text: c.petName,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            TextSpan(
                                text: ' — ${c.treatmentName}',
                                style: const TextStyle(color: AppColors.mutedForeground)),
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(_formatDate(c.date),
                        style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Stacked proportion bar: used / no-longer-in-stock / still-in-stock,
/// against the total donated. Reflects the precise FIFO-derived fractions
/// (see [DonationImpactLine]) even when a single event happened to draw from
/// more than one batch.
class _ImpactBar extends StatelessWidget {
  final DonationImpactLine line;
  const _ImpactBar({required this.line});

  @override
  Widget build(BuildContext context) {
    final total = line.donatedQty <= 0 ? 1.0 : line.donatedQty;
    final usedFrac = (line.usedQty / total).clamp(0.0, 1.0);
    final discardedFrac = (line.discardedQty / total).clamp(0.0, 1.0 - usedFrac);
    final remainingFrac = (1.0 - usedFrac - discardedFrac).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            if (usedFrac > 0) Expanded(flex: (usedFrac * 1000).round(), child: Container(color: AppColors.primary)),
            if (discardedFrac > 0)
              Expanded(
                  flex: (discardedFrac * 1000).round(),
                  child: Container(color: AppColors.border)),
            if (remainingFrac > 0)
              Expanded(
                  flex: (remainingFrac * 1000).round(),
                  child: Container(color: AppColors.stockInStock.withValues(alpha: 0.35))),
          ],
        ),
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatLine({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label: ',
            style: const TextStyle(fontSize: 12.5, color: AppColors.mutedForeground)),
        Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

const _monthAbbrev = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime date) =>
    '${_monthAbbrev[date.month - 1]} ${date.day}, ${date.year}';
