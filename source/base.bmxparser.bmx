SuperStrict

Import Brl.Map
Import Brl.ObjectList
Import Brl.Vector
Import "base.bmxparser.toker.bmx"
Import "base.util.longmap.bmx"

'Maybe we need a "sourceInformation.unresolvedNodes" which
'is iterated once parsing is done - ans so GetType can be done
'OR ... all nodes get a "onParseFinish()" method which is
'executed on all tree elements after parsing ("step 2")
'this way eg "param"-nodes can use a "classNode" which is defined
'later in the code
'Alternatively all "Getters" need to be "lazy loaders" so stuff is fetched
'afterwards



Rem
Global pInfo:TBMXParserInformation = new TBMXParserInformation
pInfo.TryAutoConfig()

Global p:TBMXParser = New TBMXParser
p.Parse(LoadText("lsp.core.message.bmx"), CurrentDir(), pInfo)

'print p.sourceInformation.rootNode.DumpTree()


local n:TBMXNode = p.sourceInformation.GetNode(1603)
if not n
	print "NO NODE!"
else
	print "Node: " + n.ToString()
EndIf

Print "DONE."
End
endrem



'container for ALL parsed source files (and modules)
Type TBMXParserInformation
	Field bmxDirectory:String
	Field processedImports:TStringMap
	'elementNodeIDs -> TObjectList of TBMXNodes
	Field elements:TLongMap = New TLongMap
	'sourceID -> TBMXSourceInformation
	Field sources:TLongMap = New TLongMap
	
	
	Method TryAutoConfig:Int()
		' TODO
		' use environment or so
		bmxDirectory = "/home/ronny/Arbeit/Tools/BlitzMaxNG/mod"
	End Method
	
	
	Method LoadCaches()
		'modules...
		
		'specific files?
	End Method
	
	
	Method AddSource(source:TBMXSourceInformation)
		sources.Insert(source.GetID(), source)
	End Method


	Method GetSource:TBMXSourceInformation(sourceID:Long)
		Return TBMXSourceInformation(sources.ValueForKey(sourceID))
	End Method

	
	Method AddElement(element:TBMXNode)
		Local ol:TObjectList = TObjectList(elements.ValueForKey(element.GetID()))
		If Not ol
			ol = New TObjectList
			elements.Insert(element.GetID(), ol)
		EndIf
		If Not ol.contains(element)
			ol.AddLast(element)
		EndIf
	End Method


	'return first element for the given ID (there migh be multiple "local x:Int")
	Method GetElement:TBMXNode(elementID:Long)
		Local ol:TObjectList = TObjectList(elements.ValueForKey(elementID))
		If Not ol Then Return Null
		Return TBMXNode(ol.First())
	End Method


	'return first element for the given ID (there migh be multiple "local x:Int")
	Method GetElements:TObjectList(elementID:Long)
		Return TObjectList(elements.ValueForKey(elementID))
	End Method
End Type



Type TBMXNodeType
	Global SOURCE_RAW:Int         = 1
	Global SOURCE_MODULE:Int      = 2
	Global SOURCE_IMPORTFILE:Int  = 3
	Global SOURCE_INCLUDEFILE:Int = 4

	Global CLASS_TYPE:Int         = 101
	Global CLASS_INTERFACE:Int    = 102
	Global CLASS_STRUCT:Int       = 103

	Global CALLABLE_FUNCTION:Int  = 201
	Global CALLABLE_METHOD:Int    = 202
	
	Global PROPERTY_GLOBAL:Int    = 301
	Global PROPERTY_LOCAL:Int     = 302
	Global PROPERTY_FIELD:Int     = 303
	Global PROPERTY_CONST:Int     = 304
	Global PROPERTY_PARAM:Int     = 305

	Global LOGICBLOCK:Int         = 401
End Type



Type TBMXSourceContentBlock
	Field value:String
	Field startPos:Int
	Field endPos:Int

	Method New(value:String, startPos:Int, endPos:Int)
		Self.value = value
		Self.startPos = startPos
		Self.endPos = endPos
	End Method
End Type



'container for each individual source (file)
Type TBMXSourceInformation
	Field id:Int
	Field uri:String
	Field rootNode:TBMXNode
	
	'connected source information contains? (modules)
	'this way they can be refreshed autonomously
	'Field importedSourceInformation:TLongMap

	'sourcePosition at which lines start
	Field _linesStartPos:Int[]
	Field _lineCount:Int
	Field _length:Int
	Field _imports:TLongMap = New TLongMap
	Field _types:TLongMap = New TLongMap
	Field _interfaces:TLongMap = New TLongMap
	Field _structs:TLongMap = New TLongMap
	Field _functions:TLongMap = New TLongMap
	Field _methods:TLongMap = New TLongMap
	Field _locals:TLongMap = New TLongMap
	Field _fields:TLongMap = New TLongMap
	Field _consts:TLongMap = New TLongMap
	Field _globals:TLongMap = New TLongMap
	'all nodes according to their position in the source
	Field _nodesByPos:TIntMap = New TIntMap
	
	
	Private
	Method New()
	End Method

	Public
	
	Method New(uri:String)
		Self.uri = uri
	End Method


	Method GetID:Long()
		If id = 0
			If Not uri Then Throw "TBMXSourceInformation: Cannot generate ID without uri"
			id = uri.ToLower().Hash()
		EndIf
		Return id
	End Method


	Method HandleNewContent(content:String, t:TToker = Null)
		_length = content.length
		
		'read line start positions
		Local newLineLength:Int = "~n".length
		if t
			if _linesStartPos.length <> t._lines.length
				_linesStartPos = New Int[t._lines.length]
			endif
			_linesStartPos[0] = 0
			If t._lines.length > 0
				For Local i:Int = 1 Until t._lines.length
					_linesStartPos[i] = _linesStartPos[i-1] + t._lines[i-1].length + newLineLength
				Next
			EndIf
		else
			Local contentLineLengths:Int[50]
			Local contentLineIndex:Int
			Local lastPos:int = 0
			For local i:int = 0 until content.length
				if content[i] = Asc("~n")
					'resize if needed
					if contentLineLengths.length <= contentLineIndex then contentLineLengths = contentLineLengths[.. contentLineLengths.length + 20]
					contentLineLengths[contentLineIndex] = (i - lastPos)
					lastPos = i
					contentLineIndex :+ 1
				endif
			Next
			'remove exceed array space
			if contentLineLengths.length <> contentLineIndex+1 then contentLineLengths = contentLineLengths[.. contentLineIndex + 1 + 1] '+1 space for last
			contentLineLengths[contentLineIndex] = (content.length - lastPos)
			contentLineIndex :+ 1
			

			if _linesStartPos.length <> contentLineLengths.length
				_linesStartPos = New Int[contentLineLengths.length]
			endif
			_linesStartPos[0] = 0
			If contentLineLengths.length > 0
				For Local i:Int = 1 Until contentLineLengths.length
					_linesStartPos[i] = _linesStartPos[i-1] + contentLineLengths[i-1] 'not adding newLineLength here... is already included
				Next
			EndIf
		endif
	End Method


	Method AddNode(node:TBMXNode)
		Select node.nodeType
			Case TBMXNodeType.SOURCE_IMPORTFILE, TBMXNodeType.SOURCE_INCLUDEFILE, TBMXNodeType.SOURCE_RAW, TBMXNodeType.SOURCE_MODULE
				_imports.insert(node.GetID(), node)

			Case TBMXNodeType.CLASS_INTERFACE
				_interfaces.Insert(node.GetID(), node)
			Case TBMXNodeType.CLASS_STRUCT
				_structs.Insert(node.GetID(), node)
			Case TBMXNodeType.CLASS_TYPE
				_types.Insert(node.GetID(), node)

			Case TBMXNodeType.CALLABLE_FUNCTION
				_functions.Insert(node.GetID(), node)
			Case TBMXNodeType.CALLABLE_METHOD
				_methods.Insert(node.GetID(), node)

			Case TBMXNodeType.PROPERTY_CONST
				_consts.Insert(node.GetID(), node)
			Case TBMXNodeType.PROPERTY_FIELD
				_fields.Insert(node.GetID(), node)
			Case TBMXNodeType.PROPERTY_GLOBAL
				_globals.Insert(node.GetID(), node)
			Case TBMXNodeType.PROPERTY_LOCAL
				_locals.Insert(node.GetID(), node)
			Case TBMXNodeType.PROPERTY_PARAM
				'Nothing to do

			Case TBMXNodeType.LOGICBLOCK
				'Nothing to do

			Default
				print "adding unhandled node type: " + node.nodeType
		End Select

		'store start and end (for easier retrieval of "previous")
		_nodesByPos.insert( node._start.pos, node )

		'Ron: do not "blindly" insert "end" - as some nodes (eg logic 
		'blocks) do not know the "end" when getting added
		if node._end.pos > 0
			_nodesByPos.insert( node._end.pos, node )
		endif
	End Method


	Method GetNode:TBMXNode(line:Int, linePos:Int, posMap:TIntMap = Null)
		Return GetNode(GetPosition(line, linePos), posMap)
	End Method
	
	
'	weitermachen - contentpos 0 macht segfault.
'	und message getpathinteger liefert noch "0" statt der gesuchten werte...
	
	Method GetNode:TBMXNode(sourcePos:Int, posMap:TIntMap = Null)
		Local result:TBMXNode
		Local currentPos:Int = sourcePos
		If Not posMap Then posMap = _nodesByPos
		Repeat
			result = TBMXNode(posMap.ValueForKey(currentPos))
			If Not result Then currentPos :- 1
		Until result Or currentPos < 0
		'if result then print "found result " + result.ToString() + "   currentPos="+currentPos + "   start end: " + result._start.pos + " - " + result._end.pos
		
		'check if the "first found" node already ended before the
		'requested position!
		If result And result._end.pos < sourcePos 
			If result._parent
				Local parent:TBMXNode = result._parent
				Repeat
					if parent._end.pos > sourcePos then return parent 
					parent = parent._parent
				Until Not parent
			EndIf
			result = Null
		EndIf
		
		Return result
	End Method
	
	
	Method GetClassNode:TBMXNode(name:String)
		local nameLower:String = name.ToLower()
		
		For local n:TBMXNode = EachIn _types.Values()
			if n.nameLower = nameLower Then return n
		Next
		For local n:TBMXNode = EachIn _interfaces.Values()
			if n.nameLower = nameLower Then return n
		Next
		For local n:TBMXNode = EachIn _structs.Values()
			if n.nameLower = nameLower Then return n
		Next
		Return Null
	End Method


	Method GetNodeByType:TBMXNode(name:String, nodeType:int)
		local map:TLongMap
		Select nodeType
			Case TBMXNodeType.SOURCE_IMPORTFILE, TBMXNodeType.SOURCE_INCLUDEFILE, TBMXNodeType.SOURCE_RAW, TBMXNodeType.SOURCE_MODULE
				map = _imports
			Case TBMXNodeType.CLASS_INTERFACE
				map = _interfaces
			Case TBMXNodeType.CLASS_STRUCT
				map = _structs
			Case TBMXNodeType.CLASS_TYPE
				map = _types
			Case TBMXNodeType.CALLABLE_FUNCTION
				map = _functions
			Case TBMXNodeType.CALLABLE_METHOD
				map = _methods
			Case TBMXNodeType.PROPERTY_CONST
				map = _consts
			Case TBMXNodeType.PROPERTY_FIELD
				map = _fields
			Case TBMXNodeType.PROPERTY_GLOBAL
				map = _globals
			Case TBMXNodeType.PROPERTY_LOCAL
				map = _locals
			Default
				'
		End Select

		if map
			local nameLower:String = name.ToLower()
			
			For local n:TBMXNode = EachIn map.Values()
				if n.nameLower = nameLower Then return n
			Next
		EndIf
		Return Null
	End Method


	Method GetNode:TBMXNode(name:String, usedAtPos:Int, usedInNode:TBMXNode = Null)
		Local result:TBMXNode
		
		If Not usedInNode Then usedInNode = GetNode(usedAtPos)
		'defined in other module?
		If Not usedInNode
			Print "TODO: defined in another module?"
			Return Null
		EndIf
		
		'if "self" is to lookup, we need a class node..
		Local classNodeRequired:Int = (name.ToLower() = "self")

		'check self and then parents (types, global scope ...)
		Local checkedNode:TBMXNode = usedInNode
		Repeat
Rem
if name.ToLower() = "info" 

	If TBMXClassNode(checkedNode) 
		print "  checked class: " + checkedNode.ToString()
		For local n:TBMXNode = EachIn TBMXClassNode(checkedNode)._children
			print "  child: " + n.name
		Next
		print "  has child:  "+checkedNode.HasChild(name)
	elseif TBMXCallableNode(checkedNode) 
		print "  checked callable: " + checkedNode.ToString()
		For local n:TBMXNode = EachIn TBMXCallableNode(checkedNode)._params
			print "  param: " + n.name
		Next
		print "  has param:  "+TBMXCallableNode(checkedNode).HasParam(name)
	else
		print "  checked node: " + checkedNode.ToString()
	EndIf
Endif
endrem
			'looking up "self" ?
			if classNodeRequired and not TBMXClassNode(checkedNode)
				checkedNode = checkedNode._parent
				if not checkedNode then exit
				continue
			endif


			'defined inside this node?
			result = checkedNode.GetChild(name)
			If result Then Return result

			'defined as param this node?
			'(a local definition has higher priority than a function param)
			If TBMXCallableNode(checkedNode)
				result = TBMXCallableNode(checkedNode).GetParam(name)
				If result Then Return result
			EndIf

			'if not global and not import/module ... it is unknown 
			If checkedNode = rootNode Then Return Null

			'not possible if current is a "type/function in a function" - different scopes?
			If checkedNode <> usedInNode And TBMXCallableNode(usedInNode) And TBMXCallableNode(checkedNode) Then Return Null

			checkedNode = checkedNode._parent
		Until Not checkedNode
		
		Return Null
	End Method	

	
	Method GetPosition:Int(line:Int, linePos:Int)
		If line < 1 Then line = 1
		If line = 1 then return linePos
		If line > _linesStartPos.length Then line = _linesStartPos.length
		Return Min(_length, _linesStartPos[line-1] + linePos)
	End Method

	
	Method Serialize:String()
	End Method


	Method Deserialize(s:String)
		'clear all maps
		
		'load in content
	End Method
End Type



Struct SSourcePosition
	Field pos:Int
	Field line:Int
	Field linePos:Int
	
	Method New(pos:Int, line:Int, linePos:Int)
		Self.pos = pos
		Self.line = line
		Self.linePos = linePos
	End Method
End Struct



Type TBMXParser
	Field content:String 
	Field contentPos:Int
	Field contentLine:Int
	Field contentLinePos:Int
	Field sourceInformation:TBMXSourceInformation
	Field nodeTree:TObjectList = New TObjectList
	'uncomment to make bcc segfault
	'Field nodeTree2:TStack<TBMXNode> = new TStack<TBMXNode>

'DISABLED FOR NOW
Global parseImports:Int = False

	
	Method Parse(content:String, workingDirectory:String = "", info:TBMXParserInformation, useRootNode:TBMXSourceNode=Null)
		If Not info Then Throw "You need to pass a parser information container to the parser."
		If Not info.processedImports Then info.processedImports = New TStringMap

		sourceInformation = New TBMXSourceInformation

		If useRootNode
			sourceInformation.rootNode = useRootNode
		Else
			sourceInformation.rootNode = New TBMXSourceNode.Init( TBMXNodeType.SOURCE_RAW, "", workingDirectory )
		EndIf
	
	
		Local isExtern:Int = False
		nodeTree.AddLast(sourceInformation.rootNode)
		Local t:TToker = New TToker.Create("", content)

		sourceInformation.HandleNewContent(content, t)


		Local openedSelect:Int = 0
		Local openedSelectCase:Int = 0
		
		Repeat
			t.NextToke()
			If t._tokeType = TOKE_KEYWORD 
				Select t._tokeLower
					Case "select"
						Local node:TBMXLogicNode = New TBMXLogicNode
						node.nodeType = TBMXNodeType.LOGICBLOCK
						node.SetName(t._tokeLower)
						node.SetStart(t._tokePos, t._line, t._linePos)

						sourceInformation.AddNode(node)
						info.AddElement(node)

						node._parent = TBMXNode(nodeTree.Last())
						If node._parent Then node._parent.AddChild(node)
						nodeTree.AddLast(node)

					Case "case", "default"
						'close case/default nodes
						local lastNode:TBMXNode	= TBMXNode(nodeTree.Last())
						if lastNode and (lastNode.name = "case" or lastNode.name = "default") 
							Local node:TBMXNode = TBMXNode(nodeTree.RemoveLast())
							If node Then node.SetEnd(t)
						endif
						
						'start new
						Local node:TBMXLogicNode = New TBMXLogicNode
						node.nodeType = TBMXNodeType.LOGICBLOCK
						node.SetName(t._tokeLower)
						node.SetStart(t._tokePos, t._line, t._linePos)

						sourceInformation.AddNode(node)
						info.AddElement(node)

						node._parent = TBMXNode(nodeTree.Last())
						If node._parent Then node._parent.AddChild(node)
						nodeTree.AddLast(node)

					Case "endselect"
						'close case/default nodes
						local lastNode:TBMXNode	= TBMXNode(nodeTree.Last())
						if lastNode and (lastNode.name = "case" or lastNode.name = "default") 
							Local node:TBMXNode = TBMXNode(nodeTree.RemoveLast())
							If node Then node.SetEnd(t)
						endif
						
						'close self
						Local node:TBMXNode = TBMXNode(nodeTree.RemoveLast())
						If node Then node.SetEnd(t)

					Case "for", "repeat", "while"  ', "if", "else", "elseif"

						'for "if": bcc -> parser.bmx -> ParseIfStmt()
						'or... have some "ParseExpr()" - so "if 1=1 n=1" is identified
						'as singlelineif with "1=1" being the condition and "n=1" the action
						
						Local node:TBMXLogicNode = New TBMXLogicNode
						node.nodeType = TBMXNodeType.LOGICBLOCK
						node.SetName(t._tokeLower)
						node.SetStart(t._tokePos, t._line, t._linePos)

						sourceInformation.AddNode(node)
						info.AddElement(node)

						node._parent = TBMXNode(nodeTree.Last())
						If node._parent Then node._parent.AddChild(node)
						nodeTree.AddLast(node)
					

					Case "next", "until", "wend" ', "endif"
						Local node:TBMXNode = TBMXNode(nodeTree.RemoveLast())
						If node Then node.SetEnd(t)
						
					Case "extern" 
						'read until end extern?
						isExtern = True

						Local node:TBMXLogicNode = New TBMXLogicNode
						node.nodeType = TBMXNodeType.LOGICBLOCK
						node.SetName(t._tokeLower)
						node.SetStart(t._tokePos, t._line, t._linePos)

						sourceInformation.AddNode(node)
						info.AddElement(node)

						node._parent = TBMXNode(nodeTree.Last())
						If node._parent Then node._parent.AddChild(node)
						nodeTree.AddLast(node)

					Case "include"
						'TODO
						
					Case "import"
If Not parseImports Then Continue
						
						Local node:TBMXSourceNode = TBMXSourceNode(ParseImport(t, workingDirectory, info))
						If Not node Then Continue

						If node.nodeType = TBMXNodeType.SOURCE_IMPORTFILE Or node.nodeType = TBMXNodeType.SOURCE_MODULE
							If node.uri And Not info.processedImports.Contains(node.uri)
								Local importParser:TBMXParser = New TBMXParser
								'print "loading import " + node.uri
								info.processedImports.Insert(node.uri, node)

								importParser.Parse( LoadText(node.uri), ExtractDir(node.uri), info, node)

								'disabled, we pass "node" as root already,
								'to avoid an additional root node being added
								'add to the parent
								'node.AddChild(importParser.rootNode)
							EndIf
						EndIf
			
						sourceInformation.AddNode(node)
						info.AddElement(node)

						'maybe rename to "users" for imports/includes
						node._parent = TBMXNode(nodeTree.Last())
						If node._parent Then node._parent.AddChild(node)

					Case "type"
						Local node:TBMXNode = ParseClass(t, TBMXNodeType.CLASS_TYPE)
						If TBMXClassNode(node)
							
							sourceInformation.AddNode(node)
							info.AddElement(node)
							
							node._parent = TBMXNode(nodeTree.Last())
							If node._parent Then node._parent.AddChild(node)
							nodeTree.AddLast(node)
						EndIf

					Case "interface"
						Local node:TBMXNode = ParseClass(t, TBMXNodeType.CLASS_INTERFACE)
						If TBMXClassNode(node)
							sourceInformation.AddNode(node)
							info.AddElement(node)

							node._parent = TBMXNode(nodeTree.Last())
							If node._parent Then node._parent.AddChild(node)
							nodeTree.AddLast(node)
						EndIf

					Case "struct"
						Local node:TBMXNode = ParseClass(t, TBMXNodeType.CLASS_STRUCT)
						If TBMXClassNode(node)
							sourceInformation.AddNode(node)
							info.AddElement(node)

							node._parent = TBMXNode(nodeTree.Last())
							If node._parent Then node._parent.AddChild(node)
							nodeTree.AddLast(node)
						EndIf

					Case "function"
						'ignore externs for now
						If isExtern Then Continue
						
						Local node:TBMXNode = ParseCallable(t, TBMXNodeType.CALLABLE_FUNCTION)
						If TBMXCallableNode(node)
							sourceInformation.AddNode(node)
							info.AddElement(node)

							node._parent = TBMXNode(nodeTree.Last())
							If node._parent Then node._parent.AddChild(node)
							If Not TBMXCallableNode(node)._abstract
								nodeTree.AddLast(node)
							EndIf
						EndIf

					Case "method"
						Local node:TBMXNode = ParseCallable(t, TBMXNodeType.CALLABLE_METHOD)
						If TBMXCallableNode(node)
'if node.ToString().Find("_ParseProperty") >= 0 then print "_ParseProperty. startPos="+node._start.pos+" start="+node._start.line+":"+node._start.linePos+"  end="+t._line+":"+t._linePos  +"  ... " + node.ToString();end
							sourceInformation.AddNode(node)
							info.AddElement(node)

							node._parent = TBMXNode(nodeTree.Last())
							If node._parent Then node._parent.AddChild(node)
							If Not TBMXCallableNode(node)._abstract
								nodeTree.AddLast(node)
							EndIf
						EndIf

					Case "endtype", "endinterface", "endstruct", "endfunction", "endmethod"
						Local node:TBMXNode = TBMXNode(nodeTree.RemoveLast())
						If node Then node.SetEnd(t)

					Case "endextern"
						isExtern = False

						Local node:TBMXNode = TBMXNode(nodeTree.RemoveLast())
						If node Then node.SetEnd(t)
				
					'check if upcoming is "type/interface/struct..."
					Case "end"
						Select PeekNextToke(t, True)
							Case "extern"
								NextToke(t)

								isExtern = False

								Local node:TBMXNode = TBMXNode(nodeTree.RemoveLast())
								If node Then node.SetEnd(t)
							Case "select"
								NextToke(t)

								'close case/default nodes
								local lastNode:TBMXNode	= TBMXNode(nodeTree.Last())
								if lastNode and (lastNode.name = "case" or lastNode.name = "default") 
									Local node:TBMXNode = TBMXNode(nodeTree.RemoveLast())
									If node Then node.SetEnd(t)
								endif
								
								'close self
								Local node:TBMXNode = TBMXNode(nodeTree.RemoveLast())
								If node Then node.SetEnd(t)
								
							Case "type", "interface", "struct"
								NextToke(t)
								
								Local node:TBMXNode = TBMXNode(nodeTree.RemoveLast())
								If node Then node.SetEnd(t)
							Case "function", "method"
								NextToke(t)

								Local node:TBMXNode = TBMXNode(nodeTree.RemoveLast())
								If node Then node.SetEnd(t)
							Rem
							Case "if" 'end if
								NextToke(t)

								local node:TBMXNode = TBMXNode(nodeTree.RemoveLast())
								if node then node.SetEnd(t)
							endrem
						End Select

					Case "local"
						'you can define multiple properties in one line
						'local x:int, y:int, z:int -> multiple get returned	
						Local nodes:TBMXNode[] = ParseProperties(t, TBMXNodeType.PROPERTY_LOCAL)
						For Local node:TBMXPropertyNode = EachIn nodes
							sourceInformation.AddNode(node)
							info.AddElement(node)

							node._parent = TBMXNode(nodeTree.Last())
							If node._parent Then node._parent.AddChild(node)
						Next					

					Case "global"
						Local nodes:TBMXNode[] = ParseProperties(t, TBMXNodeType.PROPERTY_GLOBAL)
						For Local node:TBMXPropertyNode = EachIn nodes
							sourceInformation.AddNode(node)
							info.AddElement(node)

							node._parent = TBMXNode(nodeTree.Last())
							If node._parent Then node._parent.AddChild(node)
						Next
						
					Case "const"
						Local nodes:TBMXNode[] = ParseProperties(t, TBMXNodeType.PROPERTY_CONST)
						For Local node:TBMXPropertyNode = EachIn nodes
							sourceInformation.AddNode(node)
							info.AddElement(node)

							node._parent = TBMXNode(nodeTree.Last())
							If node._parent Then node._parent.AddChild(node)
						Next

					Case "field"
						Local nodes:TBMXNode[] = ParseProperties(t, TBMXNodeType.PROPERTY_FIELD)
						For Local node:TBMXPropertyNode = EachIn nodes
							sourceInformation.AddNode(node)
							info.AddElement(node)

							node._parent = TBMXNode(nodeTree.Last())
							If node._parent Then node._parent.AddChild(node)
						Next
					
					Default
'						print t._toke
'						NextToke(t) --- um leeren type zu verhindern

				End Select
			EndIf
		Until t._tokeType = TOKE_EOF
	

		if nodeTree.Count() > 1
			Print "left on stack (in addition to root/source): " + nodeTree.Count() + "   " + TBMXNode(nodeTree.Last()).ToString()
		endif

'		Print rootNode.DumpTree()
	End Method
	
	
	Method ParseClass:TBMXNode(t:TToker, nodeType:Int)
		t.NextToke() 'type
		Repeat t.NextToke()
			If t._tokeType = TOKE_EOF Then Exit
		Until t._tokeType = TOKE_IDENT


		Local node:TBMXClassNode = New TBMXClassNode
		node.nodeType = nodeType
		node.SetStart(t._tokePos, t._line, t._linePos)
		node.SetName(t._toke)
		If node.name = "" Then Return Null

		t.NextToke()
		t.NextToke()

		'extends
		If CParse(t, "extends" )
			If nodeType = TBMXNodeType.CLASS_STRUCT
				Error("Structs cannot be extended")
			EndIf
'
			If nodeType = TBMXNodeType.CLASS_INTERFACE
				node._parentName = "brl.classes.object"
			Else
				node._parentName = t._toke
			EndIf

			t.NextToke()
			t.NextToke()
		EndIf
Rem


		If CParse( "implements" )

			If attrs & CLASS_STRUCT
				Err "Implements cannot be used with Structs"
			EndIf

			'If attrs & DECL_EXTERN
			'	Err "Implements cannot be used with external classes."
			'EndIf

			If attrs & CLASS_INTERFACE
				Err "Implements cannot be used with interfaces."
			EndIf

			'If attrs & CLASS_TEMPLATEARG
			'	Err "Implements cannot be used with class parameters."
			'EndIf

			Local nimps:Int
			Repeat
				If imps.Length=nimps imps=imps + New TIdentType[10]
				imps[nimps]=ParseIdentType()
				nimps:+1
			Until Not CParse(",")
			imps=imps[..nimps]
		EndIf

endrem

		If CParse(t, "final")
			node._final = True
		Else If CParse(t, "abstract")
			node._abstract = True
		EndIf
		
		'meta
'		meta = ParseMetaData()

		node.SetHeaderEnd(t._tokePos, t._line, t._linePos)
		Return node
	End Method


	Method ParseImport:TBMXNode(t:TToker, workingDirectory:String="", info:TBMXParserInformation)
		t.NextToke() 'import
'		t.NextToke() 'space
		Repeat t.NextToke()
			If t._tokeType = TOKE_EOF Then Exit
		Until t._tokeType = TOKE_IDENT Or t._tokeType = TOKE_STRINGLIT


		Local node:TBMXSourceNode = New TBMXSourceNode
		node.SetStart(t._tokePos, t._line, t._linePos)
		
		'import "file.bmx"
		If t._tokeType = TOKE_STRINGLIT
			node.nodeType = TBMXNodeType.SOURCE_IMPORTFILE
			node.SetName(BmxUnquote(t._toke))
			node.uri = node.name

			If Not node.name.ToLower().EndsWith(".bmx")
				t.nextToke()
				Return Null
			EndIf


			If workingDirectory Then node.uri = workingDirectory + "/" + node.uri
			node.uri = ActualPath(node.uri) 'correct casing
			node.uri = RealPath(node.uri) 'absolute path

		'import my.module
		Else
			node.nodeType = TBMXNodeType.SOURCE_MODULE
			node.SetName(ParseModulePath(t))

			Local parts:String[] = node.name.ToLower().Split(".")
			Local modPath:String = info.bmxDirectory + "/"
			For Local p:String = EachIn parts
				modPath :+ p + ".mod/"
			Next
			modPath :+ parts[parts.length-1] + ".bmx"
			
			modPath = ActualPath(modPath)
'			Throw "BMX: "+ modPath

			node.uri = modPath

		EndIf
		t.NextToke()


		node.SetHeaderEnd(t._tokePos, t._line, t._linePos)
		Return node
	End Method
	
	
	
	Method _ParseProperty:TBMXPropertyNode(t:TToker, nodeType:Int)
		Local _type:String = "Int" 'default to Int ?
	
		Local node:TBMXPropertyNode = New TBMXPropertyNode
		node.nodeType = nodeType
		node.SetStart(t._tokePos, t._line, t._linePos)

		'eat spaces, connectors, tabs ..
		Repeat t.NextToke()
			If t._tokeType = TOKE_EOF Then Return Null
		Until t._tokeType = TOKE_IDENT
		node.SetName(t._toke)

		'find ":" - local i:int  |  local x:int(y) 
		'or "(" - local f(x:int)
		Repeat t.NextToke()
			'non strict?
			If t._toke = "," Then Return node
			If t._tokeType = TOKE_EOF Then Return Null
		Until t._toke = ":" Or t._toke = "(" 'TOKE_SYMBOL

		'eat spaces, connectors, tabs ..
		Repeat t.NextToke()
			If t._tokeType = TOKE_EOF Then Return Null
		Until t._tokeType = TOKE_KEYWORD Or t._tokeType = TOKE_IDENT Or t._toke = ")" 'type or object
		If t._toke = ")"
			_type = "()"
		Else
			_type = t._toke
		EndIf


		Local nextT:String = PeekNextToke(t)
		Local hasAssignment:Int = False
		Local assignment:String
		While nextT <> ","  And nextT <> "~n"
			If nextT = "=" 
				hasAssignment = True
				assignment :+ " " + nextT.Trim() + " "
			Else
				assignment :+ nextT.Trim()
			EndIf
			
			NextToke(t)
			nextT = PeekNextToke(t)
		Wend
		'assignment is borked for now (can contain half commands)
		'if assignment Then _type = _type + " = " + assignment
'print "type: " + _type
'if _type = "String" then DebugStop
Rem
		'function definition?
		if t._toke = ":"
print "COLON"
			'read return
			t.NextToke()
			
			_type :+ ":" + t._toke
			
			t.NextToke()
		endif
		
		If t._toke = "("
print "BRACKET"
			Local args:String
			Local openBracket:Int = 1
			While openBracket
				NextToke(t)
				If t._toke = ")" 
					openBracket :- 1
					If openBracket = 0 Then Exit
				EndIf
				If t._toke = "(" Then openBracket :+ 1

				args :+ t._toke
			Wend

			Local argsSplit:String[] = ParseCallableArgs(args)
			Local argsBeautified:String
			For Local arg:String = EachIn argsSplit
				If argsBeautified Then argsBeautified :+ ", "
				argsBeautified :+ arg
			Next
			
			_type = "(" + argsBeautified +")"
			
			NextToke(t)
		EndIf		
endrem
		
		node._typeName = _type
		if _type = "()"
			node._callable = True
		endif
		
		node.SetHeaderEnd(t)
		node.SetEnd(t)
		Return node
	End Method


	Method ParseProperties:TBMXNode[](t:TToker, propertyType:Int)
		t.NextToke() 'global/local/...

		Local nodes:TBMXPropertyNode[] = New TBMXPropertyNode[0]
		
		'read in all properties
		While True
			Local node:TBMXPropertyNode = _ParseProperty(t, propertyType)
			If Not node Then Exit
			
'print "parsed property ~q" + node.ToString() + "~q"
			nodes :+ [node]
			
'			print "after reading: ~q" + t._toke +"~q"
			
			'next property
			If t._toke <> "," Then Exit
		Wend

		NextToke(t)


		Return nodes
	End Method
	
	
	Method ParseIdent:String(t:TToker)
		Select t._toke
			Case "@"
				t.NextToke()
			Case "string","object", "self"
			Default
				If t._tokeType <> TOKE_IDENT
					Local kw:String
					If t._tokeType = TOKE_KEYWORD
						kw = " keyword"
					End If
					Error("Syntax error - expecting identifier, but found" + kw + " '" + t._toke + "'")
				End If
		End Select
		Local id:String = t._toke
		t.NextToke()
		Return id
	End Method



	Method ParseCallable:TBMXNode(t:TToker, nodeType:Int)
		t.NextToke() 'function
		Local line:Int = t._line
		Local linePos:Int = t._linePos
		Local tokePos:Int = t._tokePos
		Repeat t.NextToke()
			If t._tokeType = TOKE_EOF Then Exit
		Until t._tokeType = TOKE_IDENT Or (t._tokeType = TOKE_KEYWORD And t._toke.ToLower() = "new") 'Method New()
'print " -> " + t._toke + "   tokePos="+t._tokePos

		Local node:TBMXCallableNode = New TBMXCallableNode
		node.nodeType = nodeType
		node.SetStart(tokePos, line, linePos)
		node.SetName(t._toke)
		If node.name = "" Then Return Null
		NextToke(t) 'skip spaces

		If t._toke = ":"
			node._returns = NextToke(t)
			NextToke(t)
		EndIf

		If t._toke = "("
			Local args:String
			Local openBracket:Int = 1
			While openBracket
				NextToke(t)
				If t._toke = ")" 
					openBracket :- 1
					If openBracket = 0 Then Exit
				EndIf
				If t._toke = "(" Then openBracket :+ 1

				If t._toke = "." And PeekNextToke(t) = "." '.. connector
					NextToke(t)
					NextToke(t)
					Continue
				EndIf
				
				args :+ t._toke
			Wend
'wohl besser nicht einfach alle "anfuegen" sondern wirklich
'bis zum naechsten komma ... und zum naechsten --- und wenn da dann "(" enthalten,
'dort "drin" als Gesamtwerk sehen
			'split functions
'			if args.Find("(") >= 0
'				throw "TODO: functions in params"
'			else

			Local argsSplit:String[] = ParseCallableArgs(args)
			For Local arg:String = EachIn argsSplit
				Local argNode:TBMXPropertyNode = New TBMXPropertyNode
				argNode.nodeType = TBMXNodeType.PROPERTY_PARAM
				
				Local splitterPos:Int = arg.Find(":")
				If splitterPos = -1
					argNode.SetName(arg)
					'default to ":int"
					argNode._typeName = "int"
				Else
					argNode.SetName(arg[.. splitterPos])
					'variants:
					'myparam:int(p:int) = defaultCallback
					'myparam(p:int) = defaultCallback
					'myparam = defaultValue
					Rem
					Local argType:String = arg[splitterPos+1 ..]
					Local argDefaultSplitter:Int = argType.FindLast("=") 
					if argDefaultSplitter >= 0
						Local argFuncDefEndPos:Int = argType.FindLast(")")
						if argFuncDefEndPos > 0 and argFuncDefEndPos < argDefaultSplitter
							
						if argType.Find(")") > argDefaultSplitter
					endrem
					Local argDefaultSplitter:Int = arg.FindLast("=") 
					If argDefaultSplitter >= 0 
						argNode._typeName = arg[splitterPos+1 .. argDefaultSplitter]
					Else
						argNode._typeName = arg[splitterPos+1 ..]
					EndIf
					
				EndIf
			
				node.AddParam(argNode)
'print "Callable: " + node.name + ". Added argument: " + argNode.name +"["+argNode._typeName+"]"
			Next
		EndIf


'		NextToke(t)
		
	'	While t.NextToke() <> ")"
	'	Wend


		If PeekNextToke(t) = "final"
			node._final = True
			NextToke(t)
		Else If PeekNextToke(t) = "abstract"
			node._abstract = True
			NextToke(t)
		EndIf

		node.SetHeaderEnd(t._tokePos, t._line, t._linePos)
		Return node
	End Method
	
	
	Method ParseCallableArgs:String[](args:String)
		Local result:String[]
		args = args.Trim()
		While args
'print node.name +" remaining args: ~q" + args +"~q"
			'scan for next "(" and scan for next ","
			'if "(" comes before next "," then read function definition
			Local nextBracket:Int = args.Find("(") 
			Local nextComma:Int = args.Find(",")
			If nextComma = -1
				args = RemoveDoubleDots(args).Trim()
				If args Then result :+ [args]
				Exit
			ElseIf nextBracket >= 0 And nextBracket < nextComma
				Local bracketsToClose:Int = 0
				Local argEnd:Int = 0
				For Local i:Int = 0 Until args.length
					If args[i] = Asc("(") Then bracketsToClose :+ 1
					If args[i] = Asc(")") Then bracketsToClose :- 1
					If args[i] = Asc(",") And bracketsToClose = 0 Then Exit
					argEnd :+ 1
				Next
		
				Local a:String = RemoveDoubleDots(args[.. argEnd]).Trim()
				args = args[argEnd + 1 ..]
				If Not a Then Continue

				result :+ [a]
'				print "argF: ~q" + a + "~q     remaining: ~q" + args +"~q"
			Else
				'read normal parameter
				Local a:String = RemoveDoubleDots(args[.. nextComma]).Trim()
				args = args[nextComma + 1 ..]

				If Not a Then Continue

				result :+ [a]
'				print "arg: ~q" + a + "~q     remaining: ~q" + args +"~q"
			EndIf
		Wend
		Return result
	End Method
	
	
	'from bcc/parser.bmx
	Method ActualPath:String(path:String)
		Local dir:String = ExtractDir(path)
		Local origFile:String = StripDir(path)
		Local lowerFile:String = origFile.ToLower()
		
		Local actualDir:String = ExtractDir(RealPath(path))

		Local files:String[] = LoadDir(actualDir)
		For Local file:String = EachIn files

			If file.ToLower() = lowerFile Then
				If file <> origFile Then
					' we could raise as a warning instead, but an error encourages the user to fix their code ;-)
					Error("Actual file '" + file + "' differs in case with import '" + origFile + "'")
					
					' what we might do were we to warn instead...
					If dir Then
						Return dir + "/" + file
					Else
						Return file
					End If
				End If
				Exit
			End If
		Next
		Return path
	End Method


	Method RemoveDoubleDots:String(s:String)
		Local dotPos:Int = s.Find("..")
		While dotPos <> -1
			s = s[.. dotPos] + s[dotPos + 2 ..]
			dotPos = s.Find("..")
		Wend
		Return s
	End Method
	
	
	Method CountOccurrences:Int(s:String, subS:String)
		Local arr:String[] = s.Split(subS)
		Return arr.length - 1
	End Method


	Method SkipEols(toker:TToker)
		While CParse(toker, "~n") Or CParse(toker, ";")
		Wend
	End Method
	
	
	Method SkipSpaceAndConnectors(toker:TToker)
'Print "SkipSpaceAndConnectors: begin: ~q" + toker._toke +"~q"
		Local skipped:Int = False
		Repeat
			'Print "                      : peeknexttoke = ~q" + PeekNextToke(toker) + "~q"
			If toker._toke = " " Or PeekNextToke(toker) = " "
				skipped = True
				Repeat
					toker.NextToke()
				Until toker.tokeType() <> TOKE_SPACE Or toker.tokeType() = TOKE_EOF

			ElseIf PeekNextToke(toker) = ".."
				'Print "found dots"

				Repeat
					toker.NextToke()
				Until toker._toke <> "." Or toker.tokeType() = TOKE_EOF
				
				skipped = True
			EndIf
		Until skipped = False
'Print "SkipSpaceAndConnectors: end: ~q" + toker._toke +"~q"
	End Method



	Method ParseModulePath:String(toker:TToker)
		'begin
		Local path:String = toker._toke
		NextToke(toker)
	
		While CParse(toker, "." )
			If toker._tokeType = TOKE_IDENT 
				path :+ "." + toker._toke
			EndIf
		Wend
		Return path
	End Method
	

	Method PeekNextToke:String(toker:TToker, returnLower:Int = False)
		Return NextToke(New TToker.Copy(toker), returnLower)
Rem
		local t:TToker = new TToker.Copy(toker)
		't.NextToke()
		Repeat
			t.NextToke()
		Until t.tokeType() <> TOKE_SPACE

		Return t._toke
endrem
	End Method


	Method CParse:Int( toker:TToker, toke:String )
		If toker._toke.ToLower() <> toke
			Return False
		EndIf
		NextToke(toker)
		Return True
	End Method


	Method NextToke:String(toker:TToker, returnLower:Int = False)
		Repeat
			toker.NextToke()
		Until toker.tokeType() <> TOKE_SPACE Or toker.tokeType() = TOKE_EOF

		If returnLower
			Return toker._tokeLower
		Else
			Return toker._toke
		EndIf
	End Method

Rem
	Method FindAhead:Int(s:String, start:Int, maxDistance:Int = -1, caseSensitive:Int = False)
		If start + s.length > content.length Then Return -1
		
		If maxDistance = -1 Then maxDistance = content.length - s.length - start
		If maxDistance < 0 Then Return -1

		'keep it simple
		'local pos:Int = content.Find(s, start)
		'if pos > start + maxDistance Then Return -1
		'return pos
		
		Local found:Int = True
		If Not caseSensitive 
			Local sLow:String = s.ToLower()
			For Local i:Int = contentPos Until contentPos + maxDistance
'				if content[i] = 
			Next
		EndIf
	End Method
endrem
End Type




Type TBMXNode
	Field name:String
	Field nameLower:String
	Field nodeType:Int
	Field id:Long
	Field key:Long
	Field _start:SSourcePosition
	Field _end:SSourcePosition
	Field _headerEnd:SSourcePosition
	' NG's GC allows cross references and cleans them up properly
	Field _parent:TBMXNode
	Field _parentName:String 'lazy loaded class node


	Method New()
	End Method
	
	
	Method SetName(name:String)
		Self.name = name
		Self.nameLower = name.ToLower()
	End Method
	
	
	Method GetID:Long()
		If id = 0
			If Not name Then Throw "TBMXNode: Cannot generate ID without name"
			'blitzmax types, variables, ... are not case sensitive!
			id = (nameLower + _start.pos).Hash()
		EndIf
		Return id
	End Method


	Method GetKey:Long()
		If key = 0
			If Not name Then Throw "TBMXNode: Cannot generate Key without name"
			'blitzmax types, variables, ... are not case sensitive!
			key = name.ToLower().Hash()
		EndIf
		Return key
	End Method

	
	Method AddChild:Int(node:TBMXNode)
		Return False
	End Method


	Method GetChildren:TObjectlist()
		Return Null
	End Method


	Method GetChild:TBMXNode(name:String)
		Return Null
	End Method


	Method HasChild:Int(name:String)
		Return GetChild(name) <> Null
	End Method


	Method HasChild:Int(node:TBMXNode)
		Return False
	End Method
	
	
	Method IsCallable:Int()
		Return False
	End Method

	
	Method GetCallable:TBMXNode(name:String)
		local n:TBMXNode = GetChild(name)
		if n.IsCallable() Then Return n
	End Method


	Method SetStart(pos:Int, line:Int, linePos:Int)
		_start = New SSourcePosition(pos, line, linePos)
	End Method

	Method SetStart(t:TToker)
		_start = New SSourcePosition(t._tokePos, t._line, t._linePos)
	End Method


	Method SetEnd(pos:Int, line:Int, linePos:Int)
		_end = New SSourcePosition(pos, line, linePos)
	End Method

	Method SetEnd(t:TToker)
		_end = New SSourcePosition(t._tokePos, t._line, t._linePos)
	End Method

	'function, type ... headers
	Method SetHeaderEnd(pos:Int, line:Int, linePos:Int)
		_headerEnd = New SSourcePosition(pos, line, linePos)
	End Method

	Method SetHeaderEnd(t:TToker)
		_headerEnd = New SSourcePosition(t._tokePos, t._line, t._linePos)
	End Method
	
	
	Method ToString:String()
		Return "Node [line="+_start.line+", linePos="+_start.linePos+"]"
	End Method
	
	
	Method DumpTree:String(level:Int = 0)
		Return ""
	End Method
End Type




Type TBMXBlockNode Extends TBMXNode
	Field _children:TObjectList


	Method GetChildren:TObjectlist()
		Return _children
	End Method

	
	Method AddChild:Int(node:TBMXNode) Override
		If Not _children Then _children = New TObjectList
		
		_children.AddLast(node)
		
		Return True
	End Method
	

	Method GetChild:TBMXNode(name:String) Override
		If Not _children Then Return Null
		
		name = name.ToLower()
		For Local n:TBMXNode = EachIn _children
			If n.nameLower = name Then Return n
		Next
		'TODO: fuzzy search?
		
		Return Null
	End Method


	Method HasChild:Int(node:TBMXNode) Override
		If Not _children Then Return False
		
		Return _children.Contains(node)
	End Method


	Method DumpTree:String(level:Int = 0)
		Local res:String
		res = RSet("", level*2) + ToString() + "~n"

		If _children
			For Local n:TBMXNode = EachIn _children
				res :+ n.DumpTree(level + 1)
			Next
		EndIf
		
		Return res
	End Method
End Type




Type TBMXLogicNode Extends TBMXBlockNode
	Method ToString:String()
		Return "logic ~q"+name+"~q [line="+_start.line+"]"
	End Method
End Type




Type TBMXSourceNode Extends TBMXBlockNode
	Field uri:String
	Field strictLevel:Int = 0
	
	Method Init:TBMXSourceNode(nodeType:Int, name:String, uri:String)
		Self.nodeType = nodeType
		Self.SetName(name)
		Self.uri = uri
		Return Self
	End Method


	Method ToString:String()
		Return "source ~q"+name+"~q [uri=~q"+uri+"~q  line="+_start.line+"]"
	End Method
End Type




Type TBMXClassNode Extends TBMXBlockNode
	Field _abstract:Int = False
	Field _final:Int = False
	

	Method ToString:String()
		Local info:String = "line="+_start.line
		If _abstract Then info :+ " abstract"
		If _final Then info :+ " final"
		If _parent Then info :+ " parent="+_parent.name
		If _parentName And Not _parent Then info :+ " parent="+_parentName
		Return "Class node ~q"+name+"~q ["+ info+"]"
	End Method
End Type	




Type TBMXCallableNode Extends TBMXBlockNode
	Field _returns:String
	Field _params:TObjectList = New TObjectList
	'Field _superName:String 'lazy loaded class node
	'Field _super:TBMXNode
	Field _abstract:Int = False
	Field _final:Int = False
	
	
	Method AddParam:Int(node:TBMXNode)
		If Not _params Then _params = New TObjectList
		
		_params.AddLast(node)
		
		Return True
	End Method


	Method GetParam:TBMXNode(name:String)
		If Not _params Then Return Null
		
		For Local n:TBMXNode = EachIn _params
			If n.name.ToLower() = name Then Return n
		Next
		'TODO: fuzzy search?
		
		Return Null
	End Method


	Method HasParam:Int(name:String)
		Return GetParam(name) <> Null
	End Method


	Method HasParam:Int(node:TBMXNode)
		If Not _params Then Return False
		
		Return _params.Contains(node)
	End Method


	Method IsCallable:Int() override
		Return True
	End Method


	Method ToString:String()
		Local info:String = "line="+_start.line
		If _abstract Then info :+ " abstract"
		If _final Then info :+ " final"
		If _parent Then info :+ " parent="+_parent.name
		If _parentName And Not _parent Then info :+ " parent="+_parentName
	
		Local r:String
		If _returns Then r = ":" + _returns 

		Local p:String
		If _params And _params.Count() > 0
			For Local param:TBMXNode = EachIn _params
				If p Then p:+ ", "
				p :+ param.name
			Next
		EndIf
		p = "(" + p + ")"
		
		Select nodeType
			Case TBMXNodeType.CALLABLE_FUNCTION
				Return "function: "+name + r + p + " ["+ info+"]"
			Case TBMXNodeType.CALLABLE_METHOD
				Return "method: "+name + r + p + " ["+ info+"]"
		End Select
	End Method
End Type	




Type TBMXPropertyNode Extends TBMXNode
	Field _typeName:String
	Field _type:TBMXNode 'cache once retrieved
	Field _callable:Int
	'Field _superName:String 'lazy loaded class node
	'Field _super:TBMXNode


	Method IsCallable:Int() override
		Return _callable
	End Method
	

	Method GetTypeName:String()
		Return _typeName
	End Method
	
	
	Method GetType:TBMXNode()
		'lazy resolve
		If Not _type
			Throw "Implement me"
		'	_type = sourceInformation.GetNode(_typeName)
		EndIf
		Return _type
	End Method
	

	Method ToString:String()
		Local info:String = "line="+_start.line+" linePos="+_start.linePos
		If _parent Then info :+ " parent="+_parent.name
		If _parentName And Not _parent Then info :+ " parent="+_parentName
	
		Local t:String
		If _type
			t = _type.name
		Else
			t = _typeName
		EndIf
		
		Select nodeType
			Case TBMXNodeType.PROPERTY_GLOBAL
				Return "global: "+name + ":" + t +" ["+ info+"]"
			Case TBMXNodeType.PROPERTY_LOCAL
				Return "local: "+name + ":" + t +" ["+ info+"]"
			Case TBMXNodeType.PROPERTY_FIELD
				Return "field: "+name + ":" + t +" ["+ info+"]"
			Case TBMXNodeType.PROPERTY_CONST
				Return "const: "+name + ":" + t +" ["+ info+"]"
			Case TBMXNodeType.PROPERTY_PARAM
				Return "param: "+name + ":" + t +" ["+ info+"]"
			Default
				Return "unknown property type: "+name + ":" + t +" ["+ info+"]"
		End Select
	End Method
End Type	

