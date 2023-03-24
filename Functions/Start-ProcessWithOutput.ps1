#region Start-ProcessWithOutput
Function Start-ProcessWithOutput
  {
      [CmdletBinding()] 
        Param
          (        
              [Parameter(Mandatory=$True)]
              [ValidateNotNullOrEmpty()]
              [String]$FilePath,
                
              [Parameter(Mandatory=$False)]
              [AllowEmptyCollection()]
              [AllowNull()]
              [String[]]$ArgumentList,

              [Parameter(Mandatory=$False)]
              [AllowEmptyCollection()]
              [AllowNull()]
              [String[]]$AcceptableExitCodeList,

              [Parameter(Mandatory=$False)]
              [Switch]$CreateNoWindow,
              
              [Parameter(Mandatory=$False)]
              [ValidateNotNullOrEmpty()]
              #[Regex]$StandardOutputParsingExpression = "(?:\s+)(?<PropertyName>.+)(?:\s+\:\s+)(?<PropertyValue>.+)",
              [Regex]$StandardOutputParsingExpression,
              
              [Parameter(Mandatory=$False)]
              [Switch]$LogOutput
          )
                  
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
            
            $LoggingDetails = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'    
              $LoggingDetails.LogMessage = $Null
              $LoggingDetails.WarningMessage = $Null
              $LoggingDetails.ErrorMessage = $Null
            
            $OutputObjectProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
              $OutputObjectProperties.ExitCode = $Null
              $OutputObjectProperties.ExitCodeAsHex = $Null
              $OutputObjectProperties.ExitCodeAsInteger = $Null
              $OutputObjectProperties.ExitCodeAsDecimal = $Null
              $OutputObjectProperties.StandardOutput = $Null
              $OutputObjectProperties.StandardOutputObject = $Null
              $OutputObjectProperties.StandardError = $Null
              $OutputObjectProperties.StandardErrorObject = $Null
        
            $Process = New-Object -TypeName 'System.Diagnostics.Process'
              $Process.StartInfo.FileName = $FilePath
              $Process.StartInfo.UseShellExecute = $False
              $Process.StartInfo.CreateNoWindow = ($CreateNoWindow.IsPresent)
              $Process.StartInfo.RedirectStandardOutput = $True
              $Process.StartInfo.RedirectStandardError = $True

            Switch (($Null -ieq $AcceptableExitCodeList) -or ($AcceptableExitCodeList.Count -eq 0))
              {
                  {($_ -eq $True)}
                    {
                        $AcceptableExitCodeList += '0'
                    }
              }
            
            Switch (($Null -ine $ArgumentList) -and ($ArgumentList.Count -gt 0))
              {
                  {($_ -eq $True)}
                    {
                        $Process.StartInfo.Arguments = $ArgumentList -Join ' '

                        $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to execute the following command: `"$($Process.StartInfo.FileName)`" $($Process.StartInfo.Arguments)"
                        Write-Verbose -Message ($LoggingDetails.LogMessage)
                    }

                  Default
                    {
                        $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to execute the following command: `"$($Process.StartInfo.FileName)`""
                        Write-Verbose -Message ($LoggingDetails.LogMessage)
                    }
              }
                            
            $Null = $Process.Start()
      
            $OutputObjectProperties.StandardOutput = $Process.StandardOutput.ReadToEnd()
            $OutputObjectProperties.StandardError = $Process.StandardError.ReadToEnd()
    
            $Null = $Process.WaitForExit()
           
            $OutputObjectProperties.ExitCode = $Process.ExitCode
            $OutputObjectProperties.ExitCodeAsHex = Try {'0x' + [System.Convert]::ToString($OutputObjectProperties.ExitCode, 16).PadLeft(8, '0').ToUpper()} Catch {$Null}
            $OutputObjectProperties.ExitCodeAsInteger = Try {$OutputObjectProperties.ExitCodeAsHex -As [Int]} Catch {$Null}
            $OutputObjectProperties.ExitCodeAsDecimal = Try {[System.Convert]::ToString($OutputObjectProperties.ExitCodeAsHex, 10)} Catch {$Null}

            $ExitCodeMessageList = New-Object -TypeName 'System.Collections.Generic.List[String]'
            
            $Null = $OutputObjectProperties.GetEnumerator() | Where-Object {($_.Key -imatch '(^ExitCode.*$)')} | Sort-Object -Property @('Key') | ForEach-Object {$ExitCodeMessageList.Add("[$($_.Key): $($_.Value)]")}
            
            $StartProcessExecutionTimespan = New-TimeSpan -Start ($Process.StartTime) -End ($Process.ExitTime)
                                                                        
            $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - The command execution took $($StartProcessExecutionTimespan.Hours.ToString()) hour(s), $($StartProcessExecutionTimespan.Minutes.ToString()) minute(s), $($StartProcessExecutionTimespan.Seconds.ToString()) second(s), and $($StartProcessExecutionTimespan.Milliseconds.ToString()) millisecond(s)."
            Write-Verbose -Message ($LoggingDetails.LogMessage)

            Switch (($OutputObjectProperties.ExitCode.ToString() -iin $AcceptableExitCodeList) -or ($OutputObjectProperties.ExitCodeAsHex.ToString() -iin $AcceptableExitCodeList) -or ($OutputObjectProperties.ExitCodeAsInteger.ToString() -iin $AcceptableExitCodeList) -or ($OutputObjectProperties.ExitCodeAsDecimal.ToString() -iin $AcceptableExitCodeList))
              {
                  {($_ -eq $True)}
                    {
                        $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - The command execution was successful. $($ExitCodeMessageList -Join ' ')"
                        Write-Verbose -Message ($LoggingDetails.LogMessage)
                    }

                  {($_ -eq $False)}
                    {
                        $LoggingDetails.WarningMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) -  The command execution was unsuccessful. $($ExitCodeMessageList -Join ' ')" 
                        Write-Warning -Message ($LoggingDetails.WarningMessage) -Verbose

                        $ErrorMessage = "$($LoggingDetails.WarningMessage)"
                        $Exception = [System.Exception]::New($ErrorMessage)           
                        $ErrorRecord = [System.Management.Automation.ErrorRecord]::New($Exception, [System.Management.Automation.ErrorCategory]::InvalidResult.ToString(), [System.Management.Automation.ErrorCategory]::InvalidResult, $Process)

                        $PSCmdlet.ThrowTerminatingError($ErrorRecord)
                    }
              }
     
            Switch (($OutputObjectProperties.ExitCode.ToString() -iin $AcceptableExitCodeList) -or ($OutputObjectProperties.ExitCodeAsHex.ToString() -iin $AcceptableExitCodeList) -or ($OutputObjectProperties.ExitCodeAsInteger.ToString() -iin $AcceptableExitCodeList) -or ($OutputObjectProperties.ExitCodeAsDecimal.ToString() -iin $AcceptableExitCodeList))
              {
                  {($_ -eq $True)}
                    {
                        [String]$CommandContents = $OutputObjectProperties.StandardOutput
      
                        Switch (([String]::IsNullOrEmpty($StandardOutputParsingExpression) -eq $False) -and ([String]::IsNullOrWhiteSpace($StandardOutputParsingExpression) -eq $False))
                          {
                              {($_ -eq $True)}
                                {
                                    $RegexOptions = New-Object -TypeName 'System.Collections.Generic.List[System.Text.RegularExpressions.RegexOptions]'
                                      $RegexOptions.Add([System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                                      $RegexOptions.Add([System.Text.RegularExpressions.RegexOptions]::Multiline)

                                    [System.Text.RegularExpressions.Regex]$RegularExpression = [System.Text.RegularExpressions.Regex]::New($StandardOutputParsingExpression, $RegexOptions.ToArray())

                                    [String[]]$RegularExpressionGroups = $RegularExpression.GetGroupNames() | Where-Object {($_ -notin @('0'))}

                                    [System.Text.RegularExpressions.MatchCollection]$RegularExpressionMatches = $RegularExpression.Matches($CommandContents)

                                    $StandardOutputObjectProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
 
                                    For ($RegularExpressionMatchIndex = 0; $RegularExpressionMatchIndex -lt $RegularExpressionMatches.Count; $RegularExpressionMatchIndex++)
                                      {
                                          [System.Text.RegularExpressions.Match]$RegularExpressionMatch = $RegularExpressionMatches[$RegularExpressionMatchIndex]
      
                                          For ($RegularExpressionGroupIndex = 0; $RegularExpressionGroupIndex -lt $RegularExpressionGroups.Count; $RegularExpressionGroupIndex++)
                                            {
                                                [String]$RegularExpressionGroup = $RegularExpressionGroups[$RegularExpressionGroupIndex]

                                                Switch ($RegularExpressionGroup)
                                                  {
                                                      {($_ -imatch '(^PropertyName$)')}
                                                        {
                                                            $PropertyDetails = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                              $PropertyDetails.Add('Name', $Null)
                                                              $PropertyDetails.Add('Value', $Null)
                            
                                                            $PropertyDetails.Name = ($RegularExpressionMatch.Groups[$($RegularExpressionGroup)].Value) -ireplace '(\s+)|(\-)|(_)', ''
                                                        }
                    
                                                      {($_ -imatch '(^PropertyValue$)')}
                                                        {
                                                            $PropertyDetails.Value = $RegularExpressionMatch.Groups[$($RegularExpressionGroup)].Value
                                    
                                                            Switch ($True)
                                                              {
                                                                  {($PropertyDetails.Value -imatch '\+(\-){1,}\+')}
                                                                    {
                                                                        $PropertyDetails.Value = $Null
                                                                    }
                                            
                                                                  {($PropertyDetails.Value -imatch '(.+\,\s+.+){1,}')}
                                                                    {
                                                                        #$PropertyDetails.Value = $PropertyDetails.Value.Split(',').Trim()
                                                                    }
                                                                    
                                                                  {($PropertyDetails.Value -imatch '.+\(.+\).+')}
                                                                    {
                                                                        #$PropertyDetails.Value = ($PropertyDetails.Value.Split('()', [System.StringSplitOptions]::RemoveEmptyEntries) -ireplace 'bytes', '')[1]
                                                                    }
                                                              }
                                                  
                                                            Switch ($Null -ine $PropertyDetails.Value)
                                                              {
                                                                  {($_ -eq $True)}
                                                                    {
                                                                        $PropertyDetails.Value = $PropertyDetails.Value.Trim()
                                                                    }
                                                              }  
                                                        }
                                                  }    
                                            }

                                          Switch ($StandardOutputObjectProperties.Contains($PropertyDetails.Name))
                                            {
                                                {($_ -eq $False)}
                                                  {
                                                      $Null = $StandardOutputObjectProperties.Add($PropertyDetails.Name, $PropertyDetails.Value)
                                                  }
                                            }                 
                                      }
              
                                    $OutputObjectProperties.StandardOutputObject = New-Object -TypeName 'PSObject' -Property ($StandardOutputObjectProperties)
                                }
                          }      
                    }
              }
        }
      Catch
        {
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
                  Write-Warning -Message ($LoggingDetails.ErrorMessage) -Verbose
              }

            Throw "$($_.Exception.Message)"
        }
      Finally
        {
            $OutputObject = New-Object -TypeName 'PSObject' -Property ($OutputObjectProperties)
            
            Switch (($LogOutput.IsPresent -eq $True) -or ($LogOutput -eq $True))
              {
                  {($_ -eq $True)}
                    {
                        ForEach ($Property In $OutputObject.PSObject.Properties)
                          {
                              Switch ($Property.Name)
                                {
                                    {($_ -iin @('StandardOutput', 'StandardError'))}
                                      {
                                          Switch (([String]::IsNullOrEmpty($Property.Value) -eq $False) -and ([String]::IsNullOrWhiteSpace($Property.Value) -eq $False))
                                            {
                                                {($_ -eq $True)}
                                                  {
                                                      $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - $($Property.Name): $($Property.Value)"
                                                      Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                                  }
                                                  
                                                Default
                                                  {
                                                      $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - $($Property.Name): N/A"
                                                      Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                                  }
                                            }
                                      }
                                }
                          }
                    }
              }
    
            Write-Output -InputObject ($OutputObject)
        }
  }
#endregion

<#
  $ProcessOutput = Start-ProcessWithOutput -FilePath 'dsregcmd.exe' -ArgumentList '/status' -CreateNoWindow -Verbose

  $ProcessOutput.StandardOutputObject | ConvertTo-JSON -Depth 10 -OutVariable 'AzureADDetails'

  $ProcessOutput
#>