script_path = r"C:\Codex\LembreteAmigo\tools\adequar_tcc_ifpi.py"
with open(script_path, encoding="utf-8") as source:
    script = source.read()

script = script.replace(
    "for paragraph in doc.paragraphs:\n    text = paragraph.text.strip()",
    "for paragraph_index, paragraph in enumerate(doc.paragraphs):\n    text = paragraph.text.strip()",
)
script = script.replace(
    "if 35 <= doc.paragraphs.index(paragraph) <= 58:",
    "if 35 <= paragraph_index <= 58:",
)
exec(compile(script, script_path, "exec"))
