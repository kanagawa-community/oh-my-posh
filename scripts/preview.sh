# Preview hook for .github/scripts/render-previews.sh. Oh My Posh draws the prompts
# of each theme from template data (`print --data --data-only`), so the images show
# the same user, host, path, git state and versions on every machine, and nothing
# of the machine that renders them. A recorded data file (`config export data`)
# gives the exact property names; the scenes below change only the values shown.
# The prompt is what this port themes, so the image shows the 16 terminal colors
# and six prompts: a clean repository, a dirty one, a failed command with a Kubernetes
# context and a low battery, and the Vi modes (normal, visual, insert).
# Requires: oh-my-posh 32 or later, git, python3, perl.
# The renderer sources this file: it sets name, and provides work and root.
# shellcheck shell=bash disable=SC2034,SC2154
name="Oh My Posh"

setup() {
  # Record the data once, in a repository with a Node.js project, so every segment
  # the scenes use has all its properties. The scenes overwrite what they show.
  demo="$work/demo"
  mkdir -p "$demo" "$work/home" "$work/cache" "$work/bin"
  printf '#!/bin/sh\necho v22.12.0\n' >"$work/bin/node"
  chmod +x "$work/bin/node"
  printf '{ "name": "kanagawa", "version": "1.0.0" }\n' >"$demo/package.json"
  git -C "$demo" init -q -b main
  (cd "$demo" && env -i PATH="$work/bin:$PATH" HOME="$work/home" XDG_CACHE_HOME="$work/cache" LC_ALL=C.UTF-8 \
    oh-my-posh config export data --config "$root/themes/kanagawa-wave.omp.json" --output "$work/base.json" >/dev/null)
}

# scenes VARIANT: write $work/scene-N.json and $work/scene-N.cmd for each prompt.
scenes() {
  python3 -I - "$work" "$root/themes/kanagawa-$1.omp.json" "$1" <<'PY'
import copy, json, sys
work, theme, variant = sys.argv[1:]
base = json.load(open(f"{work}/base.json"))
t = json.load(open(theme))
git_opts = next(s for b in t["blocks"] for s in b["segments"] if s["type"] == "git")["options"]
icon = git_opts["branch_icon"]
# Only these segments show. Everything else stays off, whatever the recording machine had.
SHOWN = {"session", "path", "git", "node", "project", "kubectl", "battery", "vimode", "executiontime", "status", "text"}


def scene(code=0, ms=120, dirty=False, project=False, kube=False, battery=False, mode=None, vim_insert=False):
    d = copy.deepcopy(base)
    d["env"].update(PWD="/home/kanagawa/oh-my-posh", AbsolutePWD="/home/kanagawa/oh-my-posh", Folder="oh-my-posh",
                    PSWD="", UserName="kanagawa", HostName=variant, Code=code, Root=False, Jobs=0,
                    OS="linux", Shell="shell", Var={**t["var"], "vim_show_insert": vim_insert})
    s = d["segments"]
    for k, v in s.items():
        v["enabled"] = k in SHOWN
    s["session"]["data"]["SSHSession"] = False
    p = s["path"]["data"]
    p.update(Path={"$markup": "~/kanagawa/oh-my-posh"}, Location="/home/kanagawa/oh-my-posh", Parent="/home/kanagawa/")
    g = s["git"]["data"]
    g.update(HEAD={"$markup": icon + "main"}, Ref="main", Ahead=1 if dirty else 0, Behind=0, StashCount=0,
             BranchStatus={"$markup": "↑1" if dirty else "≢"})
    for part, counts in (("Working", dict(Modified=2, Untracked=1)), ("Staging", dict(Added=1))):
        w = g[part] or {}
        w.pop("String", None)
        w.update({k: 0 for k in ("Added", "Deleted", "Modified", "Untracked", "Unmerged", "Moved")})
        w["Changed"] = dirty
        if dirty:
            w.update(counts)
        g[part] = w
    s["node"]["data"].update(Full="22.12.0", Major="22", Minor="12", Patch="0", Error="")
    s["project"]["enabled"] = project
    s["project"]["data"].update(Version="1.0.0", Name="kanagawa", Error="")
    s["kubectl"]["enabled"] = kube
    s["kubectl"]["data"].update(Context={"$markup": "prod-eu"}, Namespace="web")
    b = s["battery"]
    b["enabled"] = battery
    b["data"].update(Percentage=14, State=4, Error="")  # 4 is Discharging
    s["vimode"]["enabled"] = mode is not None
    s["vimode"]["data"].update(Mode=mode or "", Keymap={"normal": "vicmd", "visual": "visual", "insert": "viins"}.get(mode, ""))
    s["executiontime"]["data"].update(Ms=ms, FormattedMs=f"{ms}ms" if ms < 1000 else f"{ms / 1000:.1f}s")
    s["status"]["data"].update(Meaning=str(code))
    return d


SCENES = [
    (scene(ms=120), "git status"),
    (scene(ms=1840, dirty=True, project=True), "npm test"),
    (scene(code=127, ms=35, kube=True, battery=True), "kubectl get pods"),
    (scene(mode="normal", vim_insert=True), ""),
    (scene(mode="visual", vim_insert=True), "git log --oneline"),
    (scene(mode="insert", vim_insert=True), "git log --oneline"),
]
for i, (d, cmd) in enumerate(SCENES):
    json.dump(d, open(f"{work}/scene-{i}.json", "w"))
    open(f"{work}/scene-{i}.cmd", "w").write(cmd)
PY
}

# Print one prompt from a scene, with the shell integration and link sequences dropped
# (they carry the path) and the typed command after the prompt. A third argument "last"
# keeps only the last line of the prompt.
prompt() {
  local out
  out=$(env -i PATH="$PATH" HOME="$work/home" XDG_CACHE_HOME="$work/cache" COLORTERM=truecolor LC_ALL=C.UTF-8 \
    oh-my-posh print primary --config "$root/themes/kanagawa-$1.omp.json" --shell shell --terminal-width 100 \
    --data "$work/scene-$2.json" --data-only 2>/dev/null | perl -pe 's/\e\][^\a\e]*(\a|\e\\)//g')
  [[ ${3:-} == last ]] && out=${out##*$'\n'}
  printf '%s%s\n' "$out" "$(<"$work/scene-$2.cmd")"
}

capture() {
  scenes "$1"
  : >"$2"
  # The 16 terminal colors, from the palette through the terminal theme.
  { for base in 40 100; do for c in 0 1 2 3 4 5 6 7; do printf '\e[%sm   \e[0m' $((base + c)); done; printf '\n'; done; printf '\n'; } >>"$2"
  for i in 0 1 2; do prompt "$1" "$i" >>"$2"; printf '\n' >>"$2"; done
  {
    prompt "$1" 3
    prompt "$1" 4 last
    prompt "$1" 5 last
  } >>"$2"
}
