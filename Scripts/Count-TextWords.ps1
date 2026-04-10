<#
.SYNOPSIS
    统计TXT文本文件中的汉字数量与英文单词数量。
.DESCRIPTION
    读取指定TXT文件，过滤掉标点/空格/换行符后，分别统计汉字（[\u4e00-\u9fa5]）和英文单词（[\w]+）的数量；
    支持循环执行，自动处理文件读取异常，输出清晰的统计结果。
.PARAMETER FilePath
    待统计的TXT文件完整路径（如：D:\test.txt），脚本启动时可直接传入。
.EXAMPLE
    .\Count-TextWords.ps1
    （执行后手动输入文件路径，统计指定TXT的汉字/单词数）
.EXAMPLE
    .\Count-TextWords.ps1 -FilePath "C:\docs\readme.txt"
    （直接指定文件路径执行统计）
#>

# 【修复点1】param块必须放在注释之后、所有可执行代码之前，不能嵌套在循环里
param(
    [Parameter(Mandatory=$false)]
    [string]$FilePath
)

# 脚本启动：打印功能说明与依赖（符合交互规范）
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "📝 文本字数统计工具" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "核心功能：" -ForegroundColor Yellow
Write-Host "1. 统计TXT文件中的纯汉字数量" -ForegroundColor White
Write-Host "2. 统计TXT文件中的英文单词数量（排除标点/空格）" -ForegroundColor White
Write-Host "3. 自动处理文件读取异常，输出详细错误信息" -ForegroundColor White
Write-Host "依赖项：无外部依赖（仅PowerShell内置命令）" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan

# 循环执行逻辑（符合交互规范）
do {
    try {
        # 【修复点2】循环内仅处理路径输入，不重复定义param
        # 若启动时未传路径、或已完成一次统计，让用户输入新路径
        if (-not $FilePath) {
            $FilePath = Read-Host "请输入待统计的TXT文件完整路径（如 D:\test.txt）"
        }

        # 验证文件是否存在
        if (-not (Test-Path -Path $FilePath -PathType Leaf)) {
            throw "文件不存在：$FilePath，请检查路径是否正确！"
        }

        # 验证文件格式为TXT
        if ([System.IO.Path]::GetExtension($FilePath) -ne ".txt") {
            throw "文件格式错误：仅支持 .txt 文本文件！"
        }

        # 读取文件内容（兼容UTF-8/GBK编码）
        $fileContent = Get-Content -Path $FilePath -Raw -Encoding Default

        # 统计汉字：精准匹配中文字符
        $chineseChars = [regex]::Matches($fileContent, '[\u4e00-\u9fa5]').Count
        # 统计英文单词：过滤标点/换行/多余空格后计数
        $cleanContent = $fileContent -replace '[^\w\s]', '' -replace "`n|`r", ' ' -replace '\s+', ' '
        $englishWords = [regex]::Matches($cleanContent, '\b\w+\b').Count

        # 输出统计结果
        Write-Host "`n✅ 统计完成（文件：$FilePath）" -ForegroundColor Green
        Write-Host "📊 汉字数量：$chineseChars" -ForegroundColor White
        Write-Host "📊 英文单词数量：$englishWords" -ForegroundColor White

    } catch {
        # 错误处理（符合规范）
        Write-Error "❌ 执行失败：$($_.Exception.Message)"
        Write-Host "详细错误信息：$_" -ForegroundColor Red
    } finally {
        # 每次循环结束清空路径，下次循环让用户重新输入
        $FilePath = $null
    }

    # 询问是否继续（符合交互规范：默认Y，回车视为继续）
    $continueChoice = Read-Host "`n是否继续统计新文件？(Y/N，默认Y)"
    $isContinue = ($continueChoice.Trim().ToLower() -ne "n")

} while ($isContinue)

Write-Host "`n👋 脚本已退出，感谢使用！`n" -ForegroundColor Cyan