VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "CFTPLink"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
' Author: Gary Ong
' Acknowledgements: Philipp 'Schlaubi' Stern, Kristian Trenskow
'
Option Explicit
Option Compare Text
DefInt A-Z

Public Enum StatusEventType
    glSETInfo = 0
    glSETWarning = 1
    glSETError = 2
End Enum

Public Event StatusUpdate(vsText As String, vlEventType As StatusEventType)

Private Declare Sub Sleep Lib "kernel32" (ByVal dwMilliseconds As Long)

Private frmWS               As frmWinsock
Private WithEvents wskRead  As Winsock
Attribute wskRead.VB_VarHelpID = -1
Private WithEvents wskWrite As Winsock
Attribute wskWrite.VB_VarHelpID = -1
Private mclnFilesToSend     As Collection

Private msResponse          As String
Private mnTimeout           As Integer
Private msServerName        As String
Private msUsername          As String
Private msPassword          As String
Private mbSendComplete      As Boolean
Private mbConnected         As Boolean

Private Sub Class_Initialize()

    Set frmWS = New frmWinsock
    Set wskRead = frmWS.Winsock1
    Set wskWrite = frmWS.Winsock2
    Set mclnFilesToSend = New Collection
    mnTimeout = 25 'default timeout (sec)
    
End Sub

Private Sub Class_Terminate()
    
    ClearAllFiles
    Set wskRead = Nothing
    Set wskWrite = Nothing
    Unload frmWS
    Set frmWS = Nothing
    Set mclnFilesToSend = Nothing

End Sub

Public Property Let ResponseTimeout(ByVal vnTimeoutInSeconds As Integer)
    mnTimeout = vnTimeoutInSeconds
End Property

Public Property Get ResponseTimeout() As Integer
    ResponseTimeout = mnTimeout
End Property

Public Property Let Server(ByVal vsName As String)
    If vsName <> vbNullString Then
        msServerName = vsName
    End If
End Property

Public Property Let Username(ByVal vsUser As String)
    If vsUser <> vbNullString Then
        msUsername = vsUser
    End If
End Property

Public Property Let Password(ByVal vsPwd As String)
    If vsPwd <> vbNullString Then
        msPassword = vsPwd
    End If
End Property

Public Function AddFileToSend(ByVal vsLocalFilename As String, ByVal vsRemoteFilename As String) As Boolean
    Dim colFileDetail As Collection
    
    If Dir$(vsLocalFilename) <> "" Then
        Set colFileDetail = New Collection
        colFileDetail.Add vsLocalFilename, "Local"
        colFileDetail.Add vsRemoteFilename, "Remote"
        
        mclnFilesToSend.Add colFileDetail, CStr(mclnFilesToSend.Count + 1)
        AddFileToSend = True
    End If
    
    Exit Function
    
ErrorAddFileToSend:
    
End Function

Public Function SendFiles() As Integer
    Dim i           As Integer
    Dim colFileInfo As Collection
    Dim iSentOk     As Integer
    Dim bPortOk     As Boolean
    Dim sRemote     As String
    Dim sLocal      As String
    
    If msServerName = "" Or msUsername = "" Then
        SendFiles = -1
        Exit Function
    End If
    
    If EstablishConnection() Then
    
        For Each colFileInfo In mclnFilesToSend
    
            bPortOk = False
            
            Do
                
                bPortOk = EstablishPort()
                
                If Not bPortOk Then
                    
                    Debug.Print "Re-establishing connection..."
                    
                    If Not EstablishConnection() Then
                        Debug.Print "Failed to re-establish connection"
                        RaiseEvent StatusUpdate("Failed to re-establish connection", glSETError)
                        Exit Function
                    End If
                    
                End If
                
            Loop While Not bPortOk
            
            RaiseEvent StatusUpdate("Connected. Sending file...", glSETInfo)
        
            sRemote = colFileInfo.Item("Remote")
            sLocal = colFileInfo.Item("Local")
            
            If SendFile(sRemote, sLocal) Then
                iSentOk = iSentOk + 1
            End If
        
            wskRead.Close
            
            If Not WaitFor("226", False) Then
                RaiseEvent StatusUpdate("Transfer failed to complete", glSETError)
            End If
        
        Next
        
        wskWrite.Close
            
        RaiseEvent StatusUpdate(iSentOk & " files sent ok", glSETInfo)
        SendFiles = iSentOk
        
    End If
       
    'cleanup
    ClearAllFiles
    
End Function

Private Function WaitFor(ResponseCode As String, Optional ByVal vbIgnoreOtherResponses As Boolean = True) As Boolean
    Dim Start   As Single
    Dim Tmr     As Single
    
    Start = Timer ' Time event so won't get stuck in loop
    WaitFor = False
    Debug.Print "WaitingFor msResponse: " & ResponseCode
    
    While Len(msResponse) = 0
        Tmr = Timer - Start
        DoEvents ' Let System keep checking for incoming msResponse **IMPORTANT**
        
        If Tmr > mnTimeout Then ' Time in seconds to wait
            ' RaiseEvent StatusUpdate("FTP service error, timed out while waiting for msResponse", glSETError)
            Exit Function
        End If
        Sleep 1  ' to prevent hogging of the CPU
    Wend
    
    If vbIgnoreOtherResponses Then
        
        While Left(msResponse, 3) <> ResponseCode
            Tmr = Timer - Start
            DoEvents
            
            If Tmr > mnTimeout Then
                ' RaiseEvent StatusUpdate("FTP service error, impromper msResponse code. Code should have been: " + ResponseCode + " Code recieved: " + msResponse, glSETError)
                Exit Function
            End If
            Sleep 1  ' to prevent hogging of the CPU
        Wend
        
    Else
        
        If Left(msResponse, 3) <> ResponseCode Then
            Debug.Print "Waiting for msResponse code: " & ResponseCode & " but got:" & msResponse & " instead"
            Exit Function
        End If
    
    End If
    
    msResponse = "" ' Sent msResponse code to blank **IMPORTANT**
    WaitFor = True
    
End Function

Private Function WaitForAction(ActionCode As String) As Boolean
    Dim Start   As Single
    Dim Tmr     As Single
    
    WaitForAction = False
    Start = Timer ' Time event so won't get stuck in loop
    Debug.Print "Waiting for action: " & ActionCode
    
    Select Case ActionCode
        
        Case "SendComplete"
            Do While Not mbSendComplete
                
                Tmr = Timer - Start
                DoEvents ' Let System keep checking for incoming msResponse **IMPORTANT**
                
                If Tmr > mnTimeout Then ' Time in seconds to wait
                    'RaiseEvent StatusUpdate("FTP service error, timed out while waiting for msResponse", glSETError)
                    Exit Function
                End If
                Sleep 1  ' to prevent hogging of the CPU
            
            Loop
            
        Case "Connection"
            Do While Not mbConnected
            
                Tmr = Timer - Start
                DoEvents ' Let System keep checking for incoming msResponse **IMPORTANT**
                
                If Tmr > mnTimeout Then ' Time in seconds to wait
                    'RaiseEvent StatusUpdate("FTP service error, timed out while waiting for msResponse", glSETError)
                    Exit Function
                End If
                Sleep 1  ' to prevent hogging of the CPU
            
            Loop
        
        Case Else
            Exit Function
            
    End Select
    
    WaitForAction = True
End Function

Private Function EstablishConnection() As Boolean
    
    msResponse = ""
    wskWrite.Close
    wskWrite.LocalPort = 0 ' Must set local port to 0 (Zero) or you can only send 1 e-mail pre program start
    
    If wskWrite.State = sckClosed Then ' Check to see if socket is closed
        
        wskWrite.Protocol = sckTCPProtocol ' Set protocol for sending
        wskWrite.RemoteHost = msServerName ' Set the server address
        wskWrite.RemotePort = 21 ' Set the SMTP Port
        wskWrite.Connect ' Start connection
        
        If Not WaitFor("220", False) Then
            RaiseEvent StatusUpdate("Connection failed", glSETError)
            Exit Function
        End If
        
        RaiseEvent StatusUpdate("Connecting...", glSETInfo)
        
        wskWrite.SendData ("USER " & msUsername & vbCrLf)
        
        If Not WaitFor("331", False) Then
            RaiseEvent StatusUpdate("User command failed", glSETError)
            Exit Function
        End If
        
        wskWrite.SendData ("PASS " & msPassword & vbCrLf)
        
        If Not WaitFor("230", False) Then
            RaiseEvent StatusUpdate("Password rejected", glSETError)
            Exit Function
        End If
    
        EstablishConnection = True
        
    End If
    
End Function

Private Function EstablishPort() As Boolean
    Dim bPortOk  As Boolean
    Dim sIPAddr  As String
    Dim lRandNo1 As Long
    Dim lRandNo2 As Long
    
    bPortOk = False
    
    Randomize Timer
    lRandNo1 = Int(10 * Rnd + 1) ' Find two random numbers to specify port the server connects to
    Randomize Timer
    lRandNo2 = Int(41 * Rnd + 10)
    sIPAddr = wskWrite.LocalIP

    Do Until InStr(sIPAddr, ".") = 0 ' replace every "." in sIPAddr With a ","
        sIPAddr = Mid(sIPAddr, 1, InStr(sIPAddr, ".") - 1) & "," & Mid(sIPAddr, InStr(sIPAddr, ".") + 1)
    Loop
                    
    Debug.Print "PORT " & sIPAddr & "," & Trim(Str(lRandNo1)) & "," & Trim(Str(lRandNo2))
    wskWrite.SendData "PORT " & sIPAddr & "," & Trim(Str(lRandNo1)) & "," & Trim(Str(lRandNo2)) & vbCrLf 'Tell the server With which sIPAddr he has to connect and with which port
    
    bPortOk = WaitFor("200", False)
    
    If bPortOk Then
        
        wskRead.Close
        wskRead.LocalPort = lRandNo1 * 256 Or lRandNo2 ' Set port of second winsock-control to the port the server will connect to
        Debug.Print "LocalPort = " & wskRead.LocalPort
        wskRead.Listen
        EstablishPort = True
        
    End If

End Function

Private Function SendFile(ByVal vsRemoteName As String, ByVal vsLocalName As String) As Boolean
    Dim hFile           As Integer
    Dim lReadBytes      As Long
    Dim sBuffer         As String
    Dim iSendPercent    As Integer
    Dim bSendError      As Boolean
    Const Buffersize    As Long = 2920
    
    hFile = FreeFile
    
    If IsBinaryFile(vsLocalName) Then
        Open vsLocalName For Binary As #hFile
        wskWrite.SendData "TYPE I" & vbCrLf
    Else
        Open vsLocalName For Input As #hFile
        wskWrite.SendData "TYPE A" & vbCrLf
    End If
     
    If Not WaitFor("200", False) Then
        RaiseEvent StatusUpdate("Type command failed", glSETError)
    Else
     
        Debug.Print "About to Send STOR command"
        
        mbConnected = False
        
        wskWrite.SendData "STOR " & vsRemoteName & vbCrLf 'Store a file, With RETR you can Get a file, with LIST you get a list of all file on the server, all this information is sent through the data-connection (to change directory use CWD)
        
        ' wait for connection
        WaitForAction "Connection"
        
        If Not WaitFor("150", False) Then
            RaiseEvent StatusUpdate("STOR command failed", glSETError)
        Else
        
            Do While Not EOF(hFile)
                If LOF(hFile) - Seek(hFile) < Buffersize Then
                    lReadBytes = LOF(hFile) - Seek(hFile) + 1
                Else
                    lReadBytes = Buffersize
                End If
                
                mbSendComplete = False
                sBuffer = Input(lReadBytes, hFile)
                wskRead.SendData sBuffer
                
                ' wait for send complete
                If Not WaitForAction("SendComplete") Then
                    bSendError = True
                    RaiseEvent StatusUpdate("Error during send of " & vsLocalName, glSETError)
                    Exit Do
                End If
                
                iSendPercent = (Seek(hFile) / LOF(hFile)) * 100
                
                If iSendPercent > 100 Then
                    iSendPercent = 100
                End If
                
                RaiseEvent StatusUpdate(iSendPercent & "% of " & vsLocalName & " sent", glSETInfo)
                
                If lReadBytes < Buffersize Then
                    Exit Do
                End If
                
            Loop
        
        End If
                        
    End If
    
    Close #hFile
    
    If Not bSendError Then
        SendFile = True
    End If
    
End Function

Private Sub ClearAllFiles()
    Dim i As Integer
    
    ' Remove all attachments after send
    For i = 1 To mclnFilesToSend.Count
        mclnFilesToSend.Remove 1
    Next

End Sub

'------------------- winsock event handlers -----------------

Private Sub wskRead_Close()
    Debug.Print "wskRead: Close"
End Sub

Private Sub wskRead_Connect()
    Debug.Print "wskRead: Connect"
End Sub

Private Sub wskRead_ConnectionRequest(ByVal requestID As Long)
    wskRead.Close
    wskRead.Accept requestID
    Debug.Print "wskRead: Connection Request accepted: " & requestID
    mbConnected = True
End Sub

Private Sub wskRead_DataArrival(ByVal bytesTotal As Long)
    Dim data As String
    
    wskRead.GetData data
    Debug.Print "DataArrival1:" & data
    wskRead.Close ' You have to close the connection after the Server had send you data, he will establish it again, when he sends more
    wskRead.Listen

End Sub

Private Sub wskRead_Error(ByVal Number As Integer, Description As String, ByVal Scode As Long, ByVal Source As String, ByVal HelpFile As String, ByVal HelpContext As Long, CancelDisplay As Boolean)
    Debug.Print "wskRead: Error"
End Sub

Private Sub wskRead_SendComplete()
    Debug.Print "wskRead: Send Complete"
    mbSendComplete = True
End Sub

Private Sub wskRead_SendProgress(ByVal bytesSent As Long, ByVal bytesRemaining As Long)
    Debug.Print "wskRead: SendProgress " & (bytesSent / (bytesSent - bytesRemaining)) * 100
End Sub

Private Sub wskWrite_Close()
    Debug.Print "wskWrite: Close"
End Sub

Private Sub wskWrite_Connect()
    Debug.Print "wskWrite: Connect"
End Sub

Private Sub wskWrite_ConnectionRequest(ByVal requestID As Long)
    Debug.Print "wskWrite: Connection Request"
End Sub

Private Sub wskWrite_DataArrival(ByVal bytesTotal As Long)

    wskWrite.GetData msResponse ' Check for incoming msResponse *IMPORTANT*
    Debug.Print "wskWrite: " & msResponse
    
End Sub

Private Sub wskWrite_Error(ByVal Number As Integer, Description As String, ByVal Scode As Long, ByVal Source As String, ByVal HelpFile As String, ByVal HelpContext As Long, CancelDisplay As Boolean)
    Debug.Print "wskWrite: Error"
End Sub

Private Sub wskWrite_SendComplete()
    Debug.Print "wskWrite: SendComplete"
End Sub

Private Sub wskWrite_SendProgress(ByVal bytesSent As Long, ByVal bytesRemaining As Long)
    Debug.Print "wskWrite: SendProgress " & (bytesSent / (bytesSent - bytesRemaining)) * 100
End Sub

Public Function IsBinaryFile(ByVal vsFilename As String) As Boolean
    Dim hFile           As Integer
    Dim sBuffer         As String
    Dim lFileLen        As Long
    Dim lBytesToRead    As Long

    ' Assume binary unless proven otherwise
    IsBinaryFile = True
    
    hFile = FreeFile
    Open vsFilename For Binary As #hFile
    lFileLen = LOF(hFile)
    
    If lFileLen > 100 Then
        lBytesToRead = 100
    Else
        lBytesToRead = lFileLen
    End If

    sBuffer = Input(lBytesToRead, hFile)
    
    If InStr(sBuffer, Chr(0)) = 0 And InStr(sBuffer, Chr(1)) = 0 Then
        
        If InStr(sBuffer, Chr(2)) = 0 And InStr(sBuffer, Chr(3)) = 0 Then
    
            If InStr(sBuffer, Chr(4)) = 0 And InStr(sBuffer, Chr(5)) = 0 Then

                If InStr(sBuffer, Chr(6)) = 0 And InStr(sBuffer, Chr(7)) = 0 Then
                    
                    ' If the first 100 bytes do not
                    ' contain one of the above ascii
                    ' values then it's probably a
                    ' text file (?)
                    IsBinaryFile = False
                                            
                End If
                
            End If
            
        End If
        
    End If
    
    Close #hFile
    Exit Function
    
ErrorIsBinaryFile:

End Function
