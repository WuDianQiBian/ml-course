#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$ROOT_DIR/activate_venv.sh"
ensure_and_activate_venv

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <notebook.ipynb>" >&2
  exit 1
fi

NOTEBOOK_ARG="$1"

NOTEBOOK_PATH="$(
  python3 - "$ROOT_DIR" "$NOTEBOOK_ARG" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()
arg = Path(sys.argv[2])
notebook = (arg if arg.is_absolute() else root / arg).resolve()

print(notebook)
PY
)"

OUTPUT_STEM="$(
  python3 - "$ROOT_DIR" "$NOTEBOOK_ARG" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()
notebooks_root = root / "notebooks"
arg = Path(sys.argv[2])
notebook = (arg if arg.is_absolute() else root / arg).resolve()

if notebook.is_relative_to(notebooks_root):
    rel = notebook.relative_to(notebooks_root)
elif notebook.is_relative_to(root):
    rel = notebook.relative_to(root)
else:
    rel = Path(notebook.name)

print(rel.with_suffix(''))
PY
)"

if [[ ! -f "$NOTEBOOK_PATH" ]]; then
  echo "Notebook not found: $NOTEBOOK_PATH" >&2
  exit 1
fi

if [[ "${NOTEBOOK_PATH##*.}" != "ipynb" ]]; then
  echo "Expected an .ipynb file: $NOTEBOOK_PATH" >&2
  exit 1
fi

HTML_PATH="$ROOT_DIR/tmp/pdfs/$OUTPUT_STEM.html"
PDF_PATH="$ROOT_DIR/pdfs/$OUTPUT_STEM.pdf"

mkdir -p "$(dirname "$HTML_PATH")" "$(dirname "$PDF_PATH")"

echo "Exporting notebook to HTML..."
jupyter nbconvert \
  --to html \
  "$NOTEBOOK_PATH" \
  --output "$(basename "${HTML_PATH%.html}")" \
  --output-dir "$(dirname "$HTML_PATH")"

echo "Printing PDF..."
python3 - "$HTML_PATH" "$PDF_PATH" <<'PY'
from pathlib import Path
import subprocess
import sys

from playwright.sync_api import Error, sync_playwright

html_path = Path(sys.argv[1]).resolve()
pdf_path = Path(sys.argv[2]).resolve()

css = """
@page {
  size: Letter;
  margin: 0.24in 0.26in;
}
:root {
  --jp-notebook-padding: 4px !important;
  --jp-cell-prompt-width: 52px !important;
  --jp-cell-collapser-width: 0px !important;
}
html, body {
  margin: 0 !important;
  padding: 0 !important;
  background: #ffffff !important;
  -webkit-print-color-adjust: exact !important;
  print-color-adjust: exact !important;
}
body.jp-Notebook, main, .jp-Notebook {
  width: 100% !important;
  max-width: none !important;
  margin: 0 !important;
  padding: 0 !important;
  overflow: visible !important;
}
.jp-Cell {
  margin: 0 0 8px 0 !important;
  break-inside: avoid-page;
  page-break-inside: avoid;
}
.jp-Collapser,
.jp-MarkdownCell .jp-InputPrompt,
.jp-OutputPrompt {
  display: none !important;
  width: 0 !important;
  padding: 0 !important;
}
.jp-MarkdownOutput {
  padding-left: 0 !important;
  width: auto !important;
}
.jp-RenderedHTMLCommon {
  padding-right: 0 !important;
}
.jp-InputArea,
.jp-Cell-inputWrapper,
.jp-Cell-outputWrapper,
.jp-OutputArea-child {
  width: 100% !important;
}
.jp-InputArea-editor,
.jp-OutputArea-output {
  overflow: visible !important;
}
.jp-RenderedHTMLCommon img,
.jp-OutputArea img,
img {
  max-width: 100% !important;
  height: auto !important;
}
"""


def render_pdf() -> None:
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch()
        page = browser.new_page(
            viewport={"width": 1500, "height": 2200},
            device_scale_factor=1.5,
        )
        page.goto(html_path.as_uri(), wait_until="load", timeout=120_000)
        page.wait_for_load_state("networkidle", timeout=120_000)
        page.add_style_tag(content=css)
        page.emulate_media(media="print")
        page.pdf(
            path=str(pdf_path),
            format="Letter",
            print_background=True,
            margin={
                "top": "0.24in",
                "right": "0.26in",
                "bottom": "0.24in",
                "left": "0.26in",
            },
            prefer_css_page_size=True,
            scale=1.0,
        )
        browser.close()


try:
    render_pdf()
except Error as exc:
    if "executable doesn't exist" not in str(exc).lower():
        raise

    subprocess.run(
        [sys.executable, "-m", "playwright", "install", "chromium"],
        check=True,
    )
    render_pdf()

print(pdf_path)
PY

echo "Saved PDF to: $PDF_PATH"
