SuperStrict
Import Brl.Map
Import "lsp.core.messagecollection.bmx"
Import "lsp.methodhandler.bmx"

Global AppData:TLSPAppData = new TLSPAppData


Type TLSPAppData
	'other incoming messages are almost ignored until "initialize"
	'was received
	Field receivedInitializePacket:Int = False
	'registered "method" handlers
	Field methodHandlers:TStringMap = new TStringMap
	
	'1 = default to "in order" method
	'0 = default to "not in order" method
	Field defaultMethodOrderHandling:Int = 1
	'set to true to exit all threads and finish "Run()"
	Field exitApp:Int = False


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