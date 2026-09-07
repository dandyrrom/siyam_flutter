#!/usr/bin/env python3
"""Generate SIYAM test-case cross-check report PDF (Times New Roman, 12pt)."""

import json
from collections import Counter
from datetime import datetime
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

FONT_REGULAR = "/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf"
FONT_BOLD = "/usr/share/fonts/truetype/liberation/LiberationSerif-Bold.ttf"
FONT_ITALIC = "/usr/share/fonts/truetype/liberation/LiberationSerif-Italic.ttf"
FONT_NAME = "TimesNewRoman"

pdfmetrics.registerFont(TTFont(f"{FONT_NAME}", FONT_REGULAR))
pdfmetrics.registerFont(TTFont(f"{FONT_NAME}-Bold", FONT_BOLD))
pdfmetrics.registerFont(TTFont(f"{FONT_NAME}-Italic", FONT_ITALIC))
pdfmetrics.registerFontFamily(
    FONT_NAME,
    normal=f"{FONT_NAME}",
    bold=f"{FONT_NAME}-Bold",
    italic=f"{FONT_NAME}-Italic",
    boldItalic=f"{FONT_NAME}-Bold",
)

FONT_SIZE = 12
OUTPUT = Path(__file__).resolve().parents[1] / "SIYAM_TestCase_CrossCheck_vernon-2.pdf"
DATA = Path("/tmp/crosscheck_results.json")


def esc(text: str) -> str:
    return (
        str(text)
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )


def build_styles():
    base = getSampleStyleSheet()
    return {
        "title": ParagraphStyle(
            "Title",
            parent=base["Title"],
            fontName=f"{FONT_NAME}-Bold",
            fontSize=16,
            leading=20,
            alignment=TA_CENTER,
            spaceAfter=12,
        ),
        "subtitle": ParagraphStyle(
            "Subtitle",
            parent=base["Normal"],
            fontName=FONT_NAME,
            fontSize=FONT_SIZE,
            leading=14,
            alignment=TA_CENTER,
            spaceAfter=18,
        ),
        "heading1": ParagraphStyle(
            "H1",
            parent=base["Heading1"],
            fontName=f"{FONT_NAME}-Bold",
            fontSize=14,
            leading=18,
            spaceBefore=14,
            spaceAfter=8,
        ),
        "heading2": ParagraphStyle(
            "H2",
            parent=base["Heading2"],
            fontName=f"{FONT_NAME}-Bold",
            fontSize=FONT_SIZE,
            leading=14,
            spaceBefore=10,
            spaceAfter=6,
        ),
        "body": ParagraphStyle(
            "Body",
            parent=base["Normal"],
            fontName=FONT_NAME,
            fontSize=FONT_SIZE,
            leading=14,
            alignment=TA_JUSTIFY,
            spaceAfter=6,
        ),
        "bullet": ParagraphStyle(
            "Bullet",
            parent=base["Normal"],
            fontName=FONT_NAME,
            fontSize=FONT_SIZE,
            leading=14,
            leftIndent=18,
            bulletIndent=6,
            spaceAfter=4,
        ),
        "table_cell": ParagraphStyle(
            "TableCell",
            parent=base["Normal"],
            fontName=FONT_NAME,
            fontSize=10,
            leading=12,
        ),
        "table_header": ParagraphStyle(
            "TableHeader",
            parent=base["Normal"],
            fontName=f"{FONT_NAME}-Bold",
            fontSize=10,
            leading=12,
        ),
    }


def summary_table(styles, headers, rows, col_widths):
    data = [[Paragraph(esc(h), styles["table_header"]) for h in headers]]
    for row in rows:
        data.append([Paragraph(esc(str(c)), styles["table_cell"]) for c in row])
    table = Table(data, colWidths=col_widths, repeatRows=1)
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#E8E8E8")),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 6),
                ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    return table


def main():
    with DATA.open() as f:
        cases = json.load(f)

    styles = build_styles()
    story = []

    story.append(Paragraph("SIYAM Test Case Cross-Check Report", styles["title"]))
    story.append(
        Paragraph(
            "Google Doc vs vernon-2 Branch — Group4_SIYAM_TestCase",
            styles["subtitle"],
        )
    )
    story.append(
        Paragraph(
            f"Generated: {datetime.utcnow().strftime('%B %d, %Y')} (UTC)  |  "
            "Branch: vernon-2 @ 8a61289  |  Font: Times New Roman 12pt",
            styles["subtitle"],
        )
    )
    story.append(Spacer(1, 0.15 * inch))

    doc_counts = Counter(c["doc_status"] for c in cases)
    impl_counts = Counter(c["impl_status"] for c in cases)

    story.append(Paragraph("Executive Summary", styles["heading1"]))
    story.append(
        Paragraph(
            "This report cross-checks all 133 unique test cases from the Google Doc "
            "(9 tabs) against the SIYAM Flutter codebase on the vernon-2 branch. "
            "Doc execution status reflects Pass/Fail markings in the document. "
            "Implementation status reflects whether the feature exists in code.",
            styles["body"],
        )
    )
    story.append(
        summary_table(
            styles,
            ["Category", "Count"],
            [
                ["Total unique test cases in doc", len(cases)],
                ["Marked Pass in doc", doc_counts.get("Pass", 0)],
                ["Marked Fail in doc", doc_counts.get("Fail", 0)],
                ["Unmarked in doc (not yet executed)", doc_counts.get("Unmarked", 0)],
                ["Implementation Ready on vernon-2", impl_counts.get("Ready", 0)],
                ["Implementation Partial", impl_counts.get("Partial", 0)],
                ["Not implemented", impl_counts.get("Not Implemented", 0)],
            ],
            [4.2 * inch, 2.0 * inch],
        )
    )
    story.append(Spacer(1, 0.1 * inch))
    story.append(
        Paragraph(
            "<b>Bottom line:</b> No test cases are marked Pass or Fail in the Google Doc yet. "
            "On vernon-2, 132 of 133 test cases have full implementation support; "
            "one case (TC_PROFILE_EDIT_INVALID_ALL) has a partial gap.",
            styles["body"],
        )
    )

    story.append(Paragraph("Doc Execution Status", styles["heading1"]))
    tab_doc = Counter()
    for c in cases:
        tab_doc[c["tab"]] += 1
    tab_rows = []
    for tab in sorted(tab_doc.keys(), key=lambda t: tab_doc[t], reverse=True):
        count = tab_doc[tab]
        tab_rows.append([tab, count, 0, 0, count])
    story.append(
        summary_table(
            styles,
            ["Tab", "Cases", "Pass", "Fail", "Unmarked"],
            tab_rows,
            [2.8 * inch, 0.7 * inch, 0.55 * inch, 0.55 * inch, 0.9 * inch],
        )
    )

    story.append(Paragraph("Implementation Status on vernon-2", styles["heading1"]))
    story.append(Paragraph("Ready (132 cases)", styles["heading2"]))
    story.append(
        Paragraph(
            "Auth, registration, profile, notifications, manager modules (dashboard, "
            "suppliers, animals, settings, donations, audit, reports, staff accounts), "
            "donor modules, and staff modules (dashboard, inventory, medical, ordering, "
            "reports, my activity) are implemented.",
            styles["body"],
        )
    )

    story.append(Paragraph("Partial (1 case)", styles["heading2"]))
    story.append(
        summary_table(
            styles,
            ["Test Case ID", "Title", "Gap"],
            [
                [
                    "TC_PROFILE_EDIT_INVALID_ALL",
                    "Update Profile with Invalid Input",
                    "Phone validation works; first/last name fields have no validators — blank names may save.",
                ]
            ],
            [1.5 * inch, 1.8 * inch, 2.9 * inch],
        )
    )

    story.append(Paragraph("Not Implemented (0 cases)", styles["heading2"]))
    story.append(
        Paragraph(
            "No test case in the document targets a completely missing feature.",
            styles["body"],
        )
    )

    story.append(Paragraph("Tab-by-Tab Implementation Readiness", styles["heading1"]))
    tab_impl = {}
    for c in cases:
        tab = c["tab"]
        if tab not in tab_impl:
            tab_impl[tab] = Counter()
        tab_impl[tab][c["impl_status"]] += 1
    impl_rows = []
    for tab, counts in sorted(tab_impl.items(), key=lambda x: sum(x[1].values()), reverse=True):
        total = sum(counts.values())
        impl_rows.append(
            [
                tab,
                total,
                counts.get("Ready", 0),
                counts.get("Partial", 0),
                counts.get("Not Implemented", 0),
            ]
        )
    story.append(
        summary_table(
            styles,
            ["Tab", "Total", "Ready", "Partial", "Not Implemented"],
            impl_rows,
            [2.8 * inch, 0.6 * inch, 0.6 * inch, 0.65 * inch, 1.0 * inch],
        )
    )

    story.append(Paragraph("Issues Before Manual Testing", styles["heading1"]))

    story.append(Paragraph("1. Test credentials mismatch", styles["heading2"]))
    story.append(
        Paragraph(
            "The Google Doc uses credentials such as antonlee@manager.siyam / Manager123!. "
            "Mock data on vernon-2 uses manager@siyam.test, staff@siyam.test, and "
            "donor@siyam.test (all with password password123). Use mock credentials or "
            "seed matching Supabase accounts before executing login steps.",
            styles["body"],
        )
    )

    story.append(Paragraph("2. Doc ID/title mismatches", styles["heading2"]))
    story.append(
        summary_table(
            styles,
            ["ID in doc", "Issue"],
            [
                [
                    "TC_ROP_DEFAULT_MGR",
                    "ID suggests ROP defaults, but content tests invalid Expiration Warning Window input.",
                ],
                [
                    "TC_ROP_OVERRIDE_MGR",
                    "Title says Item ROP Overrides; description tests ROP default lead time/safety stock.",
                ],
            ],
            [1.8 * inch, 4.4 * inch],
        )
    )
    story.append(
        Paragraph(
            "Both features are implemented in lib/pages/settings_page.dart; follow step "
            "descriptions rather than ID labels when executing these two cases.",
            styles["body"],
        )
    )

    story.append(Paragraph("3. Dependency-only references", styles["heading2"]))
    story.append(
        Paragraph(
            "These appear as dependencies but have no standalone test table: TC_ALL_LOGIN_AD, "
            "TC_ALL_LOGIN_STAFF, TC_ALL_LOGIN_STF, TC_ANIMAL_VIEW_STAFF, TC_MEDLOG_VIEW_STAFF, "
            "TC_ORDER_VIEW_STF. Staff has no /animal-records route (manager-only).",
            styles["body"],
        )
    )

    story.append(Paragraph("4. Intentional design differences", styles["heading2"]))
    bullets = [
        "Manager cannot open inventory from notifications (read-only guidance by design).",
        "Staff audit (My Activity) has no before/after JSON detail by design.",
        "Donor drop-off date is optional; picker allows today through +365 days.",
    ]
    for b in bullets:
        story.append(Paragraph(f"• {esc(b)}", styles["bullet"]))

    story.append(Paragraph("Recommended Next Steps", styles["heading1"]))
    steps = [
        "Begin manual execution — all 133 cases are currently unmarked in the doc.",
        "Start with auth smoke tests using mock credentials.",
        "Watch TC_PROFILE_EDIT_INVALID_ALL for possible Fail on blank name fields.",
        "Use step descriptions (not ID names) for the two mismatched ROP-related cases.",
        "Add first/last name validators on the profile page if a clean Pass is required.",
    ]
    for i, step in enumerate(steps, 1):
        story.append(Paragraph(f"{i}. {esc(step)}", styles["bullet"]))

    story.append(PageBreak())
    story.append(Paragraph("Appendix: Full Test Case Matrix", styles["heading1"]))
    story.append(
        Paragraph(
            "All 133 unique test cases with document status and vernon-2 implementation assessment.",
            styles["body"],
        )
    )
    story.append(Spacer(1, 0.08 * inch))

    matrix_rows = []
    for c in sorted(cases, key=lambda x: (x["tab"], x["tc_id"])):
        matrix_rows.append(
            [
                c["tc_id"],
                c["title"][:55] + ("…" if len(c["title"]) > 55 else ""),
                c["doc_status"],
                c["impl_status"],
            ]
        )

    # Split appendix across pages in chunks for readability
    chunk_size = 35
    for i in range(0, len(matrix_rows), chunk_size):
        chunk = matrix_rows[i : i + chunk_size]
        story.append(
            summary_table(
                styles,
                ["Test Case ID", "Title", "Doc Status", "Impl Status"],
                chunk,
                [1.65 * inch, 2.55 * inch, 0.85 * inch, 0.85 * inch],
            )
        )
        if i + chunk_size < len(matrix_rows):
            story.append(Spacer(1, 0.12 * inch))

    doc = SimpleDocTemplate(
        str(OUTPUT),
        pagesize=letter,
        leftMargin=0.85 * inch,
        rightMargin=0.85 * inch,
        topMargin=0.85 * inch,
        bottomMargin=0.85 * inch,
        title="SIYAM Test Case Cross-Check Report",
        author="Cursor Cloud Agent",
    )

    def footer(canvas, doc_obj):
        canvas.saveState()
        canvas.setFont(FONT_NAME, 10)
        canvas.drawCentredString(
            letter[0] / 2,
            0.5 * inch,
            f"Page {doc_obj.page}",
        )
        canvas.restoreState()

    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    print(f"Wrote {OUTPUT}")


if __name__ == "__main__":
    main()
