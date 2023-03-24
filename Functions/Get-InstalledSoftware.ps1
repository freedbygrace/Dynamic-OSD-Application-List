## Microsoft Function Naming Convention: http://msdn.microsoft.com/en-us/library/ms714428(v=vs.85).aspx

#region Function Get-InstalledSoftware
Function Get-InstalledSoftware
    {
        <#
          .SYNOPSIS
          Retrieves a list of software installed on the current device.
          
          .DESCRIPTION
          Supports filtering the resulting list of software by using regular expressions. 
          
          .PARAMETER FilterInclusionExpression
          Includes software based on their display name.

          .PARAMETER FilterInclusionExpression
          Excludes software based on their display name.

          .PARAMETER ContinueOnError
          Continues processing even if an error has occured.

          .EXAMPLE
          Get-InstalledSoftware
          
          .EXAMPLE
          Get-InstalledSoftware -Verbose

          .EXAMPLE
          $GetInstalledSoftwareParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
            $GetInstalledSoftwareParameters.FilterInclusionExpression = "(.*)"
            $GetInstalledSoftwareParameters.FilterExclusionExpression = "(^.{0,0}$)"
            $GetInstalledSoftwareParameters.ContinueOnError = $False
            $GetInstalledSoftwareParameters.Verbose = $True

          $GetInstalledSoftwareResult = Get-InstalledSoftware @GetInstalledSoftwareParameters

          Write-Output -InputObject ($GetInstalledSoftwareResult)
        #>
        
        [CmdletBinding()]
       
        Param
          (        
                [Parameter(Mandatory=$False)]
                [ValidateNotNullOrEmpty()]
                [Alias('FIE')]
                [Regex]$FilterInclusionExpression,

                [Parameter(Mandatory=$False)]
                [ValidateNotNullOrEmpty()]
                [Alias('FEE')]
                [Regex]$FilterExclusionExpression,
                                                    
                [Parameter(Mandatory=$False)]
                [Alias('COE')]
                [Switch]$ContinueOnError        
          )
      
        Begin
          {
              Try
                {
                    $DateTimeLogFormat = 'dddd, MMMM dd, yyyy @ hh:mm:ss.FFF tt'  ###Monday, January 01, 2019 @ 10:15:34.000 AM###
                    [ScriptBlock]$GetCurrentDateTimeLogFormat = {(Get-Date).ToString($DateTimeLogFormat)}
                    $DateTimeMessageFormat = 'MM/dd/yyyy HH:mm:ss.FFF'  ###03/23/2022 11:12:48.347###
                    [ScriptBlock]$GetCurrentDateTimeMessageFormat = {(Get-Date).ToString($DateTimeMessageFormat)}
                    $DateFileFormat = 'yyyyMMdd'  ###20190403###
                    [ScriptBlock]$GetCurrentDateFileFormat = {(Get-Date).ToString($DateFileFormat)}
                    $DateTimeFileFormat = 'yyyyMMdd_HHmmss'  ###20190403_115354###
                    [ScriptBlock]$GetCurrentDateTimeFileFormat = {(Get-Date).ToString($DateTimeFileFormat)}
                    $TextInfo = (Get-Culture).TextInfo
                    $LoggingDetails = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'    
                      $LoggingDetails.Add('LogMessage', $Null)
                      $LoggingDetails.Add('WarningMessage', $Null)
                      $LoggingDetails.Add('ErrorMessage', $Null)
                    $CommonParameterList = New-Object -TypeName 'System.Collections.Generic.List[String]'
                      $CommonParameterList.AddRange([System.Management.Automation.PSCmdlet]::CommonParameters)
                      $CommonParameterList.AddRange([System.Management.Automation.PSCmdlet]::OptionalCommonParameters)

                    [ScriptBlock]$ErrorHandlingDefinition = {
                                                                $ErrorMessageList = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                  $ErrorMessageList.Add('Message', $_.Exception.Message)
                                                                  $ErrorMessageList.Add('Category', $_.Exception.ErrorRecord.FullyQualifiedErrorID)
                                                                  $ErrorMessageList.Add('Script', $_.InvocationInfo.ScriptName)
                                                                  $ErrorMessageList.Add('LineNumber', $_.InvocationInfo.ScriptLineNumber)
                                                                  $ErrorMessageList.Add('LinePosition', $_.InvocationInfo.OffsetInLine)
                                                                  $ErrorMessageList.Add('Code', $_.InvocationInfo.Line.Trim())

                                                                ForEach ($ErrorMessage In $ErrorMessageList.GetEnumerator())
                                                                  {
                                                                      $LoggingDetails.ErrorMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) -  ERROR: $($ErrorMessage.Key): $($ErrorMessage.Value)"
                                                                      Write-Warning -Message ($LoggingDetails.ErrorMessage)
                                                                  }

                                                                Switch (($ContinueOnError.IsPresent -eq $False) -or ($ContinueOnError -eq $False))
                                                                  {
                                                                      {($_ -eq $True)}
                                                                        {                  
                                                                            Throw
                                                                        }
                                                                  }
                                                            }
                    
                    #Determine the date and time we executed the function
                      $FunctionStartTime = (Get-Date)
                    
                    [String]$FunctionName = $MyInvocation.MyCommand
                    [System.IO.FileInfo]$InvokingScriptPath = $MyInvocation.PSCommandPath
                    [System.IO.DirectoryInfo]$InvokingScriptDirectory = $InvokingScriptPath.Directory.FullName
                    [System.IO.FileInfo]$FunctionPath = "$($InvokingScriptDirectory.FullName)\Functions\$($FunctionName).ps1"
                    [System.IO.DirectoryInfo]$FunctionDirectory = "$($FunctionPath.Directory.FullName)"
                    
                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Function `'$($FunctionName)`' is beginning. Please Wait..."
                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
              
                    #Define Default Action Preferences
                      $ErrorActionPreference = 'Stop'
                      
                    [String[]]$AvailableScriptParameters = (Get-Command -Name ($FunctionName)).Parameters.GetEnumerator() | Where-Object {($_.Value.Name -inotin $CommonParameterList)} | ForEach-Object {"-$($_.Value.Name):$($_.Value.ParameterType.Name)"}
                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Available Function Parameter(s) = $($AvailableScriptParameters -Join ', ')"
                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                    [String[]]$SuppliedScriptParameters = $PSBoundParameters.GetEnumerator() | ForEach-Object {"-$($_.Key):$($_.Value.GetType().Name)"}
                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Supplied Function Parameter(s) = $($SuppliedScriptParameters -Join ', ')"
                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Execution of $($FunctionName) began on $($FunctionStartTime.ToString($DateTimeLogFormat))"
                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                    #region Set Default Parameter Values
                        Switch ($True)
                          {
                              {([String]::IsNullOrEmpty($FilterInclusionExpression) -eq $True) -or ([String]::IsNullOrWhiteSpace($FilterInclusionExpression) -eq $True)}
                                {
                                    [Regex]$FilterInclusionExpression = '(.*)'
                                }

                              {([String]::IsNullOrEmpty($FilterExclusionExpression) -eq $True) -or ([String]::IsNullOrWhiteSpace($FilterExclusionExpression) -eq $True)}
                                {
                                    [Regex]$FilterExclusionExpression = '(^.{0,0}$)'
                                }
                          }
                    #endregion

                    #Create a table for the conversion of dates
                      $DateTimeProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                        $DateTimeProperties.FormatList = New-Object -TypeName 'System.Collections.Generic.List[String]'
                          $DateTimeProperties.FormatList.AddRange(([System.Globalization.DateTimeFormatInfo]::CurrentInfo.GetAllDateTimePatterns()))
                          $DateTimeProperties.FormatList.AddRange(([System.Globalization.DateTimeFormatInfo]::InvariantInfo.GetAllDateTimePatterns()))
                          $DateTimeProperties.FormatList.Add('yyyyMM')
                          $DateTimeProperties.FormatList.Add('yyyyMMdd')
                        $DateTimeProperties.Culture = $Null
                        $DateTimeProperties.Styles = New-Object -TypeName 'System.Collections.Generic.List[System.Globalization.DateTimeStyles]'
                          $DateTimeProperties.Styles.Add([System.Globalization.DateTimeStyles]::AssumeLocal)
                          $DateTimeProperties.Styles.Add([System.Globalization.DateTimeStyles]::AllowWhiteSpaces)
                                        
                    #Create an object that will contain the functions output.
                      $OutputObjectList = New-Object -TypeName 'System.Collections.Generic.List[PSObject]'
                }
              Catch
                {
                    $ErrorHandlingDefinition.Invoke()
                }
              Finally
                {

                }
          }

        Process
          {
              Try
                {
                    $DateTimeLogFormat = 'dddd, MMMM dd, yyyy @ hh:mm:ss.FFF tt'  ###Monday, January 01, 2019 @ 10:15:34.000 AM###
                    [ScriptBlock]$GetCurrentDateTimeLogFormat = {(Get-Date).ToString($DateTimeLogFormat)}
                    $DateTimeMessageFormat = 'MM/dd/yyyy HH:mm:ss.FFF'  ###03/23/2022 11:12:48.347###
                    [ScriptBlock]$GetCurrentDateTimeMessageFormat = {(Get-Date).ToString($DateTimeMessageFormat)}
                    $DateFileFormat = 'yyyyMMdd'  ###20190403###
                    [ScriptBlock]$GetCurrentDateFileFormat = {(Get-Date).ToString($DateFileFormat)}
                    $DateTimeFileFormat = 'yyyyMMdd_HHmmss'  ###20190403_115354###
                    [ScriptBlock]$GetCurrentDateTimeFileFormat = {(Get-Date).ToString($DateTimeFileFormat)}
                    $TextInfo = (Get-Culture).TextInfo
                    $LoggingDetails = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'    
                      $LoggingDetails.Add('LogMessage', $Null)
                      $LoggingDetails.Add('WarningMessage', $Null)
                      $LoggingDetails.Add('ErrorMessage', $Null)
                    $CommonParameterList = New-Object -TypeName 'System.Collections.Generic.List[String]'
                      $CommonParameterList.AddRange([System.Management.Automation.PSCmdlet]::CommonParameters)
                      $CommonParameterList.AddRange([System.Management.Automation.PSCmdlet]::OptionalCommonParameters)
                    $RegularExpressionTable = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                      $RegularExpressionTable.Base64 = '^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=|[A-Za-z0-9+/]{4})$' -As [Regex]
                      $RegularExpressionTable.GUID = '(\{){0,1}[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}(\}){0,1}' -As [Regex]   
                    $RegexOptionList = New-Object -TypeName 'System.Collections.Generic.List[System.Text.RegularExpressions.RegexOptions[]]'
                      $RegexOptionList.Add([System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                      $RegexOptionList.Add([System.Text.RegularExpressions.RegexOptions]::Multiline)
      
                    [ScriptBlock]$ErrorHandlingDefinition = {
                                                                $ErrorMessageList = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                  $ErrorMessageList.Add('Message', $_.Exception.Message)
                                                                  $ErrorMessageList.Add('Category', $_.Exception.ErrorRecord.FullyQualifiedErrorID)
                                                                  $ErrorMessageList.Add('Script', $_.InvocationInfo.ScriptName)
                                                                  $ErrorMessageList.Add('LineNumber', $_.InvocationInfo.ScriptLineNumber)
                                                                  $ErrorMessageList.Add('LinePosition', $_.InvocationInfo.OffsetInLine)
                                                                  $ErrorMessageList.Add('Code', $_.InvocationInfo.Line.Trim())
      
                                                                ForEach ($ErrorMessage In $ErrorMessageList.GetEnumerator())
                                                                  {
                                                                      $LoggingDetails.ErrorMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) -  ERROR: $($ErrorMessage.Key): $($ErrorMessage.Value)"
                                                                      Write-Warning -Message ($LoggingDetails.ErrorMessage)
                                                                  }
      
                                                                Switch (($ContinueOnError.IsPresent -eq $False) -or ($ContinueOnError -eq $False))
                                                                  {
                                                                      {($_ -eq $True)}
                                                                        {                  
                                                                            Throw
                                                                        }
                                                                  }
                                                            }
                        
                    $OutputObjectList = New-Object -TypeName 'System.Collections.Generic.List[PSObject]'
                    
                    $OutputObjectValueList = New-Object -TypeName 'System.Collections.Generic.List[String]'
                      $OutputObjectValueList.Add('DisplayName')
                      $OutputObjectValueList.Add('DisplayVersion')
                      $OutputObjectValueList.Add('UninstallString')
                      $OutputObjectValueList.Add('InstallLocation')
                      $OutputObjectValueList.Add('Publisher')
                      $OutputObjectValueList.Add('InstallDate')
                                  
                    $RegistryHiveList = New-Object -TypeName 'System.Collections.Generic.List[PSObject]'
                    
                    $RegistryHiveProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                      $RegistryHiveProperties.Add('Type', [Microsoft.Win32.RegistryHive]::LocalMachine)
                      $RegistryHiveProperties.Add('KeyList', (New-Object -TypeName 'System.Collections.Generic.List[String]'))
                        $RegistryHiveProperties.KeyList.Add('Software\Microsoft\Windows\CurrentVersion\Uninstall')
                        $RegistryHiveProperties.KeyList.Add('Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall')
                    $RegistryHiveObject = New-Object -TypeName 'PSObject' -Property ($RegistryHiveProperties)
                    $RegistryHiveList.Add($RegistryHiveObject)
      
                    $RegistryHiveProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                      $RegistryHiveProperties.Add('Type', [Microsoft.Win32.RegistryHive]::CurrentUser)
                      $RegistryHiveProperties.Add('KeyList', (New-Object -TypeName 'System.Collections.Generic.List[String]'))
                        $RegistryHiveProperties.KeyList.Add('Software\Microsoft\Windows\CurrentVersion\Uninstall')
                    $RegistryHiveObject = New-Object -TypeName 'PSObject' -Property ($RegistryHiveProperties)
                    $RegistryHiveList.Add($RegistryHiveObject)
      
                    For ($RegistryHiveListIndex = 0; $RegistryHiveListIndex -lt $RegistryHiveList.Count; $RegistryHiveListIndex++)
                      {
                          $RegistryHive = $RegistryHiveList[$RegistryHiveListIndex]
      
                          $RegistryHiveObject = [Microsoft.Win32.RegistryKey]::OpenBaseKey($RegistryHive.Type, [Microsoft.Win32.RegistryView]::Default)
      
                          For ($KeyListIndex = 0; $KeyListIndex -lt $RegistryHive.KeyList.Count; $KeyListIndex++)
                            {
                                $RegistryKey = $RegistryHive.KeyList[$KeyListIndex]
      
                                $RegistryKeyObject = $RegistryHiveObject.OpenSubKey($RegistryKey)
                                
                                Switch ($Null -ine $RegistryKeyObject)
                                  {
                                      {($_ -eq $True)}
                                        {
                                            $SubKeyNameList = $RegistryKeyObject.GetSubKeyNames() | Sort-Object
      
                                            For ($SubKeyNameListIndex = 0; $SubKeyNameListIndex -lt $SubKeyNameList.Count; $SubKeyNameListIndex++)
                                              {
                                                  Try
                                                    {
                                                        $SubKeyName = $SubKeyNameList[$SubKeyNameListIndex]
      
                                                        $SubKeyObject = $RegistryKeyObject.OpenSubKey($SubKeyName)
      
                                                        $SubKeyObjectSegments = $SubKeyObject.Name.Split('\')
      
                                                        $OutputObjectProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                          $OutputObjectProperties.Path = $SubKeyObject.Name
                                                          $OutputObjectProperties.Hive = $SubKeyObjectSegments[0]
                                                          $OutputObjectProperties.Location = ($SubKeyObjectSegments[1..$($SubKeyObjectSegments.GetUpperBound(0))]) -Join '\'


                                                          
                                                        ForEach ($OutputObjectValueName In $OutputObjectValueList)
                                                          {
                                                              $OutputObjectProperties.$($OutputObjectValueName) = $Null
                                                          }
            
                                                        $ValueNameList = $SubKeyObject.GetValueNames() | Sort-Object

                                                        $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Now processing entry `"$($OutputObjectProperties.Path)`" [ValueCount: $($ValueNameList.Count)]. Please Wait..."
                                                        Write-Verbose -Message ($LoggingDetails.LogMessage)

                                                        $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Value Name List: $(($ValueNameList | Sort-Object) -Join '; ')"
                                                        Write-Verbose -Message ($LoggingDetails.LogMessage)
              
                                                        Switch ($ValueNameList.Count -gt 0)
                                                          {
                                                              {($_ -eq $True)}
                                                                {      
                                                                    For ($ValueNameListIndex = 0; $ValueNameListIndex -lt $ValueNameList.Count; $ValueNameListIndex++)
                                                                      {
                                                                          $ValueName = $ValueNameList[$ValueNameListIndex]
            
                                                                          $ValueKind = $SubKeyObject.GetValueKind($ValueName)
              
                                                                          Switch ($ValueKind)
                                                                            {
                                                                                {($_ -ieq 'PlaceHolder')}
                                                                                  {
      
                                                                                  }
      
                                                                                Default
                                                                                  {
                                                                                      $Value = $SubKeyObject.GetValue($ValueName)
                                                                                  }
                                                                            }
      
                                                                          $OutputObjectProperties.$ValueName = $Value
                                                                      }
      
                                                                    $OutputObjectProperties.ProductCode = Try {[Regex]::Match($OutputObjectProperties.Location, $RegularExpressionTable.GUID.ToString(), $RegexOptionList.ToArray()).Value.Trim()} Catch {$Null}
                                                                    
                                                                    Switch (($OutputObjectProperties.DisplayName -imatch $FilterInclusionExpression.ToString()) -and ($OutputObjectProperties.DisplayName -inotmatch $FilterExclusionExpression.ToString()))
                                                                      {
                                                                          {($_ -eq $True)}
                                                                            {
                                                                                ForEach ($OutputObjectProperty In ($OutputObjectProperties.Keys | Sort-Object))
                                                                                  {
                                                                                      $OutputObjectPropertyName = $OutputObjectProperty

                                                                                      $OutputObjectPropertyValue = $OutputObjectProperties.$($OutputObjectPropertyName)

                                                                                      Switch ($OutputObjectPropertyName)
                                                                                        {
                                                                                            {($_ -iin @('DisplayVersion'))}
                                                                                              {
                                                                                                  $OutputObjectPropertyValue = Try {New-Object -TypeName 'System.Version' -ArgumentList ($OutputObjectPropertyValue)} Catch {$OutputObjectPropertyValue}
                                                                                              }

                                                                                            {($_ -iin @('InstallDate'))}
                                                                                              {
                                                                                                  $DateTime = New-Object -TypeName 'DateTime'

                                                                                                  $DateTimeProperties.Input = $OutputObjectPropertyValue
                                                                                                  $DateTimeProperties.Successful = [DateTime]::TryParseExact($DateTimeProperties.Input, $DateTimeProperties.FormatList, $DateTimeProperties.Culture, $DateTimeProperties.Styles.ToArray(), [Ref]$DateTime)
                                                                                                  $DateTimeProperties.DateTime = $DateTime

                                                                                                  $DateTimeObject = New-Object -TypeName 'PSObject' -Property ($DateTimeProperties)

                                                                                                  Switch ($DateTimeObject.Successful)
                                                                                                    {
                                                                                                        {($_ -eq $True)}
                                                                                                          {
                                                                                                              $OutputObjectPropertyValue = $DateTimeObject.DateTime
                                                                                                          }
                                                                                                    }
                                                                                              }

                                                                                            Default
                                                                                              {
                                                                                                  Switch ($OutputObjectPropertyValue)
                                                                                                    {
                                                                                                        {($_ -imatch '(^\d+$)')}
                                                                                                          {
                                                                                                              $OutputObjectPropertyValue = $OutputObjectPropertyValue -As [Int32]
                                                                                                          }
                                                                                                    }
                                                                                              }
                                                                                        }
    
                                                                                      $OutputObjectProperties.Remove($OutputObjectPropertyName)
            
                                                                                      $OutputObjectProperties.$($OutputObjectPropertyName) = $OutputObjectPropertyValue
                                                                                  }
                      
                                                                                $OutputObject = New-Object -TypeName 'PSObject' -Property ($OutputObjectProperties)
                                                                    
                                                                                $OutputObjectList.Add($OutputObject)
                                                                            }
                                                                      }         
                                                                }
                                                          }
      
                                                        Try {$Null = $SubKeyObject.Close()} Catch {}
                                                    }
                                                  Catch
                                                    {
      
                                                    }
                                                  Finally
                                                    {
      
                                                    }     
                                              }
                                        }
                                  }
      
                                Try {$Null = $RegistryKeyObject.Close()} Catch {}
                            }
          
                          Try {$Null = $RegistryHiveObject.Close()} Catch {}
                      }
                }
              Catch
                {
                    $ErrorHandlingDefinition.Invoke()
                }
              Finally
                {
                    
                }
          }

        End
          {
              Try
              {
                  $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Found $($OutputObjectList.Count) instances of software matching the specified regular expression(s)."
                  Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                  
                  #Determine the date and time the function completed execution
                    $FunctionEndTime = (Get-Date)

                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Execution of $($FunctionName) ended on $($FunctionEndTime.ToString($DateTimeLogFormat))"
                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                  #Log the total script execution time  
                    $FunctionExecutionTimespan = New-TimeSpan -Start ($FunctionStartTime) -End ($FunctionEndTime)

                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Function execution took $($FunctionExecutionTimespan.Hours.ToString()) hour(s), $($FunctionExecutionTimespan.Minutes.ToString()) minute(s), $($FunctionExecutionTimespan.Seconds.ToString()) second(s), and $($FunctionExecutionTimespan.Milliseconds.ToString()) millisecond(s)"
                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                  
                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Function `'$($FunctionName)`' is completed."
                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
              }
            Catch
              {
                  $ErrorHandlingDefinition.Invoke()
              }
            Finally
              {
                  #Write the object to the powershell pipeline
                    $OutputObjectList = $OutputObjectList.ToArray()

                    Write-Output -InputObject ($OutputObjectList)
              }
          }
    }
#endregion