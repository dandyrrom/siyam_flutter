# SIYAM Proposed System Diagram (BPMN Swim-Lane)

Business Process Model and Notation view of the **proposed / current** SIYAM
operating loop for Dumaguete Animal Sanctuary.

| Artifact | Path |
| --- | --- |
| SVG (source of truth for editing) | [`proposed_system_bpmn.svg`](proposed_system_bpmn.svg) |
| Generator | [`generate_bpmn_proposed_system.py`](generate_bpmn_proposed_system.py) |

Regenerate:

```bash
python3 docs/system-diagrams/generate_bpmn_proposed_system.py
```

---

## Pool and lanes

| Lane | Who | Responsibility on this diagram |
| --- | --- | --- |
| **Donor** | Login role | Register/sign in, submit donations, await status, view impact |
| **Manager** | Login role | Approve/decline submissions, confirm receipt, stock in donations, configure ROP/thresholds, review reports/audit |
| **Staff** | Login role | Purchase stock-in, medical treatments, stock-out, Ordering replenishment review, usage/My Activity |
| **SIYAM System** | Software | Auth, status machine, FEFO batches, dual-pool stock, ROP calc, FIFO impact, alerts/reports |

**Not a lane:** Supplier — external vendor master data only (selected on purchase stock-in). No supplier login.

---

## Process phases (left → right)

1. **Access** — role-gated authentication  
2. **Donation Intake** — submit → review → approve/decline → await drop-off  
3. **Inventory Receipt** — donated stock-in (Manager) and purchased stock-in (Staff); FEFO batches  
4. **Clinical / Usage** — treatment deduction or waste/expired/adjustment stock-out  
5. **Replenish** — ADU + ROP suggestions; Staff reviews Ordering; **manual** purchase loop (no auto-PO)  
6. **Oversight** — alerts, monthly usage / ROP / audit, donor impact  

### Submission status machine

`pending → approved → received → stocked`  
`rejected` is terminal and only from `pending`.

### Stock-out reasons

`waste` | `expired` | `adjustment`

---

## Notation

- Rounded rectangle = BPMN **task**
- Diamond with **X** = exclusive (**XOR**) gateway
- Thin circle = **start** event
- Double circle = **end** event
- Solid arrow = sequence flow (same lane / continuation)
- Dashed arrow = message / data flow across lanes

---

## Scope notes

Collapsed into Manager “Configure thresholds & ROP” (not exploded here):
category/unit catalog CRUD, animal records, supplier CRUD, profile edits,
dashboard chrome, social-media caption helper.

Grounded in implemented routes/services (`nav_config.dart`, donation workflow,
inventory/treatment/ROP/impact/audit), not wishlist features.
