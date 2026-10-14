#!/usr/bin/env bash
# ============================================================
# 个人档案体检 (doctor)：把 personal-archive 协议里的「硬要求」变成可校验的检查。
#
# 用法:
#   bash scripts/doctor.sh                 # 检查仓库内模板档案
#   bash scripts/doctor.sh <档案目录>       # 检查指定档案（如你的真档案）
#   bash scripts/doctor.sh <目录> --strict  # 警告也视为失败（适合 CI）
#
# 退出码: 0=通过(可含警告)  1=发现错误  2=用法/路径错误
#
# 检查项:
#   A 目录体例   顶层总索引与板块目录是否齐备（板块动态识别，不限定名称）
#   B frontmatter 是否闭合、必填字段（title/type/created/updated）、推荐字段（tags/status）
#   C 体例一致   同板块内编号风格是否混用（NN- 前缀 vs 无前缀）
#   D 正文禁令   是否出现机器绝对路径（错误）
#   E 脱敏       是否残留证件号、银行卡号（错误）与完整手机号（警告）
#   F 索引一致   板块下的篇目是否都挂进了总索引
#   G 版本       SKILL.md 的 version 字段
# ============================================================
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
STRICT=0
ARCH=""

for a in "$@"; do
  case "$a" in
    --strict) STRICT=1 ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    -*) echo "✗ 未知参数: $a" >&2; exit 2 ;;
    *) [ -z "${ARCH}" ] && ARCH="$a" || { echo "✗ 多余参数: $a" >&2; exit 2; } ;;
  esac
done

if [ -z "${ARCH}" ]; then
  ARCH="${HERE}/personal-archive/archive"
else
  case "${ARCH}" in "~"*) ARCH="${HOME}${ARCH#\~}" ;; esac
fi
ARCH="${ARCH%/}"

if [ ! -d "${ARCH}" ]; then
  echo "✗ 档案目录不存在: ${ARCH}" >&2
  echo "  用法: bash scripts/doctor.sh [档案目录]" >&2
  exit 2
fi

# 板块动态识别：顶层普通目录（排除隐藏目录），不限定命名 → 新增板块无需改脚本
SECTIONS=""
while IFS= read -r d; do
  [ -n "$d" ] && SECTIONS="${SECTIONS}$(basename "$d") "
done < <(find "${ARCH}" -mindepth 1 -maxdepth 1 -type d ! -name '.*' | sort)
SECTIONS="${SECTIONS% }"

# 总索引：兼容新旧命名（无编号体例用 总索引.md，历史编号体例用 00-总索引.md）
IDX=""
for cand in "${ARCH}/总索引.md" "${ARCH}/00-总索引.md"; do
  [ -f "${cand}" ] && IDX="${cand}" && break
done

TYPE_ENUM="rule index profile log decision economics finance"
STATUS_ENUM="生效中 已作废 草稿"
ABS_RE='[/]Users[/][A-Za-z0-9_.-]+|[/]home[/][A-Za-z0-9_.-]+|[Cc]:[\\/]Users[\\/]'

ERR=0; WARN=0
err(){  echo "    ✗ $1"; ERR=$((ERR+1)); }
warn(){ echo "    ⚠️  $1"; WARN=$((WARN+1)); }
ok(){   echo "  ✓ $1"; }
info(){ echo "    · $1"; }

echo "══ 个人档案 · 体检 ══"
echo "档案位置: ${ARCH}"
echo ""

fm_closed(){
  awk '
    NR==1 { if ($0 !~ /^---[[:space:]]*$/) { print "noopen"; bad=1; exit } }
    { if ($0 ~ /^---[[:space:]]*$/) n++ }
    END { if (!bad) { if (n>=2) print "closed"; else print "unclosed" } }
  ' "$1"
}
fm_get(){
  awk -v k="$2" '
    NR==1 && $0 !~ /^---[[:space:]]*$/ { exit }
    NR>1 && $0 ~ /^---[[:space:]]*$/ { exit }
    NR>1 { if (index($0, k ":") == 1) { v=$0; sub(/^[^:]*:[[:space:]]*/, "", v); gsub(/[[:space:]]+$/, "", v); print v; exit } }
  ' "$1"
}

# 收集篇目（排除隐藏文件与 README）
DOCS=""
while IFS= read -r f; do [ -n "$f" ] && DOCS="${DOCS}${f}\n"; done \
  < <(find "${ARCH}" -type f -name '*.md' ! -name '.*' ! -name 'README.md' | sort)
DOCS="$(printf '%b' "${DOCS}")"

# ---------- A. 目录体例 ----------
echo "[A] 目录体例"
if [ -n "${IDX}" ]; then
  ok "总索引就位（$(basename "${IDX}")）"
else
  err "缺少总索引（总索引.md 或 00-总索引.md，档案的入口）"
fi
if [ -z "${SECTIONS}" ]; then
  warn "未发现任何顶层板块目录（档案尚未建立板块体例）"
else
  for s in ${SECTIONS}; do
    if [ -d "${ARCH}/${s}" ]; then
      n=$(find "${ARCH}/${s}" -maxdepth 1 -type f -name '*.md' ! -name '.*' 2>/dev/null | wc -l | tr -d ' ')
      ok "板块 ${s} 就位（${n} 篇）"
    else
      warn "板块目录 ${s}/ 不可读"
    fi
  done
fi
STRAY=$(find "${ARCH}" -maxdepth 2 -type f \( -name 'tmp*' -o -name '*.tmp' -o -name '*~' -o -name '*.bak' \) 2>/dev/null | head -5)
if [ -n "${STRAY}" ]; then
  while IFS= read -r f; do [ -n "$f" ] && warn "残留/临时文件: ${f#${ARCH}/}"; done <<< "${STRAY}"
else
  ok "无临时/残留文件"
fi
echo ""

# ---------- B. frontmatter ----------
echo "[B] frontmatter"
NFM=0
if [ -n "${DOCS}" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    rel="${f#${ARCH}/}"
    case "$(basename "$f")" in .*) continue ;; esac
    if [ "$(fm_closed "$f")" != "closed" ]; then
      err "${rel}: frontmatter 未闭合或缺失（首行须为 --- 且成对出现）"; NFM=$((NFM+1)); continue
    fi
    miss=""
    for k in title type created updated; do
      [ -z "$(fm_get "$f" "$k")" ] && miss="${miss}${k} "
    done
    if [ -n "${miss}" ]; then
      err "${rel}: 缺必填字段 → ${miss}"; NFM=$((NFM+1)); continue
    fi
    for k in tags status; do
      if [ -z "$(fm_get "$f" "$k")" ]; then
        warn "${rel}: 建议补 ${k}（不是必填，但便于检索与判定时效）"
      fi
    done
    ty="$(fm_get "$f" type)"
    case " ${TYPE_ENUM} " in *" ${ty} "*) : ;; *) warn "${rel}: type=${ty} 不在常用枚举内（${TYPE_ENUM}）";; esac
    st="$(fm_get "$f" status)"
    if [ -n "${st}" ]; then
      case " ${STATUS_ENUM} " in *" ${st} "*) : ;; *) warn "${rel}: status=${st} 不在枚举内（${STATUS_ENUM}）";; esac
    fi
    cr="$(fm_get "$f" created)"; up="$(fm_get "$f" updated)"
    if [ -n "${up}" ] && [ -n "${cr}" ] && [ "${up}" \< "${cr}" ]; then
      warn "${rel}: updated(${up}) 早于 created(${cr})"
    fi
  done <<< "${DOCS}"
fi
[ "${NFM}" -eq 0 ] && ok "所有篇目 frontmatter 合规"
echo ""

# ---------- C. 体例一致 ----------
echo "[C] 体例一致（编号风格是否混用）"
BADNUM=0
for s in ${SECTIONS}; do
  [ -d "${ARCH}/${s}" ] || continue
  with=0; without=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    b="$(basename "$f")"
    case "${b}" in [0-9][0-9]-*) with=$((with+1)) ;; *) without=$((without+1)) ;; esac
  done < <(find "${ARCH}/${s}" -maxdepth 1 -type f -name '*.md' ! -name '.*' | sort)
  if [ "${with}" -gt 0 ] && [ "${without}" -gt 0 ]; then
    warn "${s}: 编号风格混用（${with} 篇带 NN- 前缀 / ${without} 篇不带）→ 统一为一种"
    BADNUM=$((BADNUM+1))
  elif [ "${with}" -gt 0 ]; then
    ok "${s}: 统一 NN- 编号前缀（${with} 篇）"
  else
    ok "${s}: 统一无编号前缀（${without} 篇）"
  fi
done
[ "${BADNUM}" -eq 0 ] && ok "各板块编号风格一致"
echo ""

# ---------- D. 正文禁令 ----------
echo "[D] 正文禁令（机器绝对路径）"
DABS=0
if [ -n "${DOCS}" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    rel="${f#${ARCH}/}"
    if grep -Eq "${ABS_RE}" "$f"; then
      err "${rel}: 出现机器绝对路径 → 改用相对路径或「日期+主题」"
      DABS=$((DABS+1))
    fi
  done <<< "${DOCS}"
fi
[ "${DABS}" -eq 0 ] && ok "无机器绝对路径"
echo ""

# ---------- E. 脱敏 ----------
echo "[E] 脱敏（可识别身份字段）"
PID=0
if [ -n "${DOCS}" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    rel="${f#${ARCH}/}"
    if grep -Eq '[0-9]{17}[0-9Xx]' "$f"; then
      err "${rel}: 疑似证件号（18 位）→ 只留尾号或标签"; PID=$((PID+1))
    fi
    if grep -Eq '[0-9]{16,19}' "$f"; then
      err "${rel}: 疑似银行卡号（16–19 位连号）→ 只留尾号"; PID=$((PID+1))
    fi
    if grep -Eq '(^|[^0-9])1[3-9][0-9]{9}([^0-9]|$)' "$f"; then
      warn "${rel}: 疑似完整手机号（11 位）→ 只留尾号"; PID=$((PID+1))
    fi
  done <<< "${DOCS}"
fi
[ "${PID}" -eq 0 ] && ok "未残留可识别身份字段"
echo ""

# ---------- F. 索引一致性 ----------
echo "[F] 索引一致（篇目是否挂进总索引）"
MISS=0
if [ -z "${IDX}" ]; then
  err "无总索引，无法校验索引一致性"
else
  for s in ${SECTIONS}; do
    [ -d "${ARCH}/${s}" ] || continue
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      b="$(basename "$f" .md)"
      if ! grep -qF "${b}" "${IDX}"; then
        warn "${s}/${b}.md 未挂进总索引"
        MISS=$((MISS+1))
      fi
    done < <(find "${ARCH}/${s}" -maxdepth 1 -type f -name '*.md' ! -name '.*' | sort)
  done
fi
[ "${MISS}" -eq 0 ] && ok "板块篇目均已挂索引"
echo ""

# ---------- G. 版本 ----------
echo "[G] 协议版本"
if [ -f "${HERE}/personal-archive/SKILL.md" ]; then
  V="$(sed -n 's/^version:[[:space:]]*//p' "${HERE}/personal-archive/SKILL.md" | head -1)"
  if [ -n "${V}" ]; then ok "SKILL.md version=${V}"; else warn "SKILL.md 缺 version 字段"; fi
else
  info "本机无仓库内的 SKILL.md（仅装到 agent 目录时正常）"
fi
echo ""

echo "══ 汇总 ══"
echo "  错误 ${ERR} · 警告 ${WARN}"
if [ "${ERR}" -gt 0 ]; then
  echo "  ❌ 存在错误，请修正后重跑。"
  exit 1
elif [ "${WARN}" -gt 0 ] && [ "${STRICT}" -eq 1 ]; then
  echo "  ❌ --strict 模式下警告视为失败。"
  exit 1
elif [ "${WARN}" -gt 0 ]; then
  echo "  ⚠️  仅警告，不阻塞（加 --strict 可让警告也失败）。"
  exit 0
else
  echo "  ✅ 全部通过。"
  exit 0
fi
