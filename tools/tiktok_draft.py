"""Send a video to the TikTok app's drafts (inbox) via the Content Posting API; you then tap Post in the app.

One-time setup (TikTok developer app with Login Kit + Content Posting API, scope video.upload):
  python3 tools/tiktok_draft.py auth-url            # open the printed URL, approve, copy the code= from the redirect
  python3 tools/tiktok_draft.py token CODE          # prints the refresh token to store as TIKTOK_REFRESH_TOKEN
Daily:
  python3 tools/tiktok_draft.py upload FILE.mp4

Env: TIKTOK_CLIENT_KEY, TIKTOK_CLIENT_SECRET, TIKTOK_REDIRECT_URI, TIKTOK_REFRESH_TOKEN (upload only).
"""
import json
import os
import pathlib
import sys
import urllib.parse
import urllib.request

API = "https://open.tiktokapis.com/v2"


def env(name):
    v = os.environ.get(name)
    if not v:
        raise SystemExit(f"missing env {name}")
    return v


def call(method, url, body=None, headers=None, form=False):
    headers = dict(headers or {})
    if body is not None and not isinstance(body, bytes):
        if form:
            body = urllib.parse.urlencode(body).encode()
            headers["Content-Type"] = "application/x-www-form-urlencoded"
        else:
            body = json.dumps(body).encode()
            headers["Content-Type"] = "application/json; charset=UTF-8"
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            raw = r.read()
    except urllib.error.HTTPError as e:
        raise SystemExit(f"{method} {url} -> {e.code}: {e.read().decode(errors='replace')}")
    return json.loads(raw) if raw else {}


def token(grant):
    data = dict(client_key=env("TIKTOK_CLIENT_KEY"), client_secret=env("TIKTOK_CLIENT_SECRET"), **grant)
    r = call("POST", f"{API}/oauth/token/", data, form=True)
    if "access_token" not in r:
        raise SystemExit(f"token error: {r}")
    return r


def auth_url():
    q = dict(client_key=env("TIKTOK_CLIENT_KEY"), scope="user.info.basic,video.upload", response_type="code",
             redirect_uri=env("TIKTOK_REDIRECT_URI"), state="shorts")
    print("https://www.tiktok.com/v2/auth/authorize/?" + urllib.parse.urlencode(q))


def upload(path):
    path = pathlib.Path(path)
    access = token(dict(grant_type="refresh_token", refresh_token=env("TIKTOK_REFRESH_TOKEN")))["access_token"]
    size = path.stat().st_size
    if size > 64 * 1024 * 1024:
        raise SystemExit("video over 64MB; single-chunk upload only")
    auth = {"Authorization": f"Bearer {access}"}
    init = call("POST", f"{API}/post/publish/inbox/video/init/",
                {"source_info": {"source": "FILE_UPLOAD", "video_size": size, "chunk_size": size, "total_chunk_count": 1}},
                auth)
    if init.get("error", {}).get("code") not in (None, "ok"):
        raise SystemExit(f"init error: {init['error']}")
    data = init["data"]
    call("PUT", data["upload_url"], path.read_bytes(),
         {"Content-Type": "video/mp4", "Content-Range": f"bytes 0-{size - 1}/{size}"})
    print("sent to TikTok drafts, publish_id", data["publish_id"])


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "auth-url":
        auth_url()
    elif cmd == "token" and len(sys.argv) == 3:
        r = token(dict(grant_type="authorization_code", code=sys.argv[2], redirect_uri=env("TIKTOK_REDIRECT_URI")))
        print("TIKTOK_REFRESH_TOKEN =", r["refresh_token"])
    elif cmd == "upload" and len(sys.argv) == 3:
        upload(sys.argv[2])
    else:
        raise SystemExit(__doc__)
