<#
.SYNOPSIS
    一键发布 sing-box libbox SDK（GitHub Releases + JitPack）

.DESCRIPTION
    完整执行发布流程，每步都有校验，失败即停：
      1. 前置校验（aar 就绪、gh 可用、同名 release 不存在）
      2. 对齐 build.gradle 的 version 与 -Version（幂等替换）
      3. 提交（简体中文惯例消息）并推送 main
      4. 创建 draft release 并上传 libbox.aar，核对资产字节数
      5. 发布 release（GitHub 以 main HEAD 建同名 tag）
      6. 触发并等待 JitPack 构建（容忍 tagNotFound/none 中间态，15 分钟超时）
      7. 核验 JitPack 产物字节数与本地一致

    版本号只在 -Version 参数出现一次，杜绝复制命令忘改版本号的笔误。

.EXAMPLE
    ./publish.ps1 -Version 1.14.5
#>
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version
)

$ErrorActionPreference = 'Stop'
$Repo    = 'singbox-android/libbox'
$Group   = 'com.github.singbox-android'
$Root    = $PSScriptRoot
$AarPath = Join-Path $Root 'libbox.aar'
$Gradle  = Join-Path $Root 'build.gradle'

function Write-Step([string]$Message) { Write-Host "`n=== $Message ===" -ForegroundColor Cyan }
function Write-Ok([string]$Message)   { Write-Host "  [OK] $Message" -ForegroundColor Green }
function Write-Info([string]$Message) { Write-Host "  $Message" -ForegroundColor DarkGray }

# ── 0. 定位 gh CLI（安装后旧终端 PATH 可能未刷新，回退到默认安装路径）──
$gh = (Get-Command gh -ErrorAction SilentlyContinue).Source
if (-not $gh) { $gh = 'C:\Program Files\GitHub CLI\gh.exe' }
if (-not (Test-Path $gh)) { throw '未找到 gh CLI，请先安装并登录：winget install --id GitHub.cli; gh auth login' }

# ── 1. 前置校验 ──
Write-Step "步骤 1/7 前置校验"

if (-not (Test-Path $AarPath)) { throw "缺少 $AarPath —— 请先把新版 aar 放到仓库根目录" }
$AarSize = (Get-Item $AarPath).Length
Write-Ok "libbox.aar 就绪（$AarSize 字节）"

& $gh auth status *> $null
if ($LASTEXITCODE -ne 0) { throw 'gh CLI 未登录，请先执行: gh auth login' }
Write-Ok 'gh CLI 已登录'

& $gh release view $Version --repo $Repo *> $null
if ($LASTEXITCODE -eq 0) {
    throw "release $Version 已存在，拒绝重复发布。若是误发布需清理，请手动执行: gh release delete $Version --repo $Repo --cleanup-tag --yes"
}
Write-Ok "release $Version 不存在，可以发布"

# 远程已有同名 tag 也会导致发布时撞车
$remoteTag = git -C $Root ls-remote --tags origin "refs/tags/$Version"
if ($remoteTag) { throw "远程已存在 tag $Version（但没有对应 release），请先人工排查" }
Write-Ok "远程无同名 tag"

# ── 2. 对齐版本号 ──
Write-Step "步骤 2/7 对齐 build.gradle 版本号为 $Version"

$content = [IO.File]::ReadAllText($Gradle)
if ($content -match "(?m)^version = '[^']*'$") {
    $content = $content -replace "(?m)^version = '[^']*'$", "version = '$Version'"
    # UTF-8 无 BOM 写回，与 Gradle 文件惯例一致
    [IO.File]::WriteAllText($Gradle, $content, [Text.UTF8Encoding]::new($false))
    Write-Ok "version = '$Version'"
} else {
    throw "build.gradle 中找不到 version = '...' 形式的行，请人工确认"
}

# ── 3. 提交并推送 main ──
Write-Step '步骤 3/7 提交并推送 main'

# 只添加发布相关文件，绝不 git add -A（工作区常有本地配置文件）
git -C $Root add build.gradle libbox-sources.jar
git -C $Root diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
    git -C $Root commit -m "chore(build): sing-box sdk 升级到 $Version"
    if ($LASTEXITCODE -ne 0) { throw 'git commit 失败' }
    Write-Ok "已提交: chore(build): sing-box sdk 升级到 $Version"
} else {
    Write-Info '无待提交改动（build.gradle 已是该版本），跳过提交'
}

git -C $Root push origin main
if ($LASTEXITCODE -ne 0) { throw 'git push 失败' }
$Head = (git -C $Root rev-parse HEAD).Trim()
Write-Ok "已推送 main，HEAD = $Head"

# ── 4. 创建 draft release 并上传 aar ──
Write-Step "步骤 4/7 上传 libbox.aar 到 draft release $Version（约 1~2 分钟）"

& $gh release create $Version $AarPath --repo $Repo --draft --title $Version --notes "sing-box sdk $Version"
if ($LASTEXITCODE -ne 0) { throw 'gh release create 失败' }

$asset = & $gh release view $Version --repo $Repo --json assets --jq '.assets[] | select(.name == "libbox.aar") | .size'
if ([int64]$asset -ne $AarSize) { throw "资产字节数不一致: GitHub=$asset 本地=$AarSize" }
Write-Ok "资产上传成功，字节数一致（$AarSize）"

# ── 5. 发布 release（GitHub 以 main HEAD 建同名 tag）──
Write-Step "步骤 5/7 发布 release $Version"

& $gh release edit $Version --repo $Repo --draft=false
if ($LASTEXITCODE -ne 0) { throw 'gh release edit 失败' }

$tagSha = ((git -C $Root ls-remote --tags origin "refs/tags/$Version") -split "`t")[0]
if ($tagSha -ne $Head) { throw "tag 指向异常: tag=$tagSha HEAD=$Head（发布早于推送？请人工排查）" }
Write-Ok "tag $Version -> $Head"

# ── 6. 等待 JitPack 构建 ──
Write-Step '步骤 6/7 等待 JitPack 构建（惰性触发，一般 3~15 分钟）'

# 首次请求该版本以触发构建（JitPack 为惰性构建）
Invoke-WebRequest -Uri "https://jitpack.io/$Group/libbox/$Version/" -UseBasicParsing -TimeoutSec 60 *> $null

$deadline = (Get-Date).AddMinutes(15)
while ($true) {
    try { $build = Invoke-RestMethod -Uri "https://jitpack.io/api/builds/$Group/libbox/$Version" -TimeoutSec 60 }
    catch { Start-Sleep -Seconds 30; continue }   # 瞬时网络抖动，重试

    if ($build.status -eq 'ok')    { break }
    if ($build.status -eq 'error') { throw "JitPack 构建失败，日志: https://jitpack.io/$Group/libbox/$Version" }
    if ((Get-Date) -gt $deadline)  { throw '等待 JitPack 构建超时（15 分钟），请稍后手动查询该 API' }

    Write-Info "JitPack 状态: $($build.status)，30 秒后重试..."
    Start-Sleep -Seconds 30
}
Write-Ok 'JitPack 构建成功'

# ── 7. 核验 JitPack 产物 ──
Write-Step '步骤 7/7 核验 JitPack 产物'

$AarUrl = "https://jitpack.io/$Group/libbox/$Version/libbox-$Version.aar"
$headers = & curl.exe -sIL --max-time 90 $AarUrl
$lenLine = $headers | Select-String -Pattern '^[Cc]ontent-[Ll]ength:\s*(\d+)' | Select-Object -Last 1
if (-not $lenLine) { throw "无法从响应头取得 Content-Length，请人工核验: $AarUrl" }
$remoteLen = [int64]$lenLine.Matches[0].Groups[1].Value
if ($remoteLen -ne $AarSize) { throw "产物字节数不一致: JitPack=$remoteLen 本地=$AarSize" }
Write-Ok "产物字节数一致（$AarSize）"

Write-Host ''
Write-Host '================================================================' -ForegroundColor Green
Write-Host '发布完成！' -ForegroundColor Green
Write-Host "  下游坐标: implementation '$Group:libbox:$Version'" -ForegroundColor Green
Write-Host '================================================================' -ForegroundColor Green
