# Remove data
$ApDir = Join-Path $env:LOCALAPPDATA 'InterruptToDo'
$ApFile = Join-Path $ApDir 'ToDoTasks.json'

if( Test-Path $ApFile ){
	Remove-Item $ApFile
}

if( Test-Path $ApDir ){
	Remove-Item $ApDir -Force -Recurse
}
