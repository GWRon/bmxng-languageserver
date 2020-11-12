SuperStrict
Import "lsp.core.message.bmx"


Type TLSPMethodHandler
	Field methods:String[]
	Field methodsLower:String[]
	

	Method SetHandledMethods(methods:String[])
		self.methods = methods
		self.methodsLower = new String[methods.length]
		For local i:int = 0 until self.methodsLower.length
			self.methodsLower[i] = self.methods[i].ToLower()
		Next
	End Method

	
	'method actually processing a message
	Method HandleMessage:Int(message:TLSPMessage) abstract
End Type
