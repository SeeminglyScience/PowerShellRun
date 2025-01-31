class FileSystemRegistry
{
    $favoritesEntries = [System.Collections.Generic.List[PowerShellRun.SelectorEntry]]::new()
    $fileManagerEntry = [System.Collections.Generic.List[PowerShellRun.SelectorEntry]]::new()

    $isFavoritesEnabled = $false
    $isFileManagerEnabled = $false
    $isEntryUpdated = $false

    [ScriptBlock]$defaultEditorScript
    $fileManagerArguments

    FileSystemRegistry()
    {
        $this.defaultEditorScript = {
            param ($path)
            Invoke-Item $path
        }

        $this.fileManagerArguments = @{
            This = $this
            FolderActionKeys = @(
                [PowerShellRun.ActionKey]::new($script:globalStore.firstActionKey, 'Go inside')
                [PowerShellRun.ActionKey]::new($script:globalStore.secondActionKey, 'Set-Location')
                [PowerShellRun.ActionKey]::new($script:globalStore.thirdActionKey, 'Open with default app')
                [PowerShellRun.ActionKey]::new($script:globalStore.copyActionKey, 'Copy path to Clipboard')
            )
            FileActionKeys = @(
                [PowerShellRun.ActionKey]::new($script:globalStore.firstActionKey, 'Open with default app')
                [PowerShellRun.ActionKey]::new($script:globalStore.secondActionKey, 'Edit with default editor')
                [PowerShellRun.ActionKey]::new($script:globalStore.thirdActionKey, 'Open containing folder')
                [PowerShellRun.ActionKey]::new($script:globalStore.copyActionKey, 'Copy path to Clipboard')
            )
            PreviewScriptFolder = {
                param ($path)
                $childItems = Get-ChildItem $path
                $childItems | ForEach-Object {
                    if ($_.PSIsContainer)
                    {
                        $icon = '📁'
                    }
                    else
                    {
                        $icon ='📄'
                    }
                    "{0} {1}" -f $icon, $_.Name
                }
            }
            PreviewScriptFile = {
                param ($path)
                Get-Item $path | Out-String
            }
        }
    }

    [System.Collections.Generic.List[PowerShellRun.SelectorEntry]] GetEntries()
    {
        $entries = [System.Collections.Generic.List[PowerShellRun.SelectorEntry]]::new()
        if ($this.isFavoritesEnabled)
        {
            $entries.AddRange($this.favoritesEntries)
        }
        if ($this.isFileManagerEnabled)
        {
            $entries.AddRange($this.fileManagerEntry)
        }
        return $entries
    }

    [void] EnableEntries([String[]]$categories)
    {
        $this.isEntryUpdated = $true

        $this.isFavoritesEnabled = $categories.Contains('Favorite')

        $this.isFileManagerEnabled = $categories.Contains('Utility')
        $this.fileManagerEntry.Clear()
        if ($this.isFileManagerEnabled)
        {
            $this.RegisterFileManagerEntry()
        }
    }

    [void] SetDefaultEditorScript([ScriptBlock]$scriptBlock)
    {
        $this.defaultEditorScript = $scriptBlock
    }

    [void] RegisterFileManagerEntry()
    {
        $callback = {
            $result = $args[0].Result
            $arguments = $args[0].ArgumentList
            $rootDir = (Get-Location).Path

            if ($result.KeyCombination -eq $script:globalStore.firstActionKey)
            {
                [FileSystemRegistry]::FileManagerLoop($rootDir, $arguments)
            }
            elseif ($result.KeyCombination -eq $script:globalStore.copyActionKey)
            {
                $rootDir | Set-Clipboard
            }
        }

        $entry = [PowerShellRun.SelectorEntry]::new()
        $entry.Icon = '🔍'
        $entry.Name = 'File Manager (PSRun)'
        $entry.Description = 'Navigate file system with PowerShellRun based on the current directory'
        $entry.ActionKeys = @(
            [PowerShellRun.ActionKey]::new($script:globalStore.firstActionKey, 'Explore current directory')
            [PowerShellRun.ActionKey]::new($script:globalStore.copyActionKey, 'Copy current directory path to Clipboard')
        )

        $entry.UserData = @{
            ScriptBlock = $callback
            ArgumentList = $this.fileManagerArguments
        }

        $this.fileManagerEntry.Add($entry)
    }

    [void] AddFavoriteFolder($folderPath, $icon, $name, $description, $preview)
    {
        $callback = {
            $result = $args[0].Result
            $arguments, $path = $args[0].ArgumentList

            if ($result.KeyCombination -eq $script:globalStore.firstActionKey)
            {
                [FileSystemRegistry]::FileManagerLoop($path, $arguments)
            }
            elseif ($result.KeyCombination -eq $script:globalStore.secondActionKey)
            {
                Set-Location $path
            }
            elseif ($result.KeyCombination -eq $script:globalStore.thirdActionKey)
            {
                Invoke-Item $path
            }
            elseif ($result.KeyCombination -eq $script:globalStore.copyActionKey)
            {
                $path | Set-Clipboard
            }
        }

        $entry = [PowerShellRun.SelectorEntry]::new()
        $entry.Icon = if ($icon) {$icon} else {'📁'}
        $entry.Name = if ($name) {$name} else {Split-Path $folderPath -Leaf}
        $entry.Description = if ($description) {$description} else {$folderPath}
        if ($preview)
        {
            $entry.Preview = $preview
        }
        else
        {
            $entry.PreviewAsyncScript = $this.fileManagerArguments.PreviewScriptFolder
            $entry.PreviewAsyncScriptArgumentList = $folderPath
        }
        $entry.ActionKeys = $this.fileManagerArguments.FolderActionKeys

        $entry.UserData = @{
            ScriptBlock = $callback
            ArgumentList = $this.fileManagerArguments, $folderPath
        }

        $this.favoritesEntries.Add($entry)
        $this.isEntryUpdated = $true
    }

    [void] AddFavoriteFile($filePath, $icon, $name, $description, $preview)
    {
        $callback = {
            $result = $args[0].Result
            $arguments, $path = $args[0].ArgumentList

            if ($result.KeyCombination -eq $script:globalStore.firstActionKey)
            {
                Invoke-Item $path
            }
            elseif ($result.KeyCombination -eq $script:globalStore.secondActionKey)
            {
                $arguments.This.EditWithDefaultEditor($path)
            }
            elseif ($result.KeyCombination -eq $script:globalStore.thirdActionKey)
            {
                $arguments.This.OpenContainingFolder($path)
            }
            elseif ($result.KeyCombination -eq $script:globalStore.copyActionKey)
            {
                $path | Set-Clipboard
            }
        }

        $entry = [PowerShellRun.SelectorEntry]::new()
        $entry.Icon = if ($icon) {$icon} else {'📄'}
        $entry.Name = if ($name) {$name} else {Split-Path $filePath -Leaf}
        $entry.Description = if ($description) {$description} else {$filePath}
        if ($preview)
        {
            $entry.Preview = $preview
        }
        else
        {
            $entry.PreviewAsyncScript = $this.fileManagerArguments.PreviewScriptFile
            $entry.PreviewAsyncScriptArgumentList = $filePath
        }
        $entry.ActionKeys = $this.fileManagerArguments.FileActionKeys

        $entry.UserData = @{
            ScriptBlock = $callback
            ArgumentList = $this.fileManagerArguments, $filePath
        }

        $this.favoritesEntries.Add($entry)
        $this.isEntryUpdated = $true
    }

    static [void] FileManagerLoop($rootDir, $arguments)
    {
        $option = $script:globalStore.psRunSelectorOption.DeepClone()
        $option.QuitWithBackspaceOnEmptyQuery = $true

        $depth = 0
        $dir = $rootDir
        $parentDir = $null
        while ($true)
        {
            $option.Prompt = "$dir> "

            $result = Get-ChildItem -Path $dir | ForEach-Object {
                $entry = [PowerShellRun.SelectorEntry]::new()
                $entry.UserData = $_
                $entry.Name = $_.Name
                if ($_.PSIsContainer)
                {
                    $entry.Icon = '📁'
                    $entry.PreviewAsyncScript = $arguments.PreviewScriptFolder
                    $entry.ActionKeys = $arguments.FolderActionKeys
                }
                else
                {
                    $entry.Icon = '📄'
                    $entry.PreviewAsyncScript = $arguments.PreviewScriptFile
                    $entry.ActionKeys = $arguments.FileActionKeys
                }
                $entry.PreviewAsyncScriptArgumentList = $_.FullName
                $entry
            } | Invoke-PSRunSelectorCustom -Option $option

            if ($result.KeyCombination -eq 'Backspace')
            {
                if ($depth -eq 0)
                {
                    Restore-PSRunFunctionParentSelector
                    break
                }
                else
                {
                    $depth--
                    $dir = $parentDir
                    $parentDir = ([System.IO.Directory]::GetParent($dir)).FullName
                    continue
                }
            }

            if (-not $result.FocusedEntry)
            {
                break
            }

            $item = $result.FocusedEntry.UserData
            if ($result.KeyCombination -eq $script:globalStore.firstActionKey)
            {
                if ($item.PSIsContainer)
                {
                    $depth++
                    $parentDir = $dir
                    $dir = $item.FullName
                }
                else
                {
                    Invoke-Item $item.FullName
                    break
                }
            }
            elseif ($result.KeyCombination -eq $script:globalStore.secondActionKey)
            {
                if ($item.PSIsContainer)
                {
                    Set-Location $item.FullName
                }
                else
                {
                    $arguments.This.EditWithDefaultEditor($item.FullName)
                }
                break
            }
            elseif ($result.KeyCombination -eq $script:globalStore.thirdActionKey)
            {
                if ($item.PSIsContainer)
                {
                    Invoke-Item $item.FullName
                }
                else
                {
                    $arguments.This.OpenContainingFolder($item.FullName)
                }
                break
            }
            elseif ($result.KeyCombination -eq $script:globalStore.copyActionKey)
            {
                $item.FullName | Set-Clipboard
                break
            }
            else
            {
                break
            }
        }
    }

    [void] OpenContainingFolder($path)
    {
        if ($script:isWindows)
        {
            & explorer.exe (('/select,{0}' -f $path).Split())
        }
        else
        {
            $parentDir = ([System.IO.Directory]::GetParent($path)).FullName
            Invoke-Item $parentDir
        }
    }

    [void] EditWithDefaultEditor($path)
    {
        $this.defaultEditorScript.Invoke($path)
    }

    [bool] UpdateEntries()
    {
        $updated = $this.isEntryUpdated
        $this.isEntryUpdated = $false
        return $updated
    }
}

