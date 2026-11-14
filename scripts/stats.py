"""Appends one row of download counts to a CSV. Usage: python scripts/stats.py <csv> <label>
Each site is fetched on its own; a failing site leaves its cell empty and never fails the run."""
import csv, datetime, html, json, os, re, sys, urllib.request

def get(url, token=None):
    headers = {"User-Agent": "Mozilla/5.0 BruhForeverStats"}
    if token: headers["Authorization"] = "Bearer " + token
    return urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=30).read().decode()

def github():
    repo, token = os.environ["GITHUB_REPOSITORY"], os.environ.get("GITHUB_TOKEN")
    releases = json.loads(get(f"https://api.github.com/repos/{repo}/releases?per_page=100", token))
    return sum(a["download_count"] for r in releases for a in r["assets"])

def curseforge():  # curseforge.com blocks scripts, so this goes through the public cfwidget mirror
    return json.loads(get("https://api.cfwidget.com/1794727"))["downloads"]["total"]

def wowinterface():
    return int(json.loads(get("https://api.mmoui.com/v3/game/WOW/filedetails/27302.json"))[0]["UIHitCount"])

def wago():  # the addon page embeds its data as an Inertia JSON blob
    page = re.search(r'data-page="([^"]+)"', get("https://addons.wago.io/addons/j6jAZONR")).group(1)
    return json.loads(html.unescape(page))["props"]["metadata"]["download_count"]

def main(path, label):
    row = [datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M"), label]
    for fn in (github, curseforge, wowinterface, wago):
        try:
            row.append(fn())
        except Exception as e:
            print(f"stats: {fn.__name__} failed: {e}", file=sys.stderr)
            row.append("")
    new = not os.path.exists(path)
    with open(path, "a", newline="") as f:
        w = csv.writer(f)
        if new: w.writerow(["utc", "label", "github", "curseforge", "wowinterface", "wago"])
        w.writerow(row)
    print(",".join(map(str, row)))

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
