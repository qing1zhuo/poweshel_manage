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
    [Parameter(Mandatory = $false, HelpMessage = "请输入文件夹路径")]
    [string]$Path,

    [Parameter(Mandatory = $false, HelpMessage = "请输入 GitHub 仓库 URL")]
    [string]$RemoteUrl,

    [Parameter(Mandatory = $false)]
    [string]$CommitMessage = "Initial commit via script"
)

do {
    # 如果没有通过参数传递路径，则在此询问
    if ([string]::IsNullOrWhiteSpace($Path)) {
        $currentPath = Read-Host "`n请输入需要推送的文件夹绝对路径"
    } else {
        $currentPath = $Path
        # 清除参数路径，以便下次循环时询问
        $Path = $null
    }

    # 1. 检查文件夹路径是否存在
    if (-not (Test-Path $currentPath)) {
        Write-Host "错误: 路径 '$currentPath' 不存在。" -ForegroundColor Red
    } else {
        # 切换到目标路径
        Push-Location $currentPath

        try {
            # 2. 检查 Git 是否安装
            if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
                Write-Host "错误: 系统中未找到 git，请先安装 Git。" -ForegroundColor Red
            } else {
                # 3. 检查是否已经是 Git 仓库
                if (-not (Test-Path ".git")) {
                    Write-Host "正在初始化 Git 仓库..." -ForegroundColor Cyan
                    git init
                    git checkout -b main
                }

                # 4. 添加文件
                Write-Host "正在添加文件到暂存区..." -ForegroundColor Cyan
                git add .

                # 5. 提交更改
                Write-Host "正在提交更改..." -ForegroundColor Cyan
                git commit -m $CommitMessage

                # 6. 处理远程仓库
                $tempRemoteUrl = $RemoteUrl
                if ([string]::IsNullOrWhiteSpace($tempRemoteUrl)) {
                    $existingRemote = git remote get-url origin 2>$null
                    if ($null -eq $existingRemote) {
                        $tempRemoteUrl = Read-Host "未检测到远程仓库，请输入 GitHub 远程 URL"
                    } else {
                        Write-Host "检测到现有远程仓库: $existingRemote" -ForegroundColor Green
                        $tempRemoteUrl = $existingRemote
                    }
                }

                if (-not [string]::IsNullOrWhiteSpace($tempRemoteUrl)) {
                    if (-not (git remote | Select-String "origin")) {
                        git remote add origin $tempRemoteUrl
                    } else {
                        $currentUrl = git remote get-url origin
                        if ($currentUrl -ne $tempRemoteUrl) {
                            Write-Host "更新远程仓库 URL 为: $tempRemoteUrl" -ForegroundColor Yellow
                            git remote set-url origin $tempRemoteUrl
                        }
                    }

                    # 7. 推送代码
                    Write-Host "正在推送至 GitHub (main 分支)..." -ForegroundColor Cyan
                    git push -u origin main
                    Write-Host "`n操作成功！代码已同步至 GitHub。" -ForegroundColor Green
                } else {
                    Write-Warning "未提供远程 URL，脚本仅在本地提交。"
                }
            }
        } catch {
            Write-Host "执行过程中发生错误: $_" -ForegroundColor Red
        } finally {
            Pop-Location
        }
    }

    $continueChoice = Read-Host "`n是否需要处理新的路径？(Y/N，默认Y)"
} while ($continueChoice.Trim().ToLower() -ne "n")
