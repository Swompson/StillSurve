from pathlib import Path
import wave, numpy as np
root=Path(__file__).resolve().parents[1]
p=root/'.godot/voy2_decoded.wav'
with wave.open(str(p)) as w:
 rate=w.getframerate(); channels=w.getnchannels(); samples=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').reshape(-1,channels)
block=int(rate*.02)
rms=np.array([np.sqrt(np.mean(samples[i:i+block].astype(float)**2)) for i in range(0,len(samples),block)])
active=np.where(rms>max(150,rms.max()*.025))[0]
groups=np.split(active,np.where(np.diff(active)>25)[0]+1)
print('segments',[(round(g[0]*.02,2),round(g[-1]*.02,2)) for g in groups if len(g)])
assert len(groups)==4, 'Inspect detected pauses before splitting'
out=root/'assets/audio/monster/howls';out.mkdir(parents=True,exist_ok=True)
for i,g in enumerate(groups):
 a=max(0,int((g[0]*.02-.12)*rate)); b=min(len(samples),int((g[-1]*.02+.25)*rate))
 with wave.open(str(out/f'howl_{i+2}.wav'),'wb') as w:
  w.setnchannels(channels);w.setsampwidth(2);w.setframerate(rate);w.writeframes(samples[a:b].tobytes())
