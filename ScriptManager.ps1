<#
.SYNOPSIS
PowerShell脚本管理工具 v1.2 - 最终完整版
.DESCRIPTION
本地运行的脚本管理工具，支持脚本新增/修改/删除/运行、功能介绍、版本回滚
存储路径：D:\powershell_manage
兼容环境：PowerShell 5.1（Windows默认）
#>

# -------------------------- 配置区 --------------------------
$ScriptRootPath = "D:\powershell_manage\Scripts"        # 脚本主目录
$VersionBackupPath = "D:\powershell_manage\VersionBackup" # 版本备份目录
$MetaDataFile = "D:\powershell_manage\ScriptMetaData.json"# 脚本元数据文件
# -----------------------------------------------------------------------------

# -------------------------- 初始化函数 --------------------------
function Initialize-Environment {
    <# 初始化目录和元数据文件 #>
    try {
        # 创建主目录和备份目录（强制创建，包括父级目录）
        if (-not (Test-Path -Path $ScriptRootPath)) {
            New-Item -Path $ScriptRootPath -ItemType Directory -Force | Out-Null
            Write-Host "✅ 已创建脚本主目录: $ScriptRootPath" -ForegroundColor Green
        }
        if (-not (Test-Path -Path $VersionBackupPath)) {
            New-Item -Path $VersionBackupPath -ItemType Directory -Force | Out-Null
            Write-Host "✅ 已创建版本备份目录: $VersionBackupPath" -ForegroundColor Green
        }

        # 初始化元数据文件（JSON格式）
        if (-not (Test-Path -Path $MetaDataFile)) {
            $initialMetaData = @{}
            $initialMetaData | ConvertTo-Json | Out-File -FilePath $MetaDataFile -Encoding utf8
            Write-Host "✅ 已初始化脚本元数据文件: $MetaDataFile" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "❌ 环境初始化失败: $_" -ForegroundColor Red
        exit 1
    }
}

# -------------------------- 元数据管理函数 --------------------------
function Get-ScriptMetaData {
    <# 读取脚本元数据 #>
    try {
        $metaData = Get-Content -Path $MetaDataFile -Encoding utf8 | ConvertFrom-Json
        return $metaData
    }
    catch {
        Write-Host "❌ 读取元数据失败: $_" -ForegroundColor Red
        return $null
    }
}

function Save-ScriptMetaData {
    <# 保存脚本元数据 #>
    param (
        [Parameter(Mandatory=$true)]
        $MetaData
    )
    try {
        $MetaData | ConvertTo-Json -Depth 10 | Out-File -FilePath $MetaDataFile -Encoding utf8
        return $true
    }
    catch {
        Write-Host "❌ 保存元数据失败: $_" -ForegroundColor Red
        return $false
    }
}

# -------------------------- 版本管理函数 --------------------------
function Backup-ScriptVersion {
    <# 备份当前脚本版本 #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$ScriptName
    )
    try {
        $metaData = Get-ScriptMetaData
        if (-not $metaData.$ScriptName) {
            Write-Host "❌ 未找到脚本[$ScriptName]的元数据，无法备份" -ForegroundColor Red
            return $false
        }

        # 获取当前版本号并递增
        $currentVersion = if ($metaData.$ScriptName.Version) { $metaData.$ScriptName.Version } else { 1 }
        $newVersion = $currentVersion + 1
        $metaData.$ScriptName.Version = $newVersion

        # 备份文件命名规则：脚本名_版本号.ps1
        $backupFileName = "$ScriptName`_v$currentVersion.ps1"
        $sourcePath = "$ScriptRootPath\$ScriptName.ps1"
        $backupPath = "$VersionBackupPath\$backupFileName"

        # 复制到备份目录
        Copy-Item -Path $sourcePath -Destination $backupPath -Force
        Save-ScriptMetaData -MetaData $metaData

        Write-Host "✅ 已备份[$ScriptName] v$currentVersion 到: $backupPath" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ 版本备份失败: $_" -ForegroundColor Red
        return $false
    }
}

function Get-ScriptVersionList {
    <# 获取脚本的所有版本列表 #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$ScriptName
    )
    try {
        $versionFiles = Get-ChildItem -Path $VersionBackupPath -Filter "$ScriptName`_v*.ps1" | Sort-Object Name
        if ($versionFiles.Count -eq 0) {
            Write-Host "⚠️ 未找到[$ScriptName]的历史版本" -ForegroundColor Yellow
            return $null
        }

        # 解析版本号并展示
        $versionList = @()
        Write-Host "`n📜 [$ScriptName] 历史版本列表:" -ForegroundColor Cyan
        for ($i=0; $i -lt $versionFiles.Count; $i++) {
            $fileName = $versionFiles[$i].Name
            $version = ($fileName -split '_v')[1] -replace '\.ps1$',''
            $versionList += @{
                Index = $i+1
                Version = $version
                FilePath = $versionFiles[$i].FullName
            }
            Write-Host "  $($i+1). v$version - $($versionFiles[$i].LastWriteTime)" -ForegroundColor White
        }
        return $versionList
    }
    catch {
        Write-Host "❌ 获取版本列表失败: $_" -ForegroundColor Red
        return $null
    }
}

# -------------------------- UI 辅助函数 --------------------------
function Show-FormattedScriptList {
    <# 以精美格式展示脚本列表，支持带序号选择模式 #>
    param (
        [Parameter(Mandatory=$false)]
        [switch]$WithSelection, # 是否显示序号供选择
        [Parameter(Mandatory=$false)]
        [string]$Title = "📜 脚本详情列表"
    )

    try {
        Write-Host "========================================================" -ForegroundColor Cyan
        Write-Host "                $Title" -ForegroundColor Yellow
        Write-Host "========================================================" -ForegroundColor Cyan
        
        $scriptFiles = Get-ChildItem -Path $ScriptRootPath -Filter "*.ps1" -File
        if ($scriptFiles.Count -eq 0) {
            Write-Host "❌ 暂无可用脚本！" -ForegroundColor Red
            return $null
        }

        $metaData = Get-ScriptMetaData
        for ($i=0; $i -lt $scriptFiles.Count; $i++) {
            $scriptName = $scriptFiles[$i].Name -replace '\.ps1$',''
            $scriptMeta = $metaData.$scriptName
            
            $desc = if ($scriptMeta -and $scriptMeta.Description) { $scriptMeta.Description } else { "无介绍" }
            $version = if ($scriptMeta -and $scriptMeta.Version) { $scriptMeta.Version } else { "1" }
            $createTime = if ($scriptMeta -and $scriptMeta.CreateTime) { $scriptMeta.CreateTime } else { "未知" }

            Write-Host "--------------------------------------------------------" -ForegroundColor DarkGray
            
            # 如果是选择模式，显示序号
            if ($WithSelection) {
                Write-Host " [$($i+1)] " -NoNewline -ForegroundColor Green
            }

            Write-Host "📦 名称 : " -NoNewline -ForegroundColor Cyan
            Write-Host "$scriptName.ps1" -ForegroundColor White
            
            Write-Host "     🔢 版本 : " -NoNewline -ForegroundColor Cyan
            Write-Host "v$version" -ForegroundColor Green
            
            Write-Host "     🕒 时间 : " -NoNewline -ForegroundColor Cyan
            Write-Host "$createTime" -ForegroundColor Gray
            
            Write-Host "     🔍 介绍 : " -NoNewline -ForegroundColor Cyan
            Write-Host "$desc" -ForegroundColor Yellow
        }
        
        Write-Host "--------------------------------------------------------" -ForegroundColor DarkGray
        if ($WithSelection) {
            Write-Host " 💡 提示: 输入序号开始操作，输入 0 或直接按回车返回主菜单" -ForegroundColor Gray
        }
        Write-Host "========================================================" -ForegroundColor Cyan
        return $scriptFiles
    }
    catch {
        Write-Host "❌ 展示列表失败: $_" -ForegroundColor Red
        return $null
    }
}

# -------------------------- 核心操作函数 --------------------------
function New-Script {
    <# 新增脚本 #>
    try {
        Clear-Host
        Write-Host "==================== 新增脚本 ====================" -ForegroundColor Cyan
        
        # 输入脚本名称（不含.ps1后缀）
        do {
            $scriptName = Read-Host "`n请输入脚本名称（不含.ps1后缀，如：MyTestScript）"
            if ([string]::IsNullOrEmpty($scriptName)) {
                Write-Host "❌ 名称不能为空！" -ForegroundColor Red
            }
        } while ([string]::IsNullOrEmpty($scriptName))

        # 检查脚本是否已存在
        $scriptPath = "$ScriptRootPath\$scriptName.ps1"
        if (Test-Path -Path $scriptPath) {
            Write-Host "❌ 脚本[$scriptName.ps1]已存在，无法新增！" -ForegroundColor Red
            Read-Host "按任意键返回菜单"
            return
        }

        # 输入功能介绍
        $scriptDesc = Read-Host "请输入脚本功能介绍"
        if ([string]::IsNullOrEmpty($scriptDesc)) {
            $scriptDesc = "无介绍"
        }

        # 创建空脚本文件
        New-Item -Path $scriptPath -ItemType File -Force | Out-Null

        # 编辑脚本内容（调用默认编辑器）
        Write-Host "`n📝 即将打开编辑器编辑脚本内容（保存后关闭编辑器继续）" -ForegroundColor Yellow
        Start-Process -FilePath notepad.exe -ArgumentList $scriptPath -Wait

        # 更新元数据（初始版本号为1）
        $metaData = Get-ScriptMetaData
        $metaData | Add-Member -MemberType NoteProperty -Name $scriptName -Value @{
            Description = $scriptDesc
            Version = 1
            CreateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        } -Force
        Save-ScriptMetaData -MetaData $metaData

        Write-Host "`n✅ 脚本[$scriptName.ps1]新增成功！" -ForegroundColor Green
        Read-Host "按任意键返回菜单"
    }
    catch {
        Write-Host "❌ 新增脚本失败: $_" -ForegroundColor Red
        Read-Host "按任意键返回菜单"
    }
}

function Edit-Script {
    <# 修改脚本 #>
    try {
        Clear-Host
        $scriptFiles = Show-FormattedScriptList -Title "🛠️ 请选择要修改的脚本" -WithSelection
        if ($null -eq $scriptFiles) {
            Read-Host "按任意键返回菜单"
            return
        }

        # 选择要修改的脚本
        do {
            $choice = Read-Host "`n请输入脚本序号（或输入0返回）"
            if ([string]::IsNullOrWhiteSpace($choice) -or $choice -eq "0") {
                Write-Host "✅ 已取消修改操作" -ForegroundColor Green
                Read-Host "按任意键返回菜单"
                return
            }
            if (-not [int]::TryParse($choice, [ref]$null) -or $choice -lt 1 -or $choice -gt $scriptFiles.Count) {
                Write-Host "❌ 输入无效，请输入 1-$($scriptFiles.Count) 之间的数字！" -ForegroundColor Red
            }
        } while (-not [int]::TryParse($choice, [ref]$null) -or $choice -lt 1 -or $choice -gt $scriptFiles.Count)

        $selectedScript = $scriptFiles[$choice-1]
        $scriptName = $selectedScript.Name -replace '\.ps1$',''
        $scriptPath = $selectedScript.FullName

        # 先备份当前版本
        Write-Host "`n🔄 正在备份当前版本..." -ForegroundColor Yellow
        if (-not (Backup-ScriptVersion -ScriptName $scriptName)) {
            Read-Host "按任意键返回菜单"
            return
        }

        # 可选修改功能介绍
        $metaData = Get-ScriptMetaData
        $currentDesc = if ($metaData.$scriptName.Description) { $metaData.$scriptName.Description } else { "无介绍" }
        Write-Host "`n当前功能介绍: $currentDesc" -ForegroundColor White
        $updateDesc = Read-Host "是否修改功能介绍？(Y/N，默认Y)"
        if ($updateDesc -ne 'N' -and $updateDesc -ne 'n') {
            $newDesc = Read-Host "请输入新的功能介绍"
            if (-not [string]::IsNullOrEmpty($newDesc)) {
                $metaData.$scriptName.Description = $newDesc
                Save-ScriptMetaData -MetaData $metaData
                Write-Host "✅ 功能介绍已更新" -ForegroundColor Green
            }
        }

        # 编辑脚本内容
        Write-Host "`n📝 即将打开编辑器修改脚本内容（保存后关闭编辑器）" -ForegroundColor Yellow
        Start-Process -FilePath notepad.exe -ArgumentList $scriptPath -Wait

        Write-Host "`n✅ 脚本[$scriptName.ps1]修改成功！" -ForegroundColor Green
        Read-Host "按任意键返回菜单"
    }
    catch {
        Write-Host "❌ 修改脚本失败: $_" -ForegroundColor Red
        Read-Host "按任意键返回菜单"
    }
}

function Remove-Script {
    <# 删除脚本 #>
    try {
        Clear-Host
        $scriptFiles = Show-FormattedScriptList -Title "🗑️ 请选择要删除的脚本" -WithSelection
        if ($null -eq $scriptFiles) {
            Read-Host "按任意键返回菜单"
            return
        }

        # 选择要删除的脚本
        do {
            $choice = Read-Host "`n请输入脚本序号（或输入0返回）"
            if ([string]::IsNullOrWhiteSpace($choice) -or $choice -eq "0") {
                Write-Host "✅ 已取消删除操作" -ForegroundColor Green
                Read-Host "按任意键返回菜单"
                return
            }
            if (-not [int]::TryParse($choice, [ref]$null) -or $choice -lt 1 -or $choice -gt $scriptFiles.Count) {
                Write-Host "❌ 输入无效，请输入 1-$($scriptFiles.Count) 之间的数字！" -ForegroundColor Red
            }
        } while (-not [int]::TryParse($choice, [ref]$null) -or $choice -lt 1 -or $choice -gt $scriptFiles.Count)

        $selectedScript = $scriptFiles[$choice-1]
        $scriptName = $selectedScript.Name -replace '\.ps1$',''
        $scriptPath = $selectedScript.FullName

        # 二次确认
        $confirm = Read-Host "⚠️ 确定要删除[$scriptName.ps1]吗？(Y/N，默认Y)"
        if ($confirm -eq 'N' -or $confirm -eq 'n') {
            Write-Host "✅ 已取消删除操作" -ForegroundColor Green
            Read-Host "按任意键返回菜单"
            return
        }

        # 删除脚本文件
        Remove-Item -Path $scriptPath -Force
        # 删除版本备份
        Get-ChildItem -Path $VersionBackupPath -Filter "$scriptName`_v*.ps1" | Remove-Item -Force
        # 删除元数据
        $metaData = Get-ScriptMetaData
        $metaData.PSObject.Properties.Remove($scriptName)
        Save-ScriptMetaData -MetaData $metaData

        Write-Host "`n✅ 脚本[$scriptName.ps1]已彻底删除（含历史版本）！" -ForegroundColor Green
        Read-Host "按任意键返回菜单"
    }
    catch {
        Write-Host "❌ 删除脚本失败: $_" -ForegroundColor Red
        Read-Host "按任意键返回菜单"
    }
}

function Rollback-ScriptVersion {
    <# 版本回滚 #>
    try {
        Clear-Host
        $scriptFiles = Show-FormattedScriptList -Title "🔄 请选择要回滚的脚本" -WithSelection
        if ($null -eq $scriptFiles) {
            Read-Host "按任意键返回菜单"
            return
        }

        # 选择要回滚的脚本
        do {
            $choice = Read-Host "`n请输入脚本序号（或输入0返回）"
            if ([string]::IsNullOrWhiteSpace($choice) -or $choice -eq "0") {
                Write-Host "✅ 已取消回滚操作" -ForegroundColor Green
                Read-Host "按任意键返回菜单"
                return
            }
            if (-not [int]::TryParse($choice, [ref]$null) -or $choice -lt 1 -or $choice -gt $scriptFiles.Count) {
                Write-Host "❌ 输入无效，请输入 1-$($scriptFiles.Count) 之间的数字！" -ForegroundColor Red
            }
        } while (-not [int]::TryParse($choice, [ref]$null) -or $choice -lt 1 -or $choice -gt $scriptFiles.Count)

        $selectedScript = $scriptFiles[$choice-1]
        $scriptName = $selectedScript.Name -replace '\.ps1$',''

        # 获取版本列表
        $versionList = Get-ScriptVersionList -ScriptName $scriptName
        if (-not $versionList) {
            Read-Host "按任意键返回菜单"
            return
        }

        # 选择要回滚的版本
        do {
            $versionChoice = Read-Host "`n请输入要回滚的版本序号（1-$($versionList.Count)）"
            if (-not [int]::TryParse($versionChoice, [ref]$null) -or $versionChoice -lt 1 -or $versionChoice -gt $versionList.Count) {
                Write-Host "❌ 输入无效，请输入1-$($versionList.Count)之间的数字！" -ForegroundColor Red
            }
        } while (-not [int]::TryParse($versionChoice, [ref]$null) -or $versionChoice -lt 1 -or $versionChoice -gt $versionList.Count)

        $selectedVersion = $versionList[$versionChoice-1]
        $sourcePath = $selectedVersion.FilePath
        $targetPath = "$ScriptRootPath\$scriptName.ps1"

        # 二次确认
        $confirm = Read-Host "⚠️ 确定要回滚[$scriptName.ps1]到v$($selectedVersion.Version)版本吗？(Y/N，默认Y)"
        if ($confirm -eq 'N' -or $confirm -eq 'n') {
            Write-Host "✅ 已取消回滚操作" -ForegroundColor Green
            Read-Host "按任意键返回菜单"
            return
        }

        # 先备份当前版本（避免回滚后无法恢复）
        Backup-ScriptVersion -ScriptName $scriptName | Out-Null
        # 恢复选中的版本
        Copy-Item -Path $sourcePath -Destination $targetPath -Force

        Write-Host "`n✅ 脚本[$scriptName.ps1]已成功回滚到v$($selectedVersion.Version)版本！" -ForegroundColor Green
        Read-Host "按任意键返回菜单"
    }
    catch {
        Write-Host "❌ 版本回滚失败: $_" -ForegroundColor Red
        Read-Host "按任意键返回菜单"
    }
}

function Show-ScriptList {
    <# 查看脚本列表及介绍 #>
    try {
        Clear-Host
        $scriptFiles = Show-FormattedScriptList -Title "📜 脚本详情列表"
        if ($null -eq $scriptFiles) {
            Read-Host "按任意键返回菜单"
            return
        }
        Read-Host "`n按任意键返回菜单"
    }
    catch {
        Write-Host "❌ 查看脚本列表失败: $_" -ForegroundColor Red
        Read-Host "按任意键返回菜单"
    }
}

function Run-Script {
    <# 运行脚本 - 新增核心功能 #>
    try {
        Clear-Host
        $scriptFiles = Show-FormattedScriptList -Title "🚀 请选择要运行的脚本" -WithSelection
        if ($null -eq $scriptFiles) {
            Read-Host "按任意键返回菜单"
            return
        }

        # 选择要运行的脚本
        do {
            $choice = Read-Host "`n请输入脚本序号（或输入0返回）"
            if ([string]::IsNullOrWhiteSpace($choice) -or $choice -eq "0") {
                Write-Host "✅ 已返回主菜单" -ForegroundColor Green
                return
            }
            if (-not [int]::TryParse($choice, [ref]$null) -or $choice -lt 1 -or $choice -gt $scriptFiles.Count) {
                Write-Host "❌ 输入无效，请输入 1-$($scriptFiles.Count) 之间的数字！" -ForegroundColor Red
            }
        } while (-not [int]::TryParse($choice, [ref]$null) -or $choice -lt 1 -or $choice -gt $scriptFiles.Count)

        $selectedScript = $scriptFiles[$choice-1]
        $scriptName = $selectedScript.Name -replace '\.ps1$',''
        $scriptPath = $selectedScript.FullName

        # 执行脚本（捕获所有错误）
        Write-Host "`n🚀 正在运行[$scriptName.ps1]，执行结果如下：" -ForegroundColor Green
        Write-Host "--------------------------------------------------------" -ForegroundColor Gray
        try {
            # 用&操作符执行脚本，保留执行输出
            & $scriptPath
        }
        catch {
            Write-Host "`n❌ 脚本执行失败: $_" -ForegroundColor Red
        }
        Write-Host "--------------------------------------------------------" -ForegroundColor Gray
        Write-Host "✅ 脚本执行结束！" -ForegroundColor Green
        Read-Host "按任意键返回菜单"
    }
    catch {
        Write-Host "❌ 运行脚本流程失败: $_" -ForegroundColor Red
        Read-Host "按任意键返回菜单"
    }
}

# -------------------------- 主菜单 --------------------------
function Show-MainMenu {
    Clear-Host
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host "           PowerShell脚本管理工具 v1.2" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host "脚本存储目录: $ScriptRootPath" -ForegroundColor Gray
    Write-Host "`n请选择操作：" -ForegroundColor White
    Write-Host "  1. 新增脚本"
    Write-Host "  2. 修改脚本"
    Write-Host "  3. 删除脚本"
    Write-Host "  4. 版本回滚"
    Write-Host "  5. 查看脚本列表"
    Write-Host "  6. 运行脚本"  # 新增菜单选项
    Write-Host "  0. 退出工具"
    Write-Host "========================================================" -ForegroundColor Cyan
}

# -------------------------- 程序入口 --------------------------
# 初始化环境
Initialize-Environment

# 主循环
while ($true) {
    Show-MainMenu
    $choice = Read-Host "`n请输入操作序号"
    
    switch ($choice) {
        "1" { New-Script }
        "2" { Edit-Script }
        "3" { Remove-Script }
        "4" { Rollback-ScriptVersion }
        "5" { Show-ScriptList }
        "6" { Run-Script }  # 新增分支处理
        "0" { 
            Write-Host "👋 感谢使用，再见！" -ForegroundColor Green
            exit 0 
        }
        default {
            Write-Host "❌ 输入无效，请输入0-6之间的数字！" -ForegroundColor Red
            Read-Host "按任意键返回菜单"
        }
    }
}