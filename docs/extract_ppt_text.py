from pathlib import Path
from zipfile import ZipFile
import re
import xml.etree.ElementTree as ET
ppt = Path(r'C:\Users\hp\Downloads\NeuroGuardian_X_Phase2_Presentation (1).pptx')
print('exists', ppt.exists(), 'size', ppt.stat().st_size if ppt.exists() else None)
ns = {'a': 'http://schemas.openxmlformats.org/drawingml/2006/main'}
with ZipFile(ppt) as z:
    slides = sorted(
        [n for n in z.namelist() if re.match(r'ppt/slides/slide\d+\.xml$', n)],
        key=lambda x: int(re.search(r'slide(\d+)\.xml', x).group(1)),
    )
    print('slides', len(slides))
    for idx, name in enumerate(slides, 1):
        root = ET.fromstring(z.read(name))
        texts = []
        for t in root.findall('.//a:t', ns):
            if t.text and t.text.strip():
                texts.append(t.text.strip())
        print(f'--- SLIDE {idx} ---')
        print('\n'.join(texts)[:3000])
