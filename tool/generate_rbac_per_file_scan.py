#!/usr/bin/env python3
"""Emit tool/rbac_per_file_scan.md — RBAC heuristics for every lib/screens + lib/widgets file."""

from __future__ import annotations

import os
import re
import sys

WORKSPACE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SECTIONS = [
    ("screens", os.path.join(WORKSPACE, "lib", "screens")),
    ("widgets", os.path.join(WORKSPACE, "lib", "widgets")),
]

PATTERNS = {
    "perms_watch": re.compile(r"watchResolvedPermissions|readResolvedPermissions"),
    # Stream/async permission resolution (counts as in-file RBAC surface)
    "perms_provider": re.compile(r"effectivePermissionsProvider"),
    "perm_denied": re.compile(r"PermissionDeniedScaffold"),
    "perm_ids": re.compile(r"PermissionIds\.|canOpen\w+\("),
    "nav_push": re.compile(r"Navigator\.(of\([^)]*\)\.)?push|AppMaterialPageRoute"),
    "show_dialog": re.compile(r"showDialog"),
}


def is_leaf_path(rel: str) -> bool:
    return bool(
        "/components/" in rel
        or rel.startswith("cafe/components/")
        or "/sales/components/" in rel
        or "dashboard/components/" in rel
        or "dashboard/widgets/" in rel
        or rel.endswith("_flow.dart")
        or "loyalty/components/" in rel
        or "merchandise/components/" in rel
        or "tables/components/" in rel
        or rel.endswith("components.dart")
    )


def note_for_file(rel: str, flags: dict[str, bool]) -> str:
    has_perm_surface = (
        flags["perms_watch"] or flags["perm_denied"] or flags["perms_provider"]
    )
    if not (flags["nav_push"] and not has_perm_surface):
        return "—"
    if is_leaf_path(rel) or any(x in rel for x in ("landing/", "legal/", "auth/", "debug/")):
        return "leaf/public/parent"
    if rel.startswith("tournament/") and ("dialog" in rel or "widget" in rel):
        return "tournament leaf; parent/detail gates"
    if rel == "inventory/inventory_pricing_screen.dart":
        return "tab under InventoryHubScreen (`nav.inventory`)"
    if rel in (
        "dialogs/customer_selection_dialog.dart",
        "dialogs/players_selection_dialog.dart",
    ):
        return "push AddCustomerScreen; pre-check + footer hide without `nav.customers`"
    if rel == "enhanced_customer_search.dart":
        return "push AddCustomerScreen; `canAddCustomer` from caller"
    if rel.endswith("_screen.dart"):
        return "REVIEW: confirm `own` gate or parent shell"
    return "REVIEW"


def scan_dir(base: str) -> list[tuple[str, dict[str, bool], str]]:
    rows: list[tuple[str, dict[str, bool], str]] = []
    for dp, _dns, fns in os.walk(base):
        for fn in fns:
            if not fn.endswith(".dart"):
                continue
            path = os.path.join(dp, fn)
            rel = os.path.relpath(path, base).replace("\\", "/")
            try:
                text = open(path, encoding="utf-8").read()
            except OSError:
                continue
            flags = {k: bool(p.search(text)) for k, p in PATTERNS.items()}
            rows.append((rel, flags, note_for_file(rel, flags)))
    return sorted(rows, key=lambda x: x[0])


def main() -> None:
    lines = [
        "# RBAC per-file heuristic scan",
        "",
        "Generated for every Dart file under `lib/screens/` and `lib/widgets/`.",
        "",
        "```bash",
        "python3 tool/generate_rbac_per_file_scan.py",
        "```",
        "",
        "| Column | Meaning |",
        "|--------|---------|",
        "| **watchResolved** | `watchResolvedPermissions` / `readResolvedPermissions` |",
        "| **PermissionDenied** | `PermissionDeniedScaffold` |",
        "| **effPermStream** | `effectivePermissionsProvider` (in-file permission stream) |",
        "| **PermissionIds** | `PermissionIds.` or `canOpen*(` on effective permissions |",
        "| **push/route** | `Navigator.push` / `AppMaterialPageRoute` |",
        "| **showDialog** | `showDialog` |",
        "",
        "**REVIEW** is a heuristic: file pushes routes but has no in-file "
        "`watchResolved` / `PermissionDenied` / `effectivePermissionsProvider` "
        "— verify parent or destination (see [`rbac_audit.md`](rbac_audit.md)).",
        "",
    ]
    for label, base in SECTIONS:
        if not os.path.isdir(base):
            print(f"skip missing {base}", file=sys.stderr)
            continue
        rows = scan_dir(base)
        lines.append(f"## `{label}/` ({len(rows)} files)")
        lines.append("")
        lines.append(
            "| File | watchResolved | PermissionDenied | effPermStream | PermissionIds | push/route | showDialog | Notes |"
        )
        lines.append(
            "|------|---------------|------------------|---------------|---------------|------------|------------|-------|"
        )
        for rel, f, note in rows:
            eff = f["perms_provider"]
            lines.append(
                f"| `{rel}` | {f['perms_watch']} | {f['perm_denied']} | {eff} | {f['perm_ids']} | {f['nav_push']} | {f['show_dialog']} | {note} |"
            )
        lines.append("")

    out = os.path.join(WORKSPACE, "tool", "rbac_per_file_scan.md")
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"Wrote {out}")

    write_screens_inventory()


def inventory_row(rel: str) -> tuple[str, str, str]:
    """Category, gate column, account relevance."""
    if rel.startswith("auth/"):
        acct = "owner_register" if rel == "auth/register_company_screen.dart" else "none"
        return ("pre_auth", "N/A", acct)
    if rel.startswith("legal/"):
        return ("public", "N/A", "none")
    if rel.startswith("landing/"):
        return ("public", "N/A", "anonymous_landing")
    if "/services/" in rel or rel.endswith("_service.dart"):
        return ("service", "N/A", "none")
    if rel.startswith("sales/providers/"):
        return ("service", "N/A", "none")
    acct = "none"
    if rel == "admin/create_staff_screen.dart":
        acct = "staff_invite"
    elif rel == "customers/add_customer_screen.dart":
        acct = "customer_record"
    if rel.endswith("_screen.dart"):
        return ("tenant_route", "see rbac_audit.md", acct)
    return ("leaf_widget", "see rbac_audit.md", acct)


def write_screens_inventory() -> None:
    base = os.path.join(WORKSPACE, "lib", "screens")
    paths: list[str] = []
    for dp, _dns, fns in os.walk(base):
        for fn in fns:
            if fn.endswith(".dart"):
                paths.append(os.path.relpath(os.path.join(dp, fn), base).replace("\\", "/"))
    paths.sort()
    lines = [
        "# Full `lib/screens` RBAC inventory",
        "",
        "Regenerated by [`generate_rbac_per_file_scan.py`](generate_rbac_per_file_scan.py) (same command as per-file scan). "
        "Hand-maintained permission detail: [`rbac_audit.md`](rbac_audit.md).",
        "",
        "| Path | Category | Gate / notes | Account relevance |",
        "|------|----------|--------------|-------------------|",
    ]
    for rel in paths:
        cat, gate, acct = inventory_row(rel)
        lines.append(f"| `{rel}` | {cat} | {gate} | {acct} |")
    out = os.path.join(WORKSPACE, "tool", "screens_rbac_inventory.md")
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"Wrote {out} ({len(paths)} paths)")


if __name__ == "__main__":
    main()
