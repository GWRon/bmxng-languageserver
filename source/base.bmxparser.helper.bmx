SuperStrict

Import Brl.Retro
Import Brl.StringBuilder


Function IsSpace:Int( ch:Int )
	Return ch<=Asc(" ") Or ch=$A0 ' NO-BREAK SPACE (U+00A0)
End Function

Function IsDigit:Int( ch:Int )
	Return ch>=Asc("0") And ch<=Asc("9")
End Function

Function IsAlpha:Int( ch:Int )
	Return (ch>=Asc("A") And ch<=Asc("Z")) Or (ch>=Asc("a") And ch<=Asc("z"))
End Function

Function IsBinDigit:Int( ch:Int )
	Return ch=Asc("0") Or ch=Asc("1")
End Function

Function IsHexDigit:Int( ch:Int )
	Return IsDigit(ch) Or (ch>=Asc("A") And ch<=Asc("F")) Or (ch>=Asc("a") And ch<=Asc("f"))
End Function


Function Error(s:String)
	print "ERROR: " + s
	end
End Function


Function BmxUnquote$( str$, unquoted:Int = False )
	Local length:Int
	Local i:Int
	If Not unquoted Then
		If str.length < 2 Or str[str.length - 1] <> Asc("~q") Then
			Error("Expecting expression but encountered malformed string literal")
		End If
		length = str.length - 1
		i = 1
	Else
		length = str.length
	End If

	Local sb:TStringBuilder = New TStringBuilder

	While i < length
		Local c:Int = str[i]
		i :+ 1
		If c <> Asc("~~") Then
			sb.AppendChar(c)
			Continue
		End If

		If i = length
			Error("Bad escape sequence in string")
		EndIf
		
		c = str[i]
		i :+ 1
		
		Select c
			Case Asc("~~")
				sb.AppendChar(c)
			Case Asc("0")
				sb.AppendChar(0)
			Case Asc("t")
				sb.AppendChar(Asc("~t"))
			Case Asc("r")
				sb.AppendChar(Asc("~r"))
			Case Asc("n")
				sb.AppendChar(Asc("~n"))
			Case Asc("q")
				sb.AppendChar(Asc("~q"))
			Case Asc("$") ' hex
				c = str[i]
				i :+ 1
				Local n:Int
				While True
					Local v:Int
					If c >= Asc("0") And c <= Asc("9") Then
						v = c-Asc("0")
					Else If c >= Asc("a") And c <= Asc("f") Then
						v = c-Asc("a")+10
					Else If c >= Asc("A") And c <= Asc("F") Then
						v = c-Asc("A")+10
					Else If c <> Asc("~~")
						Error("Bad escape sequence in string")
					Else
						Exit
					End If
					n = (n Shl 4) | (v & $f)
					If i = length 
						Error("Bad escape sequence in string")
					EndIf
					c = str[i]
					i :+ 1
				Wend
				If c <> Asc("~~")
					Error("Bad escape sequence in string")
				EndIf
				sb.AppendChar(n)
			Case Asc("%") ' bin
				c = str[i]
				i :+ 1
				Local n:Int
				While c = Asc("1") Or c = Asc("0")
					n :Shl 1
					If c = Asc("1") Then
						n :| 1
					End If
					If i = length 
						Error("Bad escape sequence in string")
					EndIf
					c = str[i]
					i :+ 1
				Wend
				If c <> Asc("~~")
					Error("Bad escape sequence in string")
				EndIf
				sb.AppendChar(n)
			Default
				If c >= Asc("1") And c <= Asc("9") Then
					Local n:Int
					While c >= Asc("0") And c <= Asc("9") 
						n = n * 10 + (c-Asc("0"))
						If i = length
							Error("Bad escape sequence in string")
						EndIf
						c = str[i]
						i :+ 1
					Wend
					If c <> Asc("~~") 
						Error("Bad escape sequence in string")
					EndIf
					sb.AppendChar(n)
				Else
					Error("Bad escape sequence in string")
				End If
		End Select
	Wend
	Return sb.ToString()
End Function