#!/usr/bin/env python3
import argparse
import json
import os
import sqlite3
from pathlib import Path

import fitz  # PyMuPDF

def extract_pdf_metadata(pdf_path: str):
    doc = fitz.open(pdf_path)
    meta = doc.metadata
    title = (meta.get("title") or "").strip() or Path(pdf_path).stem
    authors = (meta.get("author") or "").strip() or "Unknown author"
    subject = (meta.get("subject") or "").strip()
    keywords = (meta.get("keywords") or "").strip()
    doi = ""
    year = 0

    try:
        year = int((meta.get("creationDate") or "").split("-")[0].replace("D:", ""[:4]) or "0")
    except Exception:
        year = 0

    text_parts = []
    for page in doc:
        text = page.get_text("text")
        if text:
            text_parts.append(text)

    full_text = "\n".join(text_parts)
    return {
        "title": title,
        "authors": authors,
        "year": year,
        "abstract": subject,
        "keywords": keywords,
        "doi": doi,
        "path": pdf_path,
        "full_text": full_text,
    }

def ensure_dirs(output_dir: Path):
    (output_dir / "db").mkdir(parents=True, exist_ok=True)
    (output_dir / "jsonl").mkdir(parents=True, exist_ok=True)
    (output_dir / "pdfs").mkdir(parents=True, exist_ok=True)

def init_database(db_path: Path):
    conn = sqlite3.connect(db_path)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS papers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            authors TEXT,
            year INTEGER,
            abstract TEXT,
            keywords TEXT,
            doi TEXT,
            file_path TEXT,
            full_text TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.execute("""
        CREATE VIRTUAL TABLE IF NOT EXISTS papers_fts USING fts5(
            title, authors, abstract, keywords, doi, full_text
        )
    """)
    return conn

def add_paper(conn, metadata):
    cur = conn.cursor()
    cur.execute("""
        INSERT INTO papers (title, authors, year, abstract, keywords, doi, file_path, full_text)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        metadata["title"],
        metadata["authors"],
        metadata["year"],
        metadata["abstract"],
        metadata["keywords"],
        metadata["doi"],
        metadata["path"],
        metadata["full_text"],
    ))
    paper_id = cur.lastrowid
    conn.execute("""
        INSERT INTO papers_fts(rowid, title, authors, abstract, keywords, doi, full_text)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    """, (
        paper_id,
        metadata["title"],
        metadata["authors"],
        metadata["abstract"],
        metadata["keywords"],
        metadata["doi"],
        metadata["full_text"],
    ))
    conn.commit()

def chunk_text(text: str, chunk_size: int = 800):
    chunks = []
    for i in range(0, len(text), chunk_size):
        part = text[i:i + chunk_size].strip()
        if part:
            chunks.append(part)
    return chunks

def write_jsonl(jsonl_path: Path, metadata):
    with open(jsonl_path, "a", encoding="utf-8") as f:
        rec = {
            "title": metadata["title"],
            "authors": metadata["authors"],
            "year": metadata["year"],
            "abstract": metadata["abstract"],
            "keywords": metadata["keywords"],
            "doi": metadata["doi"],
            "source": metadata["path"],
            "text": metadata["full_text"],
        }
        f.write(json.dumps(rec, ensure_ascii=False) + "\n")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--pdf_dir", required=True, help="Folder containing PDF papers")
    parser.add_argument("--output_dir", default="./output", help="Output folder for DB and JSONL")
    args = parser.parse_args()

    pdf_dir = Path(args.pdf_dir).resolve()
    output_dir = Path(args.output_dir).resolve()
    ensure_dirs(output_dir)

    db_path = output_dir / "db" / "mypaperhub.db"
    jsonl_path = output_dir / "jsonl" / "papers.jsonl"
    if jsonl_path.exists():
        jsonl_path.unlink()

    conn = init_database(db_path)

    for pdf in sorted(pdf_dir.glob("*.pdf")):
        metadata = extract_pdf_metadata(str(pdf))
        add_paper(conn, metadata)
        write_jsonl(jsonl_path, metadata)

        base_name = pdf.name
        target = output_dir / "pdfs" / base_name
        if not target.exists():
            target.write_bytes(pdf.read_bytes())

    conn.close()
    print(f"Prepared library: {db_path}")
    print(f"Saved JSONL: {jsonl_path}")
    print(f"Copied PDFs to: {output_dir / 'pdfs'}")

if __name__ == "__main__":
    main()