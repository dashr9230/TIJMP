
#NoTrayIcon
;#RequireAdmin

#include <WinAPI.au3>
#include <Memory.au3>

Local Const $TIJMP_REGKEY = 'HKCU\Software\TIJMP'
Local Const $TIJMP_STAGE = 'stg073.exe'

Local Const $MAX_PATH = 260

Main()

Func Main()
   Local $sGamePath = RegRead($TIJMP_REGKEY, 'GamePath')
   If @error Then
	  $sGamePath = RegRead('HKLM\SOFTWARE\WOW6432Node\SCi\The Italian Job', 'Path')
	  If @error Then
		 $sGamePath = FileSelectFolder('Please locate your The Italian Job installation...', '')
	  EndIf
   EndIf

   Local $sStageExe = $sGamePath & '\code\exes\' & $TIJMP_STAGE
   If Not FileExists($sStageExe) Then
	  ErrorBox('Failed to locate stage executable.')
	  Return
   EndIf

   RegWrite($TIJMP_REGKEY, 'GamePath', 'REG_SZ', $sGamePath)

   Local $sModModule = @WorkingDir & '\tijmp.dll'
   If Not FileExists($sModModule) Then
	  ErrorBox('TIJMP.dll module not found.')
	  Return
   EndIf

   If ProcessExists($TIJMP_STAGE) <> 0 Then
	  Local $nResponse = MsgBox($MB_YESNO, 'TIJMP', _
		 'An another instance of The Italian Job stage already running.' & _
		 @CRLF & @CRLF & 'Do you want to close it?')
	  If $nResponse <> $IDYES Then Exit 0
	  While ProcessExists($TIJMP_STAGE)
		 ProcessClose($TIJMP_STAGE)
	  WEnd
   EndIf

   Local $tSTARTUPINFO = DllStructCreate($tagSTARTUPINFO)
   Local $tPROCESS_INFORMATION = DllStructCreate($tagPROCESS_INFORMATION)

   DllStructSetData($tSTARTUPINFO, 'Size', DllStructGetSize($tSTARTUPINFO))

   Local $bResult = _WinAPI_CreateProcess(Null, $sStageExe, Null, Null, False, _
	  $CREATE_SUSPENDED, Null, $sGamePath & '\code\exes', $tSTARTUPINFO, $tPROCESS_INFORMATION)
   If Not $bResult Then
	  ErrorBox('Unable to execute The Italian Job Stage. Error code: ' & _WinAPI_GetLastError())
	  Return
   EndIf

   Local $nWritten = 0
   Local $pThreadID = Null
   Local $hProcess = DllStructGetData($tPROCESS_INFORMATION, 'hProcess')

   Local $pLibRemote = _MemVirtualAllocEx($hProcess, Null, $MAX_PATH, $MEM_COMMIT, $PAGE_READWRITE)

   Local $tBuffer = DllStructCreate('char[261]')
   DllStructSetData($tBuffer, 1, $sModModule)

   _WinAPI_WriteProcessMemory($hProcess, $pLibRemote, DllStructGetPtr($tBuffer), DllStructGetSize($tBuffer), $nWritten)

   Local $pLoadLibraryA = _WinAPI_GetProcAddress(_WinAPI_GetModuleHandle('kernel32'), 'LoadLibraryA')
   Local $hThread = _WinAPI_CreateRemoteThread($hProcess, Null, 0, $pLoadLibraryA, $pLibRemote, 0, $pThreadID)
   _WinAPI_WaitForSingleObject($hThread, 2000)
   _WinAPI_CloseHandle($hThread)

   _MemVirtualFreeEx($hProcess, $pLibRemote, $MAX_PATH, $MEM_RELEASE)

   _WinAPI_ResumeThread(DllStructGetData($tPROCESS_INFORMATION, 'hThread'))

   $tPROCESS_INFORMATION = 0
   $tSTARTUPINFO = 0
EndFunc

Func _WinAPI_ResumeThread($hThread)
   Local $aResult = DllCall('kernel32.dll', 'DWORD', 'ResumeThread', 'HANDLE', $hThread)
   If @error Or (_WinAPI_DWordToInt($aResult[0]) = -1) Then Return SetError(1, 0, -1)
   Return $aResult[0]
EndFunc

Func _WinAPI_CreateRemoteThread($hProcess,$tSecurityAttr,$iStackSize,$pStartAddr,$pParameter,$iFlags, ByRef $pThreadID)
   Local $aResult = DllCall('kernel32.dll', 'HANDLE', 'CreateRemoteThread', 'HANDLE', $hProcess, 'struct*', $tSecurityAttr, 'ulong_ptr', $iStackSize, _
	  'ptr', $pStartAddr, 'ptr', $pParameter, 'dword', $iFlags, 'dword*', 0)
   If @error Then Return SetError(@error, @extended, False)
   $pThreadID = $aResult[7]
   Return $aResult[0]
EndFunc

Func ErrorBox($sMessage)
   Return MsgBox($MB_ICONERROR, 'TIJMP Error', $sMessage)
EndFunc