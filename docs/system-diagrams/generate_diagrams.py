#!/usr/bin/env python3
"""Generate SIYAM conceptual, top-level, and level-of-explosion SVGs.

Diagram content is taken from the current product (nav, services, schema),
not from unpublished WBS numbers or unbuilt features.
"""

from __future__ import annotations

import html
from dataclasses import dataclass, field
from pathlib import Path

OUT = Path(__file__).resolve().parent

# SIYAM palette (lib/core/app_colors.dart)
SAGE = "#93B873"
SAGE_TINT = "#E9F1E2"
SAGE_DEEP = "#5A6E4E"
SKY = "#2D82C4"
SKY_TINT = "#E6F1F8"
AMBER = "#E8A93D"
AMBER_DEEP = "#C97C1F"
AMBER_TINT = "#FBEFD4"
BROWN = "#3E2723"
CREAM = "#FFF8F0"
CORAL = "#E5445C"
WHITE = "#FFFFFF"
MUTED = "#7A756E"
BORDER = "#C5D6B8"
LINE = "#6B7D6D"


def esc(text: str) -> str:
    return html.escape(text, quote=True)


def wrap(text: str, width: int) -> list[str]:
    words = text.split()
    if not words:
        return [""]
    lines: list[str] = []
    current = words[0]
    for word in words[1:]:
        trial = f"{current} {word}"
        if len(trial) <= width:
            current = trial
        else:
            lines.append(current)
            current = word
    lines.append(current)
    return lines


@dataclass
class Node:
    code: str
    title: str
    note: str = ""
    fill: str = SAGE_TINT
    stroke: str = SAGE_DEEP
    children: list["Node"] = field(default_factory=list)
    x: float = 0
    y: float = 0
    w: float = 188
    h: float = 62
    subtree_w: float = 0


def measure(node: Node, h_gap: float = 22) -> None:
    for child in node.children:
        measure(child, h_gap)
    if not node.children:
        node.subtree_w = node.w
        return
    span = sum(c.subtree_w for c in node.children) + h_gap * (len(node.children) - 1)
    node.subtree_w = max(span, node.w)


def place(node: Node, left: float, top: float, v_gap: float = 78, h_gap: float = 22) -> None:
    node.x = left + (node.subtree_w - node.w) / 2
    node.y = top
    if not node.children:
        return
    span = sum(c.subtree_w for c in node.children) + h_gap * (len(node.children) - 1)
    child_left = left + (node.subtree_w - span) / 2
    for child in node.children:
        place(child, child_left, top + node.h + v_gap, v_gap, h_gap)
        child_left += child.subtree_w + h_gap


def walk(node: Node) -> list[Node]:
    nodes = [node]
    for child in node.children:
        nodes.extend(walk(child))
    return nodes


class Diagram:
    def __init__(self, width: float, height: float, title: str, subtitle: str) -> None:
        self.width = width
        self.height = height
        self.title = title
        self.subtitle = subtitle
        self.parts: list[str] = []

    def add(self, markup: str) -> None:
        self.parts.append(markup)

    def rect(
        self,
        x: float,
        y: float,
        w: float,
        h: float,
        fill: str,
        stroke: str,
        radius: float = 10,
        sw: float = 1.6,
    ) -> None:
        self.add(
            f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" '
            f'rx="{radius}" ry="{radius}" fill="{fill}" stroke="{stroke}" '
            f'stroke-width="{sw}"/>'
        )

    def line(
        self,
        x1: float,
        y1: float,
        x2: float,
        y2: float,
        color: str = LINE,
        sw: float = 1.4,
        dashed: bool = False,
    ) -> None:
        dash = ' stroke-dasharray="6 4"' if dashed else ""
        self.add(
            f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" '
            f'stroke="{color}" stroke-width="{sw}"{dash}/>'
        )

    def arrow(
        self,
        x1: float,
        y1: float,
        x2: float,
        y2: float,
        color: str = LINE,
        sw: float = 1.4,
        dashed: bool = False,
    ) -> None:
        dash = ' stroke-dasharray="6 4"' if dashed else ""
        self.add(
            f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" '
            f'stroke="{color}" stroke-width="{sw}" marker-end="url(#arrow)"{dash}/>'
        )

    def text(
        self,
        x: float,
        y: float,
        content: str,
        *,
        size: float = 13,
        weight: str = "600",
        fill: str = BROWN,
        anchor: str = "middle",
        italic: bool = False,
    ) -> None:
        style = "italic" if italic else "normal"
        self.add(
            f'<text x="{x:.1f}" y="{y:.1f}" text-anchor="{anchor}" '
            f'font-family="Segoe UI, Helvetica, Arial, sans-serif" '
            f'font-size="{size}" font-weight="{weight}" font-style="{style}" '
            f'fill="{fill}">{esc(content)}</text>'
        )

    def multiline(
        self,
        cx: float,
        cy: float,
        lines: list[str],
        *,
        size: float = 12,
        weight: str = "600",
        fill: str = BROWN,
        leading: float = 15,
    ) -> None:
        start = cy - (len(lines) - 1) * leading / 2 + 4
        for i, line in enumerate(lines):
            self.text(cx, start + i * leading, line, size=size, weight=weight, fill=fill)

    def box(
        self,
        x: float,
        y: float,
        w: float,
        h: float,
        lines: list[str],
        fill: str,
        stroke: str,
        *,
        size: float = 12,
        radius: float = 10,
        sw: float = 1.6,
    ) -> None:
        self.rect(x, y, w, h, fill, stroke, radius=radius, sw=sw)
        char_w = max(18, int(w / 7.4))
        wrapped: list[tuple[str, str, float]] = []
        for i, line in enumerate(lines):
            weight = "700" if i == 0 else "500"
            font = size if i == 0 else size - 1
            parts = wrap(line, char_w)
            for part in parts:
                wrapped.append((part, weight, font))
                weight = "500"
                font = size - 1
        leading = 15 if len(wrapped) <= 3 else 13.5
        start = y + h / 2 - (len(wrapped) - 1) * leading / 2 + 4
        for i, (line, weight, font) in enumerate(wrapped):
            self.text(
                x + w / 2,
                start + i * leading,
                line,
                size=font,
                weight=weight,
            )

    def label_on_line(self, x: float, y: float, text: str, fill: str = MUTED) -> None:
        self.rect(x - 70, y - 9, 140, 16, WHITE, WHITE, radius=3, sw=0)
        self.text(x, y + 3, text, size=10, weight="500", fill=fill)

    def header_footer(self) -> None:
        self.rect(0, 0, self.width, self.height, CREAM, CREAM, radius=0, sw=0)
        self.rect(0, 0, self.width, 64, WHITE, BORDER, radius=0, sw=1)
        self.rect(0, 0, 8, 64, SAGE, SAGE, radius=0, sw=0)
        self.text(24, 28, self.title, size=18, weight="700", anchor="start")
        self.text(24, 50, self.subtitle, size=12, weight="500", fill=MUTED, anchor="start")
        self.rect(0, self.height - 36, self.width, 36, WHITE, BORDER, radius=0, sw=1)
        self.text(
            24,
            self.height - 14,
            "SIYAM — Animal Sanctuary Management System. Drawn from current modules, services, and updated_db.md.",
            size=11,
            weight="500",
            fill=MUTED,
            anchor="start",
        )

    def to_svg(self) -> str:
        body = "\n  ".join(self.parts)
        return f"""<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{self.width:.0f}" height="{self.height:.0f}"
     viewBox="0 0 {self.width:.0f} {self.height:.0f}" role="img">
  <defs>
    <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5"
            markerWidth="8" markerHeight="8" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="{LINE}"/>
    </marker>
  </defs>
  {body}
</svg>
"""

    def save(self, name: str) -> Path:
        path = OUT / name
        path.write_text(self.to_svg(), encoding="utf-8")
        return path


def draw_tree(
    d: Diagram,
    root: Node,
    origin_x: float,
    origin_y: float,
    v_gap: float = 78,
    h_gap: float = 22,
) -> None:
    measure(root, h_gap)
    place(root, origin_x, origin_y, v_gap, h_gap)
    nodes = walk(root)
    for parent in nodes:
        if not parent.children:
            continue
        bus_y = parent.y + parent.h + v_gap / 2
        px = parent.x + parent.w / 2
        d.line(px, parent.y + parent.h, px, bus_y)
        xs = [c.x + c.w / 2 for c in parent.children]
        d.line(min(xs), bus_y, max(xs), bus_y)
        for child in parent.children:
            cx = child.x + child.w / 2
            d.line(cx, bus_y, cx, child.y)
    for node in nodes:
        lines = [f"{node.code}  {node.title}"]
        if node.note:
            lines.append(node.note)
        needed = 24 + (2 if node.note else 1) * 16
        h = max(node.h, needed)
        y = node.y - (h - node.h) / 2
        d.box(node.x, y, node.w, h, lines, node.fill, node.stroke)


def legend(d: Diagram, x: float, y: float, items: list[tuple[str, str, str]]) -> None:
    d.text(x, y, "Legend", size=11, weight="700", anchor="start", fill=MUTED)
    for i, (fill, stroke, label) in enumerate(items):
        yy = y + 14 + i * 22
        d.rect(x, yy, 18, 14, fill, stroke, radius=3, sw=1.2)
        d.text(x + 26, yy + 11, label, size=11, weight="500", anchor="start", fill=MUTED)


def conceptual_context() -> Diagram:
    d = Diagram(
        1480,
        920,
        "Conceptual Diagram — System Context",
        "What SIYAM is, who uses it, and which external systems it talks to.",
    )
    d.header_footer()

    # Actors
    actors = [
        (90, 110, "Manager", "Sanctuary oversight", SAGE_TINT, SAGE_DEEP),
        (390, 110, "Staff", "Day-to-day operations", SKY_TINT, SKY),
        (690, 110, "Donor", "Give supplies & track impact", AMBER_TINT, AMBER_DEEP),
        (990, 110, "Suppliers", "Recorded vendors, not login users", WHITE, MUTED),
    ]
    for x, y, title, note, fill, stroke in actors:
        d.box(x, y, 240, 70, [title, note], fill, stroke)

    # System
    d.rect(280, 300, 700, 250, WHITE, SAGE_DEEP, radius=18, sw=2.2)
    d.rect(280, 300, 700, 46, SAGE_TINT, SAGE_DEEP, radius=0, sw=0)
    d.rect(280, 300, 700, 46, SAGE_TINT, SAGE_DEEP, radius=18, sw=2.2)
    d.rect(280, 328, 700, 18, SAGE_TINT, SAGE_TINT, radius=0, sw=0)
    d.text(630, 330, "0.0  SIYAM", size=20, weight="700")
    d.text(630, 372, "Animal Sanctuary Management System", size=14, weight="600", fill=SAGE_DEEP)
    d.multiline(
        630,
        430,
        [
            "Role-based Flutter web app for sanctuary operations:",
            "animal records, inventory, medical treatments, purchasing,",
            "donations, replenishment advice, reports, and audit.",
        ],
        size=13,
        weight="500",
        leading=18,
    )
    d.box(330, 490, 190, 40, ["Manager portal"], SAGE_TINT, SAGE_DEEP, size=12)
    d.box(535, 490, 190, 40, ["Staff portal"], SKY_TINT, SKY, size=12)
    d.box(740, 490, 190, 40, ["Donor portal"], AMBER_TINT, AMBER_DEEP, size=12)

    # Backend
    d.box(180, 680, 300, 80, ["Mock backend", "In-memory data for local/dev"], WHITE, MUTED)
    d.box(560, 680, 360, 80, ["Supabase backend", "GoTrue auth + Postgres + RLS"], SKY_TINT, SKY)
    d.box(990, 680, 300, 80, ["Static web host", "Flutter web build (e.g. Vercel)"], WHITE, MUTED)

    # Actor arrows into system
    d.arrow(210, 180, 430, 300)
    d.label_on_line(300, 232, "oversight / settings")
    d.arrow(510, 180, 590, 300)
    d.label_on_line(545, 232, "stock / treatments")
    d.arrow(810, 180, 760, 300)
    d.label_on_line(800, 232, "submissions / impact")
    d.arrow(1110, 180, 900, 360, dashed=True)
    d.label_on_line(1060, 268, "vendor records only")

    # System to backends
    d.arrow(480, 550, 330, 680)
    d.label_on_line(380, 620, "USE_MOCK=true")
    d.arrow(630, 550, 740, 680)
    d.label_on_line(720, 620, "USE_MOCK=false")
    d.arrow(900, 430, 1140, 680, dashed=True)
    d.label_on_line(1080, 540, "serves the UI")

    legend(
        d,
        1180,
        300,
        [
            (SAGE_TINT, SAGE_DEEP, "Manager-facing"),
            (SKY_TINT, SKY, "Staff / backend"),
            (AMBER_TINT, AMBER_DEEP, "Donor-facing"),
            (WHITE, MUTED, "External / supporting"),
        ],
    )
    return d


def conceptual_framework() -> Diagram:
    d = Diagram(
        1480,
        900,
        "Conceptual Diagram — Input / Process / Output",
        "The system as a whole: what goes in, what SIYAM does, what comes out.",
    )
    d.header_footer()

    cols = [
        (50, "INPUT", SAGE_TINT, SAGE_DEEP, [
            "Signed-in Manager, Staff, or Donor",
            "Animal identity and status",
            "Item catalog, units, categories",
            "Stock-in batches (purchase / donation)",
            "Stock-out reasons (waste / expired / adjustment)",
            "Treatment doses given to an animal",
            "Donation submissions and drop-off details",
            "Supplier and purchase records",
            "Alert thresholds and ROP defaults",
        ]),
        (510, "PROCESS  —  SIYAM", SKY_TINT, SKY, [
            "Authenticate and gate routes by role",
            "Keep animal and medical records",
            "Track dual-pool stock and FEFO batches",
            "Deduct deductible treatments from stock",
            "Recommend replenishment (does not auto-buy)",
            "Review donations through to stock-in",
            "Attribute used donations via FIFO impact",
            "Raise zero / low / expiry / donor alerts",
            "Write and show operational audit activity",
        ]),
        (970, "OUTPUT", AMBER_TINT, AMBER_DEEP, [
            "Role dashboards and navigation",
            "Current stock and movement history",
            "Treatment history per animal",
            "Replenishment shortfall suggestions",
            "Approved / received / stocked donations",
            "Donor impact (used / discarded / remaining)",
            "Monthly usage and manager ROP reports",
            "Audit trail / Staff My Activity",
            "Notifications for the signed-in role",
        ]),
    ]

    for x, title, fill, stroke, items in cols:
        d.rect(x, 100, 430, 720, WHITE, stroke, radius=16, sw=1.8)
        d.rect(x, 100, 430, 52, fill, stroke, radius=16, sw=1.8)
        d.rect(x, 132, 430, 20, fill, fill, radius=0, sw=0)
        d.text(x + 215, 134, title, size=16, weight="700")
        for i, item in enumerate(items):
            yy = 180 + i * 66
            d.box(x + 24, yy, 382, 52, wrap(item, 42), fill, stroke, size=13)

    d.arrow(480, 460, 510, 460)
    d.arrow(940, 460, 970, 460)
    return d


def top_level_functional() -> Diagram:
    d = Diagram(
        1560,
        760,
        "Top-Level Diagram — Functional Explosion of 0.0 SIYAM",
        "First decomposition of the whole system into the modules that actually exist in the app.",
    )
    d.header_footer()
    root = Node("0.0", "SIYAM", "Animal Sanctuary Management", fill=WHITE, stroke=SAGE_DEEP, w=260, h=70)
    root.children = [
        Node("1.0", "Access & Identity", "Login, roles, profile", fill=SAGE_TINT, stroke=SAGE_DEEP),
        Node("2.0", "Dashboards", "Manager / Staff / Donor", fill=SAGE_TINT, stroke=SAGE_DEEP),
        Node("3.0", "Animal & Medical", "Pets and treatments", fill=SKY_TINT, stroke=SKY),
        Node("4.0", "Inventory Control", "Stock in, out, FEFO", fill=SKY_TINT, stroke=SKY),
        Node("5.0", "Procurement", "Suppliers, ROP, purchases", fill=SKY_TINT, stroke=SKY),
        Node("6.0", "Donations", "Submissions and impact", fill=AMBER_TINT, stroke=AMBER_DEEP),
        Node("7.0", "Oversight", "Reports, audit, settings", fill=SAGE_TINT, stroke=SAGE_DEEP),
    ]
    draw_tree(d, root, 40, 120, v_gap=120, h_gap=16)
    d.text(
        780,
        430,
        "Each 1.0–7.0 box is exploded on the following Level of Explosion diagrams.",
        size=12,
        weight="500",
        fill=MUTED,
    )
    return d


def top_level_software() -> Diagram:
    d = Diagram(
        1480,
        980,
        "Top-Level Diagram — Software Structure",
        "How the running system is layered. The UI does not know which backend is compiled in.",
    )
    d.header_footer()

    layers = [
        (100, "Presentation", SAGE_TINT, SAGE_DEEP, [
            "Flutter Web pages, AppShell, role navigation (go_router + nav_config)",
            "Public: /login, /register    Authenticated shell: dashboards and modules",
        ]),
        (250, "Client state", AMBER_TINT, AMBER_DEEP, [
            "AuthController — session, profile, router refresh",
            "DataChangeBus — after a successful write, the visible page re-fetches",
        ]),
        (400, "Domain services", SKY_TINT, SKY, [
            "Abstract interfaces + factory: Auth, Inventory, Catalog, Pet, Supplier,",
            "Donation, Treatment, Dashboard, Settings, Impact, ROP, Reports, Audit, Replenishment",
        ]),
        (560, "Backend implementations  (compile-time USE_MOCK)", WHITE, MUTED, [
            "Mock* services  →  MockDatabase (seeded in-memory, resets on restart)",
            "Supabase* services  →  GoTrue + Postgres (RLS). Some services are Supabase-only.",
        ]),
        (740, "Data", CREAM, SAGE_DEEP, [
            "Tables in updated_db.md: USER, catalog, ITEM, PET, SUPPLIER, PURCHASE*,",
            "TREATMENT*, SUBMISSION, DONATION*, STOCK_OUT, SYSTEM_SETTINGS",
        ]),
    ]
    for y, title, fill, stroke, lines in layers:
        d.rect(80, y, 1320, 120, WHITE, stroke, radius=14, sw=1.8)
        d.rect(80, y, 220, 120, fill, stroke, radius=14, sw=1.8)
        d.rect(280, y, 20, 120, fill, fill, radius=0, sw=0)
        d.multiline(190, y + 60, wrap(title, 14), size=14, weight="700")
        d.multiline(900, y + 50, lines, size=14, weight="500", leading=22)

    for y in (220, 370, 520, 680):
        d.arrow(740, y, 740, y + 30)

    d.box(80, 880, 430, 44, ["kUseMock true → mock path"], WHITE, MUTED, size=12)
    d.box(540, 880, 430, 44, ["kUseMock false → Supabase path"], SKY_TINT, SKY, size=12)
    d.box(1000, 880, 400, 44, ["Call sites always use Service()"], SAGE_TINT, SAGE_DEEP, size=12)
    return d


def loe_access() -> Diagram:
    d = Diagram(
        1480,
        720,
        "Level of Explosion — 1.0 Access & Identity",
        "Who may enter SIYAM, which portal they get, and how accounts are maintained.",
    )
    d.header_footer()
    root = Node("1.0", "Access & Identity", fill=WHITE, stroke=SAGE_DEEP, w=220, h=64)
    root.children = [
        Node("1.1", "Sign in", "email + password", fill=SAGE_TINT, stroke=SAGE_DEEP),
        Node("1.2", "Donor register", "self-serve from login", fill=AMBER_TINT, stroke=AMBER_DEEP),
        Node("1.3", "Session restore", "Supabase; mock is in-memory", fill=SKY_TINT, stroke=SKY),
        Node("1.4", "Role routing", "nav_config + go_router", fill=SAGE_TINT, stroke=SAGE_DEEP),
        Node("1.5", "Profile", "name, contact, password", fill=SAGE_TINT, stroke=SAGE_DEEP),
        Node("1.6", "Staff accounts", "manager enable / disable", fill=SAGE_TINT, stroke=SAGE_DEEP),
    ]
    draw_tree(d, root, 30, 120, v_gap=110, h_gap=14)
    d.box(
        80,
        520,
        1320,
        120,
        [
            "Roles in the USER table: manager, staff, donor. Donors cannot open staff/manager modules;",
            "staff/manager cannot open the donor dashboard. Manager may use /inventory/add only when stocking a donation.",
            "Supabase can restore a session across refresh; mock auth holds the user only until the app restarts.",
        ],
        WHITE,
        BORDER,
        size=13,
    )
    return d


def loe_dashboards() -> Diagram:
    d = Diagram(
        1480,
        780,
        "Level of Explosion — 2.0 Role Dashboards",
        "The same /dashboard route renders different home screens by AppRole.",
    )
    d.header_footer()
    root = Node("2.0", "Dashboards", fill=WHITE, stroke=SAGE_DEEP, w=220, h=64)
    root.children = [
        Node("2.1", "Manager home", "counts, alerts, staff accounts, inventory overview", fill=SAGE_TINT, stroke=SAGE_DEEP, w=300, h=80),
        Node("2.2", "Staff home", "period stats, replenishment, social post helper", fill=SKY_TINT, stroke=SKY, w=300, h=80),
        Node("2.3", "Donor home", "submission status, recent impact", fill=AMBER_TINT, stroke=AMBER_DEEP, w=300, h=80),
    ]
    draw_tree(d, root, 180, 120, v_gap=120, h_gap=40)
    d.box(
        80,
        520,
        1320,
        160,
        [
            "Manager cards are clickable into the matching module or a read-only overview. Manager replenishment on the dashboard is read-only.",
            "Staff dashboard can generate a social-media post from the same replenishment tiers used by Ordering.",
            "Donor dashboard is also mounted at /donor. Shared profile and notifications sit outside this explosion (see 1.5 and 7.4).",
        ],
        WHITE,
        BORDER,
        size=13,
    )
    return d


def loe_animal_medical() -> Diagram:
    d = Diagram(
        1560,
        820,
        "Level of Explosion — 3.0 Animal & Medical Care",
        "Manager owns animal records. Staff owns treatments. Treatments can deduct inventory.",
    )
    d.header_footer()
    root = Node("3.0", "Animal & Medical Care", fill=WHITE, stroke=SKY, w=260, h=64)
    animals = Node("3.1", "Animal records", "Manager", fill=SAGE_TINT, stroke=SAGE_DEEP, w=210, h=70)
    animals.children = [
        Node("3.1.1", "Create / update", "name, species, breed, gender, owner, spay/neuter", fill=SAGE_TINT, stroke=SAGE_DEEP, w=210, h=78),
        Node("3.1.2", "Set status", "healthy / under treatment / adopted / deceased", fill=SAGE_TINT, stroke=SAGE_DEEP, w=210, h=78),
    ]
    medical = Node("3.2", "Treatments", "Staff", fill=SKY_TINT, stroke=SKY, w=220, h=70)
    medical.children = [
        Node("3.2.1", "Log treatment", "animal, items, given-by, notes", fill=SKY_TINT, stroke=SKY, w=200, h=78),
        Node("3.2.2", "Follow-up dose", "new TREATMENT_ITEM row, never merged", fill=SKY_TINT, stroke=SKY, w=200, h=78),
        Node("3.2.3", "Medical history", "per animal", fill=SKY_TINT, stroke=SKY, w=180, h=78),
        Node("3.2.4", "Stock deduction", "FEFO when the dose is deductible", fill=AMBER_TINT, stroke=AMBER_DEEP, w=210, h=78),
    ]
    root.children = [animals, medical]
    draw_tree(d, root, 40, 110, v_gap=90, h_gap=18)
    d.box(
        80,
        620,
        1400,
        120,
        [
            "Deductible: dispense unit matches package unit (package pool only) or there is no package breakdown (purchase pool).",
            "Not deducted: dispense unit differs from package unit (e.g. drops vs ml). The treatment row is still saved. See KNOWN_LIMITATIONS.md.",
        ],
        WHITE,
        BORDER,
        size=13,
    )
    return d


def loe_inventory() -> Diagram:
    d = Diagram(
        1580,
        820,
        "Level of Explosion — 4.0 Inventory Control",
        "Staff module. Dual stock pools, FEFO batches, and movement history.",
    )
    d.header_footer()
    root = Node("4.0", "Inventory Control", fill=WHITE, stroke=SKY, w=240, h=64)
    root.children = [
        Node("4.1", "Browse items", "headline qty from stock_count_mode", fill=SKY_TINT, stroke=SKY, w=200, h=78),
        Node("4.2", "Item catalog", "name, category, units, count mode", fill=SKY_TINT, stroke=SKY, w=200, h=78),
        Node("4.3", "Stock In", "purchase or donation batch", fill=SAGE_TINT, stroke=SAGE_DEEP, w=200, h=78),
        Node("4.4", "Stock Out", "waste / expired / adjustment", fill=AMBER_TINT, stroke=AMBER_DEEP, w=210, h=78),
        Node("4.5", "Movement history", "chronological event log", fill=SKY_TINT, stroke=SKY, w=200, h=78),
        Node("4.6", "FEFO pools", "purchase vs package remaining", fill=AMBER_TINT, stroke=AMBER_DEEP, w=210, h=78),
    ]
    draw_tree(d, root, 20, 120, v_gap=120, h_gap=12)
    d.box(
        60,
        520,
        1460,
        210,
        [
            "Purchase-unit stock-in moves whole containers and the matching package pool. Package-unit stock-in adds loose contents only (total_package_stock_ins).",
            "Treatments do not reduce total_purchase_stocks for packaged items — an opened bottle stays on the shelf until a whole-container stock-out.",
            "Out of stock means both pools are empty. Low-stock and expiry alerts use SYSTEM_SETTINGS, not a second invented threshold column on ITEM.",
            "Categories/units live in CatalogService and are configured under 7.4 Settings. Manager donation stock-in reuses 4.3 with type=donated.",
        ],
        WHITE,
        BORDER,
        size=13,
    )
    return d


def loe_procurement() -> Diagram:
    d = Diagram(
        1480,
        800,
        "Level of Explosion — 5.0 Procurement",
        "Suppliers plus the Staff Ordering module (replenishment + purchase history).",
    )
    d.header_footer()
    root = Node("5.0", "Procurement", fill=WHITE, stroke=SKY, w=220, h=64)
    suppliers = Node("5.1", "Suppliers", "Manager CRUD", fill=SAGE_TINT, stroke=SAGE_DEEP, w=200, h=70)
    suppliers.children = [
        Node("5.1.1", "Create / update / delete", "name, contacts, address", fill=SAGE_TINT, stroke=SAGE_DEEP, w=220, h=78),
        Node("5.1.2", "Supplier purchases", "history for that vendor", fill=SAGE_TINT, stroke=SAGE_DEEP, w=210, h=78),
    ]
    ordering = Node("5.2", "Ordering", "Staff", fill=SKY_TINT, stroke=SKY, w=200, h=70)
    ordering.children = [
        Node("5.2.1", "Replenishment", "ADU, lead time, safety stock, ROP", fill=SKY_TINT, stroke=SKY, w=230, h=78),
        Node("5.2.2", "Purchase history", "existing PURCHASE records", fill=SKY_TINT, stroke=SKY, w=210, h=78),
        Node("5.2.3", "Record purchase", "stock-in via add-item flow", fill=SAGE_TINT, stroke=SAGE_DEEP, w=210, h=78),
    ]
    root.children = [suppliers, ordering]
    draw_tree(d, root, 80, 110, v_gap=90, h_gap=24)
    d.box(
        80,
        610,
        1320,
        110,
        [
            "ROP = ceil(ADU × lead time + safety stock). An item appears when ROP > 0 and current purchase-unit stock ≤ ROP.",
            "SIYAM only recommends replenishment. It does not automatically create a purchase record from ROP.",
        ],
        WHITE,
        BORDER,
        size=13,
    )
    return d


def loe_donations() -> Diagram:
    d = Diagram(
        1580,
        860,
        "Level of Explosion — 6.0 Donations & Donor Portal",
        "Drop-off submissions, walk-in stock-in, donor history, and FIFO impact.",
    )
    d.header_footer()
    root = Node("6.0", "Donations", fill=WHITE, stroke=AMBER_DEEP, w=220, h=64)
    root.children = [
        Node("6.1", "Submit drop-off", "Donor: schedule, notes, proof", fill=AMBER_TINT, stroke=AMBER_DEEP, w=210, h=78),
        Node("6.2", "Review", "pending → approved | rejected", fill=SAGE_TINT, stroke=SAGE_DEEP, w=210, h=78),
        Node("6.3", "Items received", "physical arrival date", fill=SAGE_TINT, stroke=SAGE_DEEP, w=200, h=78),
        Node("6.4", "Stock in donated", "creates DONATION + batches", fill=SKY_TINT, stroke=SKY, w=210, h=78),
        Node("6.5", "Walk-in donation", "no submission required", fill=SKY_TINT, stroke=SKY, w=200, h=78),
        Node("6.6", "History", "Donor donation list", fill=AMBER_TINT, stroke=AMBER_DEEP, w=190, h=78),
        Node("6.7", "Impact", "FIFO used / discarded / remaining", fill=AMBER_TINT, stroke=AMBER_DEEP, w=220, h=78),
    ]
    draw_tree(d, root, 16, 120, v_gap=120, h_gap=10)
    d.box(
        60,
        520,
        1460,
        250,
        [
            "Submission flow: pending → approved → received → stocked. Rejected is terminal and only from pending.",
            "Walk-in / drop-off on DONATION is descriptive. donorid, donor_name, and subid are independently optional.",
            "Impact replays purchase_item / donation_item / treatment_item / stock_out oldest-batch-first. It is not a stored ITEM statistic.",
            "Donor notifications (approved, received, impact) are derived from this same data — there is no separate notification table.",
        ],
        WHITE,
        BORDER,
        size=13,
    )
    return d


def loe_oversight() -> Diagram:
    d = Diagram(
        1560,
        1080,
        "Level of Explosion — 7.0 Oversight",
        "Reports, audit, settings, and alerts that sit above day-to-day stock work.",
    )
    d.header_footer()
    d.box(640, 100, 280, 56, ["7.0  Oversight"], WHITE, SAGE_DEEP, size=14)

    reports = Node("7.1", "Reports", fill=SKY_TINT, stroke=SKY, w=200, h=58)
    reports.children = [
        Node("7.1.1", "Staff usage", "used vs lost for a month", fill=SKY_TINT, stroke=SKY, w=200, h=78),
        Node("7.1.2", "Manager usage", "same usage + category filters", fill=SAGE_TINT, stroke=SAGE_DEEP, w=220, h=78),
        Node("7.1.3", "ROP status", "Manager only; same ReplenishmentService", fill=SAGE_TINT, stroke=SAGE_DEEP, w=230, h=78),
    ]
    audit = Node("7.2", "Audit", fill=SAGE_TINT, stroke=SAGE_DEEP, w=190, h=58)
    audit.children = [
        Node("7.2.1", "Full trail", "Manager, with before/after", fill=SAGE_TINT, stroke=SAGE_DEEP, w=210, h=78),
        Node("7.2.2", "My Activity", "Staff inventory + medical only", fill=SKY_TINT, stroke=SKY, w=220, h=78),
    ]
    settings = Node("7.3", "Settings", "Manager", fill=SAGE_TINT, stroke=SAGE_DEEP, w=200, h=58)
    settings.children = [
        Node("7.3.1", "Alert thresholds", "low stock, expiry days", fill=SAGE_TINT, stroke=SAGE_DEEP, w=200, h=78),
        Node("7.3.2", "ROP defaults", "lead time, safety stock; item overrides", fill=SAGE_TINT, stroke=SAGE_DEEP, w=220, h=78),
        Node("7.3.3", "Categories & units", "including requires_expiry", fill=SAGE_TINT, stroke=SAGE_DEEP, w=210, h=78),
    ]
    notif = Node("7.4", "Notifications", fill=AMBER_TINT, stroke=AMBER_DEEP, w=210, h=58)
    notif.children = [
        Node("7.4.1", "Stock alerts", "zero, low, expiring", fill=SKY_TINT, stroke=SKY, w=200, h=78),
        Node("7.4.2", "Donor updates", "approved, received, impact", fill=AMBER_TINT, stroke=AMBER_DEEP, w=220, h=78),
    ]

    draw_tree(d, reports, 40, 250, v_gap=88, h_gap=14)
    draw_tree(d, audit, 820, 250, v_gap=88, h_gap=18)
    draw_tree(d, settings, 40, 620, v_gap=88, h_gap=14)
    draw_tree(d, notif, 820, 620, v_gap=88, h_gap=18)

    r_cx = reports.x + reports.w / 2
    a_cx = audit.x + audit.w / 2
    s_cx = settings.x + settings.w / 2
    n_cx = notif.x + notif.w / 2
    bus_y = 188
    rail_y = 590
    d.line(780, 156, 780, bus_y)
    d.line(r_cx, bus_y, a_cx, bus_y)
    d.line(r_cx, bus_y, r_cx, reports.y)
    d.line(a_cx, bus_y, a_cx, audit.y)
    d.line(28, bus_y, r_cx, bus_y)
    d.line(28, bus_y, 28, rail_y)
    d.line(28, rail_y, s_cx, rail_y)
    d.line(s_cx, rail_y, s_cx, settings.y)
    d.line(a_cx, bus_y, 1532, bus_y)
    d.line(1532, bus_y, 1532, rail_y)
    d.line(n_cx, rail_y, 1532, rail_y)
    d.line(n_cx, rail_y, n_cx, notif.y)

    d.box(
        80,
        940,
        1400,
        70,
        [
            "Usage reports count treatment consumption as used, waste/expired as lost, and exclude adjustment. Quantities are shown in purchase-unit terms.",
        ],
        WHITE,
        BORDER,
        size=13,
    )
    return d


def loe_stock_flow() -> Diagram:
    d = Diagram(
        1480,
        860,
        "Level of Explosion — Cross-module stock flow",
        "How inventory actually moves between 4.0, 5.0, 6.0, and 3.2. Not a fourth diagram type — it is the shared explosion of stock.",
    )
    d.header_footer()

    d.box(80, 120, 240, 80, ["5.3 Record purchase", "PURCHASE + PURCHASE_ITEM"], SAGE_TINT, SAGE_DEEP)
    d.box(400, 120, 280, 80, ["6.4 / 6.5 Donation stock-in", "DONATION + DONATION_ITEM"], AMBER_TINT, AMBER_DEEP)
    d.box(780, 120, 240, 80, ["4.3 Generic Stock In", "same batch rules"], SKY_TINT, SKY)
    d.box(1100, 120, 280, 80, ["ITEM pools", "purchase + package + FEFO qty_remaining"], WHITE, SAGE_DEEP)

    d.arrow(320, 160, 400, 160)
    d.arrow(680, 160, 780, 160)
    d.arrow(1020, 160, 1100, 160)
    d.arrow(200, 200, 1240, 200, dashed=True)
    d.label_on_line(740, 198, "stock-in increases batches and pools")

    d.box(200, 320, 280, 90, ["3.2.4 Treatment deduction", "package pool if packaged; purchase pool if not"], SKY_TINT, SKY)
    d.box(620, 320, 280, 90, ["4.4 Stock Out", "waste / expired / adjustment at purchase-unit"], AMBER_TINT, AMBER_DEEP)
    d.box(1040, 320, 280, 90, ["6.7 FIFO impact", "replay batches for the donor's gifts"], AMBER_TINT, AMBER_DEEP)

    d.arrow(1240, 200, 340, 320)
    d.arrow(1240, 200, 760, 320)
    d.arrow(1240, 200, 1180, 320)

    d.box(80, 500, 1320, 250, [
        "Canonical remaining qty lives on each PURCHASE_ITEM / DONATION_ITEM row (qty_remaining).",
        "Headline stock on the inventory page is ITEM.stock_count_mode: package pool for deductible packaged items, else purchase pool.",
        "Opened packaged stock can show as In Stock while total_package_stocks is 0, as long as empty containers remain (total_purchase_stocks > 0).",
        "Impact is independent of those headline figures. Discarded qty comes from stock-out against the donor's FIFO slice, not from a stored ITEM.used column.",
    ], WHITE, BORDER, size=13)
    return d


def loe_data_stores() -> Diagram:
    d = Diagram(
        1560,
        980,
        "Level of Explosion — Data stores",
        "Tables from updated_db.md, grouped the way the modules use them. No fabricated fields.",
    )
    d.header_footer()

    groups = [
        (50, 110, 280, 200, "Identity", SAGE_TINT, SAGE_DEEP, ["USER", "role: manager / staff / donor"]),
        (350, 110, 380, 200, "Catalog", SKY_TINT, SKY, ["PRIMARY_CATEGORY", "SUBCATEGORY", "UNITS", "requires_expiry on category / subcategory"]),
        (750, 110, 360, 200, "Inventory core", AMBER_TINT, AMBER_DEEP, ["ITEM (dual pools)", "SYSTEM_SETTINGS", "STOCK_OUT"]),
        (1130, 110, 380, 200, "Animals & medical", SAGE_TINT, SAGE_DEEP, ["PET", "TREATMENT", "TREATMENT_ITEM"]),
        (50, 350, 480, 210, "Procurement", SKY_TINT, SKY, ["SUPPLIER", "PURCHASE", "PURCHASE_ITEM (FEFO batch + cost)"]),
        (560, 350, 500, 210, "Donations", AMBER_TINT, AMBER_DEEP, ["SUBMISSION", "DONATION", "DONATION_ITEM (FEFO batch, no cost)"]),
        (1090, 350, 420, 210, "Implemented in services, not listed in updated_db.md", WHITE, MUTED, ["audit_log (read by AuditService)", "item_rop_settings (ROP overrides)", "ROP columns on system_settings"]),
    ]
    for x, y, w, h, title, fill, stroke, lines in groups:
        d.rect(x, y, w, h, WHITE, stroke, radius=14, sw=1.6)
        d.rect(x, y, w, 40, fill, stroke, radius=14, sw=1.6)
        d.rect(x, y + 26, w, 16, fill, fill, radius=0, sw=0)
        d.text(x + w / 2, y + 26, title, size=13, weight="700")
        d.multiline(x + w / 2, y + 110, lines, size=13, weight="500", leading=22)

    d.box(
        50,
        600,
        1460,
        280,
        [
            "FEFO identity is the stock-in row itself (PURCHASE_ITEM / DONATION_ITEM). There is no separate stock_batches table in updated_db.md.",
            "ITEM.total_purchase_stocks vs total_package_stocks is the dual-pool model. total_package_stock_ins records loose package-unit stock-in.",
            "SUBMISSION.donorid is required (logged-in donor). DONATION.donorid is optional (walk-in may have no account).",
            "Do not treat siyam_db_wo_rls.md or schema.md as current. CLAUDE.md names updated_db.md as the schema source of truth.",
        ],
        WHITE,
        BORDER,
        size=13,
    )
    return d


def write_index(files: list[tuple[str, str, str]]) -> None:
    cards = []
    for name, title, kind in files:
        cards.append(
            f"""
      <article class="card">
        <p class="kind">{esc(kind)}</p>
        <h2>{esc(title)}</h2>
        <a href="{esc(name)}"><img src="{esc(name)}" alt="{esc(title)}"/></a>
      </article>"""
        )
    html_doc = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>SIYAM system diagrams</title>
  <style>
    body {{ margin: 0; font-family: Segoe UI, Helvetica, Arial, sans-serif; background: {CREAM}; color: {BROWN}; }}
    header {{ background: #fff; border-bottom: 1px solid {BORDER}; padding: 28px 40px; }}
    header h1 {{ margin: 0 0 8px; font-size: 28px; }}
    header p {{ margin: 0; color: {MUTED}; max-width: 900px; line-height: 1.5; }}
    main {{ padding: 28px 40px 80px; display: grid; gap: 36px; }}
    .card {{ background: #fff; border: 1px solid {BORDER}; border-radius: 16px; padding: 20px; }}
    .kind {{ margin: 0; font-size: 12px; letter-spacing: 0.08em; text-transform: uppercase; color: {SAGE_DEEP}; font-weight: 700; }}
    h2 {{ margin: 6px 0 16px; font-size: 20px; }}
    img {{ width: 100%; border: 1px solid {BORDER}; border-radius: 10px; background: {CREAM}; }}
  </style>
</head>
<body>
  <header>
    <h1>SIYAM system diagrams</h1>
    <p>Conceptual, top-level, and level-of-explosion views of the current SIYAM system.
       Generated from the same module map as README.md in this folder.</p>
  </header>
  <main>{''.join(cards)}
  </main>
</body>
</html>
"""
    (OUT / "index.html").write_text(html_doc, encoding="utf-8")


def main() -> None:
    generated = [
        (conceptual_context(), "01_conceptual_context.svg", "Conceptual Diagram — System Context", "Conceptual"),
        (conceptual_framework(), "02_conceptual_framework.svg", "Conceptual Diagram — Input / Process / Output", "Conceptual"),
        (top_level_functional(), "03_top_level_functional.svg", "Top-Level Diagram — Functional modules", "Top-level"),
        (top_level_software(), "04_top_level_software.svg", "Top-Level Diagram — Software structure", "Top-level"),
        (loe_access(), "05_loe_1_access.svg", "Level of Explosion — 1.0 Access & Identity", "Level of explosion"),
        (loe_dashboards(), "06_loe_2_dashboards.svg", "Level of Explosion — 2.0 Dashboards", "Level of explosion"),
        (loe_animal_medical(), "07_loe_3_animal_medical.svg", "Level of Explosion — 3.0 Animal & Medical Care", "Level of explosion"),
        (loe_inventory(), "08_loe_4_inventory.svg", "Level of Explosion — 4.0 Inventory Control", "Level of explosion"),
        (loe_procurement(), "09_loe_5_procurement.svg", "Level of Explosion — 5.0 Procurement", "Level of explosion"),
        (loe_donations(), "10_loe_6_donations.svg", "Level of Explosion — 6.0 Donations", "Level of explosion"),
        (loe_oversight(), "11_loe_7_oversight.svg", "Level of Explosion — 7.0 Oversight", "Level of explosion"),
        (loe_stock_flow(), "12_loe_stock_flow.svg", "Level of Explosion — Cross-module stock flow", "Level of explosion"),
        (loe_data_stores(), "13_loe_data_stores.svg", "Level of Explosion — Data stores", "Level of explosion"),
    ]
    index_rows = []
    for diagram, filename, title, kind in generated:
        diagram.save(filename)
        index_rows.append((filename, title, kind))
        print(f"wrote {filename}")
    write_index(index_rows)
    print("wrote index.html")


if __name__ == "__main__":
    main()
