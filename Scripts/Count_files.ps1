<#
.SYNOPSIS
    递归统计指定文件夹下指定类型文件的数量，支持多类型选择。
.DESCRIPTION
    该脚本允许用户指定一类或多类文档类型（如 pdf, doc, img, ppt 等）进行统计。
    支持自定义扩展名输入，并支持循环统计新路径。
    支持预设的简写类型：pdf, doc, ppt, xls, img, zip, txt。
#>

# 解决PowerShell中文乱码问题
chcp 65001 | Out-Null

# 定义颜色常量
$COLOR_INFO = "Cyan"
$COLOR_SUCCESS = "Green"
$COLOR_ERROR = "Red"
$COLOR_TITLE = "Yellow"

# 定义预设的类型映射（支持简写）
$TypeMap = @{
    "pdf" = @(".pdf")
    "doc" = @(".doc", ".docx")
    "ppt" = @(".ppt", ".pptx")
    "xls" = @(".xls", ".xlsx")
    "img" = @(".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp")
    "zip" = @(".zip", ".7z", ".rar", ".tar", ".gz")
    "txt" = @(".txt", ".md")
}

do {
    Clear-Host
    # ===================== 脚本启动：打印核心功能说明 ======================
    Write-Host "=====================================" -ForegroundColor $COLOR_TITLE
    Write-Host "📊 多功能文件统计脚本 (v4.1)" -ForegroundColor $COLOR_TITLE
    Write-Host "=====================================" -ForegroundColor $COLOR_TITLE
    Write-Host "🔧 核心功能：" -ForegroundColor $COLOR_INFO
    Write-Host "  1. 智能分类统计：内置 PDF、Office 文档、图片、压缩包等常见类型映射" -ForegroundColor $COLOR_INFO
    Write-Host "  2. 自定义扩展名：支持用户输入任意扩展名进行精准统计" -ForegroundColor $COLOR_INFO
    Write-Host "  3. 递归扫描：自动检索指定文件夹及其所有子文件夹中的文件" -ForegroundColor $COLOR_INFO
    Write-Host "  4. 结果可视化：按文件数量降序排列，清晰展示各类型占比" -ForegroundColor $COLOR_INFO
    Write-Host "  5. 持续作业模式：支持循环路径输入，满足大批量处理需求" -ForegroundColor $COLOR_INFO
    Write-Host "⚙️  运行依赖：" -ForegroundColor $COLOR_INFO
    Write-Host "  1. 扫描引擎：Windows PowerShell 原生支持 (Get-ChildItem)" -ForegroundColor $COLOR_INFO
    Write-Host "=====================================`n" -ForegroundColor $COLOR_TITLE
    
    # 1. 获取路径
    $targetPath = Read-Host "请输入需要统计的文件夹绝对路径"
    if ([string]::IsNullOrWhiteSpace($targetPath)) {
        $targetPath = "." # 默认为当前目录
    }

    if (-not (Test-Path -Path $targetPath -PathType Container)) {
        Write-Host "❌ 错误：输入的路径不存在，或不是有效的文件夹！" -ForegroundColor Red
        Read-Host -Prompt "按 Enter 键重新输入"
        continue
    }

    # 2. 获取要统计的类型
    Write-Host "`n可用预设类型: " -NoNewline -ForegroundColor Gray
    # 修复了 v4.0 的 bug: -join 并非 Sort-Object 的参数，应使用括号包裹后再 join
    Write-Host (($TypeMap.Keys | Sort-Object) -join ", ") -ForegroundColor Yellow
    Write-Host "你也可以直接输入扩展名（如 .py, .java）" -ForegroundColor Gray
    
    $inputTypes = Read-Host "请输入要统计的类型（多个请用逗号或空格分隔，直接回车统计所有预设类型）"
    
    # 解析用户输入
    $selectedExtensions = @()
    if ([string]::IsNullOrWhiteSpace($inputTypes)) {
        # 如果用户直接回车，统计所有预设类型
        foreach ($key in $TypeMap.Keys) { $selectedExtensions += $TypeMap[$key] }
    } else {
        # 支持多种分隔符
        $parts = $inputTypes -split "[,，\s]+" | Where-Object { $_ -ne "" }
        foreach ($part in $parts) {
            $p = $part.ToLower().Trim()
            if ($TypeMap.ContainsKey($p)) {
                $selectedExtensions += $TypeMap[$p]
            } else {
                # 如果不是预设，确保带上点号
                if (-not $p.StartsWith(".")) { $p = ".$p" }
                $selectedExtensions += $p
            }
        }
    }
    
    # 去重并排序
    $selectedExtensions = $selectedExtensions | Select-Object -Unique | Sort-Object

    Write-Host "`n🔍 正在扫描 $targetPath ..." -ForegroundColor Cyan

    try {
        # 获取所有文件（过滤掉目录）
        # 使用 -ErrorAction SilentlyContinue 避免因为权限拒绝导致的脚本中断
        $allFiles = Get-ChildItem -Path $targetPath -Recurse -File -ErrorAction SilentlyContinue
        
        $results = @()
        $totalCount = 0

        # 按扩展名统计
        foreach ($ext in $selectedExtensions) {
            # 过滤匹配扩展名的文件
            $count = ($allFiles | Where-Object { $_.Extension -eq $ext }).Count
            if ($count -gt 0) {
                $results += [PSCustomObject]@{
                    Extension = $ext
                    Count     = $count
                }
                $totalCount += $count
            }
        }

        # 输出统计结果
        Write-Host "`n===== 统计结果 =====" -ForegroundColor Cyan
        Write-Host "目标路径 : $targetPath"
        
        if ($results.Count -eq 0) {
            Write-Host "⚠️  未找到任何匹配的文件。" -ForegroundColor Yellow
        } else {
            # 按数量降序排列
            foreach ($res in $results | Sort-Object Count -Descending) {
                Write-Host "  $($res.Extension.PadRight(10)) : " -NoNewline -ForegroundColor White
                Write-Host "$($res.Count)" -ForegroundColor Green
            }
            Write-Host "--------------------" -ForegroundColor Gray
            Write-Host "  总计文件数 : " -NoNewline -ForegroundColor Cyan
            Write-Host "$totalCount" -ForegroundColor Green
        }
        Write-Host "====================`n" -ForegroundColor Cyan
    }
    catch {
        Write-Host "`n❌ 统计过程中发生错误：$($_.Exception.Message)" -ForegroundColor Red
    }

    $continueChoice = Read-Host "是否继续统计新路径？(Y/N，默认Y)"
    $isContinue = ($continueChoice.Trim().ToLower() -ne "n")

} while ($isContinue)

Write-Host "`n脚本执行完毕，感谢使用！" -ForegroundColor Blue
