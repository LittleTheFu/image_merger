<#
.SYNOPSIS
    将多张图片从上到下依次合并为一张图片。
.DESCRIPTION
    通过命令行参数接收多张图片路径，按顺序纵向拼接，
    画布宽度取所有图片的最大宽度，较窄的图片水平居中，
    背景为白色。合并结果保存到第一张图片所在目录。
.NOTES
    文件名: Merge-Images.ps1
#>

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Files
)

# 如果没有通过命名参数传入，则使用 $args 兜底（右键菜单调用时可能走这里）
if (-not $Files -or $Files.Count -eq 0) {
    $Files = $args
}

# 过滤出真实存在的图片文件
$imageExts = @('.jpg', '.jpeg', '.png', '.bmp', '.gif', '.tif', '.tiff', '.webp')
$validFiles = @()
foreach ($f in $Files) {
    if ($f -and (Test-Path -LiteralPath $f) -and
        $imageExts -contains ([System.IO.Path]::GetExtension($f).ToLower())) {
        $validFiles += (Resolve-Path -LiteralPath $f).Path
    }
}

if ($validFiles.Count -eq 0) {
    [System.Windows.Forms.MessageBox]::Show(
        '没有找到有效的图片文件。', '合并图片',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    exit 1
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$bitmaps = New-Object 'System.Collections.Generic.List[System.Drawing.Bitmap]'
try {
    # 加载所有图片
    foreach ($file in $validFiles) {
        $bmp = [System.Drawing.Bitmap]::FromFile($file)
        $bitmaps.Add($bmp)
    }

    # 计算画布宽度（取最大值）和总高度
    # 注意：Measure-Object 返回 Double，而 Bitmap 构造函数需要 int，必须显式转换
    $canvasWidth = [int](($bitmaps | Measure-Object -Property Width -Maximum).Maximum)
    $totalHeight = [int](($bitmaps | Measure-Object -Property Height -Sum).Sum)

    # 创建画布
    $result = New-Object System.Drawing.Bitmap($canvasWidth, $totalHeight)
    $graphics = [System.Drawing.Graphics]::FromImage($result)
    try {
        $graphics.Clear([System.Drawing.Color]::White)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

        $y = 0
        foreach ($bmp in $bitmaps) {
            $x = [int](($canvasWidth - $bmp.Width) / 2)
            $graphics.DrawImage($bmp, $x, $y, $bmp.Width, $bmp.Height)
            $y += $bmp.Height
        }
    }
    finally {
        $graphics.Dispose()
    }

    # 保存到第一张图片所在目录
    $saveDir = Split-Path -Parent $validFiles[0]
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $savePath = Join-Path $saveDir "合并图片_$timestamp.png"

    $result.Save($savePath, [System.Drawing.Imaging.ImageFormat]::Png)
    $result.Dispose()

    # 提示完成并打开所在文件夹
    [System.Windows.Forms.MessageBox]::Show(
        "合并完成！共 $($bitmaps.Count) 张图片，已保存到：`r`n$savePath",
        '合并图片',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null

    # 打开资源管理器并定位到生成的文件
    explorer.exe /select,"$savePath"
}
finally {
    foreach ($bmp in $bitmaps) {
        if ($bmp) { $bmp.Dispose() }
    }
}
