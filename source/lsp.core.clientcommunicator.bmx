SuperStrict
Import "base.util.jsonhelper.bmx"
Import "base.util.debugger.bmx"
Import Brl.Threads


Global ClientCommunicator:TClientCommunicator = new TClientCommunicator

Type TClientCommunicator
	Field sendMutex:TMutex = CreateMutex()
	Field retrieveMutex:TMutex = CreateMutex()

	'When talking via "stdio" Windows will automatically "internally"
	'replace "\n" with "\r\n". One cannot prohibit this across all
	'potentially used C-compilers (which BMX NG translates to).
	'So using the EOL of "\r\n" there would result in "\r\r\n" which
	'is not compatible with the LSP-protocol
	?win32
	Const JSON_EOL:String = "~n"
	?Not win32
    Const JSON_EOL:String = "~r~n"
	? 

	'error codes
	'defined by JSON RPC
	Const ERROR_ParseError:Int = -32700
	Const ERROR_InvalidRequest:Int = -32600
	Const ERROR_MethodNotFound:Int = -32601
	Const ERROR_InvalidParams:Int = -32602
	Const ERROR_InternalError:Int = -32603
	Const ERROR_serverErrorStart:Int = -32099
	Const ERROR_serverErrorEnd:Int = -32000
	Const ERROR_ServerNotInitialized:Int = -32002
	Const ERROR_UnknownErrorCode:Int = -32001
	'defined by vsCode protocol.
	Const ERROR_RequestCancelled:Int = -32800
	Const ERROR_ContentModified:Int = -32801	


	Method Send(content:String)
		LockMutex(sendMutex)

		local message:String = "Content-Length: " + content.Length + JSON_EOL + JSON_EOL + content
		StandardIOStream.WriteString(message)
		StandardIOStream.Flush()
		
		UnlockMutex(sendMutex)

		AddLog(">> LSP: " + content.Replace("~r", "~~r").Replace("~n", "~~n") + "~n")
	End Method


	' Blocking call - wait until reading something
	Method Retrieve:String()
		LockMutex(retrieveMutex)

		Local content:String
		Local stdInput:String = StandardIOStream.ReadLine()
		If stdInput and stdInput.StartsWith("Content-Length: ")
			Local contentLength:Int = Int(stdInput.Split(": ")[1])
			content = StandardIOStream.ReadString(1)
			While content <> "{"
				content = StandardIOStream.ReadString(1)
			Wend
			
			content :+ StandardIOStream.ReadString(contentLength - 1)
			UnLockMutex(retrieveMutex)

			AddLog("<< LSP: " + content.Replace("~r", "~~r").Replace("~n", "~~n") + "~n")
		else
			UnlockMutex(retrieveMutex)
		EndIf
		
		Return content
	End Method
End Type

