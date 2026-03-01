<#
.SYNOPSIS
    PowerShell 脚本管理工具 GUI 版 (v1.0)
.DESCRIPTION
    基于 WPF 的图形化脚本管理界面，支持脚本的可视化管理、运行、编辑、备份与回滚。
    兼容环境：PowerShell 5.1+ (Windows 10/11)
#>

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, Microsoft.VisualBasic

# -------------------------- 配置区 --------------------------
$ScriptRootPath = "D:\powershell_manage\Scripts"
$VersionBackupPath = "D:\powershell_manage\VersionBackup"
$MetaDataFile = "D:\powershell_manage\ScriptMetaData.json"

# -------------------------- 核心逻辑函数 (复用自 CLI 版) --------------------------
function Initialize-Environment {
    try {
        if (-not (Test-Path -Path $ScriptRootPath)) { New-Item -Path $ScriptRootPath -ItemType Directory -Force | Out-Null }
        if (-not (Test-Path -Path $VersionBackupPath)) { New-Item -Path $VersionBackupPath -ItemType Directory -Force | Out-Null }
        if (-not (Test-Path -Path $MetaDataFile)) {
            @{} | ConvertTo-Json | Out-File -FilePath $MetaDataFile -Encoding utf8
        }
    } catch { [System.Windows.MessageBox]::Show("环境初始化失败: $_", "错误", "OK", "Error") }
}

function Get-ScriptMetaData {
    try { return Get-Content -Path $MetaDataFile -Encoding utf8 | ConvertFrom-Json }
    catch { return $null }
}

function Save-ScriptMetaData {
    param ($MetaData)
    try { $MetaData | ConvertTo-Json -Depth 10 | Out-File -FilePath $MetaDataFile -Encoding utf8; return $true }
    catch { return $false }
}

function Backup-ScriptVersion {
    param ([string]$ScriptName)
    try {
        $metaData = Get-ScriptMetaData
        if (-not $metaData.$ScriptName) { return $false }
        $currentVersion = if ($metaData.$ScriptName.Version) { $metaData.$ScriptName.Version } else { 1 }
        $backupFileName = "$ScriptName`_v$currentVersion.ps1"
        $sourcePath = "$ScriptRootPath\$ScriptName.ps1"
        $backupPath = "$VersionBackupPath\$backupFileName"
        Copy-Item -Path $sourcePath -Destination $backupPath -Force
        $metaData.$ScriptName.Version = $currentVersion + 1
        Save-ScriptMetaData -MetaData $metaData
        return $true
    } catch { return $false }
}

# -------------------------- UI 定义 (WPF XAML) --------------------------
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="🛠️ PowerShell 脚本管理工具 v1.0" Height="550" Width="850" Background="#F3F3F3" WindowStartupLocation="CenterScreen">
    <Grid Margin="10">
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="2*"/>
            <ColumnDefinition Width="1*"/>
        </Grid.ColumnDefinitions>
        
        <!-- 左侧列表区 -->
        <DockPanel Grid.Column="0" Margin="0,0,10,0">
            <TextBlock DockPanel.Dock="Top" Text="📦 已安装脚本列表" FontSize="18" FontWeight="Bold" Margin="0,0,0,10" Foreground="#333"/>
            <ListView x:Name="ScriptListView" BorderThickness="1" BorderBrush="#DDD" SelectionMode="Single">
                <ListView.View>
                    <GridView>
                        <GridViewColumn Header="名称" DisplayMemberBinding="{Binding Name}" Width="150"/>
                        <GridViewColumn Header="版本" DisplayMemberBinding="{Binding Version}" Width="60"/>
                        <GridViewColumn Header="创建时间" DisplayMemberBinding="{Binding CreateTime}" Width="140"/>
                        <GridViewColumn Header="描述" DisplayMemberBinding="{Binding Description}" Width="180"/>
                    </GridView>
                </ListView.View>
            </ListView>
        </DockPanel>

        <!-- 右侧操作区与详情区 -->
        <Grid Grid.Column="1">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>

            <!-- 操作区 -->
            <StackPanel Grid.Row="0">
                <TextBlock Text="🛠️ 脚本操作" FontSize="18" FontWeight="Bold" Margin="0,0,0,10" Foreground="#333"/>
                <Border Background="White" BorderThickness="1" BorderBrush="#DDD" Padding="10" CornerRadius="5">
                    <StackPanel>
                        <Button x:Name="BtnRun" Content="🚀 运行脚本" Height="40" Margin="0,0,0,10" Background="#4CAF50" Foreground="White" FontWeight="Bold" Cursor="Hand"/>
                        <Button x:Name="BtnEdit" Content="📝 修改脚本" Height="40" Margin="0,0,0,10" Background="#2196F3" Foreground="White" FontWeight="Bold" Cursor="Hand"/>
                        <Button x:Name="BtnRollback" Content="🔄 版本回滚" Height="40" Margin="0,0,0,10" Background="#FF9800" Foreground="White" FontWeight="Bold" Cursor="Hand"/>
                        <Button x:Name="BtnDelete" Content="🗑️ 删除脚本" Height="40" Margin="0,0,0,20" Background="#F44336" Foreground="White" FontWeight="Bold" Cursor="Hand"/>
                        
                        <Separator Margin="0,0,0,20"/>
                        
                        <Button x:Name="BtnAdd" Content="✨ 新增脚本" Height="40" Margin="0,0,0,10" Background="#9C27B0" Foreground="White" FontWeight="Bold" Cursor="Hand"/>
                        <Button x:Name="BtnRefresh" Content="🔃 刷新列表" Height="40" Background="#757575" Foreground="White" FontWeight="Bold" Cursor="Hand"/>
                    </StackPanel>
                </Border>
            </StackPanel>

            <!-- 详情展示 (自动填充剩余空间) -->
            <DockPanel Grid.Row="1" Margin="0,15,0,0">
                <TextBlock DockPanel.Dock="Top" Text="🔍 脚本详情" FontSize="16" FontWeight="Bold" Margin="0,0,0,5" Foreground="#333"/>
                <Border Background="#E1F5FE" BorderThickness="1" BorderBrush="#B3E5FC" Padding="10" CornerRadius="5">
                    <ScrollViewer VerticalScrollBarVisibility="Auto">
                        <TextBlock x:Name="TxtDetail" TextWrapping="Wrap" Text="请选择一个脚本以查看详情..." Foreground="#01579B"/>
                    </ScrollViewer>
                </Border>
            </DockPanel>
        </Grid>
    </Grid>
</Window>
"@

# 加载 XAML
$reader = New-Object System.Xml.XmlNodeReader([xml]$xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# 获取控件引用
$scriptListView = $window.FindName("ScriptListView")
$btnRun = $window.FindName("BtnRun")
$btnEdit = $window.FindName("BtnEdit")
$btnRollback = $window.FindName("BtnRollback")
$btnDelete = $window.FindName("BtnDelete")
$btnAdd = $window.FindName("BtnAdd")
$btnRefresh = $window.FindName("BtnRefresh")
$txtDetail = $window.FindName("TxtDetail")

# -------------------------- UI 交互函数 --------------------------
function Update-ListView {
    $scriptListView.ItemsSource = $null
    $items = @()
    $metaData = Get-ScriptMetaData
    
    Get-ChildItem -Path $ScriptRootPath -Filter "*.ps1" | ForEach-Object {
        $name = $_.BaseName
        $meta = $metaData.$name
        $items += [PSCustomObject]@{
            Name        = $name
            Version     = if ($meta.Version) { "v$($meta.Version)" } else { "v1" }
            CreateTime  = if ($meta.CreateTime) { $meta.CreateTime } else { $_.CreationTime.ToString("yyyy-MM-dd HH:mm") }
            Description = if ($meta.Description) { $meta.Description } else { "无描述" }
            FullPath    = $_.FullName
        }
    }
    $scriptListView.ItemsSource = $items
}

# -------------------------- 事件绑定 --------------------------
# 选择变更事件
$scriptListView.add_SelectionChanged({
    $selected = $scriptListView.SelectedItem
    if ($selected) {
        $txtDetail.Text = "【名称】: $($selected.Name)`n【版本】: $($selected.Version)`n【创建时间】: $($selected.CreateTime)`n【路径】: $($selected.FullPath)`n`n【功能介绍】:`n$($selected.Description)"
    }
})

# 刷新
$btnRefresh.Add_Click({ Update-ListView })

# 运行
$btnRun.Add_Click({
    $selected = $scriptListView.SelectedItem
    if (-not $selected) { [System.Windows.MessageBox]::Show("请先选择一个脚本！"); return }
    
    # 在新窗口中运行以保持交互
    Start-Process powershell.exe -ArgumentList "-NoExit", "-File", "`"$($selected.FullPath)`""
})

# 修改
$btnEdit.Add_Click({
    $selected = $scriptListView.SelectedItem
    if (-not $selected) { [System.Windows.MessageBox]::Show("请先选择一个脚本！"); return }
    
    if (Backup-ScriptVersion -ScriptName $selected.Name) {
        Start-Process notepad.exe -ArgumentList "`"$($selected.FullPath)`"" -Wait
        Update-ListView
        [System.Windows.MessageBox]::Show("脚本已修改，原版本已备份到 VersionBackup 目录。")
    }
})

# 新增
$btnAdd.Add_Click({
    # 由于 PowerShell 原生 GUI 输入框较复杂，此处采用简单提示或打开一个交互式对话框
    # 为了保持脚本简洁，调用 CLI 版的新增逻辑或弹出输入框
    $name = [Microsoft.VisualBasic.Interaction]::InputBox("请输入新脚本名称 (不含 .ps1):", "新增脚本")
    if ([string]::IsNullOrWhiteSpace($name)) { return }
    
    $path = "$ScriptRootPath\$name.ps1"
    if (Test-Path $path) { [System.Windows.MessageBox]::Show("脚本已存在！"); return }
    
    $desc = [Microsoft.VisualBasic.Interaction]::InputBox("请输入脚本描述:", "脚本描述", "新功能描述")
    
    New-Item -Path $path -ItemType File -Force | Out-Null
    
    # 更新元数据
    $metaData = Get-ScriptMetaData
    $metaData | Add-Member -MemberType NoteProperty -Name $name -Value @{
        Description = $desc
        Version = 1
        CreateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    } -Force
    Save-ScriptMetaData -MetaData $metaData
    
    Start-Process notepad.exe -ArgumentList "`"$path`"" -Wait
    Update-ListView
})

# 删除
$btnDelete.Add_Click({
    $selected = $scriptListView.SelectedItem
    if (-not $selected) { [System.Windows.MessageBox]::Show("请先选择一个脚本！"); return }
    
    $confirm = [System.Windows.MessageBox]::Show("确定要删除脚本 [$($selected.Name)] 及其所有历史版本吗？", "确认删除", "YesNo", "Warning")
    if ($confirm -eq "Yes") {
        Remove-Item -Path $selected.FullPath -Force
        Get-ChildItem -Path $VersionBackupPath -Filter "$($selected.Name)_v*.ps1" | Remove-Item -Force
        
        $metaData = Get-ScriptMetaData
        if ($metaData.PSObject.Properties[$selected.Name]) {
            $metaData.PSObject.Properties.Remove($selected.Name)
            Save-ScriptMetaData -MetaData $metaData
        }
        Update-ListView
    }
})

# 回滚
$btnRollback.Add_Click({
    $selected = $scriptListView.SelectedItem
    if (-not $selected) { [System.Windows.MessageBox]::Show("请先选择一个脚本！"); return }
    
    $backups = Get-ChildItem -Path $VersionBackupPath -Filter "$($selected.Name)_v*.ps1" | Sort-Object LastWriteTime -Descending
    if ($backups.Count -eq 0) { [System.Windows.MessageBox]::Show("未找到历史版本！"); return }
    
    # 简单起见，回滚到最近的一个版本
    $latestBackup = $backups[0]
    $confirm = [System.Windows.MessageBox]::Show("确定回滚到版本: $($latestBackup.Name) ?", "确认回滚", "YesNo")
    if ($confirm -eq "Yes") {
        # 回滚前备份当前
        Backup-ScriptVersion -ScriptName $selected.Name | Out-Null
        Copy-Item -Path $latestBackup.FullName -Destination $selected.FullPath -Force
        Update-ListView
        [System.Windows.MessageBox]::Show("已成功回滚到最近版本。")
    }
})

# -------------------------- 启动 --------------------------
Initialize-Environment
Update-ListView
$window.ShowDialog() | Out-Null
