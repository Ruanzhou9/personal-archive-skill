# ============================================================
# Personal Archive · 一键安装脚本 (Windows / PowerShell)
#
# 默认行为：自动发现本机所有 agent 的技能目录（已知约定目录 + $HOME\*\skills、
#           $HOME\.*\skills、$HOME\.config\*\skills），把技能装到每一个，
#           让所有 agent 使用同一套个人档案读写规范。
#
# 用法:
#   powershell -ExecutionPolicy Bypass -File install.ps1
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Update
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Update -LinkArchive "D:\path\to\个人档案"
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Only claude,codex
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Target <技能父目录>
#   powershell -ExecutionPolicy Bypass -File install.ps1 -DryRun
# ============================================================
param(
  [string]$Only = "",
  [string]$Target = "",
  [string]$LinkArchive = "",
  [switch]$Update,
  [switch]$DryRun,
  [switch]$Force,
  [switch]$Yes
)

$ErrorActionPreference = "Stop"
$Dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Src = Join-Path $Dir "personal-archive"
$SkillName = "personal-archive"

if (-not (Test-Path (Join-Path $Src "SKILL.md"))) {
  Write-Host "X 未找到 $Src\SKILL.md，请在仓库根目录运行本脚本。" -ForegroundColor Red
  exit 1
}

if ($LinkArchive -ne "") {
  $LinkArchive = $LinkArchive.TrimEnd('\')
  if (-not (Test-Path $LinkArchive -PathType Container)) {
    Write-Host "X -LinkArchive 指向的目录不存在: $LinkArchive" -ForegroundColor Red
    exit 1
  }
  # 档案根目录识别兼容新旧体例：总索引叫 总索引.md（现行）或 00-总索引.md（历史编号体例）
  $IdxNew = Join-Path $LinkArchive "总索引.md"
  $IdxOld = Join-Path $LinkArchive "00-总索引.md"
  if (-not ((Test-Path $IdxNew) -or (Test-Path $IdxOld))) {
    Write-Host "X $LinkArchive 里没有 总索引.md（或 00-总索引.md）—— 这看起来不是一个个人档案，拒绝链接。" -ForegroundColor Red
    Write-Host "  正确的档案根目录应直接包含总索引与若干板块目录，如 画像\ 日志\ 规范\ 决策\"
    exit 1
  }
}

$Known = @(
  @{ N = "claude";    P = (Join-Path $HOME ".claude\skills");                    A = (Join-Path $HOME ".claude") },
  @{ N = "codex";     P = (Join-Path $HOME ".codex\skills");                     A = (Join-Path $HOME ".codex") },
  @{ N = "hermes";    P = (Join-Path $HOME ".hermes\skills");                    A = (Join-Path $HOME ".hermes") },
  @{ N = "openclaw";  P = (Join-Path $HOME ".openclaw\skills");                  A = (Join-Path $HOME ".openclaw") },
  @{ N = "opencode";  P = (Join-Path $HOME ".config\opencode\skills");           A = (Join-Path $HOME ".config\opencode") },
  @{ N = "workbuddy"; P = (Join-Path $HOME ".workbuddy\skills");                 A = (Join-Path $HOME ".workbuddy") },
  @{ N = "copilot";   P = (Join-Path $HOME ".copilot\skills");                   A = (Join-Path $HOME ".copilot") },
  @{ N = "dsh";       P = (Join-Path $HOME ".dsh\skills");                       A = (Join-Path $HOME ".dsh") },
  @{ N = "agents";    P = (Join-Path $HOME ".agents\skills");                    A = (Join-Path $HOME ".agents") }
)

$Parents = New-Object System.Collections.ArrayList
$Names = New-Object System.Collections.ArrayList

function Add-Parent([string]$p, [string]$n) {
  foreach ($x in $Parents) { if ($x -eq $p) { return } }
  [void]$Parents.Add($p)
  [void]$Names.Add($n)
}

function Test-Only([string]$name, [string]$path) {
  if ($Only -eq "") { return $true }
  foreach ($t in $Only.Split(",")) {
    if ($name -eq $t) { return $true }
    if ($path -like "*$t*") { return $true }
  }
  return $false
}

if ($Target -ne "") {
  Add-Parent $Target "custom"
} else {
  foreach ($k in $Known) {
    if (-not (Test-Only $k.N $k.P)) { continue }
    if (Test-Path $k.P) { Add-Parent $k.P $k.N }
    elseif (Test-Path $k.A) {
      if ($k.N -eq "dsh" -or $k.N -eq "agents") {
        Write-Host "  i  [$($k.N)] 未发现 $($k.P)（该 agent 是否读取此目录未经验证）-> 不创建，跳过"
      } else {
        Add-Parent $k.P $k.N
      }
    }
  }
  $patterns = @("$HOME\*\skills", "$HOME\.*\skills", "$HOME\.config\*\skills")
  foreach ($pat in $patterns) {
    Get-Item $pat -ErrorAction SilentlyContinue | ForEach-Object {
      if (-not $_.PSIsContainer) { return }
      $p = $_.FullName
      if ($p -match '\\\.(Trash|cache|npm|local|git|vscode)\\|\\\.Spotlight-V100\\') { return }
      $name = (Split-Path -Parent $p | Split-Path -Leaf).TrimStart(".")
      if (-not (Test-Only $name $p)) { return }
      Add-Parent $p $name
    }
  }
}

if ($Parents.Count -eq 0) {
  Write-Host "! 未发现任何 agent 技能目录。" -ForegroundColor Yellow
  if (-not $Yes) {
    Write-Host "  重跑时加 -Yes 可仍装入 $HOME\skills，但你的 agent 未必会读取该目录。"
    exit 1
  }
  Add-Parent (Join-Path $HOME "skills") "fallback"
}

Write-Host "源目录 : $Src"
Write-Host "目标数 : $($Parents.Count)"
Write-Host ""

$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$Ok = 0; $Skip = 0; $Warn = 0
$Installed = New-Object System.Collections.ArrayList

for ($i = 0; $i -lt $Parents.Count; $i++) {
  $parent = $Parents[$i]; $name = $Names[$i]
  $dest = Join-Path $parent $SkillName

  $variants = @(Get-ChildItem -Path (Join-Path $parent "$SkillName*") -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -ne $dest })
  if ($variants.Count -gt 0 -and -not $Force) {
    Write-Host "  ! [$name] 该目录已有同源变体: $($variants.Name -join ' ')" -ForegroundColor Yellow
    $Warn++; $Skip++; continue
  }

  $item = Get-Item $dest -Force -ErrorAction SilentlyContinue
  if ($item -and $item.LinkType) {
    Write-Host "  X [$name] 该技能是链接 -> $($item.Target)  -> 跳过且不覆盖" -ForegroundColor Red
    $Skip++; continue
  }

  if ($DryRun) {
    if (-not (Test-Path $dest)) { Write-Host "  [dry-run] [$name] -> 新增 $dest" }
    elseif (-not (Test-Path (Join-Path $dest "SKILL.md"))) { Write-Host "  [dry-run] [$name] -> 补装 $dest" }
    elseif ($Update) { Write-Host "  [dry-run] [$name] -> 更新协议（保留 archive\）$dest" }
    else { Write-Host "  [dry-run] [$name] -> 已存在，将跳过 $dest" }
    if ($LinkArchive -ne "") { Write-Host "             -> 并把 archive\ 链到 $LinkArchive" }
    continue
  }

  if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }

  if (Test-Path (Join-Path $dest "SKILL.md")) {
    if ($Update) {
      New-Item -ItemType Directory -Force -Path (Join-Path $dest ".backups") | Out-Null
      Copy-Item (Join-Path $dest "SKILL.md") (Join-Path $dest ".backups\SKILL.md.$Stamp") -Force
      Copy-Item (Join-Path $Src "SKILL.md") (Join-Path $dest "SKILL.md") -Force
      Write-Host "  + [$name] 已更新协议（保留 archive\）" -ForegroundColor Green
      $Ok++; [void]$Installed.Add($parent)
    } else {
      Write-Host "  - [$name] 已存在，跳过（加 -Update 可只更新协议）"
      $Skip++
    }
  } else {
    if (Test-Path $dest) { Copy-Item (Join-Path $Src "*") $dest -Recurse -Force }
    else { Copy-Item $Src $dest -Recurse -Force }
    Write-Host "  + [$name] 已安装到 $dest" -ForegroundColor Green
    $Ok++; [void]$Installed.Add($parent)
  }
}

if ($DryRun) { Write-Host ""; Write-Host "[dry-run] 结束，未做任何修改。"; exit 0 }

if ($LinkArchive -ne "") {
  Write-Host ""
  Write-Host "-- 统一 ArchiveRoot（-LinkArchive）--"
  foreach ($p in $Installed) {
    $dest = Join-Path $p $SkillName
    $m = Join-Path $dest "archive"
    $label = Split-Path -Leaf $p
    $item = Get-Item $m -Force -ErrorAction SilentlyContinue
    if ($item -and $item.LinkType) {
      if ($item.Target -eq $LinkArchive) { Write-Host "  - [$label] archive 已指向该档案，无需改动" }
      else { Write-Host "  ! [$label] archive 已是链接 -> $($item.Target)（不覆盖）" -ForegroundColor Yellow }
      continue
    }
    if (Test-Path $m) {
      New-Item -ItemType Directory -Force -Path (Join-Path $dest ".backups") | Out-Null
      Move-Item $m (Join-Path $dest ".backups\archive-template-$Stamp") -Force
      Write-Host "  > [$label] 原 archive\ 模板已移入 .backups\"
    }
    New-Item -ItemType Junction -Path $m -Target $LinkArchive | Out-Null
    Write-Host "  + [$label] archive -> $LinkArchive" -ForegroundColor Green
  }
}

Write-Host ""
Write-Host "完成（安装/更新 $Ok 处；跳过 $Skip 处，含同源变体告警 $Warn 处）。下一步："
Write-Host "  1) 体检你的档案：powershell -File scripts\doctor.ps1 <档案路径>   （或用 Git-Bash 跑 doctor.sh）"
Write-Host "  2) 兼容性核对：  bash scripts/compat-check.sh"
Write-Host "  3) 各 agent 新开一个会话，问它「是否加载了 personal-archive」"
