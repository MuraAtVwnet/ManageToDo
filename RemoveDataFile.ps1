$ApDir = Join-Path $env:LOCALAPPDATA 'InterruptToDo'
$ApFile = Join-Path $ApDir 'ToDoTasks.json'

Remove-Item $ApFile
Remove-Item $ApDir
