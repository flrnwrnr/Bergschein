"""Replace the privacy article and its Astro TOC payload in the attached build."""

from html import escape
import json
from pathlib import Path
import re
import unicodedata


SOURCE = Path("/Users/florianwerner/.codex/attachments/e032d84c-f0e7-42b1-91a3-db573802ba49/index.html")
DRAFT = Path(__file__).with_name("datenschutzerklaerung-entwurf.md")
TARGET = Path(__file__).with_name("privacy-index.html")


def slug(text: str) -> str:
    normalized = unicodedata.normalize("NFKD", text.lower())
    plain = "".join(c for c in normalized if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", "-", plain).strip("-")


def inline(text: str) -> str:
    links = []

    def protect_link(match: re.Match[str]) -> str:
        label, url = match.groups()
        links.append(f'<a href="{escape(url, quote=True)}">{escape(label)}</a>')
        return f"LINKPLACEHOLDER{len(links) - 1}END"

    text = re.sub(r"\[([^\]]+)\]\((https?://[^)]+)\)", protect_link, text)
    text = escape(text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    for index, link in enumerate(links):
        text = text.replace(f"LINKPLACEHOLDER{index}END", link)
    return text.replace("  \n", "<br>\n")


def render_markdown(markdown: str) -> str:
    chunks = []
    paragraph = []

    def flush() -> None:
        if paragraph:
            chunks.append("<p>" + inline("\n".join(paragraph)) + "</p>")
            paragraph.clear()

    for line in markdown.splitlines():
        if not line.strip():
            flush()
            continue
        match = re.match(r"^(#{1,3}) (.+)$", line)
        if match:
            flush()
            level = len(match.group(1))
            title = match.group(2)
            chunks.append(f'<h{level} id="{slug(title)}">{inline(title)}</h{level}>')
        else:
            paragraph.append(line)
    flush()
    return "\n".join(chunks)


source = SOURCE.read_text(encoding="utf-8")
markdown = DRAFT.read_text(encoding="utf-8").strip()
article = render_markdown(markdown)
source, article_count = re.subn(
    r'(<div class="prose">).*?(</div>\s*</article>\s*</astro-slot>)',
    lambda match: match.group(1) + "\n" + article + "\n" + match.group(2),
    source,
    count=1,
    flags=re.DOTALL,
)
if article_count != 1:
    raise RuntimeError("Privacy article not found exactly once")

toc_text = escape(json.dumps(markdown, ensure_ascii=False)[1:-1], quote=True)
source, toc_count = re.subn(
    r'(&quot;content&quot;:\[0,&quot;).*?(&quot;\]\})',
    lambda match: match.group(1) + toc_text + match.group(2),
    source,
    count=1,
    flags=re.DOTALL,
)
if toc_count != 1:
    raise RuntimeError("Astro table-of-contents content not found exactly once")

source = source.replace("https://landing.bohd4n.dev/privacy/", "https://derbergschein.de/privacy/")
source = source.replace(
    "https://apps.apple.com/de/app/study-bro-fokussiert-lernen/id6752996931",
    "https://apps.apple.com/us/app/der-bergschein-mach-ihn-voll/id6760939607",
)
TARGET.write_text(source, encoding="utf-8")
print(TARGET)
