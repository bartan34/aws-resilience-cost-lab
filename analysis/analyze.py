#!/usr/bin/env python3
"""Per-fault impact metrics from the probe CSVs and the fault log."""
import csv
import re
import statistics
from datetime import datetime, timedelta
from pathlib import Path

RAW = Path(__file__).resolve().parent.parent / "data" / "raw"
OUT = Path(__file__).resolve().parent
K = 10  # consecutive successes that count as "recovered"


def ts(s):
    return datetime.fromisoformat(s)


def load_probe(tier):
    rows = []
    with open(RAW / f"{tier.lower()}.csv") as f:
        for r in csv.DictReader(f):
            rows.append((int(r["tick"]), ts(r["sent_utc"]),
                         int(r["status"]), float(r["latency_ms"])))
    rows.sort()
    return rows


def load_faults():
    with open(RAW / "faults.csv") as f:
        faults = list(csv.DictReader(f))
    for x in faults:
        x["t"] = ts(x["injected_utc"])
        m = re.search(r"start issued (\S+?)\)", x["detail"])
        x["t_start"] = ts(m.group(1)) if m else None
    faults.sort(key=lambda x: x["t"])
    return faults


def analyse(rows, fault, window_end):
    win = [r for r in rows if fault["t"] <= r[1] < window_end]
    first = next((i for i, r in enumerate(win) if r[2] != 200), None)
    if first is None:
        return dict(impact_s=0.0, recover_s=0.0, failed=0, sent=0,
                    restart_s="", recovered_at=fault["t"])
    rec = len(win) - 1
    for i in range(first, len(win) - K + 1):
        if all(r[2] == 200 for r in win[i:i + K]):
            rec = i
            break
    seg = win[first:rec]
    return dict(
        impact_s=round((win[rec][1] - win[first][1]).total_seconds(), 1),
        recover_s=round((win[rec][1] - fault["t"]).total_seconds(), 1),
        failed=sum(1 for r in seg if r[2] != 200),
        sent=len(seg),
        restart_s=(round((win[rec][1] - fault["t_start"]).total_seconds(), 1)
                   if fault["t_start"] else ""),
        recovered_at=win[rec][1],
    )


def main():
    faults = load_faults()
    per_run, latency = [], {}
    for tier in ("T0", "T1", "T2"):
        rows = load_probe(tier)
        tf = [x for x in faults if x["tier"] == tier]
        busy = []
        for i, x in enumerate(tf):
            end = tf[i + 1]["t"] if i + 1 < len(tf) else rows[-1][1]
            res = analyse(rows, x, end)
            busy.append((x["t"], res["recovered_at"] + timedelta(seconds=30)))
            pct = round(100 * res["failed"] / res["sent"], 1) if res["sent"] else 0.0
            per_run.append(dict(tier=tier, fault=x["fault"], injected_utc=x["injected_utc"],
                                impact_s=res["impact_s"], recover_s=res["recover_s"],
                                failed=res["failed"], sent=res["sent"], failed_pct=pct,
                                restart_s=res["restart_s"]))
        steady = [r[3] for r in rows if r[2] == 200
                  and not any(a <= r[1] <= b for a, b in busy)]
        latency[tier] = (len(steady), statistics.median(steady),
                         statistics.quantiles(steady, n=20)[18])

    fields = list(per_run[0].keys())
    with open(OUT / "results_per_run.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(per_run)

    print("PER RUN")
    print(" ".join(f"{h:>12}" for h in fields if h != "injected_utc"))
    for r in per_run:
        print(" ".join(f"{str(r[h]):>12}" for h in fields if h != "injected_utc"))

    print("\nSUMMARY (median [min-max])")
    summary = []
    for key in sorted({(r["tier"], r["fault"]) for r in per_run}):
        g = [r for r in per_run if (r["tier"], r["fault"]) == key]

        def med(col):
            v = [r[col] for r in g if r[col] != ""]
            return (statistics.median(v), min(v), max(v)) if v else ("", "", "")

        row = dict(tier=key[0], fault=key[1], n=len(g))
        for col in ("impact_s", "recover_s", "failed", "failed_pct", "restart_s"):
            m, lo, hi = med(col)
            row[col] = "" if m == "" else f"{m} [{lo}-{hi}]"
        summary.append(row)
        print(row)
    with open(OUT / "summary.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(summary[0].keys()))
        w.writeheader()
        w.writerows(summary)

    print("\nSTEADY-STATE WRITE LATENCY (ms)")
    for tier, (n, p50, p95) in latency.items():
        print(f"{tier}: n={n} p50={p50:.1f} p95={p95:.1f}")


if __name__ == "__main__":
    main()