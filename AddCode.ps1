function AddCode(, [switch]$VertionCheck){

	if( $VertionCheck ){
		$ModuleName = "ManageToDo"
		$GitHubName = "MuraAtVwnet"

		$HomeDirectory = "~/"
		$Module = $ModuleName + ".psm1"
		$Installer = "Install" + $ModuleName + ".ps1"
		$UnInstaller = "UnInstall" + $ModuleName + ".ps1"
		$Vertion = "Vertion" + $ModuleName + ".txt"
		$GithubCommonURI = "https://raw.githubusercontent.com/MuraAtVwnet/ManageToDo/refs/heads/main/"

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

	# 以下本来のコード

