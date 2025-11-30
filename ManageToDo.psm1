#requires -Version 5.1

# スクリプト全体で共有する永続データ
if (-not $script:ToDoDataDir)  { $script:ToDoDataDir  = Join-Path $env:LOCALAPPDATA 'InterruptToDo' }
if (-not $script:ToDoDataPath) { $script:ToDoDataPath = Join-Path $script:ToDoDataDir 'ToDoTasks.json' }
if (-not $script:ToDoTasks)    { $script:ToDoTasks    = @() }

function ToDo([switch]$VertionCheck) {

	if( $VertionCheck ){
		$ModuleName = "ManageToDo"
		$GitHubName = "MuraAtVwnet"

		$HomeDirectory = "~/"
		$Module = $ModuleName + ".psm1"
		$Installer = "Install" + $ModuleName + ".ps1"
		$UnInstaller = "UnInstall" + $ModuleName + ".ps1"
		$Vertion = "Vertion" + $ModuleName + ".txt"
		$GithubCommonURI = "https://raw.githubusercontent.com/$GitHubName/$ModuleName/master/"

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

			$URI = $GithubCommonURI + "install.ps1"
			$InstallerFile = $HomeDirectory + $Installer
			Invoke-WebRequest -Uri $URI -OutFile $InstallerFile

			$URI = $GithubCommonURI + "uninstall.ps1"
			$OutFile = $HomeDirectory + $UnInstaller
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
	# 本来のコード

    & {

        # ここで出力が出ないようにすべて潰す
        Add-Type -AssemblyName System.Windows.Forms | Out-Null
        Add-Type -AssemblyName System.Drawing       | Out-Null
        [void][System.Windows.Forms.Application]::EnableVisualStyles()

        # -----------------------------
        # 永続化：読み込み
        # -----------------------------
        $loadTasks = {
            if (-not (Test-Path $script:ToDoDataPath)) {
                $script:ToDoTasks = @()
                return
            }

            try {
                $json = Get-Content -Path $script:ToDoDataPath -Raw
                if ([string]::IsNullOrWhiteSpace($json)) {
                    $script:ToDoTasks = @()
                    return
                }

                $loaded = $json | ConvertFrom-Json
                if ($loaded -is [System.Collections.IEnumerable] -and -not ($loaded -is [string])) {
                    $script:ToDoTasks = @($loaded)
                } else {
                    $script:ToDoTasks = @($loaded)
                }
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show(
                    "タスク読み込みエラー:`n$($_.Exception.Message)",
                    "ToDo",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                ) | Out-Null
                $script:ToDoTasks = @()
            }
        }

        # -----------------------------
        # 既存タスクのスキーマ補正
        # （古い JSON に DueDate 等が無い場合に追加する）
        # -----------------------------
        $ensureTaskSchema = {
            foreach ($t in $script:ToDoTasks) {
                if (-not $t) { continue }
                $props = $t.PSObject.Properties

                if (-not $props.Match('Id'))          { Add-Member -InputObject $t -NotePropertyName Id          -NotePropertyValue ([guid]::NewGuid().ToString()) }
                if (-not $props.Match('Title'))       { Add-Member -InputObject $t -NotePropertyName Title       -NotePropertyValue "" }
                if (-not $props.Match('Description')) { Add-Member -InputObject $t -NotePropertyName Description -NotePropertyValue "" }
                if (-not $props.Match('IsCompleted')) { Add-Member -InputObject $t -NotePropertyName IsCompleted -NotePropertyValue $false }
                if (-not $props.Match('CreatedAt'))   { Add-Member -InputObject $t -NotePropertyName CreatedAt   -NotePropertyValue (Get-Date) }
                if (-not $props.Match('CompletedAt')) { Add-Member -InputObject $t -NotePropertyName CompletedAt -NotePropertyValue $null }
                if (-not $props.Match('DueDate'))     { Add-Member -InputObject $t -NotePropertyName DueDate     -NotePropertyValue $null }
            }
        }

        & $loadTasks
        & $ensureTaskSchema

        # -----------------------------
        # 永続化：保存
        # -----------------------------
        $saveTasks = {
            try {
                if (-not (Test-Path $script:ToDoDataDir)) {
                    [void](New-Item -ItemType Directory -Path $script:ToDoDataDir -Force)
                }

                $script:ToDoTasks |
                    ConvertTo-Json -Depth 5 |
                    Out-File -FilePath $script:ToDoDataPath -Encoding UTF8 -Force
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show(
                    "タスク保存エラー:`n$($_.Exception.Message)",
                    "ToDo",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                ) | Out-Null
            }
        }

        # -----------------------------
        # 期限文字列パーサ（15, 20 などの入力を安定解釈）
        # -----------------------------
        $parseDueDate = {
            param(
                [string]$text
            )

            $text = $text.Trim()
            if (-not $text) { return $null }

            # 数字列だけを順番に抽出（例: "2025/1/5" → 2025,1,5 / "3/15" → 3,15 / "15" → 15）
            $matches = [System.Text.RegularExpressions.Regex]::Matches($text, '\d+')
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

            if ($nums.Count -eq 1) {
                # 日だけ指定（例: "15"）→ 今日以降で最も近い「○月15日」
                $day = $nums[0]

                if ($day -lt 1 -or $day -gt 31) {
                    throw "期限の『日』は 1～31 で指定してください。"
                }

                $year  = $today.Year
                $month = $today.Month

                for ($i = 0; $i -lt 24; $i++) {  # 最大 2 年先まで探す
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
            elseif ($nums.Count -eq 2) {
                # 月 / 日 （例: "3/15"）
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
                    throw "指定された月 $month に日は $day は存在しません。"
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
            elseif ($nums.Count -eq 3) {
                # 年/月/日
                $year  = $nums[0]
                $month = $nums[1]
                $day   = $nums[2]

                try {
                    $dt = [datetime]::new($year, $month, $day)
                    return $dt.Date
                }
                catch {
                    throw "期限の年月日が不正です（年/月/日 で指定してください）。"
                }
            }
            else {
                throw "期限の形式が不正です（指定できるのは 日 / 月日 / 年月日 です）。"
            }
        }

        # -----------------------------
        # フォーム
        # -----------------------------
        $form = New-Object System.Windows.Forms.Form
        $form.Text = "割り込み ToDo"
        $form.Size = New-Object System.Drawing.Size(720, 600)
        $form.StartPosition = "CenterScreen"
        $form.TopMost = $true   # 他のウィンドウの裏に隠れないように

        # タイトル
        $lblTitle = New-Object System.Windows.Forms.Label
        $lblTitle.Text = "タイトル:"
        $lblTitle.Location = New-Object System.Drawing.Point(10,10)
        $lblTitle.Size     = New-Object System.Drawing.Size(80,20)
        $form.Controls.Add($lblTitle)

        $txtTitle = New-Object System.Windows.Forms.TextBox
        $txtTitle.Location = New-Object System.Drawing.Point(90,8)
        $txtTitle.Size     = New-Object System.Drawing.Size(600,20)
        $txtTitle.Anchor   = 'Top,Left,Right'
        $form.Controls.Add($txtTitle)

        # 内容
        $lblDesc = New-Object System.Windows.Forms.Label
        $lblDesc.Text = "内容:"
        $lblDesc.Location = New-Object System.Drawing.Point(10,40)
        $lblDesc.Size     = New-Object System.Drawing.Size(80,20)
        $form.Controls.Add($lblDesc)

        $txtDesc = New-Object System.Windows.Forms.TextBox
        $txtDesc.Location   = New-Object System.Drawing.Point(90,38)
        $txtDesc.Size       = New-Object System.Drawing.Size(600,80)
        $txtDesc.Multiline  = $true
        $txtDesc.ScrollBars = 'Vertical'
        $txtDesc.Anchor     = 'Top,Left,Right'
        $form.Controls.Add($txtDesc)

        # 期限（任意）
        $lblDue = New-Object System.Windows.Forms.Label
        $lblDue.Text = "期限(任意):"
        $lblDue.Location = New-Object System.Drawing.Point(10,125)
        $lblDue.Size     = New-Object System.Drawing.Size(80,20)
        $form.Controls.Add($lblDue)

        $txtDue = New-Object System.Windows.Forms.TextBox
        $txtDue.Location = New-Object System.Drawing.Point(90,123)
        $txtDue.Size     = New-Object System.Drawing.Size(120,20)
        $txtDue.Anchor   = 'Top,Left'
        $form.Controls.Add($txtDue)

        # 追加ボタン
        $btnAdd = New-Object System.Windows.Forms.Button
        $btnAdd.Text     = "追加"
        $btnAdd.Location = New-Object System.Drawing.Point(220,121)
        $btnAdd.Size     = New-Object System.Drawing.Size(80,25)
        $form.Controls.Add($btnAdd)

        # 更新ボタン（選択したタスクの修正）※最初は無効
        $btnUpdate = New-Object System.Windows.Forms.Button
        $btnUpdate.Text     = "更新"
        $btnUpdate.Location = New-Object System.Drawing.Point(310,121)
        $btnUpdate.Size     = New-Object System.Drawing.Size(80,25)
        $btnUpdate.Enabled  = $false
        $form.Controls.Add($btnUpdate)

        # 入力クリアボタン
        $btnClear = New-Object System.Windows.Forms.Button
        $btnClear.Text     = "入力クリア"
        $btnClear.Location = New-Object System.Drawing.Point(400,121)
        $btnClear.Size     = New-Object System.Drawing.Size(80,25)
        $form.Controls.Add($btnClear)

        # 完了タスク表示トグル（CheckBox をボタン風に）
        $btnToggleCompleted = New-Object System.Windows.Forms.CheckBox
        $btnToggleCompleted.Appearance = 'Button'
        $btnToggleCompleted.Text       = "完了タスクも表示：OFF"
        $btnToggleCompleted.TextAlign  = 'MiddleCenter'
        $btnToggleCompleted.Location   = New-Object System.Drawing.Point(490,121)
        $btnToggleCompleted.Size       = New-Object System.Drawing.Size(150,25)
        $btnToggleCompleted.Checked    = $false
        $form.Controls.Add($btnToggleCompleted)

        # 完了タスク削除ボタン（完了表示 ON のときだけ有効）
        $btnDeleteCompleted = New-Object System.Windows.Forms.Button
        $btnDeleteCompleted.Text     = "完了タスク削除"
        $btnDeleteCompleted.Location = New-Object System.Drawing.Point(650,121)
        $btnDeleteCompleted.Size     = New-Object System.Drawing.Size(60,25)
        $btnDeleteCompleted.Enabled  = $false
        $btnDeleteCompleted.AutoSize = $true
        $form.Controls.Add($btnDeleteCompleted)

        # -----------------------------
        # Task ListView（チェックボックス付き）
        # -----------------------------
        $lv = New-Object System.Windows.Forms.ListView
        $lv.Location      = New-Object System.Drawing.Point(10,160)
        $lv.Size          = New-Object System.Drawing.Size(680,280)
        $lv.Anchor        = 'Top,Left,Right'
        $lv.View          = 'Details'
        $lv.FullRowSelect = $true
        $lv.GridLines     = $true
        $lv.CheckBoxes    = $true

        [void]$lv.Columns.Add("タイトル",220)
        [void]$lv.Columns.Add("期限",100)
        [void]$lv.Columns.Add("作成日時",140)
        [void]$lv.Columns.Add("状態",80)
        [void]$lv.Columns.Add("内容",120)

        $form.Controls.Add($lv)

        # -----------------------------
        # 内容全文表示エリア（RichTextBox, URL 自動リンク）
        # -----------------------------
        $lblFull = New-Object System.Windows.Forms.Label
        $lblFull.Text     = "内容（全文・URLクリック可）:"
        $lblFull.Location = New-Object System.Drawing.Point(10,450)
        $lblFull.Size     = New-Object System.Drawing.Size(260,20)
        $form.Controls.Add($lblFull)

        $rtbFull = New-Object System.Windows.Forms.RichTextBox
        $rtbFull.Location   = New-Object System.Drawing.Point(10,470)
        $rtbFull.Size       = New-Object System.Drawing.Size(680,90)
        $rtbFull.Multiline  = $true
        $rtbFull.ScrollBars = 'Vertical'
        $rtbFull.ReadOnly   = $true
        $rtbFull.Anchor     = 'Left,Right,Bottom'
        $rtbFull.DetectUrls = $true     # URL 自動検出
        $form.Controls.Add($rtbFull)

        # URL クリック時：既定ブラウザで開く
        $rtbFull.Add_LinkClicked({
            param($sender, $e)
            try {
                if ($e.LinkText) {
                    Start-Process $e.LinkText
                }
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show(
                    "URL を開けませんでした:`n$($_.Exception.Message)",
                    "ToDo",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                ) | Out-Null
            }
        })

        # -----------------------------
        # ListView 再描画
        # -----------------------------
        $refreshList = {
            $lv.BeginUpdate()
            $lv.Items.Clear()

            $showCompleted = $btnToggleCompleted.Checked

            # 並び順:
            # 1) 期限あり(0) → なし(1)
            # 2) 期限が小さい順
            # 3) 登録日（CreatedAt）が新しい順（降順）
            $tasks = $script:ToDoTasks | Sort-Object `
                @{ Expression = { if ($_.DueDate) { 0 } else { 1 } }; Ascending = $true }, `
                @{ Expression = { if ($_.DueDate) { [datetime]$_.DueDate } else { [datetime]::MaxValue } }; Ascending = $true }, `
                @{ Expression = { if ($_.CreatedAt) { [datetime]$_.CreatedAt } else { Get-Date 0 } }; Descending = $true }

            foreach ($t in $tasks) {

                if (-not $showCompleted -and $t.IsCompleted) {
                    continue
                }

                $item = New-Object System.Windows.Forms.ListViewItem($t.Title)
                $item.Tag     = $t.Id
                $item.Checked = $t.IsCompleted

                # 期限
                $dueText = ""
                if ($t.PSObject.Properties.Match('DueDate') -and $t.DueDate) {
                    $dueText = ([datetime]$t.DueDate).ToString("yyyy/MM/dd")
                }
                [void]$item.SubItems.Add($dueText)

                # 作成日時
                $createdText = ""
                if ($t.CreatedAt) {
                    $createdText = ([datetime]$t.CreatedAt).ToString("yyyy/MM/dd HH:mm")
                }
                [void]$item.SubItems.Add($createdText)

                # 状態
                $status = if ($t.IsCompleted) { "完了" } else { "未完了" }
                [void]$item.SubItems.Add($status)

                # 内容（先頭のみ）
                $descShort = $t.Description
                if ($descShort -and $descShort.Length -gt 30) {
                    $descShort = $descShort.Substring(0,30) + "..."
                }
                [void]$item.SubItems.Add($descShort)

                # 完了タスクはグレー
                if ($t.IsCompleted) {
                    $item.ForeColor = [System.Drawing.Color]::Gray
                }

                [void]$lv.Items.Add($item)
            }

            $lv.EndUpdate()
        }

        # -----------------------------
        # 入力クリア処理
        # -----------------------------
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

        $btnClear.Add_Click({ & $clearInputs })

        # -----------------------------
        # タスク追加
        # -----------------------------
        $addTask = {
            $title = $txtTitle.Text.Trim()
            $desc  = $txtDesc.Text.Trim()
            $dueTxt = $txtDue.Text.Trim()

            if ([string]::IsNullOrWhiteSpace($title)) {
                [System.Windows.Forms.MessageBox]::Show(
                    "タイトルを入力してください。",
                    "ToDo",
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
                        "ToDo",
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

            & $clearInputs
            & $refreshList
        }

        $btnAdd.Add_Click({ & $addTask })

        $txtTitle.Add_KeyDown({
            if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
                $_.SuppressKeyPress = $true
                & $addTask
            }
        })

        # -----------------------------
        # タスク更新（選択中のタスクを修正）
        #  ※ プロパティ更新はすべて Add-Member -Force で行う
        #  ※ 更新後に入力クリア
        # -----------------------------
        $updateTask = {
            if ($lv.SelectedItems.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show(
                    "更新するタスクをリストから選択してください。",
                    "ToDo",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null
                return
            }

            $id = $lv.SelectedItems[0].Tag
            $task = $script:ToDoTasks | Where-Object { $_.Id -eq $id }
            if (-not $task) { return }

            $title = $txtTitle.Text.Trim()
            $desc  = $txtDesc.Text.Trim()
            $dueTxt = $txtDue.Text.Trim()

            if ([string]::IsNullOrWhiteSpace($title)) {
                [System.Windows.Forms.MessageBox]::Show(
                    "タイトルを入力してください。",
                    "ToDo",
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
                        "ToDo",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Warning
                    ) | Out-Null
                    return
                }
            }

            # ここで Add-Member -Force を用いて既存/非既存プロパティ問わず安全に更新
            $task | Add-Member -NotePropertyName Title       -NotePropertyValue $title   -Force
            $task | Add-Member -NotePropertyName Description -NotePropertyValue $desc    -Force
            $task | Add-Member -NotePropertyName DueDate     -NotePropertyValue $dueDate -Force

            & $saveTasks
            & $refreshList
            & $clearInputs   # ← 更新後に入力クリア＆選択解除
        }

        $btnUpdate.Add_Click({ & $updateTask })

        # -----------------------------
        # トグルボタン：完了タスク表示 ON/OFF
        # -----------------------------
        $btnToggleCompleted.Add_CheckedChanged({
            if ($btnToggleCompleted.Checked) {
                $btnToggleCompleted.Text    = "完了タスクも表示：ON"
                $btnDeleteCompleted.Enabled = $true   # 完了タスク表示中だけ削除可能
            } else {
                $btnToggleCompleted.Text    = "完了タスクも表示：OFF"
                $btnDeleteCompleted.Enabled = $false  # OFF のときは削除禁止
            }

            & $refreshList
        })

        # -----------------------------
        # チェックボックス変更＝完了/未完了
        # -----------------------------
        $lv.Add_ItemCheck({
            param($sender, $e)

            $isCompletedNew = ($e.NewValue -eq [System.Windows.Forms.CheckState]::Checked)
            $item = $lv.Items[$e.Index]
            $id   = $item.Tag

            $task = $script:ToDoTasks | Where-Object { $_.Id -eq $id }
            if ($task) {
                # 既存プロパティなので代入で OK
                $task.IsCompleted = $isCompletedNew
                $task.CompletedAt = if ($isCompletedNew) { Get-Date } else { $null }

                & $saveTasks

                $item.SubItems[3].Text = if ($task.IsCompleted) { "完了" } else { "未完了" }
                $item.ForeColor = if ($task.IsCompleted) {
                    [System.Drawing.Color]::Gray
                } else {
                    [System.Drawing.Color]::Black
                }
            }
        })

        # -----------------------------
        # 完了タスクを物理削除（完了表示 ON のときだけ）
        # -----------------------------
        $btnDeleteCompleted.Add_Click({

            if (-not $btnToggleCompleted.Checked) {
                [System.Windows.Forms.MessageBox]::Show(
                    "完了タスクを削除するには「完了タスクも表示：ON」にしてください。",
                    "ToDo",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null
                return
            }

            $completed = $script:ToDoTasks | Where-Object { $_.IsCompleted }
            if (-not $completed -or $completed.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show(
                    "削除対象となる完了タスクはありません。",
                    "ToDo",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null
                return
            }

            $count = $completed.Count
            $msg = "完了タスクをすべて削除します。（${count} 件）`nよろしいですか？"
            $result = [System.Windows.Forms.MessageBox]::Show(
                $msg,
                "完了タスク削除の確認",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )

            if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
                return
            }

            $script:ToDoTasks = $script:ToDoTasks | Where-Object { -not $_.IsCompleted }

            & $saveTasks
            & $refreshList
            $rtbFull.Clear()
            $btnUpdate.Enabled = $false
        })

        # -----------------------------
        # ListView 選択時：内容全文＆編集フィールド反映
        # -----------------------------
        $lv.Add_SelectedIndexChanged({
            if ($lv.SelectedItems.Count -eq 0) {
                $rtbFull.Clear()
                $btnUpdate.Enabled = $false
                return
            }

            $id   = $lv.SelectedItems[0].Tag
            $task = $script:ToDoTasks | Where-Object { $_.Id -eq $id }
            if ($task) {
                $rtbFull.Clear()
                $rtbFull.Text = $task.Description

                $txtTitle.Text = $task.Title
                $txtDesc.Text  = $task.Description

                if ($task.PSObject.Properties.Match('DueDate') -and $task.DueDate) {
                    $txtDue.Text = ([datetime]$task.DueDate).ToString("yyyy/MM/dd")
                } else {
                    $txtDue.Clear()
                }

                $btnUpdate.Enabled = $true
            } else {
                $rtbFull.Clear()
                $btnUpdate.Enabled = $false
            }
        })

        # フォーム終了時：保存（保険）
        $form.Add_FormClosing({ & $saveTasks })

        # 初期描画
        & $refreshList
        $txtTitle.Focus()

        # ShowDialog 実行（戻り値は無視）
        [void]$form.ShowDialog()

    } | Out-Null  # ← 関数からは一切出力しない
}

