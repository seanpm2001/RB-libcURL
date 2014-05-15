#tag Class
Class cURLItem
	#tag Method, Flags = &h0
		Sub Close()
		  // cleans up the instance
		  
		  If Not libcURL.IsAvailable Then Return
		  curl_easy_cleanup(Me.Handle)
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Shared Function CloseCallback(UserData As Integer, Socket As Integer) As Integer
		  #pragma Unused Socket ' socket is an OS socket reference
		  Dim curl As WeakRef = Instances.Lookup(UserData, Nil)
		  If curl = Nil Then
		    Break ' UserData does not refer to a valid instance!
		    Return 1
		  End If
		  cURLItem(curl.Value).curlClose
		  Return 0
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Constructor()
		  // Creates a new instance, sets up the callback functions
		  If Not libcURL.IsAvailable Then Raise cURLException(0)
		  
		  If Instances = Nil Then
		    mLastError = curl_global_init(CURL_GLOBAL_ALL)
		    If Me.LastError = 0 Then
		      Instances = New Dictionary
		    Else
		      Raise cURLException(Me.LastError)
		    End If
		  End If
		  
		  mHandle = curl_easy_init()
		  If mHandle > 0 Then
		    Instances.Value(mHandle) = New WeakRef(Me)
		    InitCallbacks(Me)
		  Else
		    Raise cURLException(libcURL.Errors.INIT_FAILED)
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Sub Constructor(CopyOpts As libcURL.cURLItem)
		  // creates a new instance by cloning the passed instance
		  If Not libcURL.IsAvailable Then Raise cURLException(0)
		  If CopyOpts <> Nil And CopyOpts.Handle > 0 Then
		    mHandle = curl_easy_duphandle(CopyOpts.Handle)
		    If Me.Handle > 0 Then
		      Instances.Value(mHandle) = New WeakRef(Me)
		      InitCallbacks(Me)
		    Else
		      Raise cURLException(Me.LastError)
		    End If
		  End If
		End Sub
	#tag EndMethod

	#tag DelegateDeclaration, Flags = &h21
		Private Delegate Function cURLCallback(char As Ptr, size As Integer, nmemb As Integer, UserData As Integer) As Integer
	#tag EndDelegateDeclaration

	#tag Method, Flags = &h21
		Private Sub curlClose()
		  // called by CloseCallback
		  RaiseEvent Disconnected()
		End Sub
	#tag EndMethod

	#tag DelegateDeclaration, Flags = &h21
		Private Delegate Function cURLCloseCallback(UserData As Integer, cURLSocket As Integer) As Integer
	#tag EndDelegateDeclaration

	#tag Method, Flags = &h21
		Private Function curlDebug(info As curl_infotype, data As Ptr, Size As Integer) As Integer
		  // called by DebugCallback
		  Dim mb As MemoryBlock = data
		  Dim s As String = mb.StringValue(0, size)
		  RaiseEvent DebugMessage(info, s)
		  Return size
		End Function
	#tag EndMethod

	#tag DelegateDeclaration, Flags = &h21
		Private Delegate Function cURLDebugCallback(Handle As Integer, info As curl_infotype, data As Ptr, size As Integer, UserData As Integer) As Integer
	#tag EndDelegateDeclaration

	#tag Method, Flags = &h21
		Private Function curlHeader(char As Ptr, size As Integer, nmemb As Integer) As Integer
		  // called by HeaderCallback
		  Dim sz As Integer = nmemb * size
		  Dim data As MemoryBlock = char
		  Dim s As String = data.StringValue(0, sz)
		  RaiseEvent HeaderReceived(s)
		  Return sz
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function curlOpen(SocketType As Integer, Socket As Ptr) As Ptr
		  // called by OpenCallback
		  #pragma Warning "Fix Me"
		  Dim p As Ptr = RaiseEvent CreateSocket(SocketType, Socket)
		  Return p
		End Function
	#tag EndMethod

	#tag DelegateDeclaration, Flags = &h21
		Private Delegate Function cURLOpenCallback(UserData As Integer, SocketType As Integer, Socket As Ptr) As Ptr
	#tag EndDelegateDeclaration

	#tag Method, Flags = &h21
		Private Function curlProgress(dlTotal As UInt64, dlnow As UInt64, ultotal As UInt64, ulnow As UInt64) As Integer
		  // called by ProgressCallback
		  Return RaiseEvent Progress(dlTotal, dlnow, ultotal, ulnow)
		End Function
	#tag EndMethod

	#tag DelegateDeclaration, Flags = &h21
		Private Delegate Function cURLProgressCallback(UserData As Integer, dlTotal As UInt64, dlnow As UInt64, ultotal As UInt64, ulnow As UInt64) As Integer
	#tag EndDelegateDeclaration

	#tag Method, Flags = &h21
		Private Function curlRead(char As Ptr, size As Integer, nmemb As Integer) As Integer
		  // called by ReadCallback
		  Dim sz As Integer = nmemb * size
		  Dim data As String = RaiseEvent DataNeeded(sz)
		  If data.LenB <= sz Then
		    Dim mb As MemoryBlock = char
		    mb.StringValue(0, sz) = LeftB(data, sz)
		    Return data.LenB
		  End If
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function curlSSLInit(SSLCTX As Ptr) As Integer
		  // called by InitSSLCallback
		  Return RaiseEvent SSLInit(SSLCTX)
		End Function
	#tag EndMethod

	#tag DelegateDeclaration, Flags = &h21
		Private Delegate Function cURLSSLInitCallback(Handle As Integer, SSLCTXStruct As Ptr, UserData As Integer) As Integer
	#tag EndDelegateDeclaration

	#tag Method, Flags = &h21
		Private Function curlWrite(char As Ptr, size As Integer, nmemb As Integer) As Integer
		  // called by WriteCallback
		  ' data available
		  Dim mb As MemoryBlock = char
		  Dim s As String = mb.StringValue(0, nmemb * size)
		  RaiseEvent DataAvailable(s)
		  Return nmemb * size
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Shared Function DebugCallback(Handle As Integer, info As curl_infotype, data As Ptr, size As Integer, UserData As Integer) As Integer
		  #pragma Unused Handle ' handle is the cURL handle of the instance
		  Dim curl As WeakRef = Instances.Lookup(UserData, Nil)
		  If curl <> Nil Then
		    Return cURLItem(curl.Value).curlDebug(info, data, size)
		  End If
		  
		  Break ' UserData does not refer to a valid instance!
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Sub Destructor()
		  Me.Close()
		  Instances.Remove(mHandle)
		  If Instances.Count = 0 Then
		    curl_global_cleanup()
		    Instances = Nil
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Sub GetInfo(InfoType As Integer, Buffer As Ptr)
		  If Not libcURL.IsAvailable Then Return
		  mLastError = curl_easy_getinfo(Me.Handle, InfoType, Buffer)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Handle() As Integer
		  Return mHandle
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Shared Function HeaderCallback(char As Ptr, size As Integer, nmemb As Integer, UserData As Integer) As Integer
		  Dim curl As WeakRef = Instances.Lookup(UserData, Nil)
		  If curl <> Nil Then
		    Return cURLItem(curl.Value).curlHeader(char, size, nmemb)
		  End If
		  
		  Break ' UserData does not refer to a valid instance!
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Shared Sub InitCallbacks(Sender As libcURL.cURLItem)
		  'If Not Sender.SetOption(libcURL.Opts.OPENSOCKETDATA, Sender.Handle) Then Raise cURLException(Sender.LastError)
		  'If Not Sender.SetOption(libcURL.Opts.OPENSOCKETFUNCTION, AddressOf OpenCallback) Then Raise cURLException(Sender.LastError)
		  
		  'If Not Sender.SetOption(libcURL.Opts.SSL_CTX_DATA, Sender.Handle) Then Raise cURLException(Sender.LastError)
		  'If Not Sender.SetOption(libcURL.Opts.SSL_CTX_FUNCTION, AddressOf SSLInitCallback) Then Raise cURLException(Sender.LastError)
		  
		  If Not Sender.SetOption(libcURL.Opts.CLOSESOCKETDATA, Sender.Handle) Then Raise cURLException(Sender.LastError)
		  If Not Sender.SetOption(libcURL.Opts.CLOSESOCKETFUNCTION, AddressOf CloseCallback) Then Raise cURLException(Sender.LastError)
		  
		  If Not Sender.SetOption(libcURL.Opts.WRITEDATA, Sender.Handle) Then Raise cURLException(Sender.LastError)
		  If Not Sender.SetOption(libcURL.Opts.WRITEFUNCTION, AddressOf WriteCallback) Then Raise cURLException(Sender.LastError)
		  
		  If Not Sender.SetOption(libcURL.Opts.READDATA, Sender.Handle) Then Raise cURLException(Sender.LastError)
		  If Not Sender.SetOption(libcURL.Opts.READFUNCTION, AddressOf ReadCallback) Then Raise cURLException(Sender.LastError)
		  
		  If Not Sender.SetOption(libcURL.Opts.NOPROGRESS, False) Then Raise cURLException(Sender.LastError)
		  If Not Sender.SetOption(libcURL.Opts.PROGRESSDATA, Sender.Handle) Then Raise cURLException(Sender.LastError)
		  If Not Sender.SetOption(libcURL.Opts.PROGRESSFUNCTION, AddressOf ProgressCallback) Then Raise cURLException(Sender.LastError)
		  
		  If Not Sender.SetOption(libcURL.Opts.HEADERDATA, Sender.Handle) Then Raise cURLException(Sender.LastError)
		  If Not Sender.SetOption(libcURL.Opts.HEADERFUNCTION, AddressOf HeaderCallback) Then Raise cURLException(Sender.LastError)
		  
		  #If DebugBuild Then
		    If Not Sender.SetOption(libcURL.Opts.VERBOSE, True) Then Raise cURLException(Sender.LastError)
		    If Not Sender.SetOption(libcURL.Opts.DEBUGDATA, Sender.Handle) Then Raise cURLException(Sender.LastError)
		    If Not Sender.SetOption(libcURL.Opts.DEBUGFUNCTION, AddressOf DebugCallback) Then Raise cURLException(Sender.LastError)
		  #endif
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function LastError() As Integer
		  Return mLastError
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Shared Function OpenCallback(UserData As Ptr, SocketType As Integer, Socket As Ptr) As Ptr
		  Dim curl As WeakRef = Instances.Lookup(UserData, Nil)
		  If curl = Nil Then Return Nil
		  Return cURLItem(curl.Value).curlOpen(SocketType, Socket)
		  
		  Break ' UserData does not refer to a valid instance!
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Pause(PauseUpload As Boolean = True, PauseDownload As Boolean = True) As Boolean
		  If Not libcURL.IsAvailable Then Return False
		  Dim pU, pD As Integer
		  pU = ShiftLeft(1, 2)
		  pD = ShiftLeft(0, 1)
		  
		  Dim mask As Integer
		  If PauseUpload And PauseDownload Then
		    mask = pU Or pD
		  ElseIf PauseUpload Xor PauseDownload Then
		    If PauseUpload Then
		      mask = pU
		    Else
		      mask = pD
		    End If
		  End If
		  
		  mLastError = curl_easy_pause(Me.Handle, mask)
		  Return Me.LastError = 0
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Perform(URL As String = "") As Boolean
		  If Not libcURL.IsAvailable Then Return False
		  If URL <> "" Then
		    If Not SetOption(libcURL.Opts.URL, URL) Then Raise cURLException(Me.LastError)
		  End If
		  mLastError = curl_easy_perform(Me.Handle)
		  Return Me.LastError = 0
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Shared Function ProgressCallback(UserData As Integer, dlTotal As UInt64, dlnow As UInt64, ultotal As UInt64, ulnow As UInt64) As Integer
		  Dim curl As WeakRef = Instances.Lookup(UserData, Nil)
		  If curl <> Nil Then
		    Return cURLItem(curl.Value).curlProgress(dlTotal, dlnow, ultotal, ulnow)
		  End If
		  
		  Break ' UserData does not refer to a valid instance!
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function Read(Count As Integer, encoding As TextEncoding = Nil) As String
		  Dim mb As New MemoryBlock(Count)
		  Dim i As Integer
		  mLastError = curl_easy_recv(Me.Handle, mb, mb.Size, i)
		  If Me.LastError = 0 Then
		    Dim s As String
		    If encoding <> Nil Then
		      s = DefineEncoding(mb.StringValue(0, i), encoding)
		    Else
		      s = mb.StringValue(0, i)
		    End If
		    Return s
		  End If
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Shared Function ReadCallback(char As Ptr, size As Integer, nmemb As Integer, UserData As Integer) As Integer
		  // called when data is needed
		  Dim curl As WeakRef = Instances.Lookup(UserData, Nil)
		  If curl <> Nil Then
		    Return cURLItem(curl.Value).curlRead(char, size, nmemb)
		  End If
		  
		  Break ' UserData does not refer to a valid instance!
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Reset()
		  If Not libcURL.IsAvailable Then Return
		  curl_easy_reset(Me.Handle)
		  InitCallbacks(Me)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function SetOption(OptionNumber As Integer, NewValue As Variant) As Boolean
		  // This method marshals the NewValue into a Ptr then calls curl_easy-setopt
		  
		  If Not libcURL.IsAvailable Then Return False
		  Dim mb As MemoryBlock
		  Dim ValueType As Integer = VarType(NewValue)
		  Select Case ValueType
		  Case Variant.TypeNil
		    Raise New NilObjectException
		    
		  Case Variant.TypeBoolean
		    mb = New MemoryBlock(1)
		    mb.BooleanValue(0) = NewValue.BooleanValue
		    
		  Case Variant.TypePtr, Variant.TypeInteger
		    mb = NewValue.PtrValue
		    
		  Case Variant.TypeString
		    mb = NewValue.StringValue + Chr(0)
		    
		  Case Variant.TypeObject
		    Select Case NewValue
		    Case IsA MemoryBlock
		      mb = NewValue.PtrValue
		      
		    Case IsA cURLProgressCallback
		      Dim p As cURLProgressCallback = NewValue
		      mb = p
		      
		    Case IsA cURLCallback
		      Dim p As cURLCallback = NewValue
		      mb = p
		      
		    Case IsA cURLDebugCallback
		      Dim p As cURLDebugCallback = NewValue
		      mb = p
		      
		    Case IsA cURLCloseCallback
		      Dim p As cURLCloseCallback = NewValue
		      mb = p
		      
		    Case IsA cURLOpenCallback
		      Dim p As cURLOpenCallback = NewValue
		      mb = p
		      
		    Case IsA cURLSSLInitCallback
		      Dim p As cURLSSLInitCallback = NewValue
		      mb = p
		      
		    Else
		      Dim err As New TypeMismatchException
		      err.Message = "NewValue is of unsupported type: " + Introspection.GetType(NewValue).Name
		      Raise err
		      
		    End Select
		    
		  Else
		    Dim err As New TypeMismatchException
		    err.Message = "NewValue is of unsupported vartype: " + Str(ValueType)
		    Raise err
		  End Select
		  
		  mLastError = curl_easy_setopt(Me.Handle, OptionNumber, mb)
		  Return mLastError = 0
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Shared Function SSLInitCallback(Handle As Integer, SSLCTXStruct As Ptr, UserData As Integer) As Integer
		  #pragma Unused Handle ' Handle is the handle to the instance
		  Dim curl As WeakRef = Instances.Lookup(UserData, Nil)
		  If curl = Nil Then
		    Break ' UserData does not refer to a valid instance!
		    Return 1
		  End If
		  Return cURLItem(curl.Value).curlSSLInit(SSLCTXStruct)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function Write(Text As String) As Integer
		  Dim byteswritten As Integer
		  Dim mb As MemoryBlock = Text
		  mLastError = curl_easy_send(Me.Handle, mb, mb.Size, byteswritten)
		  If mLastError = 0 Then Return byteswritten
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Shared Function WriteCallback(char As Ptr, size As Integer, nmemb As Integer, UserData As Integer) As Integer
		  // Called when data is available
		  Dim curl As WeakRef = Instances.Lookup(UserData, Nil)
		  If curl <> Nil Then
		    Return cURLItem(curl.Value).curlWrite(char, size, nmemb)
		  End If
		  
		  Break ' UserData does not refer to a valid instance!
		End Function
	#tag EndMethod


	#tag Hook, Flags = &h0
		Event CreateSocket(SocketType As Integer, Address As Ptr) As Ptr
	#tag EndHook

	#tag Hook, Flags = &h0
		Event DataAvailable(NewData As String)
	#tag EndHook

	#tag Hook, Flags = &h0
		Event DataNeeded(MaximumLen As Integer) As String
	#tag EndHook

	#tag Hook, Flags = &h0
		Event DebugMessage(MessageType As libcURL.curl_infotype, data As String)
	#tag EndHook

	#tag Hook, Flags = &h0
		Event Disconnected()
	#tag EndHook

	#tag Hook, Flags = &h0
		Event HeaderReceived(HeaderLine As String)
	#tag EndHook

	#tag Hook, Flags = &h0
		Event Progress(dlTotal As UInt64, dlnow As UInt64, ultotal As UInt64, ulnow As UInt64) As Integer
	#tag EndHook

	#tag Hook, Flags = &h0
		Event SSLInit(SSLCTX As Ptr) As Integer
	#tag EndHook


	#tag Note, Name = Using this class
		This class provides basic access to the curl_easy API.
		
		Create a new instance, then use the SetOption method to define what cURL will be doing.
		
		For example, setting the user-agent string:
		
		   Dim mcURL As New libcURL.cURLItem
		   If Not mcURL.SetOption(libcURL.Opts.USERAGENT, "Bob's download manager/5.1") Then
		      MsgBox("cURL error: " + Str(mcURL.LastError))
		   End If
		
		SetOption accepts a Variant as the option value, but only Integers, Strings, and Booleans should be
		used. SetOption will also accept the cURL delegates as new values but that is intended for internal use
		only. Setting an option value to an unsupported type will raise a TypeMismatchException.
	#tag EndNote


	#tag Property, Flags = &h21
		Private Shared Instances As Dictionary
	#tag EndProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  //The IP address of the local connection used for the transfer
			  //Note: this is usually NOT the client's public IP
			  Dim p As Ptr
			  Me.GetInfo(INFO_LOCAL_IP, p)
			  If Me.LastError = 0 Then
			    Dim buffer As MemoryBlock = p.Ptr(0)
			    Return buffer.CString(0)
			  End If
			End Get
		#tag EndGetter
		LocalIP As String
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  //The local port used to make the connection. This is decided upon by libcurl and the OS's network stack
			  Dim mb As New MemoryBlock(4)
			  Me.GetInfo(INFO_LOCAL_PORT, mb)
			  If Me.LastError = 0 Then
			    Return mb.Int32Value(0)
			  End If
			End Get
		#tag EndGetter
		LocalPort As Integer
	#tag EndComputedProperty

	#tag Property, Flags = &h1
		Protected mHandle As Integer
	#tag EndProperty

	#tag Property, Flags = &h1
		Protected mLastError As Integer
	#tag EndProperty

	#tag ComputedProperty, Flags = &h0
		#tag Setter
			Set
			  //If the server will require a password, set it here. If the server doesn't require one, this property is ignored
			  Call Me.SetOption(libcURL.Opts.PASSWORD, value)
			End Set
		#tag EndSetter
		Password As String
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  //Remote port
			  Dim mb As New MemoryBlock(4)
			  Me.GetInfo(INFO_PRIMARY_PORT, mb)
			  If Me.LastError = 0 Then
			    Return mb.Int32Value(0)
			  End If
			End Get
		#tag EndGetter
		#tag Setter
			Set
			  //remote port.
			  Call Me.SetOption(libcURL.Opts.PORT, value)
			End Set
		#tag EndSetter
		Port As Integer
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  //The IP address of the remote server
			  Dim mb As New MemoryBlock(4)
			  Me.GetInfo(INFO_PRIMARY_IP, mb)
			  If Me.LastError = 0 Then
			    Dim buffer As MemoryBlock = mb.Ptr(0)
			    Return buffer.CString(0)
			  End If
			End Get
		#tag EndGetter
		RemoteIP As String
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  Dim p As Ptr
			  Me.GetInfo(INFO_EFFECTIVE_URL, p)
			  If p = Nil Then Return ""
			  Dim mb As MemoryBlock = p.Ptr(0)
			  If Me.LastError = 0 Then
			    Return mb.CString(0)
			  End If
			End Get
		#tag EndGetter
		#tag Setter
			Set
			  If Not SetOption(libcURL.Opts.URL, value) Then Raise cURLException(Me.LastError)
			End Set
		#tag EndSetter
		URL As String
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0
		#tag Setter
			Set
			  //Set your application's UserAgent string. The default will be the output of cURLversion()
			  Call Me.SetOption(libcURL.Opts.USERAGENT, value)
			End Set
		#tag EndSetter
		UserAgent As String
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0
		#tag Setter
			Set
			  //If the server will require a username, set it here. If the server doesn't require one, this property is ignored
			  Call Me.SetOption(libcURL.Opts.USERNAME, value)
			End Set
		#tag EndSetter
		Username As String
	#tag EndComputedProperty


	#tag Constant, Name = CURL_GLOBAL_ALL, Type = Double, Dynamic = False, Default = \"3", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = CURL_GLOBAL_SSL, Type = Double, Dynamic = False, Default = \"1", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = CURL_GLOBAL_WIN32, Type = Double, Dynamic = False, Default = \"2", Scope = Protected
	#tag EndConstant


	#tag ViewBehavior
		#tag ViewProperty
			Name="Index"
			Visible=true
			Group="ID"
			InitialValue="-2147483648"
			Type="Integer"
			InheritedFrom="Object"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Left"
			Visible=true
			Group="Position"
			InitialValue="0"
			InheritedFrom="Object"
		#tag EndViewProperty
		#tag ViewProperty
			Name="LocalIP"
			Group="Behavior"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="LocalPort"
			Group="Behavior"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Name"
			Visible=true
			Group="ID"
			InheritedFrom="Object"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Password"
			Group="Behavior"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Port"
			Group="Behavior"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="RemoteIP"
			Group="Behavior"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Super"
			Visible=true
			Group="ID"
			InheritedFrom="Object"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Top"
			Visible=true
			Group="Position"
			InitialValue="0"
			InheritedFrom="Object"
		#tag EndViewProperty
		#tag ViewProperty
			Name="URL"
			Group="Behavior"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="UserAgent"
			Group="Behavior"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Username"
			Group="Behavior"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass