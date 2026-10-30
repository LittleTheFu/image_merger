<#
.SYNOPSIS
    安装"合并图片"右键菜单。
.DESCRIPTION
    在当前用户注册表中注册 image 文件类型的 shell 动词"合并图片"，
    并配置 MultiSelectModel=Document，使选中多张图片时一次性传入合并脚本。
    无需管理员权限（写入 HKCU）。
.NOTES
    文件名: Install-ContextMenu.ps1
#>

$ErrorActionPreference = 'Stop'

# 合并脚本所在目录（与本脚本同目录）
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$mergeScript = Join-Path $scriptDir 'Merge-Images.ps1'

if (-not (Test-Path -LiteralPath $mergeScript)) {
    Write-Error "找不到合并脚本：$mergeScript"
    exit 1
}

# 转义路径中的双引号（防御性处理）
$escapedScript = $mergeScript -replace '"', '\"'

# 右键菜单动词名
$verbName = 'MergeImages'
$menuText = 'Merge Images'

# 注册表根：HKCU\Software\Classes（当前用户，无需管理员）
$regRoot = 'HKCU:\Software\Classes'
$imageShell = Join-Path $regRoot 'SystemFileAssociations\image\shell'
$verbPath = Join-Path $imageShell $verbName
$commandPath = Join-Path $verbPath 'command'

# 确保 image\shell 存在
if (-not (Test-Path -LiteralPath $imageShell)) {
    New-Item -Path $imageShell -Force | Out-Null
}

# 如果已存在同名动词，先移除
if (Test-Path -LiteralPath $verbPath) {
    Remove-Item -Path $verbPath -Recurse -Force
}

# 创建动词
New-Item -Path $verbPath -Force | Out-Null

# 显示名称
Set-ItemProperty -Path $verbPath -Name '(Default)' -Value $menuText

# 图标：使用系统自带的图片查看器图标
# imageres.dll,-72 是图片相关图标
Set-ItemProperty -Path $verbPath -Name 'Icon' -Value 'imageres.dll,-72'

# 关键：多文件选择时一次性把所有文件作为参数传给命令
Set-ItemProperty -Path $verbPath -Name 'MultiSelectModel' -Value 'Document'

# 不显示扩展（即不需要 Shift+右键也显示）
Set-ItemProperty -Path $verbPath -Name 'Extended' -Value '' -Type String
# 上面这行会让它仅在 Shift+右键时显示，我们要常态显示，所以删除它
Remove-ItemProperty -Path $verbPath -Name 'Extended' -ErrorAction SilentlyContinue

# 创建 command 子键
New-Item -Path $commandPath -Force | Out-Null

# 命令：调用 powershell 执行合并脚本
# -NoProfile 加快启动；-ExecutionPolicy Bypass 绕过脚本执行策略；%1 由 shell 替换为选中的文件
$command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + $escapedScript + '" %1'
Set-ItemProperty -Path $commandPath -Name '(Default)' -Value $command

Write-Host ""
Write-Host "✅ 右键菜单安装成功！" -ForegroundColor Green
Write-Host ""
Write-Host "使用方法：" -ForegroundColor Cyan
Write-Host "  1. 在资源管理器中选中一张或多张图片"
Write-Host "  2. 点击鼠标右键"
Write-Host "  3. 选择 ""Merge Images"""
Write-Host ""
Write-Host "注意：Windows 11 新右键菜单可能需要点击 ""显示更多选项"" 才能看到。" -ForegroundColor Yellow
Write-Host "      也可以按住 Shift 再右键，直接进入经典菜单。" -ForegroundColor Yellow
Write-Host ""
