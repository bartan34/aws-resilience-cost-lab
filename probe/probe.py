#!/usr/bin/env python3
"""Fixed-rate availability probe.

Sends one POST per tick regardless of how long earlier requests take,
and appends one CSV row per request.
"""
import argparse
import csv
import json
import signal
import threading
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone

FIELDS = ["tick", "sent_utc", "status", "latency_ms", "seq",
          "instance_id", "az_id", "error", "tier", "run_id"]


def utc_now():
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


def one_request(url, timeout):
    start = time.monotonic()
    status, body, error = 0, {}, ""
    try:
        req = urllib.request.Request(url, method="POST", data=b"")
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            status = resp.status
            body = json.loads(resp.read())
    except urllib.error.HTTPError as exc:
        status = exc.code
        try:
            body = json.loads(exc.read())
        except Exception:
            body = {}
    except Exception as exc:
        error = type(exc).__name__
    latency_ms = round((time.monotonic() - start) * 1000, 1)
    return status, latency_ms, body, error


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--url", required=True, help="e.g. http://host/write")
    p.add_argument("--tier", required=True)
    p.add_argument("--run-id", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--interval", type=float, default=1.0)
    p.add_argument("--timeout", type=float, default=2.0)
    args = p.parse_args()

    stop = threading.Event()
    signal.signal(signal.SIGINT, lambda *_: stop.set())
    signal.signal(signal.SIGTERM, lambda *_: stop.set())

    lock = threading.Lock()
    f = open(args.out, "a", newline="")
    writer = csv.DictWriter(f, fieldnames=FIELDS)
    if f.tell() == 0:
        writer.writeheader()

    def worker(tick, sent_utc):
        status, latency_ms, body, error = one_request(args.url, args.timeout)
        row = {
            "tick": tick, "sent_utc": sent_utc, "status": status,
            "latency_ms": latency_ms, "seq": body.get("seq", ""),
            "instance_id": body.get("instance_id", ""),
            "az_id": body.get("az_id", ""),
            "error": error or body.get("error", ""),
            "tier": args.tier, "run_id": args.run_id,
        }
        with lock:
            writer.writerow(row)
            f.flush()
        if status != 200:
            print(f"{sent_utc} tick={tick} status={status} {row['error']}", flush=True)

    tick = 0
    next_tick = time.monotonic()
    with ThreadPoolExecutor(max_workers=16) as pool:
        while not stop.is_set():
            pool.submit(worker, tick, utc_now())
            tick += 1
            next_tick += args.interval
            stop.wait(max(0.0, next_tick - time.monotonic()))
    f.close()
    print(f"stopped after {tick} ticks -> {args.out}")


if __name__ == "__main__":
    main()