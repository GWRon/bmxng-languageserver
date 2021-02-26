SuperStrict

Import Brl.Map
Import Brl.ObjectList
Import Brl.Vector
Import "base.bmxparser.toker.bmx"
Import "base.util.longmap.bmx"

rem
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
	Field sources:TLongMap = new TLongMap
	
	
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
		local ol:TObjectList = TObjectList(elements.ValueForKey(element.GetID()))
		if not ol
			ol = new TObjectList
			elements.Insert(element.GetID(), ol)
		endif
		If not ol.contains(element)
			ol.AddLast(element)
		EndIf
	End Method


	'return first element for the given ID (there migh be multiple "local x:Int")
	Method GetElement:TBMXNode(elementID:Long)
		local ol:TObjectList = TObjectList(elements.ValueForKey(elementID))
		if not ol then Return Null
		Return TBMXNode(ol.First())
	End Method


	'return first element for the given ID (there migh be multiple "local x:Int")
	Method GetElements:TObjectList(elementID:Long)
		Return TObjectList(elements.ValueForKey(elementID))
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
	'all nodes/elements
	Field _nodes:TLongMap = New TLongMap
	'all nodes according to their position in the source
	Field _nodesByPos:TIntMap = New TIntMap
	
	
	private
	Method New()
	End Method

	public
	
	Method New(uri:String)
		self.uri = uri
	End Method


	Method GetID:Long()
		if id = 0
			if not uri then Throw "TBMXSourceInformation: Cannot generate ID without uri"
			id = uri.ToLower().Hash()
		endif
		Return id
	End Method
	

	Method AddNode(node:TBMXNode)
		If TBMXSourceNode(node)
			_imports.insert(node.GetID(), node)
		ElseIf TBMXClassNode(node)
			Select TBMXClassNode(node).classType
				Case TBMXClassNode.CLASSTYPE_INTERFACE
					_interfaces.Insert(node.GetID(), node)
				Case TBMXClassNode.CLASSTYPE_STRUCT
					_structs.Insert(node.GetID(), node)
				Case TBMXClassNode.CLASSTYPE_TYPE
					_types.Insert(node.GetID(), node)
			End Select
		ElseIf TBMXCallableNode(node)
			Select TBMXCallableNode(node).callableType
				Case TBMXCallableNode.CALLABLETYPE_FUNCTION
					_functions.Insert(node.GetID(), node)
				Case TBMXCallableNode.CALLABLETYPE_METHOD
					_methods.Insert(node.GetID(), node)
			End Select
		ElseIf TBMXPropertyNode(node)
			Select TBMXPropertyNode(node).propertyType
				Case TBMXPropertyNode.PROPERTYTYPE_CONST
					_consts.Insert(node.GetID(), node)
				Case TBMXPropertyNode.PROPERTYTYPE_FIELD
					_fields.Insert(node.GetID(), node)
				Case TBMXPropertyNode.PROPERTYTYPE_GLOBAL
					_globals.Insert(node.GetID(), node)
				Case TBMXPropertyNode.PROPERTYTYPE_LOCAL
					_locals.Insert(node.GetID(), node)
			End Select
		
		EndIf

		'store start and end (for easier retrieval of "previous")
		_nodesByPos.insert( node._start.pos, node )
		_nodesByPos.insert( node._end.pos, node )
	End Method


	Method GetPreviousNode:TBMXNode(line:Int, linePos:Int, posMap:TIntMap = Null)
		if line < 0 or line >= _linesStartPos.length Then return Null
		Return GetPreviousNode(_linesStartPos[line-1] + linePos)
	End Method

	Method GetPreviousNode:TBMXNode(sourcePos:Int, posMap:TIntMap = Null)
		if sourcePos = 0 then return Null
		If not posMap then posMap = _nodesByPos

		Local result:TBMXNode
		Local currentPos:Int = sourcePos - 1

		Repeat
			result = TBMXNode(posMap.ValueForKey(currentPos))
			if not result then currentPos :- 1
		Until result or currentPos < 0

		'ends later?
		if result and result._end.pos >= sourcePos Then result = Null

		return result
	End Method


	Method GetNode:TBMXNode(line:Int, linePos:Int)
		if line < 0 or line >= _linesStartPos.length Then return Null
		Return GetNode(_linesStartPos[line-1] + linePos)
	End Method
	
	
	Method GetNode:TBMXNode(sourcePos:Int)
		Local result:TBMXNode
		Local currentPos:Int = sourcePos
		Repeat
			result = TBMXNode(_nodesByPos.ValueForKey(currentPos))
'if result then print "sourcePos="+sourcePos+"  currentPos="+currentPos + "  node=" + result.ToString() '_parseProperty startPos=16490 (601:8 - 601:67)
			if not result then currentPos :- 1
		Until result or currentPos < 0
		
		'check if the "first found" node already ended before the
		'requested position!
		if result and result._end.pos < sourcePos Then result = Null
		
		return result
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
		self.pos = pos
		self.line = line
		self.linePos = linePos
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
		if not info Then Throw "You need to pass a parser information container to the parser."
		if not info.processedImports then info.processedImports = new TStringMap

		sourceInformation = new TBMXSourceInformation

		if useRootNode
			sourceInformation.rootNode = useRootNode
		else
			sourceInformation.rootNode = New TBMXSourceNode.Init( TBMXSourceNode.SOURCETYPE_RAW, "", workingDirectory )
		endif
	
	
		Local isExtern:Int = False
print "pushing"
		nodeTree.AddLast(sourceInformation.rootNode)
print "done"		
		Local t:TToker = New TToker.Create("", content)
		
		'read line start positions
		sourceInformation._linesStartPos = new Int[t._lines.length]
		If t._lines.length > 0
			local newLineLength:Int = "~n".length
			For local i:int = 1 until t._lines.length
				sourceInformation._linesStartPos[i] = sourceInformation._linesStartPos[i-1] + t._lines[i-1].length + newLineLength
			Next
		Endif

		
		Repeat
			t.NextToke()
			If t._tokeType = TOKE_KEYWORD 
				Select t._tokeLower
					Case "for", "repeat", "while"  ', "if", "else", "elseif"
						'for "if": bcc -> parser.bmx -> ParseIfStmt()
						'or... have some "ParseExpr()" - so "if 1=1 n=1" is identified
						'as singlelineif with "1=1" being the condition and "n=1" the action
						
						Local node:TBMXLogicNode = new TBMXLogicNode
						node.name = t._tokeLower
						node.SetStart(t._tokePos, t._line, t._linePos)

						sourceInformation.AddNode(node)
						info.AddElement(node)

						node._parent = TBMXNode(nodeTree.Last())
						If node._parent Then node._parent.AddChild(node)
						nodeTree.AddLast(node)
					

					Case "next", "until", "wend" ', "endif"
						local node:TBMXNode = TBMXNode(nodeTree.RemoveLast())
						if node then node.SetEnd(t)
						
					Case "extern" 
						'read until end extern?
						isExtern = True

						Local node:TBMXLogicNode = new TBMXLogicNode
						node.name = t._tokeLower
						node.SetStart(t._tokePos, t._line, t._linePos)

						sourceInformation.AddNode(node)
						info.AddElement(node)

						node._parent = TBMXNode(nodeTree.Last())
						If node._parent Then node._parent.AddChild(node)
						nodeTree.AddLast(node)

					Case "include"
						'TODO
						
					Case "import"
if not parseImports then continue
						
						Local node:TBMXSourceNode = TBMXSourceNode(ParseImport(t, workingDirectory, info))
						If not node Then continue

						if node.sourceType = TBMXSourceNode.SOURCETYPE_IMPORTFILE or node.sourceType = TBMXSourceNode.SOURCETYPE_MODULE
							if node.uri and not info.processedImports.Contains(node.uri)
								local importParser:TBMXParser = New TBMXParser
								'print "loading import " + node.uri
								info.processedImports.Insert(node.uri, node)

								importParser.Parse( LoadText(node.uri), ExtractDir(node.uri), info, node)

								'disabled, we pass "node" as root already,
								'to avoid an additional root node being added
								'add to the parent
								'node.AddChild(importParser.rootNode)
							endif
						endif
			
						sourceInformation.AddNode(node)
						info.AddElement(node)

						'maybe rename to "users" for imports/includes
						node._parent = TBMXNode(nodeTree.Last())
						If node._parent Then node._parent.AddChild(node)

					Case "type"
						Local node:TBMXNode = ParseClass(t, TBMXClassNode.CLASSTYPE_TYPE)
						If TBMXClassNode(node)
							
							sourceInformation.AddNode(node)
							info.AddElement(node)
							
							node._parent = TBMXNode(nodeTree.Last())
							If node._parent Then node._parent.AddChild(node)
							nodeTree.AddLast(node)
						EndIf

					Case "interface"
						Local node:TBMXNode = ParseClass(t, TBMXClassNode.CLASSTYPE_INTERFACE)
						If TBMXClassNode(node)
							sourceInformation.AddNode(node)
							info.AddElement(node)

							node._parent = TBMXNode(nodeTree.Last())
							If node._parent Then node._parent.AddChild(node)
							nodeTree.AddLast(node)
						EndIf

					Case "struct"
						Local node:TBMXNode = ParseClass(t, TBMXClassNode.CLASSTYPE_STRUCT)
						If TBMXClassNode(node)
							sourceInformation.AddNode(node)
							info.AddElement(node)

							node._parent = TBMXNode(nodeTree.Last())
							If node._parent Then node._parent.AddChild(node)
							nodeTree.AddLast(node)
						EndIf

					Case "function"
						'ignore externs for now
						if isExtern then continue
						
						Local node:TBMXNode = ParseCallable(t, TBMXCallableNode.CALLABLETYPE_FUNCTION)
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
						Local node:TBMXNode = ParseCallable(t, TBMXCallableNode.CALLABLETYPE_METHOD)
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
						local node:TBMXNode = TBMXNode(nodeTree.RemoveLast())
						if node then node.SetEnd(t)

					Case "endextern"
						isExtern = False

						local node:TBMXNode = TBMXNode(nodeTree.RemoveLast())
						if node then node.SetEnd(t)
				
					'check if upcoming is "type/interface/struct..."
					Case "end"
						Select PeekNextToke(t, True)
							Case "extern"
								isExtern = False

								local node:TBMXNode = TBMXNode(nodeTree.RemoveLast())
								if node then node.SetEnd(t)
							Case "type", "interface", "struct"
								NextToke(t)
								
								local node:TBMXNode = TBMXNode(nodeTree.RemoveLast())
								if node then node.SetEnd(t)
							Case "function", "method"
								NextToke(t)

								local node:TBMXNode = TBMXNode(nodeTree.RemoveLast())
								if node then node.SetEnd(t)
							rem
							Case "if" 'end if
								NextToke(t)

								local node:TBMXNode = TBMXNode(nodeTree.RemoveLast())
								if node then node.SetEnd(t)
							endrem
						End Select

					Case "local"
						'you can define multiple properties in one line
						'local x:int, y:int, z:int -> multiple get returned	
						Local nodes:TBMXNode[] = ParseProperties(t, TBMXPropertyNode.PROPERTYTYPE_LOCAL)
						For Local node:TBMXPropertyNode = EachIn nodes
							sourceInformation.AddNode(node)
							info.AddElement(node)

							node._parent = TBMXNode(nodeTree.Last())
							If node._parent Then node._parent.AddChild(node)
						Next					

					Case "global"
						Local nodes:TBMXNode[] = ParseProperties(t, TBMXPropertyNode.PROPERTYTYPE_GLOBAL)
						For Local node:TBMXPropertyNode = EachIn nodes
							sourceInformation.AddNode(node)
							info.AddElement(node)

							node._parent = TBMXNode(nodeTree.Last())
							If node._parent Then node._parent.AddChild(node)
						Next
						
					Case "const"
						Local nodes:TBMXNode[] = ParseProperties(t, TBMXPropertyNode.PROPERTYTYPE_CONST)
						For Local node:TBMXPropertyNode = EachIn nodes
							sourceInformation.AddNode(node)
							info.AddElement(node)

							node._parent = TBMXNode(nodeTree.Last())
							If node._parent Then node._parent.AddChild(node)
						Next

					Case "field"
						Local nodes:TBMXNode[] = ParseProperties(t, TBMXPropertyNode.PROPERTYTYPE_FIELD)
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

print "left on stack: " + nodeTree.Count()

'		Print rootNode.DumpTree()
	End Method
	
	
	Method ParseClass:TBMXNode(t:TToker, classType:Int)
		t.NextToke() 'type
		Repeat t.NextToke()
			If t._tokeType = TOKE_EOF Then Exit
		Until t._tokeType = TOKE_IDENT


		Local node:TBMXClassNode = New TBMXClassNode
		node.classType = classType
		node.SetStart(t._tokePos, t._line, t._linePos)
		node.name = t._toke
		If node.name = "" Then Return Null

		t.NextToke()
		t.NextToke()

		'extends
		If CParse(t, "extends" )
			If classType = TBMXClassNode.CLASSTYPE_STRUCT
				Error("Structs cannot be extended")
			EndIf
'
			If classType = TBMXClassNode.CLASSTYPE_INTERFACE
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
			node.sourceType = TBMXSourceNode.SOURCETYPE_IMPORTFILE
			node.name = BmxUnquote(t._toke)
			node.uri = node.name

			if not node.name.ToLower().EndsWith(".bmx")
				t.nextToke()
				Return Null
			EndIf


			if workingDirectory Then node.uri = workingDirectory + "/" + node.uri
			node.uri = ActualPath(node.uri) 'correct casing
			node.uri = RealPath(node.uri) 'absolute path

		'import my.module
		Else
			node.sourceType = TBMXSourceNode.SOURCETYPE_MODULE
			node.name = ParseModulePath(t)

			local parts:String[] = node.name.ToLower().Split(".")
			local modPath:String = info.bmxDirectory + "/"
			For local p:String = EachIn parts
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
	
	
	
	Method _ParseProperty:TBMXPropertyNode(t:TToker, propertyType:Int)
		Local _type:String = "Int" 'default to Int ?
	
		Local node:TBMXPropertyNode = New TBMXPropertyNode
		node.propertyType = propertyType
		node.SetStart(t._tokePos, t._line, t._linePos)

		'eat spaces, connectors, tabs ..
		Repeat t.NextToke()
			If t._tokeType = TOKE_EOF Then Return Null
		Until t._tokeType = TOKE_IDENT
		node.name = t._toke

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



	Method ParseCallable:TBMXNode(t:TToker, callableType:Int)
		t.NextToke() 'function
		Local line:Int = t._line
		Local linePos:Int = t._linePos
		Local tokePos:Int = t._tokePos
		Repeat t.NextToke()
			If t._tokeType = TOKE_EOF Then Exit
		Until t._tokeType = TOKE_IDENT or (t._tokeType = TOKE_KEYWORD and t._toke.ToLower() = "new") 'Method New()
'print " -> " + t._toke + "   tokePos="+t._tokePos

		Local node:TBMXCallableNode = New TBMXCallableNode
		node.callableType = callableType
		node.SetStart(tokePos, line, linePos)
		node.name = t._toke
		If node.name = "" Then Return Null

		NextToke(t) 'skip spaces

		If t._toke = ":"
			node._returns = NextToke(t)
		EndIf

		NextToke(t)
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
				node._params :+ [arg]
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
		While CParse(toker, "~n") or CParse(toker, ";")
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

rem
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
	Field id:Long
	Field key:Long
	Field _start:SSourcePosition
	Field _end:SSourcePosition
	Field _headerEnd:SSourcePosition
	Field _children:TObjectList
	' NG's GC allows cross references and cleans them up properly
	Field _parent:TBMXNode
	Field _parentName:String 'lazy loaded class node


	Method New()
	End Method
	
	
	Method GetID:Long()
		if id = 0
			if not name then Throw "TBMXNode: Cannot generate ID without name"
			'blitzmax types, variables, ... are not case sensitive!
			id = (name.ToLower()+_start.pos).Hash()
		endif
		Return id
	End Method


	Method GetKey:Long()
		if key = 0
			if not name then Throw "TBMXNode: Cannot generate Key without name"
			'blitzmax types, variables, ... are not case sensitive!
			key = name.ToLower().Hash()
		endif
		Return key
	End Method
	
	
	Method AddChild(node:TBMXNode)
		If Not _children Then _children = New TObjectList
		
		_children.AddLast(node)
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
		Return "Node [line="+_start.line+"]"
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




Type TBMXSourceNode Extends TBMXNode
	Field sourceType:Int
	Field uri:String
	Field strictLevel:Int = 0
	
	Global SOURCETYPE_RAW:Int = 0
	Global SOURCETYPE_MODULE:Int = 1
	Global SOURCETYPE_IMPORTFILE:Int = 2
	Global SOURCETYPE_INCLUDEFILE:Int = 3
	

	Method Init:TBMXSourceNode(sourceType:Int, name:String, uri:String)
		Self.sourceType = sourceType
		Self.name = name
		Self.uri = uri
		Return Self
	End Method


	Method ToString:String()
		Return "source ~q"+name+"~q [uri=~q"+uri+"~q  line="+_start.line+"]"
	End Method
End Type




Type TBMXLogicNode Extends TBMXNode
	Method ToString:String()
		Return "logic ~q"+name+"~q [line="+_start.line+"]"
	End Method
End Type	


Type TBMXClassNode Extends TBMXNode
	Field classType:Int
	Field _abstract:Int = False
	Field _final:Int = False
	
	Global CLASSTYPE_TYPE:Int = 0
	Global CLASSTYPE_INTERFACE:Int = 1
	Global CLASSTYPE_STRUCT:Int = 2
	

	Method ToString:String()
		Local info:String = "line="+_start.line
		If _abstract Then info :+ " abstract"
		If _final Then info :+ " final"
		If _parent Then info :+ " parent="+_parent.name
		If _parentName And Not _parent Then info :+ " parent="+_parentName
		Return "Class node ~q"+name+"~q ["+ info+"]"
	End Method
End Type	


Type TBMXCallableNode Extends TBMXNode
	Field callableType:Int
	Field _returns:String
	Field _params:String[]
	Field _superName:String 'lazy loaded class node
	Field _super:TBMXNode
	Field _abstract:Int = False
	Field _final:Int = False
	
	Global CALLABLETYPE_FUNCTION:Int = 0
	Global CALLABLETYPE_METHOD:Int = 1

	Method ToString:String()
		Local info:String = "line="+_start.line
		If _abstract Then info :+ " abstract"
		If _final Then info :+ " final"
		If _parent Then info :+ " parent="+_parent.name
		If _parentName And Not _parent Then info :+ " parent="+_parentName
	
		Local r:String
		If _returns Then r = ":" + _returns 

		Local p:String
		If _params And _params.length > 0
			For Local param:String = EachIn _params
				If p Then p:+ ", "
				p :+ param
			Next
		EndIf
		p = "(" + p + ")"
		
		Select callableType
			Case CALLABLETYPE_FUNCTION
				Return "function: "+name + r + p + " ["+ info+"]"
			Case CALLABLETYPE_METHOD
				Return "method: "+name + r + p + " ["+ info+"]"
		End Select
	End Method
End Type	




Type TBMXPropertyNode Extends TBMXNode
	Field propertyType:Int
	Field _typeName:String
	Field _type:TBMXNode
	Field _superName:String 'lazy loaded class node
	Field _super:TBMXNode
	
	Global PROPERTYTYPE_GLOBAL:Int = 0
	Global PROPERTYTYPE_LOCAL:Int = 1
	Global PROPERTYTYPE_FIELD:Int = 2
	Global PROPERTYTYPE_CONST:Int = 3


	Method ToString:String()
		Local info:String = "line="+_start.line
		If _parent Then info :+ " parent="+_parent.name
		If _parentName And Not _parent Then info :+ " parent="+_parentName
	
		Local t:String
		If _type
			t = _type.name
		Else
			t = _typeName
		EndIf
		
		Select propertyType
			Case PROPERTYTYPE_GLOBAL
				Return "global: "+name + ":" + t +" ["+ info+"]"
			Case PROPERTYTYPE_LOCAL
				Return "local: "+name + ":" + t +" ["+ info+"]"
			Case PROPERTYTYPE_FIELD
				Return "field: "+name + ":" + t +" ["+ info+"]"
			Case PROPERTYTYPE_CONST
				Return "const: "+name + ":" + t +" ["+ info+"]"
		End Select
	End Method
End Type	

