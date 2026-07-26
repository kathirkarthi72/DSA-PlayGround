#!/usr/bin/env python3
"""Export InterviewQuestion literals from *Module.swift into per-question JSON files."""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACKAGES = ROOT / "Packages"
OUT = ROOT / "Packages" / "DSACore" / "Sources" / "DSACore" / "Resources" / "QuestionBank"

MODULE_MAP = {
    "DSAStack": "stack",
    "DSAQueue": "queue",
    "DSAArray": "array",
    "DSALinkedList": "linkedList",
    "DSAHashTable": "hashTable",
    "DSAHeap": "heap",
    "DSATree": "tree",
}


def extract_string(block: str, key: str) -> str | None:
    m = re.search(rf'{key}:\s*"((?:\\.|[^"\\])*)"', block)
    if m:
        raw = m.group(1)
        return raw.encode("utf-8").decode("unicode_escape") if "\\" in raw else raw

    m = re.search(rf'{key}:\s*"""(.*?)"""', block, flags=re.DOTALL)
    if not m:
        return None
    text = m.group(1)
    lines = text.splitlines()
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
    if not lines:
        return ""
    indents = [len(l) - len(l.lstrip(" ")) for l in lines if l.strip()]
    trim = min(indents) if indents else 0
    return "\n".join(l[trim:] if len(l) >= trim else l for l in lines)


def extract_tags(block: str) -> list[str]:
    m = re.search(r"tags:\s*\[(.*?)\]", block, flags=re.DOTALL)
    if not m:
        return []
    return re.findall(r'"((?:\\.|[^"\\])*)"', m.group(1))


def parse_questions(source: str) -> list[dict]:
    start = source.find("var interviewQuestions")
    if start < 0:
        return []
    brace_curly = source.find("{", start)
    brace = source.find("[", brace_curly)
    if brace < 0:
        return []

    depth = 0
    end = None
    i = brace
    while i < len(source):
        if source.startswith('"""', i):
            i += 3
            while i < len(source) and not source.startswith('"""', i):
                i += 1
            i += 3
            continue
        ch = source[i]
        if ch == '"':
            i += 1
            while i < len(source):
                if source[i] == "\\":
                    i += 2
                    continue
                if source[i] == '"':
                    i += 1
                    break
                i += 1
            continue
        if ch == "[":
            depth += 1
        elif ch == "]":
            depth -= 1
            if depth == 0:
                end = i
                break
        i += 1
    if end is None:
        return []

    body = source[brace + 1 : end]
    chunks = re.split(r"InterviewQuestion\s*\(", body)[1:]
    questions = []
    for chunk in chunks:
        depth = 1
        idx = 0
        while idx < len(chunk) and depth:
            if chunk.startswith('"""', idx):
                idx += 3
                while idx < len(chunk) and not chunk.startswith('"""', idx):
                    idx += 1
                idx += 3
                continue
            ch = chunk[idx]
            if ch == '"':
                idx += 1
                while idx < len(chunk):
                    if chunk[idx] == "\\":
                        idx += 2
                        continue
                    if chunk[idx] == '"':
                        idx += 1
                        break
                    idx += 1
                continue
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
            idx += 1
        block = chunk[: idx - 1]

        qid = extract_string(block, "id")
        title = extract_string(block, "title")
        difficulty = extract_string(block, "difficulty")
        summary = extract_string(block, "summary") or ""
        approach = extract_string(block, "approach") or ""
        code = extract_string(block, "starterCode") or extract_string(block, "swiftCode") or ""
        if not qid or not title:
            continue
        description = summary if not approach else f"{summary}\n\nApproach: {approach}"
        questions.append(
            {
                "id": qid,
                "title": title,
                "difficulty": difficulty or "Medium",
                "summary": summary,
                "description": description,
                "approach": approach,
                "swiftCode": code,
                "tags": extract_tags(block),
            }
        )
    return questions


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    total = 0
    for pkg, module_id in MODULE_MAP.items():
        candidates = list((PACKAGES / pkg / "Sources" / pkg).glob("*Module.swift"))
        if not candidates:
            print(f"skip {pkg}: no module file")
            continue
        source = candidates[0].read_text(encoding="utf-8")
        questions = parse_questions(source)
        dest_dir = OUT / module_id
        dest_dir.mkdir(parents=True, exist_ok=True)
        for q in questions:
            payload = {**q, "moduleID": module_id}
            path = dest_dir / f"{q['id']}.json"
            path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
            total += 1
        print(f"{module_id}: {len(questions)} → {dest_dir}")
    print(f"wrote {total} question JSON files")


if __name__ == "__main__":
    main()
