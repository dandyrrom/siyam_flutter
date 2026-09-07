#!/usr/bin/env python3
"""Generate SIYAM Proposed System BPMN (swim-lane) diagram as SVG."""

from __future__ import annotations

from pathlib import Path

OUT = Path(__file__).with_name("proposed_system_bpmn.svg")

# Palette — SIYAM sage / sky / amber (not generic purple)
INK = "#1f2a24"
MUTED = "#5c6b63"
LINE = "#7a8a82"
WHITE = "#ffffff"
POOL = "#f4f7f5"
DONOR = "#e8f2ec"
MANAGER = "#e7eef8"
STAFF = "#f8efe6"
SYSTEM = "#eef1f3"
DONOR_STROKE = "#2f6b4f"
MANAGER_STROKE = "#2f5f8a"
STAFF_STROKE = "#9a5b24"
SYSTEM_STROKE = "#4a5560"
TASK_FILL = "#ffffff"
GW_FILL = "#fff8e8"
START_FILL = "#d9f0e3"
END_FILL = "#f0d9d9"
MSG = "#6b7280"


def esc(text: str) -> str:
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def wrap(text: str, width: int = 18) -> list[str]:
    words = text.split()
    lines: list[str] = []
    cur = ""
    for w in words:
        trial = w if not cur else f"{cur} {w}"
        if len(trial) <= width:
            cur = trial
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines or [text]


class Svg:
    def __init__(self, w: int, h: int) -> None:
        self.w = w
        self.h = h
        self.parts: list[str] = []

    def add(self, s: str) -> None:
        self.parts.append(s)

    def rect(
        self,
        x: float,
        y: float,
        w: float,
        h: float,
        fill: str,
        stroke: str | None = None,
        sw: float = 1.2,
        r: float = 0,
        opacity: float = 1,
    ) -> None:
        st = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
        self.add(
            f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" ry="{r}" '
            f'fill="{fill}"{st} opacity="{opacity}"/>'
        )

    def circle(
        self,
        cx: float,
        cy: float,
        r: float,
        fill: str,
        stroke: str,
        sw: float = 2,
    ) -> None:
        self.add(
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}" '
            f'stroke="{stroke}" stroke-width="{sw}"/>'
        )

    def text(
        self,
        x: float,
        y: float,
        content: str,
        *,
        size: int = 13,
        weight: str = "500",
        fill: str = INK,
        anchor: str = "middle",
        family: str = "Segoe UI, Helvetica, Arial, sans-serif",
    ) -> None:
        self.add(
            f'<text x="{x}" y="{y}" fill="{fill}" font-size="{size}" '
            f'font-weight="{weight}" text-anchor="{anchor}" '
            f'font-family="{family}">{esc(content)}</text>'
        )

    def multiline(
        self,
        x: float,
        y: float,
        lines: list[str],
        *,
        size: int = 12,
        weight: str = "600",
        fill: str = INK,
        gap: float = 14,
    ) -> None:
        start = y - ((len(lines) - 1) * gap) / 2
        for i, line in enumerate(lines):
            self.text(
                x,
                start + i * gap,
                line,
                size=size,
                weight=weight,
                fill=fill,
            )

    def line(
        self,
        x1: float,
        y1: float,
        x2: float,
        y2: float,
        stroke: str = INK,
        sw: float = 1.6,
        dashed: bool = False,
        marker_end: str | None = "url(#arrow)",
    ) -> None:
        dash = ' stroke-dasharray="6 5"' if dashed else ""
        me = f' marker-end="{marker_end}"' if marker_end else ""
        self.add(
            f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" '
            f'stroke="{stroke}" stroke-width="{sw}"{dash}{me}/>'
        )

    def path(
        self,
        d: str,
        stroke: str = INK,
        sw: float = 1.6,
        dashed: bool = False,
        marker_end: str | None = "url(#arrow)",
        fill: str = "none",
    ) -> None:
        dash = ' stroke-dasharray="6 5"' if dashed else ""
        me = f' marker-end="{marker_end}"' if marker_end else ""
        self.add(
            f'<path d="{d}" fill="{fill}" stroke="{stroke}" '
            f'stroke-width="{sw}"{dash}{me}/>'
        )

    def diamond(
        self,
        cx: float,
        cy: float,
        s: float,
        fill: str,
        stroke: str,
    ) -> None:
        pts = (
            f"{cx},{cy - s} {cx + s},{cy} {cx},{cy + s} {cx - s},{cy}"
        )
        self.add(
            f'<polygon points="{pts}" fill="{fill}" stroke="{stroke}" '
            f'stroke-width="1.8"/>'
        )

    def finish(self) -> str:
        body = "\n".join(self.parts)
        return f"""<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}"
     viewBox="0 0 {self.w} {self.h}" role="img"
     aria-label="SIYAM Proposed System BPMN swim-lane diagram">
  <defs>
    <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5"
            markerWidth="8" markerHeight="8" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="{INK}"/>
    </marker>
    <marker id="arrow-msg" viewBox="0 0 10 10" refX="9" refY="5"
            markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="{MSG}"/>
    </marker>
  </defs>
  <rect width="100%" height="100%" fill="{WHITE}"/>
{body}
</svg>
"""


def task(
    svg: Svg,
    x: float,
    y: float,
    w: float,
    h: float,
    label: str,
    stroke: str,
) -> tuple[float, float, float, float]:
    """Draw BPMN task; return (cx, cy, right, mid_y)."""
    svg.rect(x, y, w, h, TASK_FILL, stroke, sw=1.7, r=10)
    svg.multiline(x + w / 2, y + h / 2 + 1, wrap(label, 16), size=12)
    return x + w / 2, y + h / 2, x + w, y + h / 2


def gateway(
    svg: Svg,
    cx: float,
    cy: float,
    label: str,
    stroke: str,
) -> None:
    svg.diamond(cx, cy, 22, GW_FILL, stroke)
    svg.text(cx, cy + 4, "X", size=12, weight="800", fill=stroke)
    if label:
        svg.text(cx, cy - 30, label, size=11, weight="600", fill=MUTED)


def start_event(svg: Svg, cx: float, cy: float, label: str) -> None:
    svg.circle(cx, cy, 16, START_FILL, DONOR_STROKE, 2.2)
    svg.text(cx, cy + 32, label, size=11, weight="600", fill=MUTED)


def end_event(svg: Svg, cx: float, cy: float, label: str, stroke: str) -> None:
    svg.circle(cx, cy, 16, END_FILL, stroke, 2.2)
    svg.circle(cx, cy, 10, END_FILL, stroke, 3.2)
    svg.text(cx, cy + 34, label, size=11, weight="600", fill=MUTED)


def build() -> str:
    # Geometry
    left_gutter = 150
    top = 110
    lane_h = 195
    lanes = [
        ("Donor", DONOR, DONOR_STROKE),
        ("Manager", MANAGER, MANAGER_STROKE),
        ("Staff", STAFF, STAFF_STROKE),
        ("SIYAM System", SYSTEM, SYSTEM_STROKE),
    ]
    pool_w = 2680
    pool_h = lane_h * len(lanes)
    width = left_gutter + pool_w + 40
    height = top + pool_h + 120

    svg = Svg(width, height)

    # Title
    svg.text(
        width / 2,
        42,
        "SIYAM — Proposed System Diagram (BPMN Swim-Lane)",
        size=26,
        weight="800",
    )
    svg.text(
        width / 2,
        72,
        "Business Process Model and Notation · Dumaguete Animal Sanctuary operating loop",
        size=14,
        weight="500",
        fill=MUTED,
    )

    # Pool
    svg.rect(left_gutter, top, pool_w, pool_h, POOL, INK, sw=2.2, r=0)
    # Vertical lane label strip
    svg.rect(left_gutter, top, 46, pool_h, "#dfe8e2", INK, sw=2.2)
    svg.add(
        f'<text x="{left_gutter + 30}" y="{top + pool_h / 2}" fill="{INK}" '
        f'font-size="15" font-weight="800" text-anchor="middle" '
        f'transform="rotate(-90 {left_gutter + 30} {top + pool_h / 2})" '
        f'font-family="Segoe UI, Helvetica, Arial, sans-serif">SIYAM Pool</text>'
    )

    lane_mids: dict[str, float] = {}
    for i, (name, fill, stroke) in enumerate(lanes):
        y = top + i * lane_h
        svg.rect(left_gutter + 46, y, pool_w - 46, lane_h, fill, LINE, sw=1)
        # lane header
        svg.rect(left_gutter + 46, y, 120, lane_h, WHITE, stroke, sw=1.5)
        svg.multiline(
            left_gutter + 106,
            y + lane_h / 2,
            wrap(name, 10),
            size=14,
            weight="800",
            fill=stroke,
        )
        if i > 0:
            svg.line(
                left_gutter + 46,
                y,
                left_gutter + pool_w,
                y,
                stroke=LINE,
                sw=1,
                marker_end=None,
            )
        lane_mids[name] = y + lane_h / 2

    # Phase banners across pool
    phases = [
        (190, 300, "1. Access"),
        (510, 720, "2. Donation Intake"),
        (1260, 430, "3. Inventory Receipt"),
        (1710, 360, "4. Clinical / Usage"),
        (2090, 280, "5. Replenish"),
        (2390, 280, "6. Oversight"),
    ]
    for x, w, label in phases:
        svg.rect(
            left_gutter + 46 + x,
            top - 28,
            w,
            24,
            WHITE,
            LINE,
            sw=1,
            r=6,
        )
        svg.text(
            left_gutter + 46 + x + w / 2,
            top - 11,
            label,
            size=12,
            weight="700",
            fill=MUTED,
        )

    # Coordinates helpers
    donor_y = lane_mids["Donor"]
    mgr_y = lane_mids["Manager"]
    staff_y = lane_mids["Staff"]
    sys_y = lane_mids["SIYAM System"]

    # ---- Phase 1: Access ----
    start_event(svg, 230, donor_y - 40, "Start")
    # Donor login/register
    d_login = task(svg, 270, donor_y - 70, 130, 58, "Register / sign in", DONOR_STROKE)
    m_login = task(svg, 270, mgr_y - 29, 130, 58, "Sign in as Manager", MANAGER_STROKE)
    s_login = task(svg, 270, staff_y - 29, 130, 58, "Sign in as Staff", STAFF_STROKE)
    sys_auth = task(
        svg,
        430,
        sys_y - 29,
        150,
        58,
        "Authenticate & gate by role",
        SYSTEM_STROKE,
    )
    svg.line(246, donor_y - 40, 270, donor_y - 40)
    # message flows to system
    svg.path(
        f"M {d_login[2]} {d_login[3]} C {d_login[2] + 40} {d_login[3]}, "
        f"{430} {sys_y - 40}, 430 {sys_y - 10}",
        stroke=MSG,
        dashed=True,
        marker_end="url(#arrow-msg)",
    )
    svg.path(
        f"M {m_login[2]} {m_login[3]} C {m_login[2] + 50} {m_login[3]}, "
        f"{400} {sys_y - 20}, 430 {sys_y}",
        stroke=MSG,
        dashed=True,
        marker_end="url(#arrow-msg)",
    )
    svg.path(
        f"M {s_login[2]} {s_login[3]} C {s_login[2] + 40} {s_login[3]}, "
        f"{410} {sys_y + 10}, 430 {sys_y + 15}",
        stroke=MSG,
        dashed=True,
        marker_end="url(#arrow-msg)",
    )

    # ---- Phase 2: Donation Intake ----
    d_submit = task(
        svg,
        620,
        donor_y - 70,
        150,
        58,
        "Submit donation form + proof",
        DONOR_STROKE,
    )
    svg.path(
        f"M {d_login[2]} {donor_y - 40} L {d_submit[0] - 75} {donor_y - 40}",
        stroke=DONOR_STROKE,
    )

    sys_pending = task(
        svg,
        620,
        sys_y - 29,
        150,
        58,
        "Create submission (pending)",
        SYSTEM_STROKE,
    )
    svg.path(
        f"M {d_submit[0]} {d_submit[3] + 29} L {d_submit[0]} {sys_pending[1] - 29}",
        stroke=MSG,
        dashed=True,
        marker_end="url(#arrow-msg)",
    )

    m_review = task(
        svg,
        820,
        mgr_y - 29,
        140,
        58,
        "Review pending submission",
        MANAGER_STROKE,
    )
    svg.path(
        f"M {sys_pending[2]} {sys_y} C {780} {sys_y}, {780} {mgr_y}, {820} {mgr_y}",
        stroke=MSG,
        dashed=True,
        marker_end="url(#arrow-msg)",
    )

    gateway(svg, 1020, mgr_y, "Decision", MANAGER_STROKE)
    svg.line(m_review[2], mgr_y, 998, mgr_y, stroke=MANAGER_STROKE)

    m_approve = task(
        svg,
        1080,
        mgr_y - 70,
        130,
        52,
        "Approve submission",
        MANAGER_STROKE,
    )
    m_reject = task(
        svg,
        1080,
        mgr_y + 20,
        130,
        52,
        "Decline submission",
        MANAGER_STROKE,
    )
    svg.path(
        f"M 1040 {mgr_y - 8} L 1040 {m_approve[1] + 26} L 1080 {m_approve[1] + 26}",
        stroke=MANAGER_STROKE,
    )
    svg.text(1055, mgr_y - 55, "yes", size=11, weight="700", fill=MANAGER_STROKE)
    svg.path(
        f"M 1040 {mgr_y + 8} L 1040 {m_reject[1] + 26} L 1080 {m_reject[1] + 26}",
        stroke=MANAGER_STROKE,
    )
    svg.text(1055, mgr_y + 55, "no", size=11, weight="700", fill=MANAGER_STROKE)

    sys_status = task(
        svg,
        1260,
        sys_y - 29,
        150,
        58,
        "Update status approved / rejected",
        SYSTEM_STROKE,
    )
    svg.path(
        f"M {m_approve[2]} {m_approve[3]} C {1220} {m_approve[3]}, "
        f"{1220} {sys_y - 10}, 1260 {sys_y - 5}",
        stroke=MSG,
        dashed=True,
        marker_end="url(#arrow-msg)",
    )
    svg.path(
        f"M {m_reject[2]} {m_reject[3]} C {1230} {m_reject[3]}, "
        f"{1230} {sys_y + 15}, 1260 {sys_y + 10}",
        stroke=MSG,
        dashed=True,
        marker_end="url(#arrow-msg)",
    )

    end_event(svg, 1460, donor_y + 50, "Rejected end", DONOR_STROKE)
    svg.path(
        f"M {sys_status[0]} {sys_y - 29} C {1460} {sys_y - 80}, "
        f"{1460} {donor_y + 80}, 1460 {donor_y + 66}",
        stroke=MSG,
        dashed=True,
        marker_end="url(#arrow-msg)",
    )
    svg.text(
        1380,
        donor_y + 20,
        "if rejected",
        size=11,
        weight="600",
        fill=MUTED,
    )

    d_wait = task(
        svg,
        1260,
        donor_y - 70,
        140,
        58,
        "Await approval / drop-off",
        DONOR_STROKE,
    )
    svg.path(
        f"M {d_submit[2]} {donor_y - 40} L {d_wait[0] - 70} {donor_y - 40}",
        stroke=DONOR_STROKE,
    )

    m_receive = task(
        svg,
        1450,
        mgr_y - 70,
        140,
        58,
        "Confirm items received",
        MANAGER_STROKE,
    )
    svg.path(
        f"M {m_approve[2]} {m_approve[3]} L {1450} {m_approve[3]}",
        stroke=MANAGER_STROKE,
    )

    # ---- Phase 3: Inventory Receipt ----
    m_stock_don = task(
        svg,
        1640,
        mgr_y - 70,
        150,
        58,
        "Stock in donated items",
        MANAGER_STROKE,
    )
    svg.line(m_receive[2], mgr_y - 40, 1640, mgr_y - 40, stroke=MANAGER_STROKE)

    s_stock_buy = task(
        svg,
        1640,
        staff_y - 70,
        150,
        58,
        "Stock in purchased goods",
        STAFF_STROKE,
    )
    # Staff can also start purchase path after login
    svg.path(
        f"M {s_login[2]} {staff_y} C {900} {staff_y}, {1400} {staff_y - 40}, "
        f"1640 {staff_y - 40}",
        stroke=STAFF_STROKE,
        sw=1.4,
    )
    svg.text(
        1180,
        staff_y - 55,
        "purchase path",
        size=11,
        weight="600",
        fill=STAFF_STROKE,
    )

    sys_stock = task(
        svg,
        1640,
        sys_y - 29,
        170,
        58,
        "Create batches (FEFO) + grow dual-pool stock",
        SYSTEM_STROKE,
    )
    svg.path(
        f"M {m_stock_don[0]} {m_stock_don[3] + 29} L {m_stock_don[0]} {sys_y - 29}",
        stroke=MSG,
        dashed=True,
        marker_end="url(#arrow-msg)",
    )
    svg.path(
        f"M {s_stock_buy[0]} {s_stock_buy[3] + 29} L {s_stock_buy[0]} {sys_y - 29}",
        stroke=MSG,
        dashed=True,
        marker_end="url(#arrow-msg)",
    )
    svg.path(
        f"M {sys_status[2]} {sys_y} L {sys_stock[0] - 85} {sys_y}",
        stroke=SYSTEM_STROKE,
        sw=1.4,
    )

    sys_stocked = task(
        svg,
        1850,
        sys_y - 70,
        140,
        52,
        "Mark submission stocked",
        SYSTEM_STROKE,
    )
    svg.line(sys_stock[2], sys_y - 45, 1850, sys_y - 45, stroke=SYSTEM_STROKE)

    # ---- Phase 4: Clinical / Usage ----
    s_treat = task(
        svg,
        1850,
        staff_y - 70,
        140,
        52,
        "Record medical treatment",
        STAFF_STROKE,
    )
    s_out = task(
        svg,
        1850,
        staff_y + 10,
        140,
        52,
        "Stock out waste/expired/adjust",
        STAFF_STROKE,
    )
    gateway(svg, 1780, staff_y, "Use stock", STAFF_STROKE)
    svg.path(
        f"M {s_stock_buy[2]} {staff_y - 40} L {1758} {staff_y - 40} "
        f"L 1758 {staff_y}",
        stroke=STAFF_STROKE,
    )
    # also from donated stock available
    svg.path(
        f"M {sys_stock[2]} {sys_y} C {1760} {sys_y}, {1720} {staff_y + 40}, "
        f"1760 {staff_y + 18}",
        stroke=MSG,
        dashed=True,
        marker_end="url(#arrow-msg)",
        sw=1.3,
    )
    svg.path(
        f"M 1800 {staff_y - 10} L 1800 {s_treat[1] + 26} L 1850 {s_treat[1] + 26}",
        stroke=STAFF_STROKE,
    )
    svg.path(
        f"M 1800 {staff_y + 10} L 1800 {s_out[1] + 26} L 1850 {s_out[1] + 26}",
        stroke=STAFF_STROKE,
    )

    sys_deduct = task(
        svg,
        2040,
        sys_y - 29,
        160,
        58,
        "FEFO deduct / write stock_out + FIFO impact",
        SYSTEM_STROKE,
    )
    svg.path(
        f"M {s_treat[2]} {s_treat[3]} C {2000} {s_treat[3]}, "
        f"{2000} {sys_y - 10}, 2040 {sys_y - 5}",
        stroke=MSG,
        dashed=True,
        marker_end="url(#arrow-msg)",
    )
    svg.path(
        f"M {s_out[2]} {s_out[3]} C {2010} {s_out[3]}, "
        f"{2010} {sys_y + 15}, 2040 {sys_y + 10}",
        stroke=MSG,
        dashed=True,
        marker_end="url(#arrow-msg)",
    )

    # ---- Phase 5: Replenish ----
    sys_rop = task(
        svg,
        2240,
        sys_y - 29,
        150,
        58,
        "Compute ADU + ROP suggestions",
        SYSTEM_STROKE,
    )
    svg.line(sys_deduct[2], sys_y, 2240, sys_y, stroke=SYSTEM_STROKE)

    s_order = task(
        svg,
        2240,
        staff_y - 29,
        150,
        58,
        "Review Ordering replenishment",
        STAFF_STROKE,
    )
    svg.path(
        f"M {sys_rop[0]} {sys_y - 29} L {sys_rop[0]} {staff_y + 29}",
        stroke=MSG,
        dashed=True,
        marker_end="url(#arrow-msg)",
    )

    # loop back note to purchase stock-in
    svg.path(
        f"M {s_order[0]} {staff_y + 29} C {2240} {staff_y + 70}, "
        f"{1700} {staff_y + 75}, 1715 {staff_y + 29}",
        stroke=STAFF_STROKE,
        sw=1.4,
        dashed=True,
    )
    svg.text(
        1960,
        staff_y + 88,
        "manual purchase stock-in (no auto-PO)",
        size=11,
        weight="700",
        fill=STAFF_STROKE,
    )

    m_cfg = task(
        svg,
        2240,
        mgr_y - 29,
        150,
        58,
        "Configure thresholds & ROP",
        MANAGER_STROKE,
    )
    svg.path(
        f"M {m_cfg[0]} {mgr_y + 29} L {m_cfg[0]} {sys_rop[1] - 29}",
        stroke=MSG,
        dashed=True,
        marker_end="url(#arrow-msg)",
        sw=1.3,
    )

    # ---- Phase 6: Oversight & Impact ----
    d_impact = task(
        svg,
        2460,
        donor_y - 70,
        150,
        58,
        "View donation impact",
        DONOR_STROKE,
    )
    svg.path(
        f"M {d_wait[2]} {donor_y - 40} C {2000} {donor_y - 40}, "
        f"{2300} {donor_y - 40}, 2460 {donor_y - 40}",
        stroke=DONOR_STROKE,
        sw=1.4,
    )

    m_report = task(
        svg,
        2460,
        mgr_y - 70,
        150,
        52,
        "Review usage / ROP / audit",
        MANAGER_STROKE,
    )
    s_report = task(
        svg,
        2460,
        staff_y - 70,
        150,
        52,
        "View usage + My Activity",
        STAFF_STROKE,
    )
    sys_alert = task(
        svg,
        2460,
        sys_y - 29,
        150,
        58,
        "Raise alerts + serve reports",
        SYSTEM_STROKE,
    )
    svg.line(sys_rop[2], sys_y, 2460, sys_y, stroke=SYSTEM_STROKE)
    svg.path(
        f"M {sys_deduct[2]} {sys_y - 20} C {2400} {sys_y - 80}, "
        f"{2400} {donor_y}, 2460 {donor_y - 20}",
        stroke=MSG,
        dashed=True,
        marker_end="url(#arrow-msg)",
        sw=1.3,
    )
    svg.path(
        f"M {sys_alert[0]} {sys_y - 29} L {sys_alert[0]} {mgr_y + 26}",
        stroke=MSG,
        dashed=True,
        marker_end="url(#arrow-msg)",
        sw=1.2,
    )
    svg.path(
        f"M {sys_alert[0] + 30} {sys_y - 29} L {sys_alert[0] + 30} {staff_y - 18}",
        stroke=MSG,
        dashed=True,
        marker_end="url(#arrow-msg)",
        sw=1.2,
    )

    end_event(svg, 2680, sys_y, "Operational end", SYSTEM_STROKE)
    svg.line(sys_alert[2], sys_y, 2664, sys_y, stroke=SYSTEM_STROKE)

    # Legend
    ly = top + pool_h + 28
    svg.text(left_gutter + 60, ly + 8, "Legend", size=13, weight="800", anchor="start")
    svg.rect(left_gutter + 140, ly - 12, 70, 28, TASK_FILL, INK, r=8)
    svg.text(left_gutter + 175, ly + 8, "Task", size=12, weight="600")
    svg.diamond(left_gutter + 260, ly + 2, 14, GW_FILL, INK)
    svg.text(left_gutter + 260, ly + 36, "XOR", size=11, weight="600", fill=MUTED)
    svg.circle(left_gutter + 330, ly + 2, 10, START_FILL, DONOR_STROKE, 2)
    svg.text(left_gutter + 330, ly + 36, "Start", size=11, weight="600", fill=MUTED)
    svg.circle(left_gutter + 390, ly + 2, 10, END_FILL, SYSTEM_STROKE, 2)
    svg.circle(left_gutter + 390, ly + 2, 6, END_FILL, SYSTEM_STROKE, 2.5)
    svg.text(left_gutter + 390, ly + 36, "End", size=11, weight="600", fill=MUTED)
    svg.line(left_gutter + 440, ly + 2, left_gutter + 520, ly + 2, stroke=INK)
    svg.text(left_gutter + 560, ly + 8, "Sequence flow", size=12, weight="600")
    svg.line(
        left_gutter + 680,
        ly + 2,
        left_gutter + 760,
        ly + 2,
        stroke=MSG,
        dashed=True,
        marker_end="url(#arrow-msg)",
    )
    svg.text(left_gutter + 820, ly + 8, "Message / data flow", size=12, weight="600")
    svg.text(
        left_gutter + 1040,
        ly + 8,
        "Supplier = external data only (no login lane) · ROP recommends only (no auto-PO)",
        size=12,
        weight="600",
        fill=MUTED,
        anchor="start",
    )
    svg.text(
        left_gutter + 1040,
        ly + 30,
        "Submission statuses: pending → approved → received → stocked · rejected from pending",
        size=12,
        weight="600",
        fill=MUTED,
        anchor="start",
    )

    return svg.finish()


def main() -> None:
    svg = build()
    OUT.write_text(svg, encoding="utf-8")
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
