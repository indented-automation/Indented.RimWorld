﻿function Copy-RWModDef {
    <#
    .SYNOPSIS
        Copies a definition from a mod.
    .DESCRIPTION
        Copies a definition from a mod.
    #>

    [CmdletBinding(DefaultParameterSetName = 'CopyFromMod')]
    [OutputType([System.Xml.Linq.XDocument])]
    param (
        # The name of the Def which should be copied.
        [Parameter(Mandatory, ParameterSetName = 'CopyFromMod')]
        [String]$Name,

        # The DefType to copy.
        [Parameter(ParameterSetName = 'CopyFromMod')]
        [String]$DefType,

        # The RimWorld version the def exists within.
        [Parameter(Mandatory, ParameterSetName = 'CopyFromMod')]
        [Version]$Version,

        # A def as an XML string.
        [Parameter(Mandatory, ParameterSetName = 'CreateFromDef')]
        [String]$Def,

        # The new name of the def.
        [String]$NewName,

        # elements which should be removed from the def.
        [String[]]$Remove,

        # Values which should be updated.
        [Hashtable]$Update,

        # Save the resulting def.
        [ValidateScript( { Test-Path $_ -PathType Leaf } )]
        [String]$SaveAs
    )

    if ($pscmdlet.ParameterSetName -eq 'CopyFromMod') {
        $id = '{0}\{1}' -f $Version, $Name
        if ($DefType) {
            $id = '{0}\{1}' -f $id, $DefType
        }

        $modName, $defName = $Name -split '[\\/]'
        if ($null -eq $modName) {
            $modName = 'Core'
        }

        if ($null -eq $Script:defCopyCache) {
            $Script:defCopyCache = @{}
        }
        if ($Script:defCopyCache.Contains($id)) {
            $def = $Script:defCopyCache[$id]
        } else {
            $params = @{
                ModName = $modName
                DefName = $defName
                Version = $Version
            }
            if ($DefType) {
                $params.DefType = $DefType
            }
            $def = Get-RWModDef @params | ForEach-Object { $_.XElement.ToString() }
            $Script:defCopyCache.Add($id, $def)
        }
    }

    if ($null -eq $def) {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [ArgumentException]::new('Cannot locate source def'),
            'UnknownDef',
            [System.Management.Automation.ErrorCategory]::InvalidArgument,
            $defName
        )
        $pscmdlet.ThrowTerminatingError($errorRecord)
    }

    $defCopy = [System.Xml.Linq.XDocument]::Parse($def)

    if ($NewName) {
        if ($defCopy.Root.Element('DefName')) {
            $defCopy.Root.Element('DefName').SetValue($NewName)
        } elseif ($defCopy.Root.Element('defName')) {
            $defCopy.Root.Element('defName').SetValue($NewName)
        } elseif ($defCopy.Root.Attribute('Name')) {
            $defCopy.Root.Attribute('Name').SetValue($NewName)
        }
    }

    if ($psboundparameters.ContainsKey('Remove')) {
        foreach ($item in $Remove) {
            $xElement = $defCopy.FirstNode
            foreach($element in $item.Split('.')) {
                if ($xElement) {
                    $xElement = $xElement.Element($element)
                }
            }
            if  ($xElement) {
                $xElement.Remove()
            }
        }
    }

    if ($psboundparameters.ContainsKey('Update')) {
        foreach ($item in $Update.Keys) {
            $xElement = $defCopy.FirstNode
            foreach ($element in $item.Split('.')) {
                $childXElement = $xElement.Element($element)
                if ($null -eq $childXElement) {
                    if ($xElement.Name -eq 'comps') {
                        $xElement = $xElement.Elements().Where( { $_.Attribute('Class').Value -eq $element } )
                    } elseif ($childAttribute = $xElement.Attribute($element)) {
                        $xElement = $childAttribute
                    } else {
                        $xElement.Add((
                            [System.Xml.Linq.XElement]::new(
                                [System.Xml.Linq.XName]$element,
                                $null
                            )
                        ))
                        $xElement = $xElement.Element($element)
                    }
                } else {
                    $xElement = $childXElement
                }
            }
            if  ($xElement) {
                if ($Update[$item] -is [Array]) {
                    foreach ($value in $Update[$item]) {
                        $xElement.Add((
                            [System.Xml.Linq.XElement]::new(
                                [System.Xml.Linq.XName]'li',
                                $value
                            )
                        ))
                    }
                } else {
                    $xElement.SetValue($Update[$item])
                }
            }
        }
    }

    if ($SaveAs) {
        $xDocument = [System.Xml.Linq.XDocument]::Load($SaveAs)
        $xDocument.Root.Add($defCopy.Root)

        $xDocument.Save($SaveAs)
    } else {
        $defCopy
    }
}
