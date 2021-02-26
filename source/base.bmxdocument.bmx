SuperStrict
Import "base.bmxparser.bmx"

rem
local doc:TBMXDocument = new TBMXDocument.Loadfile("base.bmxparser.bmx", CurrentDir())

print doc.sourceInformation.rootNode.DumpTree()
end

'local n:TBMXNode = doc.sourceInformation.GetNode(262, 16)
'local n:TBMXNode = doc.sourceInformation.GetNode(601, 20) 'OK
local n:TBMXNode = doc.sourceInformation.GetNode(283, 14)
if not n
	print "NO NODE!"
else
	print "Node: " + n.ToString()
EndIf
doc.GetAutoCompleteNodes(282, 14)

Print "DONE."
End
endrem

Type TBMXDocument
	Field uri:String
	Field id:Long
	Field content:String
	Field sourceInformation:TBMXSourceInformation
	global parserInfo:TBMXParserInformation
	
	Method New()
		if not parserInfo
			parserInfo = new TBMXParserInformation
			parserInfo.TryAutoConfig()
		Endif
	End Method

	
	Method LoadFile:TBMXDocument(uri:String, directory:String)
		self.uri = uri
		self.content = LoadText(uri)

		Local p:TBMXParser = New TBMXParser
		p.Parse(content, directory, parserInfo)
		
		sourceInformation = p.sourceInformation
		
		Return self
	End Method
	
	
	Method GetAutoCompleteNodes:TBMXNode[](line:Int, linePos:Int)
		Local result:TBMXNode[]


		'find definition
		'find parental scope - check children
		'loop upwards until no parent
		Local parentalScopeNode:TBMXNode = sourceInformation.GetPreviousNode(line, linePos)
		if parentalScopeNode then print "parentalScopeNode: " + parentalScopeNode.ToString()
	End Method
End Type