import 'package:flutter_test/flutter_test.dart';
import 'package:siyam_flutter/services/impact_fifo.dart';

void main() {
  group('runFifoLedger', () {
    test('drains a single batch by a single event', () {
      final result = runFifoLedger(
        batches: [
          ImpactBatch(id: 'b1', qty: 100, date: DateTime(2026, 1, 1)),
        ],
        events: [
          ImpactEvent(
            type: ImpactEventType.stockOut,
            qty: 40,
            date: DateTime(2026, 1, 5),
            messageAmount: 40,
            messageUnitAbbr: 'ml',
          ),
        ],
      );

      final b1 = result['b1']!;
      expect(b1.discarded, 40);
      expect(b1.used, 0);
      expect(b1.remaining, 60);
      expect(b1.contributions, hasLength(1));
    });

    test('splits one event across the tail of one batch and the head of the next (FIFO)', () {
      final result = runFifoLedger(
        batches: [
          ImpactBatch(id: 'b1', qty: 10, date: DateTime(2026, 1, 1)),
          ImpactBatch(id: 'b2', qty: 50, date: DateTime(2026, 2, 1)),
        ],
        events: [
          ImpactEvent(
            type: ImpactEventType.treatment,
            qty: 25,
            date: DateTime(2026, 3, 1),
            messageAmount: 25,
            messageUnitAbbr: 'ml',
          ),
        ],
      );

      expect(result['b1']!.used, 10);
      expect(result['b1']!.remaining, 0);
      expect(result['b2']!.used, 15);
      expect(result['b2']!.remaining, 35);
      // The whole event is attributed only to the first batch it touched.
      expect(result['b1']!.contributions, hasLength(1));
      expect(result['b2']!.contributions, isEmpty);
    });

    test('processes events oldest-first regardless of input order', () {
      final result = runFifoLedger(
        batches: [
          ImpactBatch(id: 'b1', qty: 20, date: DateTime(2026, 1, 1)),
        ],
        events: [
          ImpactEvent(
            type: ImpactEventType.stockOut,
            qty: 15,
            date: DateTime(2026, 1, 10),
            messageAmount: 15,
            messageUnitAbbr: 'ml',
          ),
          ImpactEvent(
            type: ImpactEventType.stockOut,
            qty: 5,
            date: DateTime(2026, 1, 5),
            messageAmount: 5,
            messageUnitAbbr: 'ml',
          ),
        ],
      );

      // 5 first, then 15 -- both come out of the only batch, order doesn't
      // change the totals here, but exercises the sort path.
      expect(result['b1']!.discarded, 20);
      expect(result['b1']!.remaining, 0);
    });

    test('non-deductible treatment event attaches a contribution without draining capacity', () {
      final result = runFifoLedger(
        batches: [
          ImpactBatch(id: 'b1', qty: 200, date: DateTime(2026, 1, 1)),
        ],
        events: [
          ImpactEvent(
            type: ImpactEventType.treatment,
            qty: 0,
            date: DateTime(2026, 1, 5),
            messageAmount: 3,
            messageUnitAbbr: 'drop',
            consumesCapacity: false,
          ),
        ],
      );

      final b1 = result['b1']!;
      expect(b1.used, 0);
      expect(b1.remaining, 200);
      expect(b1.contributions, hasLength(1));
    });

    test('events beyond total batch capacity are ignored once batches are exhausted', () {
      final result = runFifoLedger(
        batches: [
          ImpactBatch(id: 'b1', qty: 10, date: DateTime(2026, 1, 1)),
        ],
        events: [
          ImpactEvent(
            type: ImpactEventType.stockOut,
            qty: 10,
            date: DateTime(2026, 1, 2),
            messageAmount: 10,
            messageUnitAbbr: 'ml',
          ),
          ImpactEvent(
            type: ImpactEventType.stockOut,
            qty: 5,
            date: DateTime(2026, 1, 3),
            messageAmount: 5,
            messageUnitAbbr: 'ml',
          ),
        ],
      );

      final b1 = result['b1']!;
      expect(b1.remaining, 0);
      expect(b1.discarded, 10);
      // Second event has nothing left to attribute to.
      expect(b1.contributions, hasLength(1));
    });
  });

  group('wholeUnitBreakdown', () {
    test('fully sealed containers count as remaining, none used or discarded', () {
      final result = wholeUnitBreakdown(
        donatedQty: 3,
        ledgerResult: const ImpactBatchResult(
          used: 0,
          discarded: 0,
          remaining: 600, // 3 x 200ml, untouched
          contributions: [],
        ),
        packageQuantity: 200,
      );

      expect(result.remaining, 3);
      expect(result.used, 0);
      expect(result.discarded, 0);
    });

    test('a partially used bottle still counts as one whole "used" container', () {
      final result = wholeUnitBreakdown(
        donatedQty: 1,
        ledgerResult: const ImpactBatchResult(
          used: 1.5,
          discarded: 0,
          remaining: 148.5, // 150ml bottle, 1.5ml drawn
          contributions: [],
        ),
        packageQuantity: 150,
      );

      expect(result.remaining, 0); // not fully sealed anymore
      expect(result.discarded, 0);
      expect(result.used, 1);
    });

    test('a whole discarded container is not double counted as used', () {
      final result = wholeUnitBreakdown(
        donatedQty: 2,
        ledgerResult: const ImpactBatchResult(
          used: 0,
          discarded: 200,
          remaining: 0,
          contributions: [],
        ),
        packageQuantity: 200,
      );

      expect(result.discarded, 1);
      expect(result.remaining, 0);
      expect(result.used, 1); // the other donated container
    });
  });
}
