#requires -Version 5.1

# スクリプト全体で共有する永続データ
if (-not $script:ToDoDataDir)  { $script:ToDoDataDir  = Join-Path $env:LOCALAPPDATA 'InterruptToDo' }
if (-not $script:ToDoDataPath) { $script:ToDoDataPath = Join-Path $script:ToDoDataDir 'ToDoTasks.json' }
if (-not $script:ToDoTasks)    { $script:ToDoTasks    = @() }

function ToDo {

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

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

    & $loadTasks

    # -----------------------------
    # フォーム
    # -----------------------------
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "割り込み ToDo"
    $form.Size = New-Object System.Drawing.Size(700, 600)
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
    $txtTitle.Size     = New-Object System.Drawing.Size(580,20)
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
    $txtDesc.Size       = New-Object System.Drawing.Size(580,80)
    $txtDesc.Multiline  = $true
    $txtDesc.ScrollBars = 'Vertical'
    $txtDesc.Anchor     = 'Top,Left,Right'
    $form.Controls.Add($txtDesc)

    # 追加ボタン
    $btnAdd = New-Object System.Windows.Forms.Button
    $btnAdd.Text     = "追加"
    $btnAdd.Location = New-Object System.Drawing.Point(90,125)
    $btnAdd.Size     = New-Object System.Drawing.Size(80,25)
    $form.Controls.Add($btnAdd)

    # 完了タスク表示トグル（CheckBox をボタン風に）
    $btnToggleCompleted = New-Object System.Windows.Forms.CheckBox
    $btnToggleCompleted.Appearance = 'Button'
    $btnToggleCompleted.Text       = "完了タスクも表示：OFF"
    $btnToggleCompleted.TextAlign  = 'MiddleCenter'
    $btnToggleCompleted.Location   = New-Object System.Drawing.Point(190,125)
    $btnToggleCompleted.Size       = New-Object System.Drawing.Size(160,25)
    $btnToggleCompleted.Checked    = $false
    $form.Controls.Add($btnToggleCompleted)

    # 完了タスク削除ボタン（初期状態では無効：完了タスク表示OFFのため）
    $btnDeleteCompleted = New-Object System.Windows.Forms.Button
    $btnDeleteCompleted.Text     = "完了タスク削除"
    $btnDeleteCompleted.Location = New-Object System.Drawing.Point(360,125)
    $btnDeleteCompleted.Size     = New-Object System.Drawing.Size(120,25)
    $btnDeleteCompleted.Enabled  = $false
    $form.Controls.Add($btnDeleteCompleted)

    # -----------------------------
    # Task ListView（チェックボックス付き）
    # -----------------------------
    $lv = New-Object System.Windows.Forms.ListView
    $lv.Location      = New-Object System.Drawing.Point(10,160)
    $lv.Size          = New-Object System.Drawing.Size(660,280)
    $lv.Anchor        = 'Top,Left,Right'
    $lv.View          = 'Details'
    $lv.FullRowSelect = $true
    $lv.GridLines     = $true
    $lv.CheckBoxes    = $true

    [void]$lv.Columns.Add("タイトル",260)
    [void]$lv.Columns.Add("作成日時",160)
    [void]$lv.Columns.Add("状態",80)
    [void]$lv.Columns.Add("内容",140)

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
    $rtbFull.Size       = New-Object System.Drawing.Size(660,90)
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

        # 作成日時でソート（CreatedAt 無しは最古扱い）
        $tasks = $script:ToDoTasks | Sort-Object {
            if ($_.CreatedAt) { [datetime]$_.CreatedAt } else { Get-Date 0 }
        }

        foreach ($t in $tasks) {

            if (-not $showCompleted -and $t.IsCompleted) {
                continue
            }

            $item = New-Object System.Windows.Forms.ListViewItem($t.Title)
            $item.Tag     = $t.Id
            $item.Checked = $t.IsCompleted

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
    # タスク追加
    # -----------------------------
    $addTask = {
        $title = $txtTitle.Text.Trim()
        $desc  = $txtDesc.Text.Trim()

        if ([string]::IsNullOrWhiteSpace($title)) {
            [System.Windows.Forms.MessageBox]::Show(
                "タイトルを入力してください。",
                "ToDo",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
            return
        }

        $task = [PSCustomObject]@{
            Id          = [guid]::NewGuid().ToString()
            Title       = $title
            Description = $desc
            IsCompleted = $false
            CreatedAt   = Get-Date
            CompletedAt = $null
        }

        $script:ToDoTasks += $task
        & $saveTasks

        $txtTitle.Clear()
        $txtDesc.Clear()
        $txtTitle.Focus()

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

        # NewValue が新しい状態（Checked/Unchecked）
        $isCompletedNew = ($e.NewValue -eq [System.Windows.Forms.CheckState]::Checked)
        $item = $lv.Items[$e.Index]
        $id   = $item.Tag

        $task = $script:ToDoTasks | Where-Object { $_.Id -eq $id }
        if ($task) {
            $task.IsCompleted = $isCompletedNew
            $task.CompletedAt = if ($isCompletedNew) { Get-Date } else { $null }

            & $saveTasks

            # 状態列更新
            $item.SubItems[2].Text = if ($task.IsCompleted) { "完了" } else { "未完了" }

            # 色変更
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

        # 完了タスク以外を残す
        $script:ToDoTasks = $script:ToDoTasks | Where-Object { -not $_.IsCompleted }

        & $saveTasks
        & $refreshList
        $rtbFull.Clear()
    })

    # -----------------------------
    # ListView 選択時：内容全文表示（URL 自動リンク）
    # -----------------------------
    $lv.Add_SelectedIndexChanged({
        if ($lv.SelectedItems.Count -eq 0) {
            $rtbFull.Clear()
            return
        }

        $id   = $lv.SelectedItems[0].Tag
        $task = $script:ToDoTasks | Where-Object { $_.Id -eq $id }
        if ($task) {
            $rtbFull.Clear()
            $rtbFull.Text = $task.Description
        } else {
            $rtbFull.Clear()
        }
    })

    # フォーム終了時：保存（保険）
    $form.Add_FormClosing({ & $saveTasks })

    # 初期描画
    & $refreshList
    $txtTitle.Focus()

    # ShowDialog の戻り値を出力しない
    $null = $form.ShowDialog()
}
