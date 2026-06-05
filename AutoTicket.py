#!/usr/bin/env python3
import json
import math
import os
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

try:
    import pyperclip
except ImportError:
    print("pyperclip is required: pip install pyperclip")
    print("You also need xclip or xsel installed: sudo apt install xclip")
    sys.exit(1)

SCRIPT_DIR   = Path(__file__).parent
TEMPLATE_DIR = SCRIPT_DIR / "Templates"
OUTPUT_DIR   = SCRIPT_DIR / "ticket output"
CONFIG_FILE  = SCRIPT_DIR / "config.json"
REF_DOC      = "TemplateRefrence.txt"
ZW_PATTERN   = re.compile(r'[​‌‍﻿­]')


def load_config():
    if CONFIG_FILE.exists():
        try:
            return json.loads(CONFIG_FILE.read_text())
        except Exception:
            pass
    return {"LastTemplate": "DefaultTemplate"}


def save_config(cfg):
    CONFIG_FILE.write_text(json.dumps(cfg, indent=2))


def get_nested_value(obj, path_parts):
    current = obj
    for part in path_parts:
        if not isinstance(current, dict):
            return None
        current = current.get(part)
    return current


def format_timestamp(s):
    if re.match(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}', s):
        try:
            dt = datetime.fromisoformat(s.replace('Z', '+00:00'))
            local_dt = dt.astimezone()
            ms = local_dt.microsecond // 1000
            return (local_dt.strftime('%B ') + str(local_dt.day) +
                    local_dt.strftime(', %Y @ %H:%M:%S.') + f"{ms:03d}")
        except Exception:
            pass
    return s


def format_value(value):
    if value is None:
        return ''
    if isinstance(value, list):
        return ', '.join(format_value(item) for item in value)
    if isinstance(value, dict):
        return '; '.join(f"{k}={v}" for k, v in value.items())
    return format_timestamp(str(value))


def get_template_fields(template_path):
    fields = []
    for line in Path(template_path).read_text(encoding='utf-8').splitlines():
        line = ZW_PATTERN.sub('', line).strip()
        if line and not line.startswith('#'):
            fields.append(line)
    return fields


def get_templates():
    if not TEMPLATE_DIR.exists():
        return []
    return sorted(
        [f for f in TEMPLATE_DIR.iterdir() if f.is_file() and f.name != REF_DOC],
        key=lambda f: f.name
    )


def create_ticket(template_name):
    template_path = TEMPLATE_DIR / template_name

    clip_text = pyperclip.paste()
    if not clip_text or not clip_text.strip():
        print("\nClipboard is empty.")
        input("Press Enter to continue")
        return

    try:
        data = json.loads(clip_text)
    except json.JSONDecodeError:
        print("\nClipboard does not contain valid JSON.")
        input("Press Enter to continue")
        return

    if isinstance(data.get('_source'), dict):
        source = data['_source']
        root   = data
    else:
        source = data
        root   = None

    template_fields    = get_template_fields(template_path)
    populated_lines    = []
    unpopulated_fields = []

    for field in template_fields:
        path_parts = field.split('.')
        raw = get_nested_value(source, path_parts)
        if raw is None and root is not None:
            raw = get_nested_value(root, path_parts)

        if raw is None:
            unpopulated_fields.append(field)
        else:
            populated_lines.append(f"{field}: {format_value(raw)}")
            populated_lines.append('')

    lines = list(populated_lines)
    if lines and lines[-1] == '':
        lines.pop()

    if unpopulated_fields:
        lines += ['', '', 'Unpopulated Fields:', '']
        for field in unpopulated_fields:
            lines.append(f"{field}: ")
            lines.append('')
        if lines and lines[-1] == '':
            lines.pop()

    OUTPUT_DIR.mkdir(exist_ok=True)
    timestamp   = datetime.now().strftime('%Y%m%d_%H%M%S')
    output_file = OUTPUT_DIR / f"ticket_{timestamp}.txt"
    output_file.write_text('\n'.join(lines), encoding='utf-8')

    print(f"\nTicket saved to: {output_file}")

    if input("Copy ticket to clipboard? (y/n): ").strip().lower() == 'y':
        pyperclip.copy('\n'.join(lines))
        print("Copied to clipboard.")

    input("Press Enter to continue")


def select_template():
    templates   = get_templates()
    if not templates:
        print(f"\nNo templates found in: {TEMPLATE_DIR}")
        input("Press Enter to continue")
        return None

    page_size   = 8
    page        = 0
    total_pages = math.ceil(len(templates) / page_size)

    while True:
        os.system('clear')
        print(f"Select Template  (Page {page + 1} of {total_pages})")
        print("---------------------------------------------")

        start          = page * page_size
        page_templates = templates[start:start + page_size]

        for i, t in enumerate(page_templates):
            print(f"{i + 1}) {t.name}")

        print()
        if page < total_pages - 1:
            print("9) Next page")
        if page > 0:
            print("0) Previous page")
        print("B) Back")
        print()

        choice = input("Select: ").strip()

        if choice.lower() == 'b':
            return None
        if choice == '9' and page < total_pages - 1:
            page += 1
            continue
        if choice == '0' and page > 0:
            page -= 1
            continue

        try:
            idx = int(choice)
            if 1 <= idx <= len(page_templates):
                return page_templates[idx - 1].name
        except ValueError:
            pass

        print("Invalid selection.")
        time.sleep(0.6)


def open_template_folder():
    subprocess.Popen(['xdg-open', str(TEMPLATE_DIR)])


def main():
    config = load_config()

    while True:
        os.system('clear')
        print("AutoTicket")
        print("==========")
        print(f"Template: {config['LastTemplate']}")
        print()
        print("1) Paste from clipboard and create ticket")
        print("2) Select template")
        print("3) Open template folder")
        print("4) Quit")
        print()

        choice = input("Select option: ").strip()

        if choice == '1':
            if not (TEMPLATE_DIR / config['LastTemplate']).exists():
                print(f"\nTemplate '{config['LastTemplate']}' not found. Use option 2 to select a template.")
                input("Press Enter to continue")
            else:
                create_ticket(config['LastTemplate'])

        elif choice == '2':
            selected = select_template()
            if selected:
                config['LastTemplate'] = selected
                save_config(config)
                print(f"\nTemplate set to: {selected}")
                time.sleep(0.8)

        elif choice == '3':
            open_template_folder()

        elif choice == '4':
            sys.exit(0)


if __name__ == '__main__':
    main()
