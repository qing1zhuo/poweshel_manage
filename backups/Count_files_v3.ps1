<#
.SYNOPSIS
递归统计指定文件夹下PDF和ZIP文件的数量，并支持多次统计新路径
#>

# 定义循环，用于多次统计不同路径
do {
    # 清空控制台，让输出更清晰
    Clear-Host

    # 提示用户输入绝对路径
    $targetPath = Read-Host "请输入需要统计的文件夹绝对路径（例如：D:\test）"

    # 验证路径是否存在且是文件夹
    if (-not (Test-Path -Path $targetPath -PathType Container)) {
        Write-Host "`n错误：输入的路径不存在，或不是有效的文件夹！" -ForegroundColor Red
        # 暂停让用户看到错误提示
        Read-Host -Prompt "按Enter键继续"
        # 回到循环开头，重新输入路径
        continue
    }

    try {
        # 递归查找所有PDF文件，统计数量（忽略大小写，支持.pdf/.PDF等）
        $pdfCount = (Get-ChildItem -Path $targetPath -Recurse -Filter *.pdf -ErrorAction Stop | Where-Object { -not $_.PSIsContainer }).Count
        
        # 递归查找所有ZIP文件，统计数量（忽略大小写）
        $zipCount = (Get-ChildItem -Path $targetPath -Recurse -Filter *.zip -ErrorAction Stop | Where-Object { -not $_.PSIsContainer }).Count

        # 输出统计结果，用不同颜色区分更易读
        Write-Host "`n===== 统计结果 =====`n" -ForegroundColor Cyan
        Write-Host "目标路径：$targetPath"
        Write-Host "PDF文件总数：$pdfCount" -ForegroundColor Green
        Write-Host "ZIP压缩包总数：$zipCount" -ForegroundColor Green
        Write-Host "`n====================`n" -ForegroundColor Cyan
    }
    catch {
        # 捕获其他异常（如权限不足）
        Write-Host "`n统计失败：$($_.Exception.Message)" -ForegroundColor Red
    }

    # 询问是否继续统计新路径
    $continueChoice = Read-Host "`n是否需要统计新的路径？(Y/N，默认Y)"

    # 统一转为小写，判断是否继续（除非明确输入N，否则默认继续）
    $isContinue = ($continueChoice.Trim().ToLower() -ne "n")

} while ($isContinue)

# 脚本结束提示
Write-Host "`n脚本执行完毕，感谢使用！" -ForegroundColor Blue