■ これは何?
ローカル動作をする(クラウドにデータを置かない)シンプルな ToDo 管理ツールです
PowerShell プロンプトを閉じるとアプリも終了するので、使用中は PowerShell プロンプトを閉じないで下さい
データは %LOCALAPPDATA%\InterruptToDo\ToDoTasks.json に保存されています

スクリプトインストール後に PowerShell プロンプトで ToDo と入力するとツールが起動します

PowerShell プロンプトを閉じるとアプリも終了するので、使用中は PowerShell プロンプトを閉じないで下さい


■ オプション

-VertionCheck

最新版のスクリプトがあるか確認します
最新版があれば、自動ダウンロード & 更新します


■ スクリプトインストール方法

--- 以下を PowerShell プロンプトにコピペ ---

$ModuleName = "ManageToDo"
$GitHubName = "MuraAtVwnet"
$URI = "https://raw.githubusercontent.com/$GitHubName/$ModuleName/refs/heads/main/OnlineInstall.ps1"
$OutFile = "~/OnlineInstall.ps1"
Invoke-WebRequest -Uri $URI -OutFile $OutFile
& $OutFile


■ スクリプトアンインストール方法
--- 以下を PowerShell プロンプトにコピペ ---

~/UninstallManageToDo.ps1


■ Web サイト
以下ページで詳細説明しています

PowerShell でシンプルな ToDo 管理
https://www.vwnet.jp/Windows/PowerShell/2025120101/ManageToDo.htm


■ GitHub
以下リポジトリで公開しています
https://github.com/MuraAtVwnet/ManageToDo
git@github.com:MuraAtVwnet/ManageToDo.git


■ リポジトリ内モジュール説明
AddCode.ps1
	オンラインインストール用組み込みコード
Install.ps1
	インストーラー
ManageToDo.psm1
	モジュール本体
OnlineInstall.ps1
	オンラインインストーラー
Uninstall.ps1
	アンインストーラー
Vertion.txt
	バージョンチェックファイル
Readme.txt
	このファイル

