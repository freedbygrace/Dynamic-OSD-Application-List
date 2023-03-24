'Set object values
	Set oArguments = WScript.Arguments.Named
	Set oFSO = CreateObject("Scripting.FileSystemObject")
	Set oShell = CreateObject("WScript.Shell")
	Set oCMD = oFSO.GetFile(oShell.ExpandEnvironmentStrings("%COMSPEC%"))
	Set oPowershell = oFSO.GetFile(oShell.ExpandEnvironmentStrings("%WINDIR%") & "\System32\WindowsPowershell\v1.0\powershell.exe")
	
'Define ASCII Characters
	chrSpace = Chr(32)
	chrSingleQuote = Chr(39)
	chrDoubleQuote = Chr(34)
	
'Define Variable(s)
	ScriptInterpreter = CreateObject("Scripting.FileSystemObject").GetFileName(WScript.FullName)
	If (oArguments.Exists("Debug") = True) Then DebugMode = True End If		
	
'Dynamically convert named VBScript arguments to their eqivalent powershell format
oArgumentCount = oArguments.Count

If (oArgumentCount > 0) Then
	StringBuilder = ""
	
	oArgumentCounter = 1
	
	Set ArgumentNameExpression = New RegExp
	         
     With ArgumentNameExpression
        .Pattern    = "^Debug$"
        .IgnoreCase = True
        .Global     = False
        .Multiline  = False
     End With
     
	 Set ArgumentValueExpression = New RegExp
	 
	 With ArgumentValueExpression
	    .Pattern    = "^.*True|.*False$"
	    .IgnoreCase = True
	    .Global     = False
	    .Multiline  = False
	 End With	
		
	For Each oArgument In oArguments	
		ArgumentName = Trim(oArgument)		
		ArgumentValue = oArguments.Item(oArgument)
				   
        If (Not(ArgumentNameExpression.Test(ArgumentName))) Then	
			Select Case ((Len(ArgumentValue) > 0) And (Not(ArgumentValueExpression.Test(ArgumentValue))))
				Case True				
					If (InStr(ArgumentValue, ",") > 0) Then
						ArgumentValueParts = Split(ArgumentValue, ",")
	
						ArgumentValuePartsCount = UBound(ArgumentValueParts)
						
						ArgumentValuePartStringBuilder = ""
						
						ArgumentValuePartCounter = 0
								
						For Each ArgumentValuePart In ArgumentValueParts
							ArgumentValuePartFormat = chrDoubleQuote & ArgumentValuePart & chrDoubleQuote
							
							ArgumentValuePartStringBuilder = ArgumentValuePartStringBuilder & ArgumentValuePartFormat
							
							If	((ArgumentValuePartsCount > 0) And (ArgumentValuePartCounter < ArgumentValuePartsCount)) Then
								ArgumentValuePartStringBuilder = ArgumentValuePartStringBuilder & ","
								ArgumentValuePartCounter = ArgumentValuePartCounter + 1
							End If	
						Next
						
						ParameterFormat = "-" & ArgumentName & chrSpace & ArgumentValuePartStringBuilder
					ElseIf (IsNumeric(ArgumentValue) = True) Then
						ParameterFormat = "-" & ArgumentName & chrSpace & ArgumentValue
					Else
						ParameterFormat = "-" & ArgumentName & chrSpace & chrDoubleQuote & ArgumentValue & chrDoubleQuote	
					End If					   			   	 
				Case False
				   	ParameterFormat = "-" & ArgumentName
			End Select
					
			If (Len(ParameterFormat) > 0) Then
					
				If ((oArgumentCount > 1) And (oArgumentCounter < oArgumentCount)) Then
					StringBuilder = StringBuilder & chrSpace		
				End If
						
				StringBuilder = StringBuilder & ParameterFormat
				
				ArgumentCounter = oArgumentCounter + 1
				
				ParameterFormat = Null
			End If
		End If							 
	Next
		
	StringBuilderResult = Trim(StringBuilder)
	
	If (Len(StringBuilderResult) > 0) Then	
		PowershellScriptParameters = StringBuilderResult & ";" & chrSpace & "[System.Environment]::Exit(($LASTEXITCODE -Bor [Int](-Not $? -And -Not $LASTEXITCODE)))"
	Else
		If (DebugMode = True) Then
			WScript.Echo("Debug mode is enabled. The specified command will NOT be executed.")
		End If
		
		PowershellScriptParameters = ";" & chrSpace & "[System.Environment]::Exit(($LASTEXITCODE -Bor [Int](-Not $? -And -Not $LASTEXITCODE)))"
	End If
			
	Set ArgumentNameExpression = Nothing
			
	Set ArgumentValueExpression = Nothing		
Else
	If (DebugMode = True) Then
		WScript.Echo(oArgumentCount & chrSpace & "arguments were specified.")
	End If
End If
	
'Define Additional Variable(s)
	Set ScriptPath = oFSO.GetFile(WScript.ScriptFullName)
	ScriptDirectory = ScriptPath.ParentFolder
	System32Directory = oShell.ExpandEnvironmentStrings("%WINDIR%") & "\System32"
	CommandPromptExecutionParameters = oCMD.Name & chrSpace & "/c"
	PowershellExecutionParameters = chrDoubleQuote & oPowershell.Path & chrDoubleQuote & chrSpace & "-ExecutionPolicy Bypass -NonInteractive -NoProfile -NoLogo -WindowStyle Hidden -Command"
	PowershellScriptPath = ScriptDirectory & "\" & oFSO.GetBaseName(ScriptPath) & ".ps1"
	
'Execute Powershell Script
	If (Len(PowershellScriptParameters) > 0) Then
		Command = PowershellExecutionParameters & chrSpace & chrDoubleQuote & "&" & chrSpace & chrSingleQuote & PowershellScriptPath & chrSingleQuote & chrSpace & PowershellScriptParameters & chrDoubleQuote
	Else
		Command = PowershellExecutionParameters & chrSpace & chrDoubleQuote & "&" & chrSpace & chrSingleQuote & PowershellScriptPath & chrSingleQuote & chrDoubleQuote
	End If
	
	If ((ScriptInterpreter = "cscript.exe") Or (DebugMode = True)) Then
		WScript.Echo("Command:" & chrSpace & Command)
	End If
	
	If (DebugMode = False) Then
		RunCommand = oShell.Run(Command, 0, True)
	End If
	
	If ((ScriptInterpreter = "cscript.exe") Or (DebugMode = True)) And (IsEmpty(RunCommand) = False) Then
		WScript.Echo("Exit Code:" & chrSpace & RunCommand)
	End If
	
	If (DebugMode = False) Then 
		WScript.Quit(RunCommand)
	End If