#!/usr/bin/env python3
"""Refresh bundled content from the church's published read-only song endpoint."""
import datetime
import json
from pathlib import Path
from urllib.request import urlopen

with urlopen('https://www.pbctulsa.org/api/songs', timeout=45) as response:
    payload = json.load(response)
rows = payload['songs']
assert rows and len(rows) == payload['total'], 'Incomplete catalog'
def value(row, keys):
    for key in keys:
        v = row.get(key)
        if v is not None and str(v).strip(): return str(v).strip()
    return ''
songs = []
for row in rows:
    n = value(row, ['number','song_number','song_no','hymn_number'])
    song = dict(id=value(row,['id','song_id','slug']), title=value(row,['title','song_title','name']),
                number=int(n) if n else None, author=value(row,['author','artist','writer','composer']),
                category=value(row,['category','book','song_type','type']), songKey=value(row,['song_key','key']),
                lyrics=value(row,['lyrics_text','lyrics','song_lyrics','body','content','text']))
    assert song['id'] and song['title'] and song['lyrics'], 'Missing required song fields'
    songs.append(song)
assert len({s['id'] for s in songs}) == len(songs), 'Duplicate IDs'
time = (datetime.datetime.now(datetime.timezone.utc)-datetime.datetime(2001,1,1,tzinfo=datetime.timezone.utc)).total_seconds()
path = Path(__file__).resolve().parents[1]/'PBCSongbook/Resources/catalog.json'
temp = path.with_suffix('.tmp')
temp.write_text(json.dumps(dict(downloadedAt=time,songs=songs),ensure_ascii=False,indent=2))
temp.replace(path)
print(f'Saved {len(songs)} published songs.')
