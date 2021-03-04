SuperStrict
Import Brl.ObjectList
Import Brl.Map
Import "base.util.jsonhelper.bmx"


Type TLSPMessage
	Field id:Int = -1
	Field methodName:String
	Field methodNameLower:String
	Field _cancelled:Int = False
	Field _customJSON:String
	
	'Field _data:TData
	Field _jsonHelper:TJSONHelper


	Method New(jsonInput:String)
		_jsonHelper = new TJSONHelper(jsonInput)

		'load "standard" information
		If _jsonHelper.HasPath("id")
			id = _jsonHelper.GetPathInteger("id")
		EndIf
		methodName = _jsonHelper.GetPathString("method")
		methodNameLower = methodName.ToLower()
		
'		addLog("received:")
'		addLog(_jsonHelper.ToString())
	End Method


	Method New(jsonHelper:TJSONHelper)
		_jsonHelper = jsonHelper
		
		'load "standard" information
		If _jsonHelper.HasPath("id")
			id = _jsonHelper.GetPathInteger("id")
		EndIf
		methodName = _jsonHelper.GetPathString("method")
		methodNameLower = methodName.ToLower()
	End Method


	Method New(json:TJSON)
		_jsonHelper = new TJSONHelper(json)
		
		'load "standard" information
		If _jsonHelper.HasPath("id")
			id = _jsonHelper.GetPathInteger("id")
		EndIf
		methodName = _jsonHelper.GetPathString("method")
		methodNameLower = methodName.ToLower()
	End Method
	
	
	'@messageID     message id of the request
	'@errorCode     numeric error code
	'@errorMessage  short description of the error (optional)
	Function CreateErrorMessage:TLSPMessage(messageID:int, errorCode:Int, errorMessage:String)
		Local jsonHelper:TJSONHelper = New TJSONHelper("")
		jsonHelper.SetPathString("jsonrpc", "2.0")
		jsonHelper.SetPathInteger("id", messageID)
		jsonHelper.SetPathInteger("result/error/code", errorCode)
		jsonHelper.SetPathString("result/error/message", errorMessage)
		
		Return new TLSPMessage(jsonHelper)
	End Function


	'@messageID     message id of the request
	Function CreateNullResultMessage:TLSPMessage(messageID:int)
		'for now this manual code ensures that "result:null" is actually appended
		Local jsonHelper:TJSONHelper = New TJSONHelper("{~qjsonrpc~q:~q2.0~q, ~qid~q:" + messageID + ",~qresult~q: null}")
		Return new TLSPMessage(jsonHelper)
rem
		Local jsonHelper:TJSONHelper = New TJSONHelper("")
		jsonHelper.SetPathString("jsonrpc", "2.0")
		jsonHelper.SetPathInteger("id", messageID)
		jsonHelper.SetPathNull("result")
		
		Return new TLSPMessage(jsonHelper)
endrem
	End Function


	Function CreateRPCMessage:TLSPMessage(messageID:int, jsonHelper:TJSONHelper)
		jsonHelper.SetPathString("jsonrpc", "2.0")
		jsonHelper.SetPathInteger("id", messageID)
		
		Return new TLSPMessage(jsonHelper)
	End Function
	
	
	Method GetPathString:String(path:String)
		If not _jsonHelper Then return ""
		Return _jsonHelper.GetPathString(path)
	End Method


	Method GetPathInteger:Long(path:String)
		If not _jsonHelper Then return 0
		Return _jsonHelper.GetPathInteger(path)
	End Method


	Method GetPathReal:Double(path:String)
		If not _jsonHelper Then return 0
		Return _jsonHelper.GetPathReal(path)
	End Method


	Method GetPathBool:Int(path:String)
		If not _jsonHelper Then return 0
		Return _jsonHelper.GetPathBool(path)
	End Method


	Method GetPathSize:Int(path:String)
		If not _jsonHelper Then return 0
		Return _jsonHelper.GetPathSize(path)
	End Method


	Method HasPath:Int(path:String)
		If not _jsonHelper Then return 0
		Return _jsonHelper.HasPath(path)
	End Method
	
	
	Method IsMethod:Int(methodName:String)
		Return self.methodNameLower = methodName.ToLower()
	End Method


	Method SetCancelled:Int(bool:Int=True)
		_cancelled = bool
	End Method
	
	
	Method IsCancelled:Int()
		Return _cancelled
	End Method
	
	
	Method IsRequest:int()
		if id >= 0 Then Return True
		
		Return False
	End Method


	Method IsNotification:int()
		if id = -1 Then Return True
		
		Return False
	End Method


	Method ToString:String()
		If _customJSON Then Return _customJSON
		If _jsonHelper Then Return _jsonHelper.ToStringCompact()
		Return ""
	End Method

End Type