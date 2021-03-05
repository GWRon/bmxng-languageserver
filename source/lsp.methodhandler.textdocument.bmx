SuperStrict
Import "base.util.debugger.bmx"
Import "lsp.core.appdata.bmx"
Import "lsp.methodhandler.bmx"
Import "base.bmxdocument.bmx"

Type TLSPMethodHandler_TextDocument extends TLSPMethodHandler
	Method New() 
		SetHandledMethods(["textDocument/didOpen", ..
		                   "textDocument/didChange" ..
		                 ])
	End Method
	

	Method HandleMessage:Int(message:TLSPMessage)
		local fileURI:String
		if message.IsMethod("textDocument/didOpen")
			fileURI = message.GetPathString("params/textDocument/uri")
			fileURI = fileURI.replace("file://", "") 'we only handle local files for now

			'vscode already loads the file and passes the content!
			rem
			if FileType(fileURI) = FILETYPE_FILE
				'parse it
				Local fileDir:String = ExtractDir(fileURI)
				'Local fileName:String = StripDir(fileURI)
				local doc:TBMXDocument = new TBMXDocument
				doc.LoadFile(fileURI)
				doc.Parse(fileDir)

				AppData.documents.Insert(fileURI, doc)
				AppData.sourcesInformation.Insert(fileURI, doc.sourceInformation)
				AddLog("New file ~q" + fileURI +"~q opened and parsed.~n")
			Else
				AddLog("New file ~q" + fileURI + "~q not found.~n")
			EndIf
			endrem

			Local fileDir:String = ExtractDir(fileURI)
			local doc:TBMXDocument = new TBMXDocument
			doc.uri = fileURI
			doc.content = message.GetPathString("params/textDocument/text")
			doc.contentVersion = message.GetPathInteger("params/textDocument/version")
			doc.Parse(fileDir)

			AppData.documents.Insert(fileURI, doc)
			AppData.sourcesInformation.Insert(fileURI, doc.sourceInformation)
			AddLog("New file ~q" + fileURI +"~q parsed.~n")


		Elseif message.IsMethod("textDocument/didChange")
			fileURI = message.GetPathString("params/textDocument/uri")
			fileURI = fileURI.replace("file://", "") 'we only handle local files for now
			Local fileDir:String = ExtractDir(fileURI)

			
			Local doc:TBMXDocument = TBMXDocument(AppData.documents.ValueForKey(fileURI))
			if doc
				doc.contentVersion = Int(message.GetPathInteger("params/textDocument/version"))

				'iterate over all content changes
				'...
				Local elementCount:Int = message.GetPathSize("params/contentChanges")
				AddLog("Content Changes: " + elementCount+"~n")
				For local i:int = 0 until elementCount
					'lines + 1 as VSCode sends "line index", not "line"
					Local startLine:Int = message.GetPathInteger("params/contentChanges["+i+"]/range/start/line") + 1
					Local startLinePos:Int = message.GetPathInteger("params/contentChanges["+i+"]/range/start/character")
					Local endLine:Int = message.GetPathInteger("params/contentChanges["+i+"]/range/end/line") + 1 
					Local endLinePos:Int = message.GetPathInteger("params/contentChanges["+i+"]/range/end/character")
					Local text:String = message.GetPathString("params/contentChanges["+i+"]/text")
					
					Local startPos:Int = doc.sourceInformation.GetPosition(startLine, startLinePos)
					Local endPos:Int = doc.sourceInformation.GetPosition(endLine, endLinePos)

					doc.ReplaceContent(text, startPos, endPos)
				Next
				AddLog("Content Changes ... processed.~n")
				doc.Parse(fileDir)

				AddLog("Existing file ~q" + fileURI +"~q changed and parsed (version="+doc.contentVersion+").~n")
			Else
				AddLog("To change file ~q" + fileURI + "~q to not found.~n")
			EndIf
		EndIf
	End Method
End Type




Type TLSPMethodHandler_TextDocument_Completion extends TLSPMethodHandler

	Method New()
		SetHandledMethods(["textDocument/completion"])
	End Method
	
	
	Method GetCompletionItemKind:Int(bmxNodeType:Int)
		'https://code.visualstudio.com/api/references/vscode-api#CompletionItemKind
		Select bmxNodeType
			Case TBMXNodeType.SOURCE_RAW           Return 1   '"Text"
			Case TBMXNodeType.SOURCE_MODULE        Return 9   '"Module"
			Case TBMXNodeType.SOURCE_IMPORTFILE    Return 9   '"Module"
			Case TBMXNodeType.SOURCE_INCLUDEFILE   Return 9   '"Module"

			Case TBMXNodeType.CLASS_TYPE           Return 7   '"Class"
			Case TBMXNodeType.CLASS_INTERFACE      Return 8   '"Interface"
			Case TBMXNodeType.CLASS_STRUCT         Return 22  '"Struct"

			Case TBMXNodeType.CALLABLE_FUNCTION    Return 3   '"Function"
			Case TBMXNodeType.CALLABLE_METHOD      Return 4   '"Method"
	
			Case TBMXNodeType.PROPERTY_GLOBAL      Return 6   '"Variable"
			Case TBMXNodeType.PROPERTY_LOCAL       Return 6   '"Global"
			Case TBMXNodeType.PROPERTY_FIELD       Return 5   '"Field"
			Case TBMXNodeType.PROPERTY_CONST       Return 21  '"Constant"
			Case TBMXNodeType.PROPERTY_PARAM       Return 25  '"TypeParameter"

			default                                Return 1 
		End Select
	End Method


	Method HandleMessage:Int(message:TLSPMessage)
		AddLog("auto completition stuff requested~n")

		local helper:TJSONHelper = CreateBasicReplyJSONHelper(message.id)
		Local fileURI:String = message.GetPathString("params/textDocument/uri").Replace("file://", "")

		Local doc:TBMXDocument = TBMXDocument(AppData.documents.ValueForKey(fileURI))
		if doc
			'vscode sends "line 2" for "line 3" (offset +1)
			Local line:Int = Int(message.GetPathInteger("params/position/line")) + 1
			Local linePos:Int = Int(message.GetPathInteger("params/position/character"))
AddLog("found parsed doc. line="+line+" linePos="+linePos+"  (RAW: line="+message.GetPathInteger("params/position/line")+"  character="+message.GetPathInteger("params/position/character")+"~n")
			Local nodes:TBMXNode[] = doc.GetAutoCompleteNodes(line, linePos)
			if nodes
AddLog("found " + nodes.length+" nodes.~n")
				For local i:int = 0 until nodes.length
AddLog("Adding: " + nodes[i].name +"~n")
					helper.SetPathString("result/items[" + i + "]/label", nodes[i].name)
					helper.SetPathInteger("result/items[" + i + "]/kind", GetCompletionItemKind(nodes[i].nodeType))
				Next
			endif
		else
			AddLog("did not find parsed doc~n")
		endif

		helper.SetPathBool("result/isIncomplete", false)

		
		MessageCollection.AddOutgoingMessage( New TLSPMessage(helper) )
	End Method
End Type
