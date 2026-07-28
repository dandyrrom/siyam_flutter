import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/donation_impact.dart';
import '../../models/inventory_item.dart';
import '../../models/pet.dart';
import '../../models/stock_out.dart';
import '../../services/impact_service.dart';
import '../../state/auth_state.dart';
import '../../state/data_bus.dart';
import '../../widgets/stat_card.dart';

/// Donor-facing view of what happened to what they gave.
///
/// Built on [ImpactService], a FIFO-based read model -- see
/// [DonationImpactLine] for the assumption behind it: the system has no
/// per-unit/per-bottle tracking, so it can't know which physical bottle a
/// treatment or stock-out actually drew from. It assumes stock is consumed
/// in the order it arrived (oldest batch first, across every purchase and
/// donation of that item) and attributes outcomes on that basis.
///
/// Two different units show up on purpose: "Used Stocks"/"Still in Stock"
/// are whole purchase_unit counts (bottles, boxes -- the unit the donor
/// actually gave in, and always a whole number: any bottle touched at all
/// counts as one used bottle, see [wholeUnitBreakdown]). The per-event
/// messages below that instead quote the raw recorded amount for that one
/// event -- dispense_unit (ml, drops) for a treatment, purchase_unit for a
/// stock-out -- since those figures need no FIFO assumption at all and are
/// shown exactly as staff entered them.
class ImpactsPage extends StatefulWidget {
  const ImpactsPage({super.key});

  @override
  State<ImpactsPage> createState() => _ImpactsPageState();
}

class _ImpactsPageState extends State<ImpactsPage>
    with DataBusRefreshMixin<ImpactsPage> {
  final ImpactService _service = ImpactService();

  List<DonationImpactLine> _lines = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void onExternalDataChanged() => _load(silent: true);

  Future<void> _load({bool silent = false}) async {
    final donorId = context.read<AuthController>().profile?.userId;
    if (donorId == null) return;

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final lines = await _service.fetchDonorImpact(donorId);
      if (!mounted) return;
      setState(() {
        _lines = lines;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = 'Could not load your impact: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

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

    final treatmentContributions = _lines
        .expand((l) => l.contributions)
        .where((c) => c.kind == ImpactEventKind.treatment);
    final treatmentCount = treatmentContributions.map((c) => c.treatmentId).toSet().length;
    final animalsHelped = treatmentContributions.map((c) => c.petId).toSet().length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ============================================================
        // HEADER: Responsive title
        // ============================================================
        Text(
          'My Impact',
          style: TextStyle(
            fontSize: isMobile ? 20 : 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'See how your donations have helped animals in our care.',
          style: TextStyle(
            fontSize: isMobile ? 13 : 14,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 20),

        // ============================================================
        // STAT CARDS: Responsive - stack on mobile
        // ============================================================
        isMobile
            ? Column(
                children: [
                  _buildStatCard(
                    label: 'Items Donated',
                    value: '${_lines.length}',
                    icon: Icons.volunteer_activism_outlined,
                    accent: AppColors.roleDonor,
                  ),
                  const SizedBox(height: 10),
                  _buildStatCard(
                    label: 'Treatments Helped',
                    value: '$treatmentCount',
                    icon: Icons.medical_services_outlined,
                    accent: AppColors.primary,
                  ),
                  const SizedBox(height: 10),
                  _buildStatCard(
                    label: 'Animals Helped',
                    value: '$animalsHelped',
                    icon: Icons.pets_outlined,
                    accent: AppColors.roleStaff,
                  ),
                ],
              )
            : StatCardRow(cards: [
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

        // ============================================================
        // EMPTY STATE OR IMPACT CARDS
        // ============================================================
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
              child: _ImpactCard(line: line),
            ),
      ],
    );
  }

  // ============================================================
  // MOBILE STAT CARD (Stacked version)
  // ============================================================
  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: accent),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Builds the per-event sentence, straight from the raw recorded figures,
/// independent of the FIFO stock math on [DonationImpactLine]:
///  - Treatment: "[amount] [unit] of your donated [item] was used to treat
///    [pet] for his/her [treatment]."
///  - Stock-out: "[amount] [unit] of your donated [item] was stocked out
///    for [reason]."
String _impactMessage(DonationImpactLine line, ImpactContribution c) {
  final amount = '${formatQty(c.amount)} ${c.unitAbbr}';
  switch (c.kind) {
    case ImpactEventKind.treatment:
      final pronoun = c.petGender == PetGender.male ? 'his' : 'her';
      return '$amount of your donated ${line.itemName} was used to treat '
          '${c.petName} for $pronoun ${c.treatmentName}.';
    case ImpactEventKind.stockOut:
      return '$amount of your donated ${line.itemName} was stocked out for '
          '${_stockOutReasonPhrase(c.stockOutReason!)}.';
  }
}

String _stockOutReasonPhrase(StockOutReason reason) {
  switch (reason) {
    case StockOutReason.waste:
      return 'waste';
    case StockOutReason.expired:
      return 'expiration';
    case StockOutReason.adjustment:
      return 'an inventory adjustment';
  }
}

IconData _speciesIcon(PetSpecies species) =>
    species == PetSpecies.dog ? Icons.pets : Icons.pets_outlined;

/// Number of contribution messages shown inline before collapsing the rest
/// behind a "View all" action -- keeps a card with many treatments from
/// dominating the page.
const _previewContributionCount = 2;

class _ImpactCard extends StatelessWidget {
  final DonationImpactLine line;

  const _ImpactCard({required this.line});

  void _openAllContributions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${line.itemName}: full history'),
        content: SizedBox(
          width: 420,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final c in line.contributions) _ContributionTile(line: line, contribution: c),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    final preview = line.contributions.take(_previewContributionCount).toList();
    final remaining = line.contributions.length - preview.length;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ============================================================
          // HEADER: Item name + date
          // ============================================================
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  line.itemName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: isMobile ? 14 : 15.5,
                  ),
                ),
              ),
              Text(
                _formatDate(line.receivedDate),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // ============================================================
          // DONATED QUANTITY
          // ============================================================
          Text(
            'Donated ${formatQty(line.donatedQty)} ${line.itemUom}',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 14),

          // ============================================================
          // IMPACT BAR (web only - hidden on mobile for cleaner look)
          // ============================================================
          if (line.isQuantityPrecise && !isMobile) ...[
            _ImpactBar(line: line),
            const SizedBox(height: 12),
          ],

          // ============================================================
          // STAT CHIPS: Responsive wrap
          // ============================================================
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (line.isQuantityPrecise)
                _StatChip(
                  label: 'Used Stocks',
                  value: '${formatQty(line.usedQty)} ${line.itemUom}',
                  color: AppColors.primary,
                )
              else
                const _StatChip(
                  label: 'Used Stocks',
                  value: 'Not tracked for this item',
                  color: AppColors.mutedForeground,
                ),
              if (line.discardedQty > 0)
                _StatChip(
                  label: 'No longer in stock',
                  value: '${formatQty(line.discardedQty)} ${line.itemUom}',
                  color: AppColors.mutedForeground,
                ),
              _StatChip(
                label: 'Still in Stock',
                value: '${formatQty(line.remainingQty)} ${line.itemUom}',
                color: AppColors.stockInStock,
              ),
            ],
          ),

          // ============================================================
          // CONTRIBUTION TILES
          // ============================================================
          if (preview.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            for (final c in preview) _ContributionTile(line: line, contribution: c),
            if (remaining > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _openAllContributions(context),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: Text('View all ${line.contributions.length} updates'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// One "what happened" entry: an icon badge (species for a treatment,
/// a neutral stock icon for a stock-out) then the full sentence from
/// [_impactMessage], with the date trailing.
class _ContributionTile extends StatelessWidget {
  final DonationImpactLine line;
  final ImpactContribution contribution;

  const _ContributionTile({required this.line, required this.contribution});

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    final isTreatment = contribution.kind == ImpactEventKind.treatment;
    final badgeColor = isTreatment ? AppColors.primary : AppColors.mutedForeground;
    final icon = isTreatment
        ? _speciesIcon(contribution.petSpecies!)
        : Icons.inventory_2_outlined;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: badgeColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _impactMessage(line, contribution),
              style: TextStyle(
                fontSize: isMobile ? 12.5 : 13,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formatDate(contribution.date),
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stacked proportion bar: used / no-longer-in-stock / still-in-stock,
/// against the total donated. Reflects the precise FIFO-derived fractions
/// (see [DonationImpactLine]) even when a single event happened to draw from
/// more than one batch. Only rendered for quantity-precise items.
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
            if (usedFrac > 0)
              Expanded(
                  flex: (usedFrac * 1000).round(), child: Container(color: AppColors.primary)),
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

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 10 : 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 12 : 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

const _monthAbbrev = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime date) =>
    '${_monthAbbrev[date.month - 1]} ${date.day}, ${date.year}';