<#
.SYNOPSIS
    全自动化文档数字化流水线：批量处理 ZIP 压缩包并合成 PDF。
.DESCRIPTION
    该脚本提供了一套完整的自动化流程：
    1. 自动扫描并解压指定目录下的所有 ZIP 压缩包。
    2. 从解压后的文件夹中提取有序图片（支持 5 位补零命名规则）。
    3. 调用 ImageMagick 引擎将图片合成为高质量 PDF 电子文档。
    4. 执行静默清理，自动移除原压缩包及解压后的临时图像文件夹。
.PARAMETER WorkDir
    指定的工作路径，脚本将在该路径下递归搜索并处理文件。
.NOTES
    依赖项：需安装 ImageMagick 7+ 并确保 'magick' 命令在系统环境变量中可用。
#>
# 解决PowerShell中文乱码问题，仅执行一次即可
chcp 65001 | Out-Null
$ErrorActionPreference = "Stop" # 捕获关键异常
# 定义日志颜色常量，统一可视化输出
$COLOR_INFO = "Cyan"
$COLOR_SUCCESS = "Green"
$COLOR_ERROR = "Red"
$COLOR_CLEAN = "Yellow"
$COLOR_TITLE = "Yellow" # 新增标题颜色，突出功能说明

# ===================== 脚本启动：打印核心功能说明 ======================
Write-Host "`n=====================================" -ForegroundColor $COLOR_TITLE
Write-Host "🚀 文档自动化流水线：ZIP 提取与 PDF 合成" -ForegroundColor $COLOR_TITLE
Write-Host "=====================================" -ForegroundColor $COLOR_TITLE
Write-Host "🔧 核心功能：" -ForegroundColor $COLOR_INFO
Write-Host "  1. 智能路径管理：支持自定义工作路径，实现环境隔离操作" -ForegroundColor $COLOR_INFO
Write-Host "  2. 自动化工作流：解压 -> 提取 -> 合成 -> 清理，全程零人工干预" -ForegroundColor $COLOR_INFO
Write-Host "  3. 智能解压规则：支持 ZIP 到同名文件夹的映射解压" -ForegroundColor $COLOR_INFO
Write-Host "  4. 高质合成引擎：基于 ImageMagick 的工业级 PDF 合成技术" -ForegroundColor $COLOR_INFO
Write-Host "  5. 零残留清理：任务完成后自动销毁临时文件，保持磁盘整洁" -ForegroundColor $COLOR_INFO
Write-Host "  6. 持续作业模式：支持循环路径输入，满足大批量处理需求" -ForegroundColor $COLOR_INFO
Write-Host "⚙️  运行依赖：" -ForegroundColor $COLOR_INFO
Write-Host "  1. 解压引擎：Windows PowerShell 原生支持" -ForegroundColor $COLOR_INFO
Write-Host "  2. 合成引擎：ImageMagick 7+ (需配置系统环境变量)" -ForegroundColor $COLOR_INFO
Write-Host "=====================================`n" -ForegroundColor $COLOR_TITLE

# ===================== 定义解压功能 =====================
function Invoke-ZipExtract {
    param(
        [Parameter(Mandatory=$true)]
        [string]$WorkDir # 传入用户指定的工作路径
    )
    Write-Host "`n=====================================" -ForegroundColor $COLOR_INFO
    Write-Host "开始执行【批量解压ZIP】流程" -ForegroundColor $COLOR_INFO
    Write-Host "=====================================" -ForegroundColor $COLOR_INFO

    # 获取工作路径下的所有ZIP文件（不递归子文件夹）
    $zipFiles = Get-ChildItem -Path $WorkDir -Filter *.zip -File -ErrorAction SilentlyContinue
    if ($zipFiles.Count -eq 0) {
        Write-Host "ℹ️  工作路径下未找到ZIP压缩包，跳过解压流程" -ForegroundColor $COLOR_INFO
        return
    }

    # 遍历解压每个ZIP
    foreach ($zip in $zipFiles) {
        try {
            # 解压到「与ZIP同名」的子文件夹
            $extractDir = Join-Path -Path $WorkDir -ChildPath $zip.BaseName
            # 解压（-Force覆盖同名文件）
            Expand-Archive -Path $zip.FullName -DestinationPath $extractDir -Force
            Write-Host "✅ 解压成功：$($zip.Name) → $extractDir" -ForegroundColor $COLOR_SUCCESS
            # 解压完成后删除原ZIP包（静默忽略删除错误）
            Remove-Item -Path $zip.FullName -Force -ErrorAction SilentlyContinue
            Write-Host "🗑️  已清理原压缩包：$($zip.Name)" -ForegroundColor $COLOR_CLEAN
        }
        catch {
            Write-Host "❌ 解压失败：$($zip.Name)，错误原因：$($_.Exception.Message)" -ForegroundColor $COLOR_ERROR
        }
    }
    Write-Host "`n📌 批量解压ZIP流程执行完成" -ForegroundColor $COLOR_INFO
}

# ===================== 定义合成PDF功能 =====================
function Invoke-Img2Pdf {
    param(
        [Parameter(Mandatory=$true)]
        [string]$WorkDir # 传入用户指定的工作路径
    )
    Write-Host "`n=====================================" -ForegroundColor $COLOR_INFO
    Write-Host "开始执行【图片批量合成PDF】流程" -ForegroundColor $COLOR_INFO
    Write-Host "=====================================" -ForegroundColor $COLOR_INFO

    # 校验ImageMagick 7+的magick命令是否可用
    Write-Host "ℹ️  正在检测ImageMagick 7+环境..." -ForegroundColor $COLOR_INFO
    if (-not (Get-Command -Name magick -ErrorAction SilentlyContinue)) {
        Write-Host "❌ 未检测到ImageMagick 7+！" -ForegroundColor $COLOR_ERROR
        Write-Host "请安装ImageMagick 7+并将其安装目录添加到系统环境变量PATH中，重启PowerShell后重试" -ForegroundColor $COLOR_ERROR
        return $false # 返回执行状态，便于外层判断
    }
    Write-Host "✅ ImageMagick 7+环境检测通过" -ForegroundColor $COLOR_SUCCESS

    # 获取工作路径下的所有子文件夹
    $subFolders = Get-ChildItem -Path $WorkDir -Directory -ErrorAction SilentlyContinue
    if ($subFolders.Count -eq 0) {
        Write-Host "ℹ️  工作路径下未找到子文件夹，无图片可处理，跳过PDF合成流程" -ForegroundColor $COLOR_INFO
        return $true
    }
    Write-Host "ℹ️  共找到 $($subFolders.Count) 个待处理子文件夹，开始逐个合成PDF..." -ForegroundColor $COLOR_INFO

    # 遍历每个子文件夹处理
    foreach ($folder in $subFolders) {
        $folderPath = $folder.FullName
        $pdfName = "$($folder.Name).pdf"
        $pdfPath = Join-Path -Path $WorkDir -ChildPath $pdfName # PDF保存到工作路径根目录
        Write-Host "`nℹ️  正在处理文件夹：$($folder.Name)" -ForegroundColor $COLOR_INFO

        try {
            # 筛选符合规则的图片：5位补零纯数字命名 + 支持WebP/JPG/PNG/JPEG + 递归查找
            $imgPattern = "^(\d{5})\.(webp|jpg|png|jpeg)$"
            $images = Get-ChildItem -Path $folderPath -Recurse -File | 
                Where-Object { $_.Name -match $imgPattern -and $_.BaseName -match '^\d{5}$' } |
                Sort-Object { [int]$_.BaseName } # 按数字正序排序

            if ($images.Count -eq 0) {
                Write-Host "ℹ️  该文件夹内无符合规则的图片（5位补零纯数字命名），跳过" -ForegroundColor $COLOR_INFO
                continue
            }

            # 调用ImageMagick合成PDF（兼容中文路径）
            Write-Host "ℹ️  找到 $($images.Count) 张符合规则的图片，开始合成PDF..." -ForegroundColor $COLOR_INFO
            magick $images.FullName -compress LZW "$pdfPath" # -compress LZW优化PDF体积

            # 校验PDF是否生成成功
            if (Test-Path -Path $pdfPath -PathType Leaf) {
                Write-Host "✅ PDF合成成功：$pdfName" -ForegroundColor $COLOR_SUCCESS
                # 成功后删除原图片文件夹（强制删除，捕获删除错误）
                try {
                    Remove-Item -Path $folderPath -Recurse -Force
                    Write-Host "🗑️  已清理原图片文件夹：$($folder.Name)" -ForegroundColor $COLOR_CLEAN
                }
                catch {
                    Write-Host "⚠️  清理原文件夹失败：$($folder.Name)，错误原因：$($_.Exception.Message)" -ForegroundColor $COLOR_ERROR
                }
            }
            else {
                Write-Host "❌ PDF合成失败：未检测到生成的PDF文件" -ForegroundColor $COLOR_ERROR
            }
        }
        catch {
            Write-Host "❌ 处理文件夹 $($folder.Name) 失败，错误原因：$($_.Exception.Message)" -ForegroundColor $COLOR_ERROR
            continue # 单个文件夹失败，继续处理下一个
        }
    }
    Write-Host "`n📌 图片批量合成PDF流程执行完成" -ForegroundColor $COLOR_INFO
    return $true
}

# ===================== 定义路径校验功能（抽离复用） =====================
function Test-WorkPath {
    param(
        [Parameter(Mandatory=$true)]
        [string]$InputPath
    )
    # 处理路径引号/空格问题
    $WorkPath = $InputPath.Trim().Trim('"')
    # 校验路径是否存在
    if (-not (Test-Path -Path $WorkPath -PathType Container)) {
        Write-Host "`n错误：你输入的路径 [$WorkPath] 不存在，请检查路径是否正确！" -ForegroundColor $COLOR_ERROR
        return $null
    }
    # 转为标准绝对路径
    $WorkPath = (Resolve-Path -Path $WorkPath).Path
    Write-Host "`n✅ 工作路径校验通过，最终执行路径：$WorkPath" -ForegroundColor $COLOR_SUCCESS
    return $WorkPath
}

# ===================== 主循环执行逻辑（核心新增） =====================
do {
    # ===================== 输入并校验工作路径 =====================
    Write-Host "`n===== 请输入工作路径（所有解压/合成操作均在此路径执行）=====" -ForegroundColor $COLOR_INFO
    Write-Host "示例：D:\文档\我的图片包 或 D:\test" -ForegroundColor $COLOR_INFO
    $InputPath = Read-Host -Prompt "请输入绝对路径"
    
    # 校验路径，失败则重新输入
    $WorkPath = Test-WorkPath -InputPath $InputPath
    if ($null -eq $WorkPath) {
        continue
    }

    # ===================== 执行解压 + 合成PDF =====================
    Invoke-ZipExtract -WorkDir $WorkPath
    $pdfResult = Invoke-Img2Pdf -WorkDir $WorkPath

    # ===================== 询问是否继续执行 =====================
    Write-Host "`n=====================================" -ForegroundColor $COLOR_TITLE
    $continueInput = Read-Host -Prompt "✅ 本次流程执行完毕，是否继续处理新路径？(Y/N，默认Y)"
    # 统一转为大写，兼容大小写输入
    $continueInput = $continueInput.Trim().ToUpper()

    # 判断是否退出
    if ($continueInput -ne "N") {
	Write-Host "`n📌 准备处理新路径，请继续输入..." -ForegroundColor $COLOR_INFO
    }
    else {
	Write-Host "`n📌 感谢使用，脚本即将退出..." -ForegroundColor $COLOR_SUCCESS
        break  
    }

} while ($true) # 无限循环，直到用户选择退出