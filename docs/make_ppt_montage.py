from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import re, math
folder = Path(r'C:\Users\hp\Downloads\neuro gardian x\neuroguardian_app\docs\NeuroGuardian_X_Phase2_Presentation_review')
slides = sorted(folder.glob('slide-*.png'), key=lambda p: int(re.search(r'slide-(\d+)\.png', p.name).group(1)))
thumb_w = 320
margin = 22
label_h = 28
cols = 4
rows = math.ceil(len(slides)/cols)
images=[]
for p in slides:
    im=Image.open(p).convert('RGB')
    ratio=thumb_w/im.width
    thumb_h=int(im.height*ratio)
    images.append((p, im.resize((thumb_w, thumb_h))))
thumb_h=max(im.height for _,im in images)
out=Image.new('RGB',(cols*thumb_w+(cols+1)*margin, rows*(thumb_h+label_h)+ (rows+1)*margin),'white')
d=ImageDraw.Draw(out)
for idx,(p,im) in enumerate(images,1):
    r=(idx-1)//cols; c=(idx-1)%cols
    x=margin+c*(thumb_w+margin); y=margin+r*(thumb_h+label_h+margin)
    out.paste(im,(x,y+label_h))
    d.text((x,y),f'Slide {idx}',fill=(20,35,45))
out_path=folder.parent/'NeuroGuardian_X_Phase2_Presentation_review_montage.png'
out.save(out_path)
print(out_path)
