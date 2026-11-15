"""Local-only UI fixture. Use a dedicated test simulator, not a real account."""
import argparse
import json
import re
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

state = {}
lock = threading.RLock()
def reset():
    state.update(liked=False, disliked=False, followed=False, comments=[], next_id=1)
reset()
class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def result(self, data=None, code=200):
        raw=json.dumps({'code':code,'data':data,'msg':'success' if code==200 else 'fixture error'}).encode()
        self.send_response(200);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(raw)));self.end_headers();self.wfile.write(raw)
    def scene(self):
        return dict(id=1,dialogueId=10,title='QA scene',description='Local interaction fixture',videoUrl='http://127.0.0.1:19080/clip.mp4',coverUrl=None,
                    category='Daily',level=1,creatorUid=2,creatorName='QA author',creatorAvatar=None,sentenceCount=2,
                    likes=int(state['liked']),dislikes=int(state['disliked']),liked=state['liked'],disliked=state['disliked'],followed=state['followed'],comments=len(state['comments']))
    def do_GET(self):
        path=urlsplit(self.path).path.removeprefix('/oneCode')
        if path=='/_health': return self.result(True)
        if path=='/clip.mp4':
            raw=self.server.clip.read_bytes();start=0;end=len(raw)-1
            match=re.match(r'bytes=(\d+)-(\d*)',self.headers.get('Range',''))
            if match:
                start=int(match[1]);end=min(int(match[2]) if match[2] else end,end)
                self.send_response(206);self.send_header('Content-Range',f'bytes {start}-{end}/{len(raw)}')
            else: self.send_response(200)
            raw=raw[start:end+1];self.send_header('Content-Type','video/mp4');self.send_header('Accept-Ranges','bytes');self.send_header('Content-Length',str(len(raw)));self.end_headers();self.wfile.write(raw);return
        with lock:
            if path=='/lazyer/mobile/social/feed': return self.result({'items':[self.scene()],'nextCursor':None})
            if path=='/lazyer/mobile/social/feed/1': return self.result(self.scene())
            if path=='/lazyer/mobile/social/me': return self.result({'uid':7,'nickname':'QA viewer','avatar':None})
            if path=='/lazyer/mobile/social/feed/1/comments': return self.result({'items':state['comments'][::-1],'nextCursor':None})
            self.result(None,404)
    def do_POST(self): self.mutate('POST')
    def do_PUT(self): self.mutate('PUT')
    def do_DELETE(self): self.mutate('DELETE')
    def mutate(self, method):
        path=urlsplit(self.path).path.removeprefix('/oneCode')
        data=json.loads(self.rfile.read(int(self.headers.get('Content-Length','0'))) or '{}')
        with lock:
            if path=='/_reset': reset();return self.result(True)
            if path=='/lazyer/mobile/login': return self.result({'token':'local-ui-fixture-token'})
            if path=='/lazyer/mobile/social/creators/2/follow':
                state['followed']=method=='PUT';return self.result({'uid':2,'followed':state['followed'],'followers':int(state['followed'])})
            for reaction,other in [('like','disliked'),('dislike','liked')]:
                if path==f'/lazyer/mobile/social/feed/1/{reaction}':
                    field='liked' if reaction=='like' else 'disliked';state[field]=method=='PUT'
                    if state[field]:state[other]=False
                    return self.result({'liked':state['liked'],'disliked':state['disliked'],'likes':int(state['liked']),'dislikes':int(state['disliked'])})
            if path=='/lazyer/mobile/social/feed/1/comments' and method=='POST':
                comment={'id':state['next_id'],'uid':7,'feedId':1,'body':data['body'],'nickname':'QA viewer','avatar':None,'createdAt':'2026-11-15 12:00:00'}
                state['comments'].append(comment);state['next_id']+=1;return self.result(comment)
            if path.startswith('/lazyer/mobile/social/comments/') and method=='DELETE':
                key=int(path.rsplit('/',1)[1]);state['comments']=[x for x in state['comments'] if x['id']!=key];return self.result()
            self.result(None,404)
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--clip',required=True);args=parser.parse_args()
    server=ThreadingHTTPServer(('127.0.0.1',19080),Handler);server.clip=Path(args.clip);print('UI fixture listening on localhost:19080',flush=True);server.serve_forever()
