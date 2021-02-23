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

		local helper:TJSONHelper = CreateBasicReplyJSONHelper(message.id)
		'https://code.visualstudio.com/api/references/vscode-api#CompletionItemKind
		'0 = text
		'result set to "CompletionList" which consists of:
		'items : completionItem[]
		'isComplete: boolean
		helper.SetPathString("result/items[0]/label", "Hello")
		helper.SetPathInteger("result/items[0]/kind", 0)
		helper.SetPathString("result/items[1]/label", "World")
		helper.SetPathInteger("result/items[1]/kind", 1)
		helper.SetPathBool("result/isIncomplete", false)

'		local m:TLSPMessage = New TLSPMessage(helper)
'		AddLog("Message: " + m.id + "  " + m.methodName)
		
		MessageCollection.AddOutgoingMessage( New TLSPMessage(helper) )
	End Method
End Type
