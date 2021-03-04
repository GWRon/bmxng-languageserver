SuperStrict
'Import Brl.StringBuilder
Import "base.bmxparser.bmx"
Import "base.util.debugger.bmx"


'testcode
rem
local doc:TBMXDocument = new TBMXDocument.Loadfile("testfile.bmx")
doc.Parse(CurrentDir())

'print doc.sourceInformation.rootNode.DumpTree()

Local lines:int[] = [0, 329, 401, 62, 82] ', 404]
Local pos:int[] =   [0,  30,  31,  5, 30] ',  13]
for local i:int = 0 until lines.length
	local n:TBMXNode = doc.sourceInformation.GetNode(lines[i], pos[i])
	if not n
		print "["+lines[i]+":"+pos[i]+"] NO containing node found!"
'		continue
	else
		print "["+lines[i]+":"+pos[i]+"] Containing node: " + n.ToString()
		doc.GetAutoCompleteNodes(lines[i], pos[i])
	EndIf
next
Print "DONE."
End
endrem

Type TBMXDocument
	Field uri:String
	Field id:Long
	Field content:String
	Field contentChanged:Int
	Field sourceInformation:TBMXSourceInformation
	Field contentVersion:Int
	global parserInfo:TBMXParserInformation
	
	Method New()
		if not parserInfo
			parserInfo = new TBMXParserInformation
			parserInfo.TryAutoConfig()
		Endif
	End Method


	Method LoadFile:TBMXDocument(uri:String)
		self.uri = uri
		self.content = LoadText(uri)
		Return Self
	End Method
	
	
	Method SetContent:TBMXDocument(content:String)
		self.content = content
		Return Self
	End Method


	Method InsertContent:TBMXDocument(newContent:String, pos:Int)
		content = content[.. pos] + newContent + content[pos ..]
		contentChanged = True
		Return Self
	End Method


	Method ReplaceContent:TBMXDocument(newContent:String, startPos:Int, endPos:Int)
		content = content[.. startPos] + newContent + content[endPos ..]
		sourceInformation.HandleNewContent(content)
		contentChanged = True

		Return Self
	End Method

	
	Method Parse:TBMXDocument(workingDirectory:String)
		Local p:TBMXParser = New TBMXParser
		p.Parse(content, workingDirectory, parserInfo)
		
		sourceInformation = p.sourceInformation
		
		Return self
	End Method
	
	
	'looks backwards until a "." (outside a "()") or newline/space happens
	Method FindNameBlock:TBMXSourceContentBlock(pos:Int)
		if pos = 0 then return Null
		
		Local startPos:Int = pos
		Local endPos:Int = pos
		Local dotRequired:Int

		if content[endPos - 1] = Asc(".") and endPos > 1
			endPos :- 1
			startPos :- 1
		endif

		Repeat
			local char:Int = content[startPos - 1]

			local prevChar:Int
			if startPos >= 2 Then prevChar = content[startPos - 2]
			
			'this handles "print myvar.property" but allows "myvar.mymethod() .property"
			if dotRequired and prevChar <> Asc(".") then exit
			if prevChar = Asc(" ") or prevChar = Asc("~t") Then dotRequired = True
			if char = Asc("~n") then exit
			
			startPos :- 1
		Until startPos <= 0

		if startPos = endPos Then Return Null
		Return New TBMXSourceContentBlock(content[startPos .. endPos].Trim(), startPos, endPos)
	End Method
	
	
	Method SplitNameBlock:String[](nameBlock:TBMXSourceContentBlock var)
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
	
	
	Method FindParentalClassNode:TBMXNode(node:TBMXNode)
		Local classNode:TBMXNode = node
		If not TBMXClassNode(classNode)
			Repeat
				classNode = classNode._parent
			Until TBMXClassNode(classNode) or not classNode
		EndIf
		
		if TBMXClassNode(classNode)
			return classNode
		endIf
		Return Null
	End Method
	
	
	'returns the "field/local/type/.." node
	Method GetDefinitionNode:TBMXNode(line:int, linePos:Int)
		AddLog("  GetDefinitionNode()~n")
		'identify lookup chain:
		'myvar.myfield.myproperty.  -> all of "myproperty"
		'myvar.myfield.mypr  -> all of "myfield"
		'-> so look "back" until "." or non-allowed char (except ".." on line before?)
		local currentPos:Int = sourceInformation.GetPosition(line, linePos)
		local nameBlock:TBMXSourceContentBlock = FindNameBlock(currentPos)
		if not nameBlock then Return Null
		AddLog("   found nameBlock at currentPos=" + currentPos + ". Value=~q"+nameBlock.value+"~q" + "~n")
		
		'print "  name block found: "+nameBlock.value
		local nameBlocks:String[] = SplitNameBlock( nameBlock )
		if not nameBlocks Then Return Null
		AddLog("   found nameBlock[0]=" + nameBlocks[0] + "~n")


		'first entry might be a "cast" or something "wrapped" in braces
		'TPlayer(element).GetInventory(TInventoryType.WEAPONS).GetName().Trim()
		'-> TPlayer(element)
		'or (player).GetInventory...  is also possible
		'or ((((player)))).GetInventory...  is also possible
		local bracketPos:Int = nameBlocks[0].Find("(")
		'case: TPlayer(element) --- or myfunction()
		if bracketPos > 0
			local clearName:String = nameBlocks[0][.. bracketPos]

			'type cast?
			local classNode:TBMXNode = sourceInformation.GetNodeByType(clearName, TBMXNodeType.CLASS_TYPE)
			if classNode then return classNode

			'callable -> in children of type, or functions ?
			'might also be a property with a function callback! 
			Local containingNode:TBMXNode = sourceInformation.GetNode(currentPos)
			If containingNode
				local childNode:TBMXNode = containingNode.GetChild(clearName)
				if childNode and childNode.IsCallable() Then return childNode
			endif
		endif


		If nameBlocks[0].ToLower() = "self"
			Local containingNode:TBMXNode = sourceInformation.GetNode(currentPos)
			if containingNode then Return FindParentalClassNode(containingNode)
		Endif

		Return sourceInformation.GetNode(nameBlocks[0], currentPos)
	End Method
	

	Method GetAutoCompleteNodes:TBMXNode[](line:Int, linePos:Int)
		AddLog(" GetAutoCompleteNodes()~n")

		'where is the current element defined?
		Local definitionNode:TBMXNode = GetDefinitionNode(line, linePos)
		if not definitionNode Then Return Null
		AddLog("  found definition node: " + definitionNode.ToString() +"~n")
		
		'if it is not a class, we need to find the type definition of it
		if TBMXPropertyNode(definitionNode)
'TODO: int, string, double, long ...
			definitionNode = sourceInformation.GetClassNode(TBMXPropertyNode(definitionNode)._typeName)
			AddLog("  found type definition node: " + definitionNode.ToString() +"~n")
		endif
		If not definitionNode then Return Null

		Local list:TObjectList = definitionNode.GetChildren()
		If not list then return Null
		
'		print "  found " + list.count()  + " children."
		Local result:TBMXNode[] = new TBMXNode[ list.count() ]
		Local nIndex:Int = 0
		For local n:TBMXNode = EachIn list
'print "  adding: " + n.ToString()
			result[nIndex] = n
			nIndex :+ 1
		Next
		Return result
	End Method
End Type