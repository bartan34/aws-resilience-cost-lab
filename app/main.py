import os
from contextlib import contextmanager
from datetime import datetime, timezone

import pymysql
from fastapi import FastAPI, Response

DB = dict(
    host=os.environ["DB_HOST"],
    port=int(os.environ.get("DB_PORT", "3306")),
    user=os.environ["DB_USER"],
    password=os.environ["DB_PASSWORD"],
    database=os.environ["DB_NAME"],
    connect_timeout=2,
    read_timeout=2,
    write_timeout=2,
    autocommit=True,
)

INSTANCE_ID = os.environ.get("INSTANCE_ID", "local")
AZ_ID = os.environ.get("AZ_ID", "local")

app = FastAPI()
_schema_ready = False


@contextmanager
def db():
    conn = pymysql.connect(**DB)
    try:
        yield conn
    finally:
        conn.close()

def ensure_schema(conn):
    global _schema_ready
    if _schema_ready:
        return
    with conn.cursor() as cur:
        cur.execute(
            "CREATE TABLE IF NOT EXISTS writes ("
            "seq BIGINT AUTO_INCREMENT PRIMARY KEY, "
            "ts DATETIME(3) NOT NULL, "
            "instance_id VARCHAR(32) NOT NULL)"
        )
    _schema_ready = True

def meta():
    return {"instance_id": INSTANCE_ID, "az_id": AZ_ID}


def unavailable(response: Response, exc: Exception):
    response.status_code = 503
    return {"error": type(exc).__name__, **meta()}


@app.get("/health")
def health():
    return {"status": "ok", **meta()}


@app.get("/health/deep")
def health_deep(response: Response):
    try:
        with db() as conn, conn.cursor() as cur:
            cur.execute("SELECT 1")
        return {"status": "ok", "db": "ok", **meta()}
    except Exception as exc:
        return unavailable(response, exc)


@app.post("/write")
def write(response: Response):
    try:
        with db() as conn:
            ensure_schema(conn)
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO writes (ts, instance_id) VALUES (%s, %s)",
                    (datetime.now(timezone.utc).replace(tzinfo=None), INSTANCE_ID),
                )
                seq = cur.lastrowid
        return {"seq": seq, **meta()}
    except Exception as exc:
        return unavailable(response, exc)


@app.get("/read")
def read(response: Response):
    try:
        with db() as conn:
            ensure_schema(conn)
            with conn.cursor() as cur:
                cur.execute("SELECT COALESCE(MAX(seq), 0) FROM writes")
                (max_seq,) = cur.fetchone()
        return {"max_seq": max_seq, **meta()}
    except Exception as exc:
        return unavailable(response, exc)
