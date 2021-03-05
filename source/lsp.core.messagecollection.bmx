SuperStrict
Import Brl.ObjectList
Import Brl.Map
Import Brl.Threads
Import "lsp.core.message.bmx"

Global MessageCollection:TLSPMessageCollection = new TLSPMessageCollection

Type TLSPMessageCollection
	'messages received from the editor / client
	'messages are stored request ID as key
	'(faster retrieval/check of existence than with an TObjectList)
	Field incomingMessagesByID:TIntMap = New TIntMap
	'mutex used by accesses to the "incomingMessagesByID" container
	'and also by "incoming(Non)SequentialMessages" 
	Field incomingMessagesMutex:TMutex = CreateMutex()
	'instead of using the objectlist to count this cached value
	'allows a thread-safe access without mutex
	'(eg. TObjectlist calls "Compact()" before returning the size)
	Field incomingSequentialMessageCount:Int
	Field incomingNonSequentialMessageCount:Int
	'messages in this container need to be processed "one after another"
	'(eg because they contain "delta changes")
	Field incomingSequentialMessages:TObjectList = New TObjectList
	'messages in this container can be processed independend from others
	Field incomingNonSequentialMessages:TObjectList = New TObjectList
	'holds "method" names which need to be handled in order/sequence
	Field sequentialMethods:TStringMap = new TStringMap
	'holds "method" names which explicitely do not need to be handled
	'in order/sequence
	Field nonSequentialMethods:TStringMap = new TStringMap
	'outgoing messages are "FiFo" ordered (first in, first out)
	'so we use a TObjectList to keep order
	'also outgoing messages might have the same ID (am not sure about this)
	Field outgoingMessages:TObjectList = new TObjectList
	Field outgoingMessageCount:Int
	Field outgoingMessagesMutex:TMutex = CreateMutex()
	
	'define what "not further defined" methods are assumed to be
	'1 = default to "in order" method
	'0 = default to "not in order" method (can run in parallel)
	Field defaultMethodOrderHandling:Int = 1

	'enable to handle nonsequential methods extra (simultaneously!)
	Field enabledNonSequentialMethods:Int = False



	Method RegisterSequentialMethod:Int(methodName:String)
		sequentialMethods.Insert(methodName.ToLower(), new Object)
	End Method


	Method UnregisterSequentialMethod:Int(methodName:String)
		sequentialMethods.Remove(methodName.ToLower())
	End Method


	Method IsSequentialMethod:Int(methodName:String)
		if not enabledNonSequentialMethods or sequentialMethods.ValueForKey( methodName.ToLower() )
			Return True
		EndIf
		Return False
	End Method


	Method RegisterNonSequentialMethod:Int(methodName:String)
		nonSequentialMethods.Insert(methodName.ToLower(), new Object)
	End Method


	Method UnregisterNonSequentialMethod:Int(methodName:String)
		nonSequentialMethods.Remove(methodName.ToLower())
	End Method


	Method IsNonSequentialMethod:Int(methodName:String)
		if enabledNonSequentialMethods and nonSequentialMethods.ValueForKey( methodName.ToLower() )
			Return True
		EndIf
		Return False
	End Method


	
	
	Method HasIncomingMessage:Int(messageID:Int)
		Return GetIncomingMessage(messageID) <> Null
	End Method


	Method GetIncomingMessageCount:Int()
		Return incomingSequentialMessageCount + incomingNonSequentialMessageCount
	End Method


	Method GetIncomingMessage:TLSPMessage(messageID:Int)
		LockMutex(incomingMessagesMutex)
		Local message:TLSPMessage = TLSPMessage(incomingMessagesByID.ValueForKey(messageID))
		UnlockMutex(incomingMessagesMutex)

		Return message
	End Method

	
	Method AddIncomingMessage:Int(message:TLSPMessage)
		LockMutex(incomingMessagesMutex)
		'default to "in order"
		if defaultMethodOrderHandling = 1
			If IsSequentialMethod(message.methodName)
				incomingSequentialMessages.AddLast(message)
				incomingSequentialMessageCount :+ 1
			Else
				incomingNonSequentialMessages.AddLast(message)
				incomingNonSequentialMessageCount :+ 1
			EndIf
		'default to "not in order" 
		else
			If IsNonSequentialMethod(message.methodName)
				incomingNonSequentialMessages.AddLast(message)
				incomingNonSequentialMessageCount :+ 1
			Else
				incomingSequentialMessages.AddLast(message)
				incomingSequentialMessageCount :+ 1
			EndIf
		endif
		incomingMessagesByID.Insert(message.id, message)
		UnlockMutex(incomingMessagesMutex)
		
		Return True
	End Method
	

	Method RemoveIncomingMessage:Int(message:TLSPMessage)
		If Not message Then Return False
		
		local result:Int
		LockMutex(incomingMessagesMutex)
		If incomingSequentialMessages.Remove(message)
			incomingSequentialMessageCount :- 1
		ElseIf incomingNonSequentialMessages.Remove(message)
			incomingNonSequentialMessageCount :- 1
		EndIf
		result = incomingMessagesByID.Remove(message.id)
		UnlockMutex(incomingMessagesMutex)

		Return result
	End Method


	Method RemoveIncomingMessage:Int(messageID:Int)
		RemoveIncomingMessage( GetIncomingMessage(messageID) )
	End Method

	Method GetIncomingSequentialMessageCount:Int()
		Return incomingSequentialMessageCount
	End Method


	'returns first ("oldest") message
	Method PopIncomingSequentialMessage:TLSPMessage()
		LockMutex(incomingMessagesMutex)
		Local message:TLSPMessage = TLSPMessage(incomingSequentialMessages.RemoveFirst())
		if message 
			incomingMessagesByID.Remove(message.id)
			incomingSequentialMessageCount :- 1
		endif
		UnlockMutex(incomingMessagesMutex)

		Return message
	End Method


	Method GetIncomingNonSequentialMessageCount:Int()
		Return incomingNonSequentialMessageCount
	End Method

	'returns first ("oldest") message
	Method PopIncomingNonSequentialMessage:TLSPMessage()
		LockMutex(incomingMessagesMutex)

		Local message:TLSPMessage = TLSPMessage(incomingNonSequentialMessages.RemoveFirst())
		if message 
			incomingMessagesByID.Remove(message.id)
			incomingNonSequentialMessageCount :- 1
		endif
		UnlockMutex(incomingMessagesMutex)

		Return message
	End Method


	Method GetOutgoingMessageCount:Int()
		Return outgoingMessageCount
	End Method

	
	Method AddOutgoingMessage:Int(message:TLSPMessage)
		LockMutex(outgoingMessagesMutex)
		outgoingMessages.AddLast(message)
		outgoingMessageCount :+ 1
		UnlockMutex(outgoingMessagesMutex)
		
		Return True
	End Method


	Method RemoveOutgoingMessage:Int(message:TLSPMessage)
		LockMutex(outgoingMessagesMutex)
		If outgoingMessages.Remove(message)
			outgoingMessageCount :- 1
		EndIf
		UnlockMutex(outgoingMessagesMutex)
		
		Return True
	End Method


	Method PopOutgoingMessage:TLSPMessage()
		LockMutex(outgoingMessagesMutex)
		Local message:TLSPMessage = TLSPMessage(outgoingMessages.RemoveFirst())
		if message 
			outgoingMessageCount :- 1
		endif
		UnlockMutex(outgoingMessagesMutex)

		Return message
	End Method
End Type