SuperStrict
Import Brl.Map
Import "lsp.core.messagecollection.bmx"
Import "lsp.methodhandler.bmx"

Global AppData:TLSPAppData = new TLSPAppData


Type TLSPAppData
	'other incoming messages are almost ignored until "initialize"
	'was received
	Field receivedInitializePacket:Int = False
	'once received, all further incoming are replied with "invalid"
	Field receivedShutdownRequest:Int = False
	'registered "method" handlers
	Field methodHandlers:TStringMap = new TStringMap

	Field documents:TStringMap = new TStringMap
	Field sourcesInformation:TStringMap = new TStringMap
	
	'set to true to exit all threads and finish "Run()"
	Field exitApp:Int = False
	Field exitCode:Int = 1 '1 = not received "shutdown" yet


	Method HasMethodHandler:Int(methodName:String)
		Return 1 'GetMethodHandler(methodName) <> Null
	End Method


	Method GetMethodHandler:TLSPMethodHandler(methodName:String)
		Return TLSPMethodHandler(methodHandlers.ValueForKey(methodName.ToLower()))
	End Method

	
	Method AddMethodHandler:Int(methodHandler:TLSPMethodHandler)
		For local methodName:String = EachIn methodHandler.methodsLower
			methodHandlers.Insert(methodName, methodHandler)
		Next

		Return True
	End Method
	

	Method RemoveMethodHandler:Int(methodName:String)
		methodHandlers.Remove(methodName)
	End Method	


	Method RemoveMethodHandler:Int(methodHandler:TLSPMethodHandler)
		For local methodName:String = EachIn methodHandler.methodsLower
			methodHandlers.Remove(methodName)
		Next
	End Method
End Type