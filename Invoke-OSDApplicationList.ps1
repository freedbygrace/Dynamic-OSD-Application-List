#Requires -Version 3

<#
    .SYNOPSIS
    Dynamically creates 'MandatoryApplicationXXX' task sequence variables with the GUIDs of MDT application objects to install on a device during operating system deployment.
          
    .DESCRIPTION
    Individual applications or entire application folders can be disabled to exclude the application(s) from being considered by the script during deployment.

    Application(s) that have already been installed by the task sequence whose GUID is stored within a 'InstalledApplicationsXXX' variable will be skipped if this script is executed multiple times during a task sequence.

    .PARAMETER ApplicationFolderDefinitionPath
    A valid path to the ApplicationGroups.xml file stored within the 'Control' folder within a MDT deployment share.

    .PARAMETER ApplicationDefinitionPath
    A valid path to the Applications.xml file stored within the 'Control' folder within a MDT deployment share.
          
    .PARAMETER TaskSequenceVariables
    One or more task sequence variable(s) to retrieve during task sequence execution.
    If this parameter is not specified, all task sequence variable(s) will be stored into the variable 'TSVariableTable'.
    Any task sequence variables that are new or have been updated will be saved back to the task sequence engine for futher usage.

    $TSVariable.MyCustomVariableName = "MyCustomVariableValue"
    $TSVariable.Make = "MyDeviceModel"

    .PARAMETER LogDir
    A valid folder path. If the folder does not exist, it will be created. This parameter can also be specified by the alias "LogPath".

    .PARAMETER ContinueOnError
    Ignore failures.

    .PARAMETER DebugMode
    Allows for testing to see which applications would be deployed without running a task sequence.
          
    .EXAMPLE
    Use this command to execute a VBSCript that will launch this powershell script automatically with the specified parameters. This is useful to avoid powershell execution complexities.
    
    cscript.exe /nologo "%FolderPathContainingScript%\%ScriptName%.vbs" /SwitchParameter /ScriptParameter:"%ScriptParameterValue%" /ScriptParameterArray:"%ScriptParameterValue1%,%ScriptParameterValue2%"

    wscript.exe /nologo "%FolderPathContainingScript%\%ScriptName%.vbs" /SwitchParameter /ScriptParameter:"%ScriptParameterValue%" /ScriptParameterArray:"%ScriptParameterValue1%,%ScriptParameterValue2%"

    .EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -File "%FolderPathContainingScript%\%ScriptName%.ps1" -SwitchParameter -ScriptParameter "%ScriptParameterValue%"

    .EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -NonInteractive -NoProfile -NoLogo -WindowStyle Hidden -Command "& '%FolderPathContainingScript%\%ScriptName%.ps1' -ScriptParameter1 '%ScriptParameter1Value%' -ScriptParameter2 %ScriptParameter2Value% -SwitchParameter"
  
    .NOTES
    Came up with this concept to keep task sequence modification to an absolute minimum.
          
    .LINK
    Place any useful link here where your function or cmdlet can be referenced
#>

[CmdletBinding(SupportsShouldProcess=$True)]
  Param
    (        	     
        [Parameter(Mandatory=$False)]
        [ValidateNotNullOrEmpty()]
        [Alias('AFDP')]
        [System.IO.FileInfo]$ApplicationFolderDefinitionPath,

        [Parameter(Mandatory=$False)]
        [ValidateNotNullOrEmpty()]
        [Alias('ADP')]
        [System.IO.FileInfo]$ApplicationDefinitionPath,
        
        [Parameter(Mandatory=$False)]
        [ValidateNotNullOrEmpty()]
        [Alias('TSVars', 'TSVs')]
        [String[]]$TaskSequenceVariables,
            
        [Parameter(Mandatory=$False)]
        [ValidateNotNullOrEmpty()]
        [Alias('LogDir', 'LogPath')]
        [System.IO.DirectoryInfo]$LogDirectory,
            
        [Parameter(Mandatory=$False)]
        [Switch]$ContinueOnError,

        [Parameter(Mandatory=$False)]
        [Switch]$DebugMode
    )
        
Function Get-AdministrativePrivilege
    {
        $Identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object System.Security.Principal.WindowsPrincipal($Identity)
        Write-Output -InputObject ($Principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator))
    }

If ((Get-AdministrativePrivilege) -eq $False)
    {
        [System.IO.FileInfo]$ScriptPath = "$($MyInvocation.MyCommand.Path)"

        $ArgumentList = New-Object -TypeName 'System.Collections.Generic.List[String]'
          $ArgumentList.Add('-ExecutionPolicy Bypass')
          $ArgumentList.Add('-NoProfile')
          $ArgumentList.Add('-NoExit')
          $ArgumentList.Add('-NoLogo')
          $ArgumentList.Add("-File `"$($ScriptPath.FullName)`"")

        $Null = Start-Process -FilePath "$([System.Environment]::SystemDirectory)\WindowsPowershell\v1.0\powershell.exe" -WorkingDirectory "$([System.Environment]::SystemDirectory)" -ArgumentList ($ArgumentList.ToArray()) -WindowStyle Normal -Verb RunAs -PassThru
    }
Else
    {
        #Determine the date and time we executed the function
          $ScriptStartTime = (Get-Date)
  
        #Define Default Action Preferences
            $Script:DebugPreference = 'SilentlyContinue'
            $Script:ErrorActionPreference = 'Stop'
            $Script:VerbosePreference = 'SilentlyContinue'
            $Script:WarningPreference = 'Continue'
            $Script:ConfirmPreference = 'None'
            $Script:WhatIfPreference = $False
    
        #Load WMI Classes
          $Baseboard = Get-WmiObject -Namespace "root\CIMv2" -Class "Win32_Baseboard" -Property *
          $Bios = Get-WmiObject -Namespace "root\CIMv2" -Class "Win32_Bios" -Property *
          $ComputerSystem = Get-WmiObject -Namespace "root\CIMv2" -Class "Win32_ComputerSystem" -Property *
          $OperatingSystem = Get-WmiObject -Namespace "root\CIMv2" -Class "Win32_OperatingSystem" -Property *
          $MSSystemInformation = Get-WmiObject -Namespace "root\WMI" -Class "MS_SystemInformation" -Property *

        #Retrieve property values
          $OSArchitecture = $($OperatingSystem.OSArchitecture).Replace("-bit", "").Replace("32", "86").Insert(0,"x").ToUpper()

        #Define variable(s)
          $DateTimeLogFormat = 'dddd, MMMM dd, yyyy @ hh:mm:ss.FFF tt'  ###Monday, January 01, 2019 @ 10:15:34.000 AM###
          [ScriptBlock]$GetCurrentDateTimeLogFormat = {(Get-Date).ToString($DateTimeLogFormat)}
          $DateTimeMessageFormat = 'MM/dd/yyyy HH:mm:ss.FFF'  ###03/23/2022 11:12:48.347###
          [ScriptBlock]$GetCurrentDateTimeMessageFormat = {(Get-Date).ToString($DateTimeMessageFormat)}
          $DateFileFormat = 'yyyyMMdd'  ###20190403###
          [ScriptBlock]$GetCurrentDateFileFormat = {(Get-Date).ToString($DateFileFormat)}
          $DateTimeFileFormat = 'yyyyMMdd_HHmmss'  ###20190403_115354###
          [ScriptBlock]$GetCurrentDateTimeFileFormat = {(Get-Date).ToString($DateTimeFileFormat)}
          [System.IO.FileInfo]$ScriptPath = "$($MyInvocation.MyCommand.Definition)"
          [System.IO.DirectoryInfo]$ScriptDirectory = "$($ScriptPath.Directory.FullName)"
          [System.IO.DirectoryInfo]$ContentDirectory = "$($ScriptDirectory.FullName)\Content"
          [System.IO.DirectoryInfo]$FunctionsDirectory = "$($ScriptDirectory.FullName)\Functions"
          [System.IO.DirectoryInfo]$ModulesDirectory = "$($ScriptDirectory.FullName)\Modules"
          [System.IO.DirectoryInfo]$ToolsDirectory = "$($ScriptDirectory.FullName)\Tools"
          [System.IO.DirectoryInfo]$ToolsDirectory_OSAll = "$($ToolsDirectory.FullName)\All"
          [System.IO.DirectoryInfo]$ToolsDirectory_OSArchSpecific = "$($ToolsDirectory.FullName)\$($OSArchitecture)"
          [System.IO.DirectoryInfo]$System32Directory = [System.Environment]::SystemDirectory
          [System.IO.DirectoryInfo]$ProgramFilesDirectory = "$($Env:SystemDrive)\Program Files"
          [System.IO.DirectoryInfo]$ProgramFilesx86Directory = "$($Env:SystemDrive)\Program Files (x86)"
          [System.IO.FileInfo]$PowershellPath = "$($System32Directory.FullName)\WindowsPowershell\v1.0\powershell.exe"
          [System.IO.DirectoryInfo]$System32Directory = "$([System.Environment]::SystemDirectory)"
          $IsWindowsPE = Test-Path -Path 'HKLM:\SYSTEM\ControlSet001\Control\MiniNT' -ErrorAction SilentlyContinue
          [System.Text.RegularExpressions.RegexOptions[]]$RegexOptions = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase, [System.Text.RegularExpressions.RegexOptions]::Multiline
          [ScriptBlock]$GetRandomGUID = {[System.GUID]::NewGUID().GUID.ToString().ToUpper()}
          [String]$ParameterSetName = "$($PSCmdlet.ParameterSetName)"
          $TextInfo = (Get-Culture).TextInfo
          $Script:LASTEXITCODE = 0
          $TerminationCodes = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
            $TerminationCodes.Add('Success', @(0))
            $TerminationCodes.Add('Warning', @(5000..5999))
            $TerminationCodes.Add('Error', @(6000..6999))
          $Script:WarningCodeIndex = 0
          [ScriptBlock]$GetAvailableWarningCode = {$TerminationCodes.Warning[$Script:WarningCodeIndex]; $Script:WarningCodeIndex++}
          $Script:ErrorCodeIndex = 0
          [ScriptBlock]$GetAvailableErrorCode = {$TerminationCodes.Error[$Script:ErrorCodeIndex]; $Script:ErrorCodeIndex++}
          $LoggingDetails = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'    
            $LoggingDetails.Add('LogMessage', $Null)
            $LoggingDetails.Add('WarningMessage', $Null)
            $LoggingDetails.Add('ErrorMessage', $Null)
          $RegularExpressionTable = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
            $RegularExpressionTable.Base64 = '^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=|[A-Za-z0-9+/]{4})$' -As [Regex]
          $CommonParameterList = New-Object -TypeName 'System.Collections.Generic.List[String]'
            $CommonParameterList.AddRange([System.Management.Automation.PSCmdlet]::CommonParameters)
            $CommonParameterList.AddRange([System.Management.Automation.PSCmdlet]::OptionalCommonParameters)

          #Define the error handling definition
            [ScriptBlock]$ErrorHandlingDefinition = {
                                                        If (($Null -ieq $Script:LASTEXITCODE) -or ($Script:LASTEXITCODE -eq 0))
                                                          {
                                                              [Int]$Script:LASTEXITCODE = $GetAvailableErrorCode.InvokeReturnAsIs()
                                                          }
                                                        
                                                        $ErrorMessageList = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                          $ErrorMessageList.Add('Message', $_.Exception.Message)
                                                          $ErrorMessageList.Add('Category', $_.Exception.ErrorRecord.FullyQualifiedErrorID)
                                                          $ErrorMessageList.Add('ExitCode', $Script:LASTEXITCODE)
                                                          $ErrorMessageList.Add('Script', $_.InvocationInfo.ScriptName)
                                                          $ErrorMessageList.Add('LineNumber', $_.InvocationInfo.ScriptLineNumber)
                                                          $ErrorMessageList.Add('LinePosition', $_.InvocationInfo.OffsetInLine)
                                                          $ErrorMessageList.Add('Code', $_.InvocationInfo.Line.Trim())

                                                        ForEach ($ErrorMessage In $ErrorMessageList.GetEnumerator())
                                                          {
                                                              $LoggingDetails.ErrorMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) -  ERROR: $($ErrorMessage.Key): $($ErrorMessage.Value)"
                                                              Write-Warning -Message ($LoggingDetails.ErrorMessage) -Verbose
                                                          }

                                                        Switch (($ContinueOnError.IsPresent -eq $False) -or ($ContinueOnError -eq $False))
                                                          {
                                                              {($_ -eq $True)}
                                                                {                  
                                                                    Throw
                                                                }
                                                          }
                                                    }
	
        #Log task sequence variables if debug mode is enabled within the task sequence
          Try
            {
                [System.__ComObject]$TSEnvironment = New-Object -ComObject "Microsoft.SMS.TSEnvironment"
              
                If ($Null -ine $TSEnvironment)
                  {
                      $IsRunningTaskSequence = $True
                      
                      [Boolean]$IsConfigurationManagerTaskSequence = [String]::IsNullOrEmpty($TSEnvironment.Value("_SMSTSPackageID")) -eq $False
                      
                      Switch ($IsConfigurationManagerTaskSequence)
                        {
                            {($_ -eq $True)}
                              {
                                  $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - A Microsoft Endpoint Configuration Manager (MECM) task sequence was detected."
                                  Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                              }
                                      
                            {($_ -eq $False)}
                              {
                                  $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - A Microsoft Deployment Toolkit (MDT) task sequence was detected."
                                  Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                              }
                        }
                  }
            }
          Catch
            {
                $IsRunningTaskSequence = $False
            }
            
        #Determine default parameter value(s)       
          Switch ($True)
            {
                {([String]::IsNullOrEmpty($LogDirectory) -eq $True) -or ([String]::IsNullOrWhiteSpace($LogDirectory) -eq $True)}
                  {
                      Switch ($IsRunningTaskSequence)
                        {
                            {($_ -eq $True)}
                              {
                                  Switch ($IsConfigurationManagerTaskSequence)
                                    {
                                        {($_ -eq $True)}
                                          {
                                              [String]$_SMSTSLogPath = "$($TSEnvironment.Value('_SMSTSLogPath'))"
                                          }
                              
                                        {($_ -eq $False)}
                                          {
                                              [String]$_SMSTSLogPath = "$($TSEnvironment.Value('LogPath'))"
                                          }
                                    }

                                  Switch ([String]::IsNullOrEmpty($_SMSTSLogPath))
                                    {
                                        {($_ -eq $True)}
                                          {
                                              [System.IO.DirectoryInfo]$TSLogDirectory = "$($Env:Windir)\Temp\SMSTSLog"    
                                          }
                                    
                                        {($_ -eq $False)}
                                          {
                                              Switch ($True)
                                                {
                                                    {(Test-Path -Path ($_SMSTSLogPath) -PathType Container)}
                                                      {
                                                          [System.IO.DirectoryInfo]$TSLogDirectory = ($_SMSTSLogPath)
                                                      }
                                    
                                                    {(Test-Path -Path ($_SMSTSLogPath) -PathType Leaf)}
                                                      {
                                                          [System.IO.DirectoryInfo]$TSLogDirectory = Split-Path -Path ($_SMSTSLogPath) -Parent
                                                      }
                                                }    
                                          }
                                    }
                                         
                                  [System.IO.DirectoryInfo]$LogDirectory = "$($TSLogDirectory.FullName)\$($ScriptPath.BaseName)"
                              }
                  
                            {($_ -eq $False)}
                              {
                                  Switch ($IsWindowsPE)
                                    {
                                        {($_ -eq $True)}
                                          {
                                              [System.IO.FileInfo]$MDTBootImageDetectionPath = "$($Env:SystemDrive)\Deploy\Scripts\Litetouch.wsf"
                                      
                                              [Boolean]$MDTBootImageDetected = Test-Path -Path ($MDTBootImageDetectionPath.FullName)
                                              
                                              Switch ($MDTBootImageDetected)
                                                {
                                                    {($_ -eq $True)}
                                                      {
                                                          [System.IO.DirectoryInfo]$LogDirectory = "$($Env:SystemDrive)\MININT\SMSOSD\OSDLOGS\$($ScriptPath.BaseName)"
                                                      }
                                          
                                                    {($_ -eq $False)}
                                                      {
                                                          [System.IO.DirectoryInfo]$LogDirectory = "$($Env:Windir)\Temp\SMSTSLog"
                                                      }
                                                }
                                          }
                                          
                                        {($_ -eq $False)}
                                          {
                                              [System.IO.DirectoryInfo]$LogDirectory = "$($Env:Windir)\Logs\Software\$($ScriptPath.BaseName)"
                                          }
                                    }   
                              }
                        }
                  }       
            }

        #Start transcripting (Logging)
          [System.IO.FileInfo]$ScriptLogPath = "$($LogDirectory.FullName)\$($ScriptPath.BaseName)_$($GetCurrentDateFileFormat.Invoke()).log"
          If ($ScriptLogPath.Directory.Exists -eq $False) {$Null = [System.IO.Directory]::CreateDirectory($ScriptLogPath.Directory.FullName)}
          Start-Transcript -Path "$($ScriptLogPath.FullName)" -Force -WhatIf:$False
	
        #Log any useful information                                     
          [String]$CmdletName = $MyInvocation.MyCommand.Name
                                                   
          $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Execution of script `"$($CmdletName)`" began on $($ScriptStartTime.ToString($DateTimeLogFormat))"
          Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

          $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Script Path = $($ScriptPath.FullName)"
          Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

          [String[]]$AvailableScriptParameters = (Get-Command -Name ($ScriptPath.FullName)).Parameters.GetEnumerator() | Where-Object {($_.Value.Name -inotin $CommonParameterList)} | ForEach-Object {"-$($_.Value.Name):$($_.Value.ParameterType.Name)"}
          $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Available Script Parameter(s) = $($AvailableScriptParameters -Join ', ')"
          Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

          [String[]]$SuppliedScriptParameters = $PSBoundParameters.GetEnumerator() | ForEach-Object {"-$($_.Key):$($_.Value.GetType().Name)"}
          $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Supplied Script Parameter(s) = $($SuppliedScriptParameters -Join ', ')"
          Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
          
          Switch ($True)
            {
                {([String]::IsNullOrEmpty($ParameterSetName) -eq $False)}
                  {
                      $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Parameter Set Name = $($ParameterSetName)"
                      Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                  }
            }
          
          $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Command Line: $((Get-WMIObject -Namespace 'Root\CIMv2' -Class 'Win32_Process' -Filter "ProcessID = $($PID)").CommandLine)"
          Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

          $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - $($PSBoundParameters.Count) command line parameter(s) were specified."
          Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

          $OperatingSystemDetailsTable = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
            $OperatingSystemDetailsTable.ProductName = $OperatingSystem.Caption -ireplace '(Microsoft\s+)', ''
            $OperatingSystemDetailsTable.Version = $OperatingSystem.Version
            $OperatingSystemDetailsTable.Architecture = $OperatingSystem.OSArchitecture

          $OperatingSystemRegistryDetails = New-Object -TypeName 'System.Collections.Generic.List[PSObject]'
            $OperatingSystemRegistryDetails.Add((New-Object -TypeName 'PSObject' -Property @{Alias = ''; Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'; ValueName = 'UBR'; Value = $Null}))
            $OperatingSystemRegistryDetails.Add((New-Object -TypeName 'PSObject' -Property @{Alias = 'ReleaseVersion'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'; ValueName = 'ReleaseID'; Value = $Null}))
            $OperatingSystemRegistryDetails.Add((New-Object -TypeName 'PSObject' -Property @{Alias = 'ReleaseID'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'; ValueName = 'DisplayVersion'; Value = $Null}))

          ForEach ($OperatingSystemRegistryDetail In $OperatingSystemRegistryDetails)
            {
                $OperatingSystemRegistryDetail.Value = Try {(Get-Item -Path $OperatingSystemRegistryDetail.Path).GetValue($OperatingSystemRegistryDetail.ValueName)} Catch {}

                :NextOSDetail Switch (([String]::IsNullOrEmpty($OperatingSystemRegistryDetail.Value) -eq $False) -and ([String]::IsNullOrWhiteSpace($OperatingSystemRegistryDetail.Value) -eq $False))
                  {
                      {($_ -eq $True)}
                        {
                            Switch ($OperatingSystemRegistryDetail.ValueName)
                              {
                                  {($_ -ieq 'UBR')}
                                    {
                                        $OperatingSystemDetailsTable.Version = $OperatingSystemDetailsTable.Version + '.' + $OperatingSystemRegistryDetail.Value

                                        Break NextOSDetail
                                    }
                              }

                            Switch (([String]::IsNullOrEmpty($OperatingSystemRegistryDetail.Alias) -eq $False) -and ([String]::IsNullOrWhiteSpace($OperatingSystemRegistryDetail.Alias) -eq $False))
                              {
                                  {($_ -eq $True)}
                                    {
                                        $OperatingSystemDetailsTable.$($OperatingSystemRegistryDetail.Alias) = $OperatingSystemRegistryDetail.Value
                                    }

                                  Default
                                    {
                                        $OperatingSystemDetailsTable.$($OperatingSystemRegistryDetail.ValueName) = $OperatingSystemRegistryDetail.Value
                                    }
                              }
                        }

                      Default
                        {
                            $OperatingSystemDetailsTable.$($OperatingSystemRegistryDetail.ValueName) = $OperatingSystemRegistryDetail.Value
                        }
                  }   
            }
    
          ForEach ($OperatingSystemDetail In $OperatingSystemDetailsTable.GetEnumerator())
            {
                $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - $($OperatingSystemDetail.Key): $($OperatingSystemDetail.Value)"
                Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
            }
      
          $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Powershell Version: $($PSVersionTable.PSVersion.ToString())"
          Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
      
          $ExecutionPolicyList = Get-ExecutionPolicy -List
  
          For ($ExecutionPolicyListIndex = 0; $ExecutionPolicyListIndex -lt $ExecutionPolicyList.Count; $ExecutionPolicyListIndex++)
            {
                $ExecutionPolicy = $ExecutionPolicyList[$ExecutionPolicyListIndex]

                $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - The powershell execution policy is currently set to `"$($ExecutionPolicy.ExecutionPolicy.ToString())`" for the `"$($ExecutionPolicy.Scope.ToString())`" scope."
                Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
            }
    
        #Log hardware information
          $MSSystemInformationMembers = $MSSystemInformation.PSObject.Properties | Where-Object {($_.MemberType -imatch '^NoteProperty$|^Property$') -and ($_.Name -imatch '^Base.*|Bios.*|System.*$') -and ($_.Name -inotmatch '^.*Major.*|.*Minor.*|.*Properties.*$')} | Sort-Object -Property @('Name')
          
          Switch ($MSSystemInformationMembers.Count -gt 0)
            {
                {($_ -eq $True)}
                  {
                      $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to display device information properties from the `"$($MSSystemInformation.__CLASS)`" WMI class located within the `"$($MSSystemInformation.__NAMESPACE)`" WMI namespace. Please Wait..."
                      Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
  
                      ForEach ($MSSystemInformationMember In $MSSystemInformationMembers)
                        {
                            [String]$MSSystemInformationMemberName = ($MSSystemInformationMember.Name)
                            [String]$MSSystemInformationMemberValue = $MSSystemInformation.$($MSSystemInformationMemberName)
        
                            Switch ([String]::IsNullOrEmpty($MSSystemInformationMemberValue))
                              {
                                  {($_ -eq $False)}
                                    {
                                        $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - $($MSSystemInformationMemberName) = $($MSSystemInformationMemberValue)"
                                        Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                    }
                              }
                        }
                  }

                Default
                  {
                      $LoggingDetails.WarningMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - The `"MSSystemInformation`" WMI class could not be found."
                      Write-Warning -Message ($LoggingDetails.WarningMessage) -Verbose
                  }
            }

        #region Log Cleanup
          [Int]$MaximumLogHistory = 3
          
          $LogList = Get-ChildItem -Path ($LogDirectory.FullName) -Filter "$($ScriptPath.BaseName)_*" -Recurse -Force | Where-Object {($_ -is [System.IO.FileInfo])}

          $SortedLogList = $LogList | Sort-Object -Property @('LastWriteTime') -Descending | Select-Object -Skip ($MaximumLogHistory)

          Switch ($SortedLogList.Count -gt 0)
            {
                {($_ -eq $True)}
                  {
                      $LoggingDetails.WarningMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - There are $($SortedLogList.Count) log file(s) requiring cleanup."
                      Write-Warning -Message ($LoggingDetails.WarningMessage) -Verbose
                      
                      For ($SortedLogListIndex = 0; $SortedLogListIndex -lt $SortedLogList.Count; $SortedLogListIndex++)
                        {
                            Try
                              {
                                  $Log = $SortedLogList[$SortedLogListIndex]

                                  $LogAge = New-TimeSpan -Start ($Log.LastWriteTime) -End (Get-Date)

                                  $LoggingDetails.WarningMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to cleanup log file `"$($Log.FullName)`". Please Wait... [Last Modified: $($Log.LastWriteTime.ToString($DateTimeMessageFormat))] [Age: $($LogAge.Days.ToString()) day(s); $($LogAge.Hours.ToString()) hours(s); $($LogAge.Minutes.ToString()) minute(s); $($LogAge.Seconds.ToString()) second(s)]."
                                  Write-Warning -Message ($LoggingDetails.WarningMessage) -Verbose
                  
                                  $Null = [System.IO.File]::Delete($Log.FullName)
                              }
                            Catch
                              {
                  
                              }   
                        }
                  }

                Default
                  {
                      $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - There are $($SortedLogList.Count) log file(s) requiring cleanup."
                      Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                  }
            }
        #endregion

        #region Import Dependency Modules
          If (($ModulesDirectory.Exists -eq $True) -and ($ModulesDirectory.GetDirectories().Count -gt 0))
            {
                $Modules = Get-Module -Name "$($ModulesDirectory.FullName)\*" -ListAvailable -ErrorAction Stop 

                $ModuleGroups = $Modules | Group-Object -Property @('Name')

                ForEach ($ModuleGroup In $ModuleGroups)
                  {
                      $LatestModuleVersion = $ModuleGroup.Group | Sort-Object -Property @('Version') -Descending | Select-Object -First 1
      
                      If ($Null -ine $LatestModuleVersion)
                        {
                            $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to import dependency powershell module `"$($LatestModuleVersion.Name)`" [Version: $($LatestModuleVersion.Version.ToString())]. Please Wait..."
                            Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                            Import-Module -Name "$($LatestModuleVersion.Path)" -Global -DisableNameChecking -Force -ErrorAction Stop
                        }
                  }
            }
        #endregion
        
        #region Dot Source Dependency Scripts
          #Dot source any additional script(s) from the functions directory. This will provide flexibility to add additional functions without adding complexity to the main script and to maintain function consistency.
            Try
              {
                  If ($FunctionsDirectory.Exists -eq $True)
                    {
                        $AdditionalFunctionsFilter = New-Object -TypeName 'System.Collections.Generic.List[String]'
                          $AdditionalFunctionsFilter.Add('*.ps1')
        
                        $AdditionalFunctionsToImport = Get-ChildItem -Path "$($FunctionsDirectory.FullName)" -Include ($AdditionalFunctionsFilter) -Recurse -Force | Where-Object {($_ -is [System.IO.FileInfo])}
        
                        $AdditionalFunctionsToImportCount = $AdditionalFunctionsToImport | Measure-Object | Select-Object -ExpandProperty Count
        
                        If ($AdditionalFunctionsToImportCount -gt 0)
                          {                    
                              ForEach ($AdditionalFunctionToImport In $AdditionalFunctionsToImport)
                                {
                                    Try
                                      {
                                          $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to dot source the functions contained within the dependency script `"$($AdditionalFunctionToImport.Name)`". Please Wait... [Script Path: `"$($AdditionalFunctionToImport.FullName)`"]"
                                          Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                          
                                          . "$($AdditionalFunctionToImport.FullName)"
                                      }
                                    Catch
                                      {
                                          $ErrorHandlingDefinition.Invoke()
                                      }
                                }
                          }
                    }
              }
            Catch
              {
                  $ErrorHandlingDefinition.Invoke()          
              }
        #endregion

        #region Load any required libraries
          [System.IO.DirectoryInfo]$LibariesDirectory = "$($FunctionsDirectory.FullName)\Libraries"

          Switch ([System.IO.Directory]::Exists($LibariesDirectory.FullName))
            {
                {($_ -eq $True)}
                  {
                      $LibraryPatternList = New-Object -TypeName 'System.Collections.Generic.List[String]'
                        #$LibraryPatternList.Add('')

                      Switch ($LibraryPatternList.Count -gt 0)
                        {
                            {($_ -eq $True)}
                              {
                                  $LibraryList = Get-ChildItem -Path ($LibariesDirectory.FullName) -Include ($LibraryPatternList.ToArray()) -Recurse -Force | Where-Object {($_ -is [System.IO.FileInfo])}

                                  $LibraryListCount = ($LibraryList | Measure-Object).Count
            
                                  Switch ($LibraryListCount -gt 0)
                                    {
                                        {($_ -eq $True)}
                                          {
                                              For ($LibraryListIndex = 0; $LibraryListIndex -lt $LibraryListCount; $LibraryListIndex++)
                                                {
                                                    $Library = $LibraryList[$LibraryListIndex]
            
                                                    [Byte[]]$LibraryBytes = [System.IO.File]::ReadAllBytes($Library.FullName)
            
                                                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to load assembly `"$($Library.FullName)`". Please Wait..."
                                                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
            
                                                    $Null = [System.Reflection.Assembly]::Load($LibraryBytes)     
                                                }
                                          }
                                    }
                              }
                        }          
                  }
            }
        #endregion

        #Perform script action(s)
          Try
            {                              
                $GetInstalledSoftwareParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
	                $GetInstalledSoftwareParameters.FilterInclusionExpression = "(.*)"
	                $GetInstalledSoftwareParameters.FilterExclusionExpression = "(^.{0,0}$)"
	                $GetInstalledSoftwareParameters.ContinueOnError = $True
	                $GetInstalledSoftwareParameters.Verbose = $False

                $InstalledSoftwareList = Get-InstalledSoftware @GetInstalledSoftwareParameters
                
                #If necessary, create, get, and or set any task sequence variable(s).   
                  Switch (($IsRunningTaskSequence -eq $True) -or ($DebugMode.IsPresent -eq $True))
                    {
                        {($_ -eq $True)}
                          {
                              Try
                                {
                                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - A task sequence is currently running."
                                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                              
                                    $TSVariableTable = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'

                                    $TaskSequenceVariableRetrievalList = New-Object -TypeName 'System.Collections.Generic.List[String]'
                                
                                    Switch ($TaskSequenceVariables.Count -gt 0)
                                      {
                                          {($_ -eq $True)}
                                            {
                                                ForEach ($TaskSequenceVariable In $TaskSequenceVariables)
                                                  {
                                                      $TaskSequenceVariableRetrievalList.Add($TaskSequenceVariable)
                                                  }
                                            }
                                      }
  
                                    $TSVariableTable = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                    
                                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to retrieve the task sequence variable list. Please Wait..."
                                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                      
                                    Switch ($TaskSequenceVariableRetrievalList.Count -gt 0)
                                      {
                                          {($_ -eq $True)}
                                            {
                                                $TSVariableList = $TSEnvironment.GetVariables() | Where-Object {($_ -iin $TaskSequenceVariableRetrievalList)} | Sort-Object
                                            }
                                      
                                          Default
                                            {
                                                $TSVariableList = $TSEnvironment.GetVariables() | Sort-Object
                                            }
                                      }
                      
                                    ForEach ($TSVariable In $TSVariableList)
                                      {
                                          $TSVariableName = $TSVariable
                                          $TSVariableValue = $TSEnvironment.Value($TSVariableName)
                      
                                          Switch ($True)
                                            {
                                                {($TSVariableName -inotmatch '(^_SMSTSTaskSequence$)|(^TaskSequence$)|(^.*Pass.*word.*$)')}
                                                  {
                                                      $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to retrieve the value of task sequence variable `"$($TSVariableName)`". Please Wait..."
                                                      Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                                  }
                                                                            
                                                {($TSVariableTable.Contains($TSVariableName) -eq $False)}
                                                  {
                                                      $TSVariableTable.Add($TSVariableName, $TSVariableValue)    
                                                  }             
                                            } 
                                      }
                                      
                                    $InstalledApplicationDictionary = $TSVariableTable.GetEnumerator() | Where-Object {($_.Key -imatch '(^InstalledApplications\d{3,3}$)')}
                                    
                                    $InstalledApplicationDictionaryCount = ($InstalledApplicationDictionary | Measure-Object).Count

                                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - $($InstalledApplicationDictionaryCount) application(s) have already been installed on `"$($Env:ComputerName.ToUpper())`" during task sequence `"$($TSVariableTable.TASKSEQUENCENAME)`"."
                                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                }
                              Catch
                                {
                                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - [Error Message: $($_.Exception.Message)] [Code: $($_.InvocationInfo.Line.Trim())] [Line Number: $($_.InvocationInfo.ScriptLineNumber)] [Line Position: $($_.InvocationInfo.OffsetInLine)]"
                                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                }
                              Finally
                                {
                                
                                }
                          }
                    }

                Switch (($IsRunningTaskSequence -eq $True) -or ($DebugMode.IsPresent -eq $True))
                  {
                      {($_ -eq $True)}
                        {                             
                            #Set default parameter values
                              Switch ($True)
                                {
                                    {([String]::IsNullOrEmpty($ApplicationFolderDefinitionPath) -eq $True) -or ([String]::IsNullOrWhiteSpace($ApplicationFolderDefinitionPath) -eq $True)}
                                      {
                                          [System.IO.FileInfo]$ApplicationFolderDefinitionPath = "$($TSVariableTable.DEPLOYROOT)\Control\ApplicationGroups.xml"
                                      }

                                    {([String]::IsNullOrEmpty($ApplicationDefinitionPath) -eq $True) -or ([String]::IsNullOrWhiteSpace($ApplicationDefinitionPath) -eq $True)}
                                      {
                                          [System.IO.FileInfo]$ApplicationDefinitionPath = "$($TSVariableTable.DEPLOYROOT)\Control\Applications.xml"
                                      }
                                }

                            $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Application Folder Defintion Path: $($ApplicationFolderDefinitionPath.FullName)"
                            Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                            $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Application Definition Path: $($ApplicationDefinitionPath.FullName)"
                            Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                                              
                            Switch ([System.IO.File]::Exists($ApplicationFolderDefinitionPath.FullName))
                              {
                                  {($_ -eq $True)}
                                    {     
                                        Switch ([System.IO.File]::Exists($ApplicationDefinitionPath.FullName))
                                          {
                                              {($_ -eq $True)}
                                                {
                                                    $ApplicationFolderDefinitionContents = [System.IO.File]::ReadAllText($ApplicationFolderDefinitionPath.FullName)
                                                  
                                                    $ApplicationFolderDefinition = New-Object -TypeName 'System.Xml.XmlDocument'
                                                      $ApplicationFolderDefinition.LoadXml($ApplicationFolderDefinitionContents)
            
                                                    $ApplicationFolderObjectList = $ApplicationFolderDefinition.groups.group | Where-Object {($_.Enable -eq $True)}
                                                    
                                                    $ApplicationDefinitionContents = [System.IO.File]::ReadAllText($ApplicationDefinitionPath.FullName)
            
                                                    $ApplicationDefinition = New-Object -TypeName 'System.Xml.XmlDocument'
                                                      $ApplicationDefinition.LoadXml($ApplicationDefinitionContents)
            
                                                    $AvailableApplicationList = $ApplicationDefinition.applications.application | Where-Object {($_.Enable -eq $True) -and ($ApplicationFolderObjectList.Member -icontains $_.GUID)} | Sort-Object -Property @{Expression = {Try {($_.Version -As [Int])} Catch {($_.Version)}}}
                                                     
                                                    Switch ($InstalledApplicationDictionaryCount -gt 0)
                                                      {
                                                          {($_ -eq $True)}
                                                            {
                                                                $InstalledApplicationList = $AvailableApplicationList | Where-Object {($InstalledApplicationList.Value -icontains $_.GUID)}

                                                                ForEach ($InstalledApplication In $InstalledApplicationList)
                                                                  {
                                                                      $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Application `"$($InstalledApplication.Name)`" [GUID: $($InstalledApplication.GUID.ToUpper())] has already been installed on `"$($Env:ComputerName.ToUpper())`" and will be removed from the available application list."
                                                                      Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                                                  }
                                                                
                                                                $AvailableApplicationList = $AvailableApplicationList | Where-Object {($InstalledApplicationDictionary.Value -inotcontains $_.GUID)}
                                                            }
                                                      }
                                                    
                                                    $ApplicationObjectList = New-Object -TypeName 'System.Collections.Generic.List[Object]'

                                                    For ($AvailableApplicationListIndex = 0; $AvailableApplicationListIndex -lt $AvailableApplicationList.Count; $AvailableApplicationListIndex++)
                                                      {
                                                          $AvailableApplication = $AvailableApplicationList[$AvailableApplicationListIndex]

                                                          $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Adding available application `"$($AvailableApplication.Name)`" to the available application list. Please Wait..."
                                                          Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                                                          $ApplicationObjectList.Add($AvailableApplication)
                                                      }

                                                    [Int]$ApplicationVariableCounter = 1
                                                    
                                                    For ($ApplicationObjectListIndex = 0; $ApplicationObjectListIndex -lt $ApplicationObjectList.Count; $ApplicationObjectListIndex++)
                                                      {
                                                          Try
                                                            {                                                                                            
                                                                $ApplicationObject = $ApplicationObjectList[$ApplicationObjectListIndex]
                                                                
                                                                $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to determine the applicability of application object `"$($ApplicationObject.Name)`". Please Wait..."
                                                                Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                                                                $ApplicationObjectConfiguration = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                  $ApplicationObjectConfiguration.Applicable = $False

                                                                $ApplicationApplicabilityConditionContent = $ApplicationObject.Language

                                                                $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Application Applicability Condition: $($ApplicationApplicabilityConditionContent)"
                                                                Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                                                                Switch ($ApplicationApplicabilityConditionContent -imatch '.*\$.*')
                                                                  {
                                                                      {($_ -eq $True)}
                                                                        {
                                                                            $ApplicationApplicabilityCondition = [ScriptBlock]::Create($ApplicationApplicabilityConditionContent)

                                                                            $ApplicationObjectConfiguration.Applicable = $ApplicationApplicabilityCondition.InvokeReturnAsIs()

                                                                            $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Application Applicability Condition Result: `$$($ApplicationObjectConfiguration.Applicable)"
                                                                            Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                                                                            Switch ($ApplicationObjectConfiguration.Applicable)
                                                                              {
                                                                                  {($_ -eq $True)}
                                                                                    {
                                                                                        $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Application object `"$($ApplicationObject.Name)`" is applicable and WILL be installed."
                                                                                        Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                                                                                        $ApplicationInstallationDetails = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                                          $ApplicationInstallationDetails.Number = $ApplicationVariableCounter++     
                                                                                          $ApplicationInstallationDetails.TSVariableName = 'MandatoryApplications' + $ApplicationInstallationDetails.Number.ToString('000')
                                                                                          $ApplicationInstallationDetails.TSVariableValue = $ApplicationObject.GUID.ToUpper()
                          
                                                                                        $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to add `"$($ApplicationObject.Name)`" to the application installation list. Please Wait..."
                                                                                        Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
            
                                                                                        $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Task Sequence Variable: $($ApplicationInstallationDetails.TSVariableName)=$($ApplicationInstallationDetails.TSVariableValue)"
                                                                                        Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                    
                                                                                        $TSVariableTable."$($ApplicationInstallationDetails.TSVariableName)" = $ApplicationInstallationDetails.TSVariableValue
                                                                                    }

                                                                                  Default
                                                                                    {
                                                                                        $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Application object `"$($ApplicationObject.Name)`" is NOT applicable and will NOT be installed."
                                                                                        Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                                                                    }
                                                                              }
                                                                        }

                                                                      Default
                                                                        {
                                                                            $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - The application applicability could not determined. Skipping..."
                                                                            Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                                                            
                                                                            Continue
                                                                        }
                                                                  }
                                                            }
                                                          Catch
                                                            {
                                                                $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Application: `"$($ApplicationObject.Name)`" [Error Message: $($_.Exception.Message)] [Code: $($_.InvocationInfo.Line.Trim())] [Line Number: $($_.InvocationInfo.ScriptLineNumber)] [Line Position: $($_.InvocationInfo.OffsetInLine)]"
                                                                Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                                            }
                                                          Finally
                                                            {

                                                            }
                                                      }                        
                                                }
            
                                              Default
                                                {
                                                    $LoggingDetails.WarningMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Application definition file `"$($ApplicationDefinitionPath.FullName)`" does not exist."
                                                    Write-Warning -Message ($LoggingDetails.WarningMessage) -Verbose
                                                }
                                          }
                                    }

                                  Default
                                    {
                                        $LoggingDetails.WarningMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Application folder definition file `"$($ApplicationFolderDefinitionPath.FullName)`" does not exist."
                                        Write-Warning -Message ($LoggingDetails.WarningMessage) -Verbose
                                    }
                              }
                        }
                  }

                
                                                           
                #If necessary, create, get, and or set any task sequence variable(s).   
                  Switch (($IsRunningTaskSequence -eq $True) -or ($DebugMode.IsPresent -eq $True))
                    {
                        {($_ -eq $True)}
                          {            
                              Try
                                {
                                    ForEach ($TSVariable In $TSVariableTable.GetEnumerator())
                                      {
                                          [String]$TSVariableName = "$($TSVariable.Key)"
                                          [String]$TSVariableCurrentValue = $TSEnvironment.Value($TSVariableName)
                                          [String]$TSVariableNewValue = "$($TSVariable.Value -Join ',')"
                                                  
                                          Switch ($TSVariableCurrentValue -ine $TSVariableNewValue)
                                            {
                                                {($_ -eq $True)}
                                                  {
                                                      $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to set the task sequence variable of `"$($TSVariableName)`". Please Wait..."
                                                      Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                                      
                                                      $Null = $TSEnvironment.Value($TSVariableName) = "$($TSVariableNewValue)" 
                                                  }
                                            } 
                                      }
                                
                                    $Null = [System.Runtime.Interopservices.Marshal]::ReleaseComObject($TSEnvironment)    
                                }
                              Catch
                                {
                                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - [Error Message: $($_.Exception.Message)] [Code: $($_.InvocationInfo.Line.Trim())] [Line Number: $($_.InvocationInfo.ScriptLineNumber)] [Line Position: $($_.InvocationInfo.OffsetInLine)]"
                                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                }
                              Finally
                                {
                                    
                                }
                          }
                        
                        {($_ -eq $False)}
                          {
                              $LoggingDetails.WarningMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - There is no task sequence running."
                              Write-Warning -Message ($LoggingDetails.WarningMessage) -Verbose
                          }
                    }
                  
                $Script:LASTEXITCODE = $TerminationCodes.Success[0]
            }
          Catch
            {
                $ErrorHandlingDefinition.Invoke()
            }
          Finally
            {
                Try
                  {
                      #Determine the date and time the function completed execution
                        $ScriptEndTime = (Get-Date)

                        $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Script execution of `"$($CmdletName)`" ended on $($ScriptEndTime.ToString($DateTimeLogFormat))"
                        Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                      #Log the total script execution time  
                        $ScriptExecutionTimespan = New-TimeSpan -Start ($ScriptStartTime) -End ($ScriptEndTime)

                        $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Script execution took $($ScriptExecutionTimespan.Hours.ToString()) hour(s), $($ScriptExecutionTimespan.Minutes.ToString()) minute(s), $($ScriptExecutionTimespan.Seconds.ToString()) second(s), and $($ScriptExecutionTimespan.Milliseconds.ToString()) millisecond(s)"
                        Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
            
                      $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Exiting script `"$($ScriptPath.FullName)`" with exit code $($Script:LASTEXITCODE)."
                      Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
            
                      Stop-Transcript
                  }
                Catch
                  {
            
                  }
            }
    }