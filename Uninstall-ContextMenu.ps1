<#
.SYNOPSIS
    卸载"合并图片"右键菜单。
.DESCRIPTION
    从当前用户注册表中移除 image 文件类型的 "MergeImages" shell 动词。
.NOTES
    文件名: Uninstall-ContextMenu.ps1
#>

$ErrorActionPreference = 'Stop'

$verbName = 'MergeImages'
$verbPath = "HKCU:\Software\Classes\SystemFileAssociations\image\shell\$verbName"

if (Test-Path -LiteralPath $verbPath) {
    Remove-Item -Path $verbPath -Recurse -Force
    Write-Host ""
    Write-Host "✅ 右键菜单已成功卸载。" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "未找到已安装的 ""合并图片"" 右键菜单，无需卸载。" -ForegroundColor Yellow
}
Write-Host ""
