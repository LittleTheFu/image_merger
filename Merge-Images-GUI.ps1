<#
.SYNOPSIS
    Image Merger GUI - drag and drop images to merge them vertically (top to bottom).
.DESCRIPTION
    A Windows Forms application that lets you drag image files into the window,
    preview and reorder them, then merge them into a single PNG image.
.NOTES
    File name: Merge-Images-GUI.ps1
#>

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

[System.Windows.Forms.Application]::EnableVisualStyles()

$script:imageExts = @('.jpg', '.jpeg', '.png', '.bmp', '.gif', '.tif', '.tiff', '.webp')
$script:fileList = New-Object 'System.Collections.Generic.List[string]'

# ============================================================
# Merge logic
# ============================================================
function Merge-Images {
    param(
        [Parameter(Mandatory = $true)][string[]]$Files,
        [Parameter(Mandatory = $true)][string]$OutputPath
    )

    $bitmaps = New-Object 'System.Collections.Generic.List[System.Drawing.Bitmap]'
    try {
        foreach ($file in $Files) {
            $bitmaps.Add([System.Drawing.Bitmap]::FromFile($file))
        }

        $canvasWidth = [int](($bitmaps | Measure-Object -Property Width -Maximum).Maximum)
        $totalHeight = [int](($bitmaps | Measure-Object -Property Height -Sum).Sum)

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

        $result.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $result.Dispose()
    }
    finally {
        foreach ($bmp in $bitmaps) {
            if ($bmp) { $bmp.Dispose() }
        }
    }
}

# ============================================================
# Helpers
# ============================================================
function Test-IsImageFile {
    param([string]$Path)
    if (-not $Path) { return $false }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    return $script:imageExts -contains ([System.IO.Path]::GetExtension($Path).ToLower())
}

function Get-ImageDimensions {
    param([string]$Path)
    try {
        $img = [System.Drawing.Image]::FromFile($Path)
        $dim = "{0} x {1}" -f $img.Width, $img.Height
        $img.Dispose()
        return $dim
    } catch { return "?" }
}

function Refresh-FileList {
    $lstFiles.BeginUpdate()
    $lstFiles.Items.Clear()
    foreach ($path in $script:fileList) {
        $name = [System.IO.Path]::GetFileName($path)
        $dim = Get-ImageDimensions -Path $path
        $lstFiles.Items.Add("$name   ($dim)")
    }
    $lstFiles.EndUpdate()
    Update-Status
    Update-Preview
    Update-ButtonStates
}

function Update-Status {
    $lblStatus.Text = "Images: {0}" -f $script:fileList.Count
}

function Update-ButtonStates {
    $hasItems = $script:fileList.Count -gt 0
    $hasSelection = $lstFiles.SelectedIndex -ge 0
    $btnRemove.Enabled = $hasSelection
    $btnClear.Enabled = $hasItems
    $btnMerge.Enabled = $hasItems
    $btnUp.Enabled = $hasSelection -and $lstFiles.SelectedIndex -gt 0
    $btnDown.Enabled = $hasSelection -and $lstFiles.SelectedIndex -lt ($script:fileList.Count - 1)
}

function Update-Preview {
    $pbPreview.Image = $null
    if ($lstFiles.SelectedIndex -ge 0 -and $lstFiles.SelectedIndex -lt $script:fileList.Count) {
        $path = $script:fileList[$lstFiles.SelectedIndex]
        try {
            $img = [System.Drawing.Image]::FromFile($path)
            $pbPreview.Image = $img
        } catch { }
    }
}

function Add-Files {
    param([string[]]$Paths)
    $added = 0
    foreach ($p in $Paths) {
        if (Test-IsImageFile -Path $p) {
            $full = (Resolve-Path -LiteralPath $p).Path
            if (-not $script:fileList.Contains($full)) {
                $script:fileList.Add($full)
                $added++
            }
        }
    }
    if ($added -gt 0) {
        Refresh-FileList
        $lstFiles.SelectedIndex = $lstFiles.Items.Count - 1
    }
}

# ============================================================
# GUI
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Image Merger'
$form.Size = New-Object System.Drawing.Size(760, 560)
$form.MinimumSize = New-Object System.Drawing.Size(600, 400)
$form.StartPosition = 'CenterScreen'
$form.AllowDrop = $true
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$form.BackColor = [System.Drawing.Color]::White

# --- Top hint label ---
$lblHint = New-Object System.Windows.Forms.Label
$lblHint.Text = 'Drag & drop images here, or click Add Files'
$lblHint.AutoSize = $false
$lblHint.Location = New-Object System.Drawing.Point(12, 10)
$lblHint.Size = New-Object System.Drawing.Size(720, 24)
$lblHint.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$lblHint.ForeColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
$form.Controls.Add($lblHint)

# --- List of files ---
$lstFiles = New-Object System.Windows.Forms.ListBox
$lstFiles.Location = New-Object System.Drawing.Point(12, 42)
$lstFiles.Size = New-Object System.Drawing.Size(430, 380)
$lstFiles.AllowDrop = $true
$lstFiles.IntegralHeight = $false
$form.Controls.Add($lstFiles)

# --- Preview ---
$pbPreview = New-Object System.Windows.Forms.PictureBox
$pbPreview.Location = New-Object System.Drawing.Point(454, 42)
$pbPreview.Size = New-Object System.Drawing.Size(280, 380)
$pbPreview.SizeMode = 'Zoom'
$pbPreview.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
$pbPreview.BorderStyle = 'FixedSingle'
$form.Controls.Add($pbPreview)

# --- Action buttons ---
$btnAdd = New-Object System.Windows.Forms.Button
$btnAdd.Text = 'Add Files...'
$btnAdd.Location = New-Object System.Drawing.Point(12, 432)
$btnAdd.Size = New-Object System.Drawing.Size(90, 30)
$form.Controls.Add($btnAdd)

$btnRemove = New-Object System.Windows.Forms.Button
$btnRemove.Text = 'Remove'
$btnRemove.Location = New-Object System.Drawing.Point(108, 432)
$btnRemove.Size = New-Object System.Drawing.Size(80, 30)
$btnRemove.Enabled = $false
$form.Controls.Add($btnRemove)

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text = 'Clear'
$btnClear.Location = New-Object System.Drawing.Point(196, 432)
$btnClear.Size = New-Object System.Drawing.Size(80, 30)
$btnClear.Enabled = $false
$form.Controls.Add($btnClear)

$btnUp = New-Object System.Windows.Forms.Button
$btnUp.Text = 'Up'
$btnUp.Location = New-Object System.Drawing.Point(284, 432)
$btnUp.Size = New-Object System.Drawing.Size(60, 30)
$btnUp.Enabled = $false
$form.Controls.Add($btnUp)

$btnDown = New-Object System.Windows.Forms.Button
$btnDown.Text = 'Down'
$btnDown.Location = New-Object System.Drawing.Point(350, 432)
$btnDown.Size = New-Object System.Drawing.Size(60, 30)
$btnDown.Enabled = $false
$form.Controls.Add($btnDown)

# --- Merge button ---
$btnMerge = New-Object System.Windows.Forms.Button
$btnMerge.Text = 'Merge Images'
$btnMerge.Location = New-Object System.Drawing.Point(12, 472)
$btnMerge.Size = New-Object System.Drawing.Size(722, 40)
$btnMerge.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$btnMerge.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$btnMerge.ForeColor = [System.Drawing.Color]::White
$btnMerge.FlatStyle = 'Flat'
$btnMerge.Enabled = $false
$form.Controls.Add($btnMerge)

# --- Status label ---
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = 'Images: 0'
$lblStatus.Location = New-Object System.Drawing.Point(12, 520)
$lblStatus.Size = New-Object System.Drawing.Size(720, 20)
$lblStatus.ForeColor = [System.Drawing.Color]::Gray
$form.Controls.Add($lblStatus)

# ============================================================
# Event handlers
# ============================================================

# Common drag-drop logic
$onDragEnter = {
    param($sender, $e)
    if ($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
        $e.Effect = [System.Windows.Forms.DragDropEffects]::Copy
    } else {
        $e.Effect = [System.Windows.Forms.DragDropEffects]::None
    }
}

$onDragDrop = {
    param($sender, $e)
    $files = $e.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)
    if ($files) { Add-Files -Paths $files }
}

$form.Add_DragEnter($onDragEnter)
$form.Add_DragDrop($onDragDrop)
$lstFiles.Add_DragEnter($onDragEnter)
$lstFiles.Add_DragDrop($onDragDrop)

# Add Files button
$btnAdd.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = 'Select images'
    $dlg.Filter = 'Images|*.jpg;*.jpeg;*.png;*.bmp;*.gif;*.tif;*.tiff;*.webp|All files|*.*'
    $dlg.Multiselect = $true
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        Add-Files -Paths $dlg.FileNames
    }
})

# Remove button
$btnRemove.Add_Click({
    $idx = $lstFiles.SelectedIndex
    if ($idx -ge 0) {
        $script:fileList.RemoveAt($idx)
        Refresh-FileList
        if ($script:fileList.Count -gt 0) {
            $newIdx = [Math]::Min($idx, $script:fileList.Count - 1)
            $lstFiles.SelectedIndex = $newIdx
        }
    }
})

# Clear button
$btnClear.Add_Click({
    $script:fileList.Clear()
    Refresh-FileList
})

# Up button
$btnUp.Add_Click({
    $idx = $lstFiles.SelectedIndex
    if ($idx -gt 0) {
        $tmp = $script:fileList[$idx]
        $script:fileList[$idx] = $script:fileList[$idx - 1]
        $script:fileList[$idx - 1] = $tmp
        Refresh-FileList
        $lstFiles.SelectedIndex = $idx - 1
    }
})

# Down button
$btnDown.Add_Click({
    $idx = $lstFiles.SelectedIndex
    if ($idx -ge 0 -and $idx -lt $script:fileList.Count - 1) {
        $tmp = $script:fileList[$idx]
        $script:fileList[$idx] = $script:fileList[$idx + 1]
        $script:fileList[$idx + 1] = $tmp
        Refresh-FileList
        $lstFiles.SelectedIndex = $idx + 1
    }
})

# List selection changed -> update preview
$lstFiles.Add_SelectedIndexChanged({ Update-Preview; Update-ButtonStates })

# Merge button
$btnMerge.Add_Click({
    if ($script:fileList.Count -eq 0) { return }

    $defaultDir = Split-Path -Parent $script:fileList[0]
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $defaultName = "merged_$timestamp.png"

    $saveDlg = New-Object System.Windows.Forms.SaveFileDialog
    $saveDlg.Title = 'Save merged image'
    $saveDlg.Filter = 'PNG Image|*.png'
    $saveDlg.InitialDirectory = $defaultDir
    $saveDlg.FileName = $defaultName
    $saveDlg.OverwritePrompt = $true

    if ($saveDlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }

    $outputPath = $saveDlg.FileName

    try {
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $btnMerge.Enabled = $false
        $lblStatus.Text = 'Merging...'
        [System.Windows.Forms.Application]::DoEvents()

        Merge-Images -Files $script:fileList.ToArray() -OutputPath $outputPath

        $result = [System.Windows.Forms.MessageBox]::Show(
            $form,
            "Merge complete!`nSaved to:`n$outputPath`n`nOpen the file?",
            'Image Merger',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Information)

        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            explorer.exe /select,"$outputPath"
        }
        $lblStatus.Text = 'Merge complete.'
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            $form,
            "Merge failed:`n$($_.Exception.Message)",
            'Error',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        $lblStatus.Text = 'Merge failed.'
    } finally {
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        $btnMerge.Enabled = $true
        Update-ButtonStates
    }
})

# Initialize
Refresh-FileList

# Show the form
[void]$form.ShowDialog()
