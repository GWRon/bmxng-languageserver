SuperStrict
'Import Brl.StringBuilder
Import "base.bmxparser.bmx"


'testcode
rem
local doc:TBMXDocument = new TBMXDocument.Loadfile("testfile.bmx", CurrentDir())

'print doc.sourceInformation.rootNode.DumpTree()

Local lines:int[] = [328, 401] ', 404]
Local pos:int[] =   [ 30,  31] ',  13]
for local i:int = 0 until lines.length
	local n:TBMXNode = doc.sourceInformation.GetNode(lines[i], pos[i])
	if not n
		print "["+lines[i]+":"+pos[i]+"] NO NODE!"
'		continue
	else
		print "["+lines[i]+":"+pos[i]+"] Node: " + n.ToString()
	EndIf
	doc.GetAutoCompleteNodes(lines[i], pos[i])
next
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
	
	
	'looks backwards until a "." (outside a "()") or newline/space happens
	Method FindNameBlock:SBMXSourceContentBlock(pos:Int)
'		Local result:TStringBuilder = new TStringBuilder

		Local startPos:Int = pos
		Local endPos:Int = pos
		Local dotRequired:Int

		if content[endPos - 1] = Asc(".") and endPos > 1 then endPos :- 1
		Repeat
			local char:Int = content[startPos - 1]

			local prevChar:Int
			if startPos >= 2 Then prevChar = content[startPos - 2]
			
			'this handles "print myvar.property" but allows "myvar.mymethod() .property"
			if dotRequired and prevChar <> Asc(".") then exit
			if prevChar = Asc(" ") or prevChar = Asc("~t") Then dotRequired = True
			if prevChar = Asc("~n") then exit
			
			startPos :- 1
		Until startPos <= 0
		Return New SBMXSourceContentBlock(content[startPos .. endPos].Trim(), startPos, endPos)
	End Method
	
	
	Method SplitNameBlock:String[](nameBlock:SBMXSourceContentBlock var)
		'a name block could look like this:
		'player.GetInventory(TInventoryType.WEAPONS).GetName().Trim()'
		'so next to "." you can also have braces...
		'so we need to iterate over the string and keep track of "open" braces
		
		local result:String[]
		local openBracket:Int = 0
		local lastSplitPos:Int = 0
		For local i:int = 0 until nameBlock.value.length
			Local char:Int = nameBlock.value[i] 
			if char = Asc("(") 
				openBracket :+ 1
			elseif char = Asc(")") 
				openBracket :- 1
			endif
			if char = Asc(".") and openBracket = 0
				result :+ [ nameBlock.value[lastSplitPos .. i] ]
				lastSplitPos = i + 1
			endif
		Next
		'add last
		result :+ [nameBlock.value[lastSplitPos ..]]
		
		Return result
	End Method
	
	
	Method RemoveBrackets:String(text:String)
		local bracketStart:Int
		
		bracketStart = text.Find("(") 'casts, method calls
		if bracketStart >= 0 Then text = text[.. bracketStart]

		bracketStart = text.Find("[") 'arrays
		if bracketStart >= 0 Then text = text[.. bracketStart]
		
		Return text
	End Method
	

	Method GetAutoCompleteNodes:TBMXNode[](line:Int, linePos:Int)
		Local result:TBMXNode[]


		'identify lookup chain:
		'myvar.myfield.myproperty.  -> all of "myproperty"
		'myvar.myfield.mypr  -> all of "myfield"
		'-> so look "back" until "." or non-allowed char (except ".." on line before?)
		local currentPos:Int = sourceInformation.GetPosition(line, linePos)
		local nameBlock:SBMXSourceContentBlock = FindNameBlock(currentPos)
print "  nameBlock: "+nameBlock.value
		local nameBlocks:String[] = SplitNameBlock( nameBlock )

		local surroundingNode:TBMXNode = sourceInformation.GetNode(currentPos)
if surroundingNode then print "  surroundingNode: " + surroundingNode.ToString()
		'the node we want the autocomplete for
		local node:TBMXNode = sourceInformation.GetNode(nameBlocks[0], currentPos, surroundingNode)
		if not node 
			print "  definition not found for ~q"+nameBlocks[0]+"~q"
		else
			print "  definition found for ~q"+nameBlocks[0]+"~q : " + node.ToString()
		endif
		'iterate from left to right of the name blocks - except we cannot "find" the child
'		For local nameBlock:String = EachIn nameBlocks
'			node = FindNodeByName(nameBlock[0], currentPos )
	End Method
End Type