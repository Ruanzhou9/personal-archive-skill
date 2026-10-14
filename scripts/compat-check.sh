#!/usr/bin/env bash
# ============================================================
# Personal Archive · 兼容性核对 (compat-check)
#
# 核对本机每个 agent 技能目录里的 personal-archive 副本是否「装得上、读得到、规范一致」：
#   · SKILL.md 首行 ---（frontmatter 可被 skill 加载器识别）、闭合、必填字段
#   · name 与目录名一致、description 长度在 Agent Skills 规范内（≤1024）、声明 version
#   · 无 BOM / LF 换行 / UTF-8 合法
#   · archive/ 就位，且能解析到含 总索引.md（或 00-总索引.md）的档案目录
#   · 无同源变体（避免同一个 agent 重复加载两份协议）
#
# 用法: bash scripts/compat-check.sh          核对全部
#       bash scripts/compat-check.sh --only claude
# 退出码: 0=全部兼容  1=存在错误
# ============================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "${DIR}/.." && pwd)"
SRC="${REPO}/personal-archive"
SKILL_NAME="personal-archive"
ONLY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --only) [ $# -ge 2 ] || { echo "✗ --only 需要参数"; exit 2; }; ONLY="$2"; shift 2 ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "✗ 未知参数: $1"; exit 2 ;;
  esac
done

CANDIDATES=(
  "${HOME}/.claude/skills" "${HOME}/.codex/skills" "${HOME}/.hermes/skills"
  "${HOME}/.openclaw/skills" "${HOME}/.config/opencode/skills" "${HOME}/.workbuddy/skills"
  "${HOME}/.copilot/skills" "${HOME}/.dsh/skills" "${HOME}/.agents/skills"
)
shopt -s nullglob
for d in "${HOME}"/*/skills "${HOME}"/.*/skills "${HOME}"/.config/*/skills \
         "${HOME}/Library/Application Support"/*/skills; do
  [ -d "$d" ] || continue
  case "$d" in */.Trash/*|*/.cache/*|*/.npm/*|*/.local/*|*/.git/*|*/.vscode/*) continue ;; esac
  CANDIDATES+=("$d")
done
shopt -u nullglob

SEEN=""
TOTAL=0; ERR=0; WARN=0
ok(){ echo "      ✓ $1"; }
err(){ echo "      ✗ $1"; ERR=$((ERR+1)); }
warn(){ echo "    ⚠️  $1"; WARN=$((WARN+1)); }

echo "══ Personal Archive · 兼容性核对 ══"
echo ""

for parent in "${CANDIDATES[@]}"; do
  [ -d "${parent}" ] || continue
  dest="${parent}/${SKILL_NAME}"
  [ -e "${dest}" ] || continue
  case ",${SEEN}," in *",${dest},"*) continue ;; esac
  SEEN="${SEEN},${dest}"
  TOTAL=$((TOTAL+1))

  if [ -n "${ONLY}" ]; then
    case "${parent}" in *"${ONLY}"*) : ;; *) continue ;; esac
  fi

  n_skills=$(find "${parent}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  echo "▸ ${parent}   （该目录已有 ${n_skills} 个技能）"

  if [ -L "${dest}" ]; then
    tgt="$(readlink "${dest}")"
    if [ -f "${tgt}/SKILL.md" ]; then
      ok "软链安装 → ${tgt}"
    else
      err "软链目标无 SKILL.md: ${tgt}"
    fi
  fi

  f="${dest}/SKILL.md"
  if [ ! -f "${f}" ]; then
    err "缺少 SKILL.md"
    echo ""
    continue
  fi

  if [ "$(head -c 3 "$f" | od -An -c | tr -d ' \n')" = "---" ]; then
    ok "首行 ---（frontmatter 可识别）"
  else
    err "首行不是 ---（skill 加载器读不到 frontmatter）"
  fi

  n=$(grep -c '^---[[:space:]]*$' "$f" | tr -d ' ')
  if [ "${n}" -ge 2 ]; then ok "frontmatter 已闭合"; else err "frontmatter 未闭合"; fi

  nm="$(sed -n 's/^name:[[:space:]]*//p' "$f" | head -1)"
  if [ "${nm}" = "${SKILL_NAME}" ]; then
    ok "name=${nm} 与目录名一致"
  else
    err "name=${nm} 与目录名 ${SKILL_NAME} 不一致"
  fi

  ds="$(sed -n 's/^description:[[:space:]]*//p' "$f" | head -1)"
  dlen=$(printf '%s' "${ds}" | awk '{print length($0)}')
  if [ "${dlen}" -eq 0 ]; then
    err "缺 description"
  elif [ "${dlen}" -gt 1024 ]; then
    err "description ${dlen} 字符 > 1024（超出 Agent Skills 规范）"
  else
    ok "description ${dlen} 字符（≤1024）"
  fi

  v="$(sed -n 's/^version:[[:space:]]*//p' "$f" | head -1)"
  if [ -n "${v}" ]; then ok "version=${v}"; else warn "未声明 version"; fi

  if [ -n "$(head -c 3 "$f" | od -An -tx1 | tr -d ' \n' | grep -i 'efbbbf' || true)" ]; then
    err "存在 BOM（应去掉）"
  else
    ok "无 BOM"
  fi
  if grep -q $'\r' "$f" 2>/dev/null; then err "存在 CRLF（应为 LF）"; else ok "换行符 LF"; fi
  # UTF-8 检测用 python 解码而非 iconv：iconv 在某些非 TTY 环境会对 /dev/null 报
  # "Inappropriate ioctl for device"，退出码非 0，被误判成编码非法
  if /usr/bin/python3 -c "import sys; open(sys.argv[1], encoding='utf-8').read()" "$f" 2>/dev/null; then
    ok "UTF-8 编码合法"
  else
    err "不是合法 UTF-8"
  fi

  a="${dest}/archive"
  if [ ! -e "${a}" ]; then
    err "缺少 archive/（agent 解析不到档案根目录）"
  else
    ap="${a}"; [ -L "${a}" ] && ap="$(readlink "${a}")"
    if [ -f "${ap}/总索引.md" ] || [ -f "${ap}/00-总索引.md" ]; then
      ok "archive/ 就位；ArchiveRoot 解析 → ${ap}"
    else
      err "archive/ 下没有 总索引.md 或 00-总索引.md（解析到的不是个人档案）"
    fi
  fi

  varnt=""
  shopt -s nullglob
  for vd in "${parent}/${SKILL_NAME}"*; do
    [ -d "${vd}" ] || continue
    [ "${vd}" = "${dest}" ] && continue
    varnt="${varnt}$(basename "${vd}") "
  done
  shopt -u nullglob
  if [ -n "${varnt}" ]; then warn "同源变体: ${varnt}"; else ok "无同源变体"; fi

  echo ""
done

echo "══ 汇总 ══"
echo "  已安装 ${TOTAL} 个 agent 目录 · 错误 ${ERR} · 警告 ${WARN}"
if [ "${ERR}" -gt 0 ]; then
  echo "  ❌ 存在兼容性问题。"
  exit 1
elif [ "${TOTAL}" -eq 0 ]; then
  echo "  ⓘ 未发现已安装的 agent 目录 → 先跑 bash install.sh"
  exit 0
else
  echo "  ✅ 全部兼容。"
  exit 0
fi
