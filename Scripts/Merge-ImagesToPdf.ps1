<#
.SYNOPSIS
    将指定文件夹下的所有图片按名称字典序合成为一个 PDF 文件。
.DESCRIPTION
    1. 用户输入一个包含图片的绝对路径。
    2. 脚本扫描该路径下的所有图片（jpg, jpeg, png, bmp, webp）。
    3. 按文件名进行字典序排序。
    4. 将所有图片合成为一个 PDF，并以第一张图片的名字命名。
    5. 任务完成后询问是否继续处理其他路径。
.PARAMETER Path
    包含图片的文件夹绝对路径。
.NOTES
    依赖项：需安装 ImageMagick 7+ 并确保 'magick' 命令在系统环境变量中可用。
#>

# 设置编码，解决中文乱码
chcp 65001 | Out-Null
$ErrorActionPreference = "Stop"

# 定义颜色常量
$COLOR_TITLE = "Yellow"
$COLOR_INFO = "Cyan"
$COLOR_SUCCESS = "Green"
$COLOR_ERROR = "Red"

# ===================== 脚本启动：打印核心功能说明 ======================
Write-Host "`n=====================================" -ForegroundColor $COLOR_TITLE
Write-Host "🖼️ 图片字典序合成 PDF 工具" -ForegroundColor $COLOR_TITLE
Write-Host "=====================================" -ForegroundColor $COLOR_TITLE
Write-Host "🔧 核心功能：" -ForegroundColor $COLOR_INFO
Write-Host "  1. 字典序排序：严格按照文件名升序排列图片" -ForegroundColor $COLOR_INFO
Write-Host "  2. 智能命名：自动提取首张图片名称作为 PDF 文件名" -ForegroundColor $COLOR_INFO
Write-Host "  3. 多格式支持：兼容 JPG, JPEG, PNG, BMP, WEBP 格式" -ForegroundColor $COLOR_INFO
Write-Host "  4. 持续作业：支持循环输入路径，处理多个文件夹" -ForegroundColor $COLOR_INFO
Write-Host "⚙️  运行依赖：" -ForegroundColor $COLOR_INFO
Write-Host "  1. 合成引擎：ImageMagick 7+ (需配置系统环境变量)" -ForegroundColor $COLOR_INFO
Write-Host "=====================================`n" -ForegroundColor $COLOR_TITLE

# ===================== 环境检测 =====================
function Test-Environment {
    if (-not (Get-Command -Name magick -ErrorAction SilentlyContinue)) {
        Write-Host "❌ 未检测到 ImageMagick 7+！" -ForegroundColor $COLOR_ERROR
        Write-Host "请安装 ImageMagick 7+ 并将其安装目录添加到系统环境变量 PATH 中。" -ForegroundColor $COLOR_ERROR
        return $false
    }
    return $true
}

# ===================== 核心逻辑 =====================
do {
    if (-not (Test-Environment)) { break }

    # 1. 获取输入路径
    $inputPath = Read-Host -Prompt "请输入包含图片的文件夹绝对路径"
    if ([string]::IsNullOrWhiteSpace($inputPath)) {
        Write-Host "⚠️ 路径不能为空，请重新输入。" -ForegroundColor $COLOR_ERROR
        continue
    }

    $workDir = $inputPath.Trim().Trim('"')
    
    try {
        # 2. 校验路径
        if (-not (Test-Path -Path $workDir -PathType Container)) {
            Write-Host "❌ 路径不存在或不是文件夹: $workDir" -ForegroundColor $COLOR_ERROR
            continue
        }
        $workDir = (Resolve-Path -Path $workDir).Path

        # 3. 扫描图片并排序
        Write-Host "🔍 正在扫描图片..." -ForegroundColor $COLOR_INFO
        $imageExtensions = ".jpg", ".jpeg", ".png", ".bmp", ".webp"
        # 修复：直接使用 Get-ChildItem -Include 可能导致无法匹配目录内文件
        $images = Get-ChildItem -Path $workDir -File | 
            Where-Object { $_.Extension.ToLower() -in $imageExtensions } | 
            Sort-Object Name

        if ($images.Count -eq 0) {
            Write-Host "⚠️ 在路径下未找到支持的图片文件。" -ForegroundColor $COLOR_ERROR
            continue
        }

        Write-Host "✅ 找到 $($images.Count) 张图片。" -ForegroundColor $COLOR_SUCCESS

        # 4. 确定 PDF 名称 (第一张图片的名字)
        $firstImage = $images[0]
        $pdfFileName = "$($firstImage.BaseName).pdf"
        $pdfPath = Join-Path -Path $workDir -ChildPath $pdfFileName

        # 5. 调用 ImageMagick 合成
        Write-Host "🚀 正在合成 PDF: $pdfFileName ..." -ForegroundColor $COLOR_INFO
        
        # 使用图片的完整路径列表
        $imagePaths = $images.FullName
        
        # 执行合成命令
        & magick $imagePaths -compress LZW "$pdfPath"

        # 6. 验证结果
        if (Test-Path -Path $pdfPath) {
            Write-Host "`n✨ 合成成功！" -ForegroundColor $COLOR_SUCCESS
            Write-Host "📂 文件位置: $pdfPath" -ForegroundColor $COLOR_SUCCESS
        } else {
            Write-Host "❌ 合成失败：未能生成 PDF 文件。" -ForegroundColor $COLOR_ERROR
        }

    } catch {
        Write-Host "❌ 发生错误: $($_.Exception.Message)" -ForegroundColor $COLOR_ERROR
    }

    # 7. 询问是否继续
    Write-Host "`n-------------------------------------" -ForegroundColor $COLOR_TITLE
    $choice = Read-Host -Prompt "是否继续处理其他路径？(Y/N，默认Y)"
} while ($choice.Trim().ToLower() -ne "n")

Write-Host "`n📌 感谢使用，再见！" -ForegroundColor $COLOR_SUCCESS
