■ これは何?

■ オプション

-VertionCheck

最新版のスクリプトがあるか確認します
最新版があれば、自動ダウンロード & 更新します


■ GitHub
以下リポジトリで公開しています
https://github.com/MuraAtVwnet/ManageToDo
git@github.com:MuraAtVwnet/ManageToDo.git

■ スクリプトインストール方法

--- 以下を PowerShell プロンプトにコピペ ---

$ModuleName = "ManageToDo"
$GitHubName = "MuraAtVwnet"
$URI = "https://raw.githubusercontent.com/MuraAtVwnet/ManageToDo/refs/heads/main/Onlineinstall.ps1"
$OutFile = "~/Onlineinstall.ps1"
Invoke-WebRequest -Uri $URI -OutFile $OutFile
& $OutFile

