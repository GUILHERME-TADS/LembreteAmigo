from copy import deepcopy
from docx import Document
from docx.enum.style import WD_STYLE_TYPE
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.shared import Cm, Pt


INPUT = r"C:\Codex\LembreteAmigo\TCC-Lembrete-Amigo-original.docx"
OUTPUT = r"C:\Codex\LembreteAmigo\TCC-Lembrete-Amigo-adequado-IFPI.docx"


def set_font(run, size=12, bold=None, italic=None):
    run.font.name = "Arial"
    run._element.rPr.rFonts.set(qn("w:ascii"), "Arial")
    run._element.rPr.rFonts.set(qn("w:hAnsi"), "Arial")
    run.font.size = Pt(size)
    if bold is not None:
        run.bold = bold
    if italic is not None:
        run.italic = italic


def set_para(paragraph, align=None, first_indent=None, line=1.5, before=0, after=0):
    fmt = paragraph.paragraph_format
    if align is not None:
        paragraph.alignment = align
    fmt.left_indent = None
    fmt.right_indent = None
    fmt.first_line_indent = first_indent
    fmt.line_spacing = line
    fmt.space_before = Pt(before)
    fmt.space_after = Pt(after)


def set_heading(paragraph, level):
    paragraph.style = f"Heading {level}"
    set_para(paragraph, WD_ALIGN_PARAGRAPH.LEFT, None, 1.5, 0, 0)
    if level == 1:
        paragraph.paragraph_format.page_break_before = True
    for run in paragraph.runs:
        set_font(run, 12, bold=True)
        if level <= 2:
            run.text = run.text.upper()


def set_unumbered_title(paragraph):
    set_para(paragraph, WD_ALIGN_PARAGRAPH.CENTER, None, 1.5, 0, 0)
    for run in paragraph.runs:
        set_font(run, 12, bold=True)
        run.text = run.text.upper()


def is_caption(text):
    return text.startswith(("Figura ", "Tabela ", "Quadro ", "Algoritmo ", "Código "))


def is_source(text):
    return text.lower().startswith(("fonte:", "nota:", "obs:"))


def looks_like_code(text):
    tokens = ("{", "}", "function ", "return ", "final ", "await ", "match /", "allow ")
    return any(token in text for token in tokens)


doc = Document(INPUT)

# Página A4 e margens do anverso exigidas pelo manual IFPI.
for section in doc.sections:
    section.top_margin = Cm(3)
    section.left_margin = Cm(3)
    section.bottom_margin = Cm(2)
    section.right_margin = Cm(2)

# Estilos-base, evitando dependência de variações de formatação direta.
normal = doc.styles["Normal"]
normal.font.name = "Arial"
normal._element.rPr.rFonts.set(qn("w:ascii"), "Arial")
normal._element.rPr.rFonts.set(qn("w:hAnsi"), "Arial")
normal.font.size = Pt(12)
normal.paragraph_format.line_spacing = 1.5
normal.paragraph_format.space_before = Pt(0)
normal.paragraph_format.space_after = Pt(0)

for level in (1, 2, 3):
    style = doc.styles[f"Heading {level}"]
    style.font.name = "Arial"
    style._element.rPr.rFonts.set(qn("w:ascii"), "Arial")
    style._element.rPr.rFonts.set(qn("w:hAnsi"), "Arial")
    style.font.size = Pt(12)
    style.font.bold = True
    style.paragraph_format.line_spacing = 1.5
    style.paragraph_format.space_before = Pt(0)
    style.paragraph_format.space_after = Pt(0)

unnumbered_titles = {
    "AGRADECIMENTOS", "RESUMO", "ABSTRACT", "LISTA DE ILUSTRAÇÕES",
    "LISTA DE TABELAS", "LISTA DE ABREVIATURAS E SIGLAS", "SUMÁRIO",
    "REFERÊNCIAS", "GLOSSÁRIO", "APÊNDICES", "ANEXOS",
}

in_references = False
for paragraph in doc.paragraphs:
    text = paragraph.text.strip()
    if not text:
        continue
    upper = text.upper()

    if upper in unnumbered_titles:
        set_unumbered_title(paragraph)
        in_references = upper == "REFERÊNCIAS"
        continue

    if text[:1].isdigit() and paragraph.style.name.startswith("Heading"):
        level = int(paragraph.style.name[-1])
        set_heading(paragraph, level)
        in_references = False
        continue

    if in_references:
        set_para(paragraph, WD_ALIGN_PARAGRAPH.LEFT, None, 1.0, 0, 12)
        for run in paragraph.runs:
            set_font(run, 12)
        continue

    if is_caption(text):
        set_para(paragraph, WD_ALIGN_PARAGRAPH.CENTER, None, 1.0, 0, 0)
        for run in paragraph.runs:
            set_font(run, 12)
        continue

    if is_source(text):
        set_para(paragraph, WD_ALIGN_PARAGRAPH.LEFT, None, 1.0, 0, 0)
        for run in paragraph.runs:
            set_font(run, 10)
        continue

    if looks_like_code(text):
        set_para(paragraph, WD_ALIGN_PARAGRAPH.LEFT, None, 1.0, 0, 0)
        for run in paragraph.runs:
            set_font(run, 10)
        continue

    # Elementos de lista pré-textual e do sumário são mantidos sem recuo de parágrafo.
    if 35 <= doc.paragraphs.index(paragraph) <= 58:
        set_para(paragraph, WD_ALIGN_PARAGRAPH.LEFT, None, 1.0, 0, 0)
    else:
        set_para(paragraph, WD_ALIGN_PARAGRAPH.JUSTIFY, Cm(1.25), 1.5, 0, 0)
    for run in paragraph.runs:
        set_font(run, 12)

# A natureza da folha de rosto deve permanecer em espaço simples e à direita.
for index in (16, 18):
    if index < len(doc.paragraphs):
        paragraph = doc.paragraphs[index]
        set_para(paragraph, WD_ALIGN_PARAGRAPH.JUSTIFY, None, 1.0, 0, 0)
        paragraph.paragraph_format.left_indent = Cm(8)
        for run in paragraph.runs:
            set_font(run, 12)

# Palavras-chave devem estar separadas por ponto e vírgula, conforme o manual.
for paragraph in doc.paragraphs:
    if paragraph.text.startswith("Palavras-chave:"):
        body = paragraph.text.split(":", 1)[1].strip().rstrip(".")
        terms = [term.strip() for term in body.split(".") if term.strip()]
        revised = "Palavras-chave: " + "; ".join(terms) + "."
        paragraph.clear()
        run = paragraph.add_run(revised)
        set_font(run, 12)
        set_para(paragraph, WD_ALIGN_PARAGRAPH.JUSTIFY, Cm(1.25), 1.5, 0, 0)
    elif paragraph.text.startswith("Keywords:"):
        body = paragraph.text.split(":", 1)[1].strip().rstrip(".")
        terms = [term.strip() for term in body.split(".") if term.strip()]
        revised = "Keywords: " + "; ".join(terms) + "."
        paragraph.clear()
        run = paragraph.add_run(revised)
        set_font(run, 12)
        set_para(paragraph, WD_ALIGN_PARAGRAPH.JUSTIFY, Cm(1.25), 1.5, 0, 0)

# Tabelas: texto legível, alinhamento coerente e sem espaçamento excedente.
for table in doc.tables:
    for row_idx, row in enumerate(table.rows):
        for cell in row.cells:
            for paragraph in cell.paragraphs:
                set_para(paragraph, WD_ALIGN_PARAGRAPH.LEFT, None, 1.0, 0, 0)
                for run in paragraph.runs:
                    set_font(run, 10, bold=True if row_idx == 0 else None)

doc.save(OUTPUT)
print(OUTPUT)
