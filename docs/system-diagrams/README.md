# SIYAM Proposed System Diagram (BPMN Swim-Lane)

Business Process Model and Notation view of the **proposed / current** SIYAM
operating loop for Dumaguete Animal Sanctuary, aligned to **`main`**.

| Artifact | Path |
| --- | --- |
| SVG (editable source) | [`proposed_system_bpmn.svg`](proposed_system_bpmn.svg) |
| PNG preview | [`proposed_system_bpmn.png`](proposed_system_bpmn.png) |
| Generator | [`generate_bpmn_proposed_system.py`](generate_bpmn_proposed_system.py) |

Regenerate:

```bash
python3 docs/system-diagrams/generate_bpmn_proposed_system.py
# optional PNG:
python3 -c "import cairosvg; cairosvg.svg2png(url='docs/system-diagrams/proposed_system_bpmn.svg', write_to='docs/system-diagrams/proposed_system_bpmn.png')"
```

---

## Pool and lanes

| Lane | Who | Responsibility on this diagram |
| --- | --- | --- |
| **Donor** | Login role | Register/sign in, Forgot Password, Currently Needed, submit donations, await status, view impact |
| **Manager** | Login role | Staff Accounts, approve/decline submissions, confirm receipt, walk-in Add Donation, donated stock-in, configure ROP, reports/audit |
| **Staff** | Login role | Purchase stock-in, medical treatments, stock-out, Ordering replenishment review, usage/My Activity |
| **SIYAM System** | Software | Auth, status machine, FEFO batches, dual-pool stock, ROP calc, FIFO impact, alerts/reports |

**Not a lane:** Supplier — external vendor master data only.  
**Not a process step:** Realtime screen refresh (`realtime_sync.dart`).

---

## Process phases (left → right)

1. **Access** — register/sign-in, Forgot Password (Supabase), Manager Staff Accounts  
2. **Donation Intake** — Currently Needed → submit → review → approve/decline → await drop-off; walk-in bypass  
3. **Inventory Receipt** — donated stock-in (Manager) and purchased stock-in (Staff); FEFO batches  
4. **Clinical / Usage** — treatment deduction or waste/expired/adjustment stock-out  
5. **Replenish** — Average Daily Use + ROP suggestions; Staff reviews Ordering; **manual** purchase loop (no auto-PO); alerts feed Currently Needed  
6. **Oversight** — alerts, Monthly Usage / ROP Status / audit, donor impact  

### Submission status machine

`pending → approved → received → stocked`  
`rejected` is terminal and only from `pending`.

### Stock-out reasons

`waste` | `expired` | `adjustment`

---

## Updates vs earlier BPMN (post–`ce19f02` main)

| Added / renamed | Why |
| --- | --- |
| Forgot Password? reset via email | Donor password recovery on login (`ffc809e`) |
| View Currently Needed | Donor dashboard / donate bridge from replenishment needs |
| Create / enable / disable Staff | Manager Staff Accounts |
| Record walk-in donation (Add Donation) | Manager path that bypasses pending submission |
| Average Daily Use + ROP suggestions | Reports/Ordering terminology (`b1c0b1f`) |

---

## Notation

- Rounded rectangle = BPMN **task**
- Diamond with **X** = exclusive (**XOR**) gateway
- Thin circle = **start** event
- Double circle = **end** event
- Solid arrow = sequence flow
- Dashed arrow = message / data flow across lanes

---

## Scope notes

Collapsed into Manager “Configure thresholds & ROP” / master data:
category/unit catalog, animal records, supplier CRUD, profile edits,
dashboard chrome, social-media caption helper, treatment follow-up detail.

Grounded in implemented routes/services on `main` (`nav_config.dart`,
donation workflow, inventory/treatment/ROP/impact/audit), not wishlist features.
