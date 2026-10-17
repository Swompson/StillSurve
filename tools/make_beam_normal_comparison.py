from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import numpy as np
root=Path(__file__).resolve().parents[1]
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',19)
small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',15)
images=[Image.open(root/'.godot'/f).convert('RGB') for f in ['floor_normal_off.png','floor_normal_on.png','floor_normal_difference_x20.png']]
regions=[('Конец луча',(475,600,805,700)),('Левый край',(425,480,565,600)),('Правый край',(710,480,850,580))]
canvas=Image.new('RGB',(1040,670),'#111514');draw=ImageDraw.Draw(canvas)
for col,title in enumerate(['Без нормалей','Нормали 0,6','Разница ×20']):draw.text((10+col*345,10),title,font=font,fill='#dfd4bc')
stats=[]
for row,(name,box) in enumerate(regions):
 y=50+row*195
 draw.text((10,y),name,font=font,fill='#dfd4bc')
 for col,img in enumerate(images):
  crop=img.crop(box);crop.thumbnail((330,145));canvas.paste(crop,(10+col*345,y+30))
 a=np.asarray(images[0].crop(box)).astype(float)/255;b=np.asarray(images[1].crop(box)).astype(float)/255
 d=np.abs(a-b); stats.append(f'{name}: mean RGB difference {d.mean():.6f}, maximum {d.max():.6f}')
draw.text((10,635),'Одинаковые камера, геометрия и свет; яркость изображений не увеличена.',font=small,fill='#bcb9a7')
out=root/'docs/visuals/normal_beam_edges.png';canvas.save(out)
print('\n'.join(stats))

