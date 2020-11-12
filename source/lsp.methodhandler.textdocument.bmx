SuperStrict
Import "base.util.debugger.bmx"
Import "lsp.core.appdata.bmx"
Import "lsp.methodhandler.bmx"


Type TLSPMethodHandler_TextDocument extends TLSPMethodHandler
	Method New() 
		SetHandledMethods(["textDocument/didOpen", ..
		                   "textDocument/didChange" ..
		                 ])
	End Method
	

	Method HandleMessage:Int(message:TLSPMessage)
		if message.IsMethod("textDocument/didOpen")
			AddLog("a document got opened~n")
		Elseif message.IsMethod("textDocument/didChange")
			AddLog("the document got changed~n")
		EndIf
	End Method
End Type




Type TLSPMethodHandler_TextDocument_Completion extends TLSPMethodHandler
	Method New()
		SetHandledMethods(["textDocument/completion"])
	End Method
	

	Method HandleMessage:Int(message:TLSPMessage)
		AddLog("auto completition stuff requested~n")
'<< LSP: {"jsonrpc":"2.0","id":2,"method":"textDocument/completion","params":{"textDocument":{"uri":"file:///home/ronny/Arbeit/Projekte/BlitzMax/vscode-blitzmax-lsp/lsp.bmx"},"position":{"line":34,"character":4},"context":{"triggerKind":2,"triggerCharacter":"."}}}

		local helper:TJSONHelper = new TJSONHelper()
'		helper.SetPathString()

'		MessageCollection.AddOutgoingMessage()
	End Method
End Type
