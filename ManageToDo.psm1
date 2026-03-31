#requires -Version 5.1

# スクリプト全体で共有する永続データ
# if (-not $script:ToDoDataDir)  { $script:ToDoDataDir  = Join-Path $env:LOCALAPPDATA 'InterruptToDo' }
# if (-not $script:ToDoDataPath) { $script:ToDoDataPath = Join-Path $script:ToDoDataDir 'ToDoTasks.json' }
# if (-not $script:ToDoTasks)    { $script:ToDoTasks    = @() }

function ToDo([switch]$VertionCheck) {

	if( $VertionCheck ){
		$ModuleName = "ManageToDo"
		$GitHubName = "MuraAtVwnet"

		$HomeDirectory = "~/"
		$Module = $ModuleName + ".psm1"
		$Installer = "Install" + $ModuleName + ".ps1"
		$Uninstaller = "Uninstall" + $ModuleName + ".ps1"
		$Vertion = "Vertion" + $ModuleName + ".txt"
		$GithubCommonURI = "https://raw.githubusercontent.com/$GitHubName/$ModuleName/refs/heads/main/"
		$VertionTemp = "VertionTemp" + $ModuleName + ".tmp"
		$VertionFilePath = Join-Path "~/" $Vertion
		$VertionTempFilePath = Join-Path "~/" $VertionTemp
		$VertionFileURI = $GithubCommonURI + "Vertion.txt"


		$Update = $False

		if( -not (Test-Path $VertionFilePath)){
			$Update = $True
		}
		else{
			$LocalVertion = Get-Content -Path $VertionFilePath

			$URI = $VertionFileURI
			$OutFile = $VertionTempFilePath
			Invoke-WebRequest -Uri $URI -OutFile $OutFile
			$NowVertion = Get-Content -Path $VertionTempFilePath
			Remove-Item $VertionTempFilePath

			if( $LocalVertion -ne $NowVertion ){
				$Update = $True
			}
		}

		if( $Update ){
			Write-Output "最新版に更新します"
			Write-Output "更新完了後、PowerShell プロンプトを開きなおしてください"

			$URI = $GithubCommonURI + $Module
			$ModuleFile = $HomeDirectory + $Module
			Invoke-WebRequest -Uri $URI -OutFile $ModuleFile

			$URI = $GithubCommonURI + "Install.ps1"
			$InstallerFile = $HomeDirectory + $Installer
			Invoke-WebRequest -Uri $URI -OutFile $InstallerFile

			$URI = $GithubCommonURI + "Uninstall.ps1"
			$OutFile = $HomeDirectory + $Uninstaller
			Invoke-WebRequest -Uri $URI -OutFile $OutFile

			$URI = $GithubCommonURI + "Vertion.txt"
			$OutFile = $HomeDirectory + $Vertion
			Invoke-WebRequest -Uri $URI -OutFile $OutFile

			& $InstallerFile

			Remove-Item $ModuleFile
			Remove-Item $InstallerFile

			Write-Output "更新完了"
			Write-Output "PowerShell プロンプトを開きなおしてください"
		}
		else{
			Write-Output "更新の必要はありません"
		}
		return
	}

	# 以下本来のコード

    & {
        if ([string]::IsNullOrWhiteSpace($script:ToDoDataDir)) {
            $script:ToDoDataDir = Join-Path $env:LOCALAPPDATA 'InterruptToDo'
        }
        if ([string]::IsNullOrWhiteSpace($script:ToDoDataPath)) {
            $script:ToDoDataPath = Join-Path $script:ToDoDataDir 'ToDoTasks.json'
        }
        if ([string]::IsNullOrWhiteSpace($script:ToDoSettingsPath)) {
            $script:ToDoSettingsPath = Join-Path $script:ToDoDataDir 'ToDoSettings.json'
        }
        if ($null -eq $script:ToDoTasks) {
            $script:ToDoTasks = @()
        }
        if ($null -eq $script:ToDoInternalState) {
            $script:ToDoInternalState = [PSCustomObject]@{
                RefreshingList    = $false
                SuppressItemCheck = $false
            }
        }

        Add-Type -AssemblyName System.Windows.Forms | Out-Null
        Add-Type -AssemblyName System.Drawing | Out-Null
        [void][System.Windows.Forms.Application]::EnableVisualStyles()

        $ensureDirectory = {
            if ([string]::IsNullOrWhiteSpace($script:ToDoDataDir)) { return }
            if (-not (Test-Path -LiteralPath $script:ToDoDataDir)) {
                [void](New-Item -ItemType Directory -Path $script:ToDoDataDir -Force)
            }
        }

        $normalizeDateValue = {
            param(
                [object]$Value,
                [object]$Fallback
            )

            if ($null -eq $Value) { return $Fallback }
            if ($Value -is [datetime]) { return $Value }

            if ($Value -is [string]) {
                $parsed = [datetime]::MinValue
                if ([datetime]::TryParse($Value, [ref]$parsed)) {
                    return $parsed
                }
                return $Fallback
            }

            if ($Value -is [psobject]) {
                $props = $Value.PSObject.Properties

                foreach ($name in @('DateTime', 'dateTime', 'Value', 'value')) {
                    if ($props[$name]) {
                        return & $normalizeDateValue $props[$name].Value $Fallback
                    }
                }

                $allDateParts = $true
                foreach ($name in @('Year', 'Month', 'Day')) {
                    if (-not $props[$name]) {
                        $allDateParts = $false
                        break
                    }
                }

                if ($allDateParts) {
                    try {
                        return [datetime]::new(
                            [int]$props['Year'].Value,
                            [int]$props['Month'].Value,
                            [int]$props['Day'].Value,
                            $(if ($props['Hour'])   { [int]$props['Hour'].Value }   else { 0 }),
                            $(if ($props['Minute']) { [int]$props['Minute'].Value } else { 0 }),
                            $(if ($props['Second']) { [int]$props['Second'].Value } else { 0 })
                        )
                    }
                    catch {
                    }
                }
            }

            return $Fallback
        }

        $loadTasks = {
            if ([string]::IsNullOrWhiteSpace($script:ToDoDataPath)) {
                $script:ToDoTasks = @()
                return
            }

            if (-not (Test-Path -LiteralPath $script:ToDoDataPath)) {
                $script:ToDoTasks = @()
                return
            }

            try {
                $json = Get-Content -LiteralPath $script:ToDoDataPath -Raw -ErrorAction Stop
                if ([string]::IsNullOrWhiteSpace($json)) {
                    $script:ToDoTasks = @()
                    return
                }

                $loaded = $json | ConvertFrom-Json -ErrorAction Stop

                if ($null -eq $loaded) {
                    $script:ToDoTasks = @()
                }
                elseif ($loaded -is [System.Collections.IEnumerable] -and -not ($loaded -is [string])) {
                    $script:ToDoTasks = @($loaded)
                }
                else {
                    $script:ToDoTasks = @($loaded)
                }
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show(
                    "タスク読み込みエラー:`n$($_.Exception.Message)",
                    'ToDo',
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                ) | Out-Null
                $script:ToDoTasks = @()
            }
        }

        $ensureTaskSchema = {
            foreach ($t in @($script:ToDoTasks)) {
                if ($null -eq $t) { continue }

                $props = $t.PSObject.Properties

                if (-not $props['Id'])          { $t | Add-Member -NotePropertyName Id          -NotePropertyValue ([guid]::NewGuid().ToString()) -Force }
                if (-not $props['Title'])       { $t | Add-Member -NotePropertyName Title       -NotePropertyValue '' -Force }
                if (-not $props['Description']) { $t | Add-Member -NotePropertyName Description -NotePropertyValue '' -Force }
                if (-not $props['IsCompleted']) { $t | Add-Member -NotePropertyName IsCompleted -NotePropertyValue $false -Force }
                if (-not $props['CreatedAt'])   { $t | Add-Member -NotePropertyName CreatedAt   -NotePropertyValue (Get-Date) -Force }
                if (-not $props['CompletedAt']) { $t | Add-Member -NotePropertyName CompletedAt -NotePropertyValue $null -Force }
                if (-not $props['DueDate'])     { $t | Add-Member -NotePropertyName DueDate     -NotePropertyValue $null -Force }
            }
        }

        $normalizeTaskDates = {
            foreach ($t in @($script:ToDoTasks)) {
                if ($null -eq $t) { continue }

                $t | Add-Member -NotePropertyName CreatedAt   -NotePropertyValue (& $normalizeDateValue $t.CreatedAt   (Get-Date)) -Force
                $t | Add-Member -NotePropertyName CompletedAt -NotePropertyValue (& $normalizeDateValue $t.CompletedAt $null) -Force
                $t | Add-Member -NotePropertyName DueDate     -NotePropertyValue (& $normalizeDateValue $t.DueDate     $null) -Force

                try {
                    $t.IsCompleted = [bool]$t.IsCompleted
                }
                catch {
                    $t | Add-Member -NotePropertyName IsCompleted -NotePropertyValue $false -Force
                }

                if ([string]::IsNullOrWhiteSpace([string]$t.Id)) {
                    $t | Add-Member -NotePropertyName Id -NotePropertyValue ([guid]::NewGuid().ToString()) -Force
                }
                if ($null -eq $t.Title) {
                    $t | Add-Member -NotePropertyName Title -NotePropertyValue '' -Force
                }
                if ($null -eq $t.Description) {
                    $t | Add-Member -NotePropertyName Description -NotePropertyValue '' -Force
                }
            }
        }

        $saveTasks = {
            try {
                & $ensureDirectory
                if ([string]::IsNullOrWhiteSpace($script:ToDoDataPath)) { return }

                $script:ToDoTasks |
                    ConvertTo-Json -Depth 8 |
                    Out-File -FilePath $script:ToDoDataPath -Encoding UTF8 -Force
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show(
                    "タスク保存エラー:`n$($_.Exception.Message)",
                    'ToDo',
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                ) | Out-Null
            }
        }

        $loadSettings = {
            $settings = [PSCustomObject]@{
                SplitterDistance = 250
                WindowWidth      = 900
                WindowHeight     = 680
            }

            if ([string]::IsNullOrWhiteSpace($script:ToDoSettingsPath)) { return $settings }
            if (-not (Test-Path -LiteralPath $script:ToDoSettingsPath)) { return $settings }

            try {
                $json = Get-Content -LiteralPath $script:ToDoSettingsPath -Raw -ErrorAction Stop
                if ([string]::IsNullOrWhiteSpace($json)) { return $settings }

                $loaded = $json | ConvertFrom-Json -ErrorAction Stop
                if ($null -ne $loaded) {
                    if ($loaded.PSObject.Properties['SplitterDistance'] -and $null -ne $loaded.SplitterDistance) {
                        $settings.SplitterDistance = [int]$loaded.SplitterDistance
                    }
                    if ($loaded.PSObject.Properties['WindowWidth'] -and $null -ne $loaded.WindowWidth) {
                        $settings.WindowWidth = [int]$loaded.WindowWidth
                    }
                    if ($loaded.PSObject.Properties['WindowHeight'] -and $null -ne $loaded.WindowHeight) {
                        $settings.WindowHeight = [int]$loaded.WindowHeight
                    }
                }

                return $settings
            }
            catch {
                return $settings
            }
        }

        $saveSettings = {
            param(
                [int]$SplitterDistance,
                [int]$WindowWidth,
                [int]$WindowHeight
            )

            try {
                & $ensureDirectory
                if ([string]::IsNullOrWhiteSpace($script:ToDoSettingsPath)) { return }

                $settings = [PSCustomObject]@{
                    SplitterDistance = $SplitterDistance
                    WindowWidth      = $WindowWidth
                    WindowHeight     = $WindowHeight
                }

                $settings |
                    ConvertTo-Json -Depth 3 |
                    Out-File -FilePath $script:ToDoSettingsPath -Encoding UTF8 -Force
            }
            catch {
            }
        }

        $parseDueDate = {
            param([string]$Text)

            $Text = $Text.Trim()
            if (-not $Text) { return $null }

            $matches = [System.Text.RegularExpressions.Regex]::Matches($Text, '\d+')
            $nums = @()

            foreach ($m in $matches) {
                try {
                    $nums += [int]$m.Value
                }
                catch {
                    throw "期限の数字部分を解釈できませんでした。"
                }
            }

            if ($nums.Count -eq 0) {
                throw "期限に数字が含まれていません。"
            }

            $today = (Get-Date).Date

            switch ($nums.Count) {
                1 {
                    $day = $nums[0]
                    if ($day -lt 1 -or $day -gt 31) {
                        throw "期限の『日』は 1～31 で指定してください。"
                    }

                    $year  = $today.Year
                    $month = $today.Month

                    for ($i = 0; $i -lt 24; $i++) {
                        $daysInMonth = [datetime]::DaysInMonth($year, $month)
                        if ($day -le $daysInMonth) {
                            $candidate = [datetime]::new($year, $month, $day)
                            if ($candidate -ge $today) {
                                return $candidate.Date
                            }
                        }

                        $month++
                        if ($month -gt 12) {
                            $month = 1
                            $year++
                        }
                    }

                    throw "期限の日付を将来日に解釈できませんでした。"
                }

                2 {
                    $month = $nums[0]
                    $day   = $nums[1]

                    if ($month -lt 1 -or $month -gt 12) {
                        throw "期限の『月』は 1～12 で指定してください。"
                    }
                    if ($day -lt 1 -or $day -gt 31) {
                        throw "期限の『日』は 1～31 で指定してください。"
                    }

                    $year = $today.Year
                    if ($day -gt [datetime]::DaysInMonth($year, $month)) {
                        throw "指定された月 $month に日 $day は存在しません。"
                    }

                    $candidate = [datetime]::new($year, $month, $day)
                    if ($candidate -lt $today) {
                        $year++
                        if ($day -gt [datetime]::DaysInMonth($year, $month)) {
                            throw "指定された月日を将来日に解釈できません。"
                        }
                        $candidate = [datetime]::new($year, $month, $day)
                    }

                    return $candidate.Date
                }

                3 {
                    $year  = $nums[0]
                    $month = $nums[1]
                    $day   = $nums[2]

                    try {
                        return ([datetime]::new($year, $month, $day)).Date
                    }
                    catch {
                        throw "期限の年月日が不正です（年/月/日 で指定してください）。"
                    }
                }

                default {
                    throw "期限の形式が不正です（指定できるのは 日 / 月日 / 年月日 です）。"
                }
            }
        }

        $getTaskById = {
            param([string]$Id)

            if ([string]::IsNullOrWhiteSpace($Id)) { return $null }

            foreach ($task in @($script:ToDoTasks)) {
                if ($null -ne $task -and [string]$task.Id -eq $Id) {
                    return $task
                }
            }

            return $null
        }

        $getSortedTasks = {
            @($script:ToDoTasks | Sort-Object `
                @{ Expression = { if ($_.DueDate) { 0 } else { 1 } }; Ascending = $true }, `
                @{ Expression = { if ($_.DueDate) { [datetime]$_.DueDate } else { [datetime]::MaxValue } }; Ascending = $true }, `
                @{ Expression = { if ($_.CreatedAt) { [datetime]$_.CreatedAt } else { [datetime]::MaxValue } }; Ascending = $true })
        }

        & $loadTasks
        & $ensureTaskSchema
        & $normalizeTaskDates
        $settings = & $loadSettings

        $form = New-Object System.Windows.Forms.Form
        $form.Text = '割り込み ToDo'
        $form.Size = New-Object System.Drawing.Size($settings.WindowWidth, $settings.WindowHeight)
        $form.StartPosition = 'CenterScreen'
        $form.TopMost = $true
        $form.MinimumSize = New-Object System.Drawing.Size(760, 520)

        $rootPanel = New-Object System.Windows.Forms.TableLayoutPanel
        $rootPanel.Dock = 'Fill'
        $rootPanel.Padding = New-Object System.Windows.Forms.Padding(6)
        $rootPanel.Margin = New-Object System.Windows.Forms.Padding(0)
        $rootPanel.ColumnCount = 1
        $rootPanel.RowCount = 2
        $rootPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
        $rootPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
        $rootPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
        $form.Controls.Add($rootPanel)

        $inputTable = New-Object System.Windows.Forms.TableLayoutPanel
        $inputTable.Dock = 'Top'
        $inputTable.AutoSize = $true
        $inputTable.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
        $inputTable.ColumnCount = 2
        $inputTable.RowCount = 4
        $inputTable.Margin = New-Object System.Windows.Forms.Padding(0)
        $inputTable.Padding = New-Object System.Windows.Forms.Padding(0)
        $inputTable.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 78)))
        $inputTable.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
        $inputTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
        $inputTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
        $inputTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
        $inputTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
        $rootPanel.Controls.Add($inputTable, 0, 0)

        $lblTitle = New-Object System.Windows.Forms.Label
        $lblTitle.Text = 'タイトル:'
        $lblTitle.AutoSize = $true
        $lblTitle.Anchor = 'Left'
        $lblTitle.Margin = New-Object System.Windows.Forms.Padding(0,2,4,1)
        $inputTable.Controls.Add($lblTitle, 0, 0)

        $txtTitle = New-Object System.Windows.Forms.TextBox
        $txtTitle.Dock = 'Fill'
        $txtTitle.Margin = New-Object System.Windows.Forms.Padding(0,0,0,1)
        $inputTable.Controls.Add($txtTitle, 1, 0)

        $lblDesc = New-Object System.Windows.Forms.Label
        $lblDesc.Text = '内容:'
        $lblDesc.AutoSize = $true
        $lblDesc.Anchor = 'Left,Top'
        $lblDesc.Margin = New-Object System.Windows.Forms.Padding(0,2,4,1)
        $inputTable.Controls.Add($lblDesc, 0, 1)

        $txtDesc = New-Object System.Windows.Forms.TextBox
        $txtDesc.Multiline = $true
        $txtDesc.ScrollBars = 'Vertical'
        $txtDesc.Dock = 'Fill'
        $txtDesc.Height = 72
        $txtDesc.Margin = New-Object System.Windows.Forms.Padding(0,0,0,1)
        $inputTable.Controls.Add($txtDesc, 1, 1)

        $lblDue = New-Object System.Windows.Forms.Label
        $lblDue.Text = '期限(任意):'
        $lblDue.AutoSize = $true
        $lblDue.Anchor = 'Left'
        $lblDue.Margin = New-Object System.Windows.Forms.Padding(0,2,4,1)
        $inputTable.Controls.Add($lblDue, 0, 2)

        $duePanel = New-Object System.Windows.Forms.Panel
        $duePanel.Dock = 'Top'
        $duePanel.Height = 26
        $duePanel.Margin = New-Object System.Windows.Forms.Padding(0,0,0,1)
        $duePanel.Padding = New-Object System.Windows.Forms.Padding(0)
        $inputTable.Controls.Add($duePanel, 1, 2)

        $txtDue = New-Object System.Windows.Forms.TextBox
        $txtDue.Location = New-Object System.Drawing.Point(0, 2)
        $txtDue.Size = New-Object System.Drawing.Size(120, 22)
        $txtDue.Margin = New-Object System.Windows.Forms.Padding(0)
        $duePanel.Controls.Add($txtDue)

        $btnTodayDue = New-Object System.Windows.Forms.Button
        $btnTodayDue.Text = '今日'
        $btnTodayDue.Location = New-Object System.Drawing.Point(126, 0)
        $btnTodayDue.Size = New-Object System.Drawing.Size(62, 24)
        $btnTodayDue.Margin = New-Object System.Windows.Forms.Padding(0)
        $duePanel.Controls.Add($btnTodayDue)

        $spacerLabel = New-Object System.Windows.Forms.Label
        $spacerLabel.Text = ''
        $spacerLabel.AutoSize = $true
        $spacerLabel.Margin = New-Object System.Windows.Forms.Padding(0)
        $inputTable.Controls.Add($spacerLabel, 0, 3)

        $buttonHost = New-Object System.Windows.Forms.Panel
        $buttonHost.Dock = 'Top'
        $buttonHost.Height = 28
        $buttonHost.Margin = New-Object System.Windows.Forms.Padding(0,0,0,0)
        $buttonHost.Padding = New-Object System.Windows.Forms.Padding(0)
        $inputTable.Controls.Add($buttonHost, 1, 3)

        $btnAdd = New-Object System.Windows.Forms.Button
        $btnAdd.Text = '追加'
        $btnAdd.Size = New-Object System.Drawing.Size(88, 24)
        $btnAdd.Location = New-Object System.Drawing.Point(0, 0)
        $buttonHost.Controls.Add($btnAdd)

        $btnUpdate = New-Object System.Windows.Forms.Button
        $btnUpdate.Text = '更新'
        $btnUpdate.Size = New-Object System.Drawing.Size(88, 24)
        $btnUpdate.Location = New-Object System.Drawing.Point(94, 0)
        $btnUpdate.Enabled = $false
        $buttonHost.Controls.Add($btnUpdate)

        $btnClear = New-Object System.Windows.Forms.Button
        $btnClear.Text = '入力クリア'
        $btnClear.Size = New-Object System.Drawing.Size(98, 24)
        $btnClear.Location = New-Object System.Drawing.Point(188, 0)
        $buttonHost.Controls.Add($btnClear)

        $btnToggleCompleted = New-Object System.Windows.Forms.CheckBox
        $btnToggleCompleted.Appearance = 'Button'
        $btnToggleCompleted.Text = '完了タスクも表示：OFF'
        $btnToggleCompleted.TextAlign = 'MiddleCenter'
        $btnToggleCompleted.Size = New-Object System.Drawing.Size(166, 24)
        $btnToggleCompleted.Location = New-Object System.Drawing.Point(292, 0)
        $buttonHost.Controls.Add($btnToggleCompleted)

        $btnDeleteCompleted = New-Object System.Windows.Forms.Button
        $btnDeleteCompleted.Text = '完了タスク削除'
        $btnDeleteCompleted.Size = New-Object System.Drawing.Size(118, 24)
        $btnDeleteCompleted.Location = New-Object System.Drawing.Point(464, 0)
        $btnDeleteCompleted.Enabled = $false
        $buttonHost.Controls.Add($btnDeleteCompleted)

        $splitMain = New-Object System.Windows.Forms.SplitContainer
        $splitMain.Dock = 'Fill'
        $splitMain.Margin = New-Object System.Windows.Forms.Padding(0,2,0,0)
        $splitMain.Orientation = [System.Windows.Forms.Orientation]::Horizontal
        $splitMain.SplitterWidth = 6
        $splitMain.FixedPanel = [System.Windows.Forms.FixedPanel]::Panel1
        $splitMain.IsSplitterFixed = $false
        $splitMain.Panel1MinSize = 150
        $splitMain.Panel2MinSize = 80
        $rootPanel.Controls.Add($splitMain, 0, 1)

        $lv = New-Object System.Windows.Forms.ListView
        $lv.Dock = 'Fill'
        $lv.View = 'Details'
        $lv.FullRowSelect = $true
        $lv.GridLines = $true
        $lv.CheckBoxes = $true
        $lv.HideSelection = $false

        [void]$lv.Columns.Add('タイトル',300)
        [void]$lv.Columns.Add('期限',110)
        [void]$lv.Columns.Add('作成日時',150)
        [void]$lv.Columns.Add('状態',80)
        [void]$lv.Columns.Add('内容',200)

        $splitMain.Panel1.Controls.Add($lv)

        $panelBottom = New-Object System.Windows.Forms.Panel
        $panelBottom.Dock = 'Fill'
        $splitMain.Panel2.Controls.Add($panelBottom)

        $rtbFull = New-Object System.Windows.Forms.RichTextBox
        $rtbFull.Dock = 'Fill'
        $rtbFull.Multiline = $true
        $rtbFull.ScrollBars = 'Vertical'
        $rtbFull.WordWrap = $true
        $rtbFull.ReadOnly = $true
        $rtbFull.DetectUrls = $true
        $rtbFull.BorderStyle = 'FixedSingle'
        $panelBottom.Controls.Add($rtbFull)

        $lblFull = New-Object System.Windows.Forms.Label
        $lblFull.Text = '内容（全文・URLクリック可）:'
        $lblFull.Dock = 'Top'
        $lblFull.Height = 18
        $lblFull.Margin = New-Object System.Windows.Forms.Padding(0)
        $panelBottom.Controls.Add($lblFull)

        $resizeButtonRow = {
            $x = 0
            $gap = 6

            foreach ($ctrl in @($btnAdd, $btnUpdate, $btnClear, $btnToggleCompleted, $btnDeleteCompleted)) {
                $ctrl.Location = New-Object System.Drawing.Point($x, 0)
                $x += $ctrl.Width + $gap
            }
        }

        $clearInputs = {
            $txtTitle.Clear()
            $txtDesc.Clear()
            $txtDue.Clear()
            $rtbFull.Clear()

            foreach ($sel in @($lv.SelectedItems)) {
                $sel.Selected = $false
            }

            $btnUpdate.Enabled = $false
            $txtTitle.Focus()
        }

        $showTaskInEditor = {
            param([object]$task)

            if ($null -eq $task) {
                $rtbFull.Clear()
                $btnUpdate.Enabled = $false
                return
            }

            $rtbFull.Clear()
            $rtbFull.Text = [string]$task.Description

            $txtTitle.Text = [string]$task.Title
            $txtDesc.Text  = [string]$task.Description

            if ($task.DueDate) {
                $txtDue.Text = ([datetime]$task.DueDate).ToString('yyyy/MM/dd')
            }
            else {
                $txtDue.Clear()
            }

            $btnUpdate.Enabled = $true
        }

        $refreshList = {
            param(
                [string]$SelectedId
            )

            $script:ToDoInternalState.RefreshingList = $true
            $script:ToDoInternalState.SuppressItemCheck = $true

            try {
                $lv.BeginUpdate()
                $lv.Items.Clear()

                $showCompleted = $btnToggleCompleted.Checked
                $tasks = & $getSortedTasks

                foreach ($t in @($tasks)) {
                    if (-not $showCompleted -and $t.IsCompleted) {
                        continue
                    }

                    $item = New-Object System.Windows.Forms.ListViewItem([string]$t.Title)
                    $item.Tag = [string]$t.Id
                    $item.Checked = [bool]$t.IsCompleted

                    $dueText = ''
                    if ($t.DueDate) {
                        $dueText = ([datetime]$t.DueDate).ToString('yyyy/MM/dd')
                    }
                    [void]$item.SubItems.Add($dueText)

                    $createdText = ''
                    if ($t.CreatedAt) {
                        $createdText = ([datetime]$t.CreatedAt).ToString('yyyy/MM/dd HH:mm')
                    }
                    [void]$item.SubItems.Add($createdText)

                    $status = if ($t.IsCompleted) { '完了' } else { '未完了' }
                    [void]$item.SubItems.Add($status)

                    $descShort = [string]$t.Description
                    if ($descShort.Length -gt 30) {
                        $descShort = $descShort.Substring(0, 30) + '...'
                    }
                    [void]$item.SubItems.Add($descShort)

                    if ($t.IsCompleted) {
                        $item.ForeColor = [System.Drawing.Color]::Gray
                    }

                    [void]$lv.Items.Add($item)
                }
            }
            finally {
                $lv.EndUpdate()
                $script:ToDoInternalState.SuppressItemCheck = $false
                $script:ToDoInternalState.RefreshingList = $false
            }

            if (-not [string]::IsNullOrWhiteSpace($SelectedId)) {
                foreach ($item in @($lv.Items)) {
                    if ([string]$item.Tag -eq $SelectedId) {
                        $item.Selected = $true
                        $item.Focused = $true
                        $item.EnsureVisible()
                        break
                    }
                }
            }
        }

        $addTask = {
            $title  = $txtTitle.Text.Trim()
            $desc   = $txtDesc.Text.Trim()
            $dueTxt = $txtDue.Text.Trim()

            if ([string]::IsNullOrWhiteSpace($title)) {
                [System.Windows.Forms.MessageBox]::Show(
                    'タイトルを入力してください。',
                    'ToDo',
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null
                return
            }

            $dueDate = $null
            if ($dueTxt) {
                try {
                    $dueDate = & $parseDueDate $dueTxt
                }
                catch {
                    [System.Windows.Forms.MessageBox]::Show(
                        "期限の形式が不正です:`n$($_.Exception.Message)`n例: 2025/1/5, 1/5, 5",
                        'ToDo',
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Warning
                    ) | Out-Null
                    return
                }
            }

            $task = [PSCustomObject]@{
                Id          = [guid]::NewGuid().ToString()
                Title       = $title
                Description = $desc
                IsCompleted = $false
                CreatedAt   = Get-Date
                CompletedAt = $null
                DueDate     = $dueDate
            }

            $script:ToDoTasks += $task
            & $saveTasks
            & $refreshList ([string]$task.Id)
            & $showTaskInEditor $task
        }

        $updateTask = {
            if ($lv.SelectedItems.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show(
                    '更新するタスクをリストから選択してください。',
                    'ToDo',
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null
                return
            }

            $id = [string]$lv.SelectedItems[0].Tag
            $task = & $getTaskById $id
            if ($null -eq $task) { return }

            $title  = $txtTitle.Text.Trim()
            $desc   = $txtDesc.Text.Trim()
            $dueTxt = $txtDue.Text.Trim()

            if ([string]::IsNullOrWhiteSpace($title)) {
                [System.Windows.Forms.MessageBox]::Show(
                    'タイトルを入力してください。',
                    'ToDo',
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null
                return
            }

            $dueDate = $null
            if ($dueTxt) {
                try {
                    $dueDate = & $parseDueDate $dueTxt
                }
                catch {
                    [System.Windows.Forms.MessageBox]::Show(
                        "期限の形式が不正です:`n$($_.Exception.Message)`n例: 2025/1/5, 1/5, 5",
                        'ToDo',
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Warning
                    ) | Out-Null
                    return
                }
            }

            $task | Add-Member -NotePropertyName Title       -NotePropertyValue $title   -Force
            $task | Add-Member -NotePropertyName Description -NotePropertyValue $desc    -Force
            $task | Add-Member -NotePropertyName DueDate     -NotePropertyValue $dueDate -Force

            & $saveTasks
            & $refreshList ([string]$task.Id)
            & $showTaskInEditor $task
        }

        $form.Add_Shown({
            $savedWidth = [int]$settings.WindowWidth
            $savedHeight = [int]$settings.WindowHeight

            if ($savedWidth -lt $form.MinimumSize.Width) {
                $savedWidth = $form.MinimumSize.Width
            }
            if ($savedHeight -lt $form.MinimumSize.Height) {
                $savedHeight = $form.MinimumSize.Height
            }

            $form.Size = New-Object System.Drawing.Size($savedWidth, $savedHeight)

            & $resizeButtonRow

            $maxSplitter = $splitMain.Height - $splitMain.Panel2MinSize - $splitMain.SplitterWidth
            $minSplitter = $splitMain.Panel1MinSize
            $saved = [int]$settings.SplitterDistance

            if ($saved -lt $minSplitter) { $saved = $minSplitter }
            if ($saved -gt $maxSplitter) { $saved = $maxSplitter }

            if ($maxSplitter -ge $minSplitter) {
                $splitMain.SplitterDistance = $saved
            }

            $txtTitle.Focus()
        })

        $form.Add_Resize({
            & $resizeButtonRow
        })

        $btnTodayDue.Add_Click({
            $txtDue.Text = (Get-Date).ToString('yyyy/MM/dd')
        })

        $btnClear.Add_Click({
            & $clearInputs
        })

        $btnAdd.Add_Click({
            & $addTask
        })

        $btnUpdate.Add_Click({
            & $updateTask
        })

        $txtTitle.Add_KeyDown({
            if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
                $_.SuppressKeyPress = $true
                if ($btnUpdate.Enabled -and $lv.SelectedItems.Count -gt 0) {
                    & $updateTask
                }
                else {
                    & $addTask
                }
            }
        })

        $rtbFull.Add_LinkClicked({
            param($sender, $e)
            try {
                if (-not [string]::IsNullOrWhiteSpace($e.LinkText)) {
                    Start-Process $e.LinkText
                }
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show(
                    "URL を開けませんでした:`n$($_.Exception.Message)",
                    'ToDo',
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                ) | Out-Null
            }
        })

        $btnToggleCompleted.Add_CheckedChanged({
            if ($btnToggleCompleted.Checked) {
                $btnToggleCompleted.Text = '完了タスクも表示：ON'
                $btnDeleteCompleted.Enabled = $true
            }
            else {
                $btnToggleCompleted.Text = '完了タスクも表示：OFF'
                $btnDeleteCompleted.Enabled = $false
            }

            $selectedId = $null
            if ($lv.SelectedItems.Count -gt 0) {
                $selectedId = [string]$lv.SelectedItems[0].Tag
            }

            & $refreshList $selectedId
        })

        $lv.Add_ItemCheck({
            param($sender, $e)

            if ($script:ToDoInternalState.SuppressItemCheck) { return }
            if ($e.Index -lt 0 -or $e.Index -ge $lv.Items.Count) { return }

            $item = $lv.Items[$e.Index]
            if ($null -eq $item) { return }

            $id = [string]$item.Tag
            $task = & $getTaskById $id
            if ($null -eq $task) { return }

            $isCompletedNew = ($e.NewValue -eq [System.Windows.Forms.CheckState]::Checked)

            $task | Add-Member -NotePropertyName IsCompleted -NotePropertyValue $isCompletedNew -Force
            $task | Add-Member -NotePropertyName CompletedAt -NotePropertyValue $(if ($isCompletedNew) { Get-Date } else { $null }) -Force

            & $saveTasks

            if ($btnToggleCompleted.Checked) {
                $item.SubItems[3].Text = if ($task.IsCompleted) { '完了' } else { '未完了' }
                $item.ForeColor = if ($task.IsCompleted) { [System.Drawing.Color]::Gray } else { [System.Drawing.Color]::Black }

                if ($lv.SelectedItems.Count -gt 0 -and [string]$lv.SelectedItems[0].Tag -eq $id) {
                    & $showTaskInEditor $task
                }
            }
            else {
                & $refreshList
                if ($task.IsCompleted) {
                    $rtbFull.Clear()
                    $btnUpdate.Enabled = $false
                }
            }
        })

        $btnDeleteCompleted.Add_Click({
            if (-not $btnToggleCompleted.Checked) {
                [System.Windows.Forms.MessageBox]::Show(
                    '完了タスクを削除するには「完了タスクも表示：ON」にしてください。',
                    'ToDo',
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null
                return
            }

            $completed = @($script:ToDoTasks | Where-Object { $_.IsCompleted })
            if ($completed.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show(
                    '削除対象となる完了タスクはありません。',
                    'ToDo',
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null
                return
            }

            $count = $completed.Count
            $msg = "完了タスクをすべて削除します。（${count} 件）`nよろしいですか？"
            $result = [System.Windows.Forms.MessageBox]::Show(
                $msg,
                '完了タスク削除の確認',
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )

            if ($result -ne [System.Windows.Forms.DialogResult]::Yes) { return }

            $script:ToDoTasks = @($script:ToDoTasks | Where-Object { -not $_.IsCompleted })

            & $saveTasks
            & $refreshList
            $rtbFull.Clear()
            $btnUpdate.Enabled = $false
        })

        $lv.Add_SelectedIndexChanged({
            if ($script:ToDoInternalState.RefreshingList) { return }

            if ($lv.SelectedItems.Count -eq 0) {
                $rtbFull.Clear()
                $btnUpdate.Enabled = $false
                return
            }

            $id = [string]$lv.SelectedItems[0].Tag
            $task = & $getTaskById $id
            if ($null -ne $task) {
                & $showTaskInEditor $task
            }
            else {
                $rtbFull.Clear()
                $btnUpdate.Enabled = $false
            }
        })

        $form.Add_FormClosing({
            $width = $form.Width
            $height = $form.Height

            if ($form.WindowState -eq [System.Windows.Forms.FormWindowState]::Normal) {
                $width = $form.Size.Width
                $height = $form.Size.Height
            }

            & $saveTasks
            & $saveSettings $splitMain.SplitterDistance $width $height
        })

        & $refreshList
        [void]$form.ShowDialog()

    } | Out-Null
}

