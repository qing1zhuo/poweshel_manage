<#
.SYNOPSIS
    将指定文件夹的内容推送至 GitHub 仓库。

.DESCRIPTION
    该脚本会自动执行 Git 初始化、添加文件、提交更改，并将其推送到指定的 GitHub 远程仓库。
    如果文件夹尚未初始化为 Git 仓库，脚本将自动完成初始化。

.PARAMETER Path
    需要推送的文件夹路径。

.PARAMETER RemoteUrl
    GitHub 远程仓库的 URL (例如: https://github.com/username/repo.git)。

.PARAMETER CommitMessage
    提交信息，默认为 "Initial commit via script"。

.EXAMPLE
    .\Push-ToGitHub.ps1 -Path "C:\MyProject" -RemoteUrl "https://github.com/user/repo.git"
#>

param (
    [Parameter(Mandatory = $true, HelpMessage = "请输入文件夹路径")]
    [string]$Path,

    [Parameter(Mandatory = $false, HelpMessage = "请输入 GitHub 仓库 URL")]
    [string]$RemoteUrl,

    [Parameter(Mandatory = $false)]
    [string]$CommitMessage = "Initial commit via script"
)

# 1. 检查文件夹路径是否存在
if (-not (Test-Path $Path)) {
    Write-Error "错误: 路径 '$Path' 不存在。"
    return
}

# 切换到目标路径
Push-Location $Path

try {
    # 2. 检查 Git 是否安装
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Error "错误: 系统中未找到 git，请先安装 Git。"
        return
    }

    # 3. 检查是否已经是 Git 仓库
    if (-not (Test-Path ".git")) {
        Write-Host "正在初始化 Git 仓库..." -ForegroundColor Cyan
        git init
        # 默认使用 main 分支
        git checkout -b main
    }

    # 4. 添加文件
    Write-Host "正在添加文件到暂存区..." -ForegroundColor Cyan
    git add .

    # 5. 提交更改
    Write-Host "正在提交更改..." -ForegroundColor Cyan
    git commit -m $CommitMessage

    # 6. 处理远程仓库
    if ([string]::IsNullOrWhiteSpace($RemoteUrl)) {
        # 检查是否已有远程仓库
        $existingRemote = git remote get-url origin 2>$null
        if ($null -eq $existingRemote) {
            $RemoteUrl = Read-Host "未检测到远程仓库，请输入 GitHub 远程 URL"
            if ([string]::IsNullOrWhiteSpace($RemoteUrl)) {
                Write-Warning "未提供远程 URL，脚本将仅在本地提交。"
                return
            }
        } else {
            Write-Host "检测到现有远程仓库: $existingRemote" -ForegroundColor Green
            $RemoteUrl = $existingRemote
        }
    }

    # 设置或更新远程仓库
    if (-not (git remote | Select-String "origin")) {
        git remote add origin $RemoteUrl
    } else {
        $currentUrl = git remote get-url origin
        if ($currentUrl -ne $RemoteUrl) {
            Write-Host "更新远程仓库 URL 为: $RemoteUrl" -ForegroundColor Yellow
            git remote set-url origin $RemoteUrl
        }
    }

    # 7. 推送代码
    Write-Host "正在推送至 GitHub (main 分支)..." -ForegroundColor Cyan
    # 尝试推送到 main 分支
    git push -u origin main

    Write-Host "`n操作成功！代码已同步至 GitHub。" -ForegroundColor Green

} catch {
    Write-Error "执行过程中发生错误: $_"
} finally {
    Pop-Location
}
