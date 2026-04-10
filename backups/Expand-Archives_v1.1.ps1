<#
.SYNOPSIS
    批量解压指定目录下的压缩包并删除源包
.DESCRIPTION
    输入一个目录路径，脚本会扫描该目录下的压缩包并解压到同名文件夹，
    解压成功后自动删除对应的压缩包。默认支持 ZIP；若检测到 7-Zip (7z)，
    还将支持 .7z 和 .rar。
.PARAMETER Path
    需要处理的目录的绝对路径。如果未提供，脚本将交互式询问。
.EXAMPLE
    .\Expand-Archives.ps1 -Path "D:\Downloads"
#>

param (
    [Parameter(Mandatory = $false)]
    [string]$Path
)

# 控制台编码
chcp 65001 | Out-Null

$COLOR_INFO = "Cyan"
$COLOR_SUCCESS = "Green"
$COLOR_WARN = "Yellow"
$COLOR_ERR = "Red"
$COLOR_TITLE = "Yellow"

Write-Host "`n=====================================" -ForegroundColor $COLOR_TITLE
Write-Host "📦 批量解压与清理工具" -ForegroundColor $COLOR_TITLE
Write-Host "=====================================" -ForegroundColor $COLOR_TITLE
Write-Host "🔧 核心功能：" -ForegroundColor $COLOR_INFO
Write-Host "  1. 扫描目录下的压缩包并解压到同名文件夹" -ForegroundColor $COLOR_INFO
Write-Host "  2. 解压成功后自动删除源压缩包" -ForegroundColor $COLOR_INFO
Write-Host "  3. 支持 ZIP；如检测到 7-Zip 则支持 7Z/RAR" -ForegroundColor $COLOR_INFO
Write-Host "⚙️  运行依赖：" -ForegroundColor $COLOR_INFO
Write-Host "  - 必需：PowerShell 5.1 (内置 Expand-Archive，仅支持 ZIP)" -ForegroundColor $COLOR_INFO
Write-Host "  - 可选：7-Zip (7z.exe) 以支持 .7z/.rar" -ForegroundColor $COLOR_INFO
Write-Host "=====================================`n" -ForegroundColor $COLOR_TITLE

do {
    if ([string]::IsNullOrWhiteSpace($Path)) {
        $targetPath = Read-Host "请输入需要处理的目录绝对路径"
    } else {
        $targetPath = $Path
        $Path = $null
    }

    if (-not (Test-Path -LiteralPath $targetPath)) {
        Write-Host "❌ 路径不存在：$targetPath" -ForegroundColor $COLOR_ERR
        $retry = Read-Host "是否重新输入路径？(Y/N，默认Y)"
        if ($retry.Trim().ToLower() -eq "n") { break }
        continue
    }

    $has7z = $false
    $sevenZip = Get-Command 7z -ErrorAction SilentlyContinue
    if ($sevenZip) { $has7z = $true }

    $recurseChoice = Read-Host "是否递归子目录？(Y/N，默认N)"
    $recurse = ($recurseChoice.Trim().ToLower() -eq "y")

    $searchOption = if ($recurse) { '-Recurse' } else { $null }

    if ($has7z) {
        $archives = Get-ChildItem -LiteralPath $targetPath -File @($searchOption) | Where-Object {
            $_.Extension -in ".zip", ".7z", ".rar"
        }
    } else {
        # 无 7-Zip 时仅处理 ZIP，同时提示存在但无法处理的 RAR/7Z
        $archives = Get-ChildItem -LiteralPath $targetPath -File @($searchOption) | Where-Object {
            $_.Extension -eq ".zip"
        }
        $compressedButUnsupported = Get-ChildItem -LiteralPath $targetPath -File @($searchOption) | Where-Object {
            $_.Extension -in ".rar", ".7z"
        }
        if ($compressedButUnsupported) {
            Write-Host "⚠️ 检测到 .rar/.7z 文件但未找到 7-Zip (7z.exe)，将跳过这些文件。" -ForegroundColor $COLOR_WARN
            Write-Host "   如需处理 .rar/.7z，请安装 7-Zip 并确保 7z.exe 在 PATH 中可用。" -ForegroundColor $COLOR_WARN
        }
    }

    if (-not $archives -or $archives.Count -eq 0) {
        Write-Host "⚠️ 未找到可处理的压缩包。" -ForegroundColor $COLOR_WARN
    } else {
        Write-Host "`n找到 $($archives.Count) 个压缩包，开始处理..." -ForegroundColor $COLOR_INFO
        $ok = 0; $fail = 0
        foreach ($arc in $archives) {
            $dest = Join-Path -Path $arc.DirectoryName -ChildPath ([System.IO.Path]::GetFileNameWithoutExtension($arc.Name))
            if (-not (Test-Path -LiteralPath $dest)) {
                New-Item -ItemType Directory -Path $dest -Force | Out-Null
            }
            try {
                if ($has7z -and ($arc.Extension -in ".7z", ".rar")) {
                    & $sevenZip.Source x $arc.FullName ("-o{0}" -f $dest) -y | Out-Null
                    if ($LASTEXITCODE -ne 0) { throw "7z 解压失败，代码 $LASTEXITCODE" }
                } elseif ($has7z -and $arc.Extension -eq ".zip") {
                    & $sevenZip.Source x $arc.FullName ("-o{0}" -f $dest) -y | Out-Null
                    if ($LASTEXITCODE -ne 0) { throw "7z 解压失败，代码 $LASTEXITCODE" }
                } else {
                    Expand-Archive -LiteralPath $arc.FullName -DestinationPath $dest -Force
                }

                # 删除源压缩包
                Remove-Item -LiteralPath $arc.FullName -Force
                Write-Host "✅ 已解压并删除：$($arc.Name)" -ForegroundColor $COLOR_SUCCESS
                $ok++
            } catch {
                Write-Host "❌ 处理失败：$($arc.Name) -> $_" -ForegroundColor $COLOR_ERR
                $fail++
            }
        }
        Write-Host "`n完成：成功 $ok 个，失败 $fail 个。" -ForegroundColor $COLOR_INFO
    }

    $continueChoice = Read-Host "`n是否继续处理新的路径？(Y/N，默认Y)"
} while ($continueChoice.Trim().ToLower() -ne "n")

Write-Host "`n任务结束，感谢使用！" -ForegroundColor $COLOR_SUCCESS

