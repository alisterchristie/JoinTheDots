unit uJoinTheDotsNetwork;

interface

uses
  System.Classes, System.Generics.Collections, System.SysUtils, System.SyncObjs,
  IdContext, IdException, IdGlobal, IdTCPClient, IdTCPServer, IdUDPClient, IdUDPServer,
  IdSocketHandle;

type
  TNetworkPeer = record
    Id: string;
    Name: string;
    Host: string;
    Port: Integer;
  end;

  TNetworkMessageEvent = procedure(Sender: TObject; const AMessage: string) of object;
  TNetworkStatusEvent = procedure(Sender: TObject; const AStatus: string) of object;

  TJoinTheDotsNetwork = class(TComponent)
  private const
    DiscoveryPort = 45321;
    FirstGamePort = 45322;
    LastGamePort = 45340;
    DiscoveryPrefix = 'JOINTHEDOTS';
  private
    FClient: TIdTCPClient;
    FCriticalSection: TCriticalSection;
    FHostPort: Integer;
    FInstanceId: string;
    FIsHosting: Boolean;
    FMessageQueue: TQueue<string>;
    FOnMessage: TNetworkMessageEvent;
    FOnStatus: TNetworkStatusEvent;
    FPeers: TList<TNetworkPeer>;
    FPlayerName: string;
    FServer: TIdTCPServer;
    FStatusQueue: TQueue<string>;
    FUDPClient: TIdUDPClient;
    FUDPServer: TIdUDPServer;
    function HasServerClient: Boolean;
    procedure BroadcastLoop;
    procedure EnqueueMessage(const AMessage: string);
    procedure EnqueueStatus(const AStatus: string);
    procedure TCPClientReadLoop;
    procedure TCPConnect(AContext: TIdContext);
    procedure TCPExecute(AContext: TIdContext);
    procedure UDPRead(AThread: TIdUDPListenerThread; const AData: TIdBytes; ABinding: TIdSocketHandle);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function FirstPeer(out APeer: TNetworkPeer): Boolean;
    function IsConnected: Boolean;
    procedure ConnectToPeer(const APeer: TNetworkPeer);
    procedure Disconnect;
    procedure PollEvents;
    procedure SendMessage(const AMessage: string);
    procedure StartDiscovery;
    procedure StartHosting;
    property HostPort: Integer read FHostPort;
    property IsHosting: Boolean read FIsHosting;
    property OnMessage: TNetworkMessageEvent read FOnMessage write FOnMessage;
    property OnStatus: TNetworkStatusEvent read FOnStatus write FOnStatus;
    property PlayerName: string read FPlayerName write FPlayerName;
  end;

implementation

constructor TJoinTheDotsNetwork.Create(AOwner: TComponent);
begin
  inherited;
  FInstanceId := TGUID.NewGuid.ToString;
  FPlayerName := 'Player';
  FPeers := TList<TNetworkPeer>.Create;
  FMessageQueue := TQueue<string>.Create;
  FStatusQueue := TQueue<string>.Create;
  FCriticalSection := TCriticalSection.Create;
  FHostPort := FirstGamePort;

  FUDPClient := TIdUDPClient.Create(Self);
  FUDPClient.BroadcastEnabled := True;

  FUDPServer := TIdUDPServer.Create(Self);
  FUDPServer.DefaultPort := DiscoveryPort;
  FUDPServer.OnUDPRead := UDPRead;

  FServer := TIdTCPServer.Create(Self);
  FServer.OnConnect := TCPConnect;
  FServer.OnExecute := TCPExecute;

  FClient := TIdTCPClient.Create(Self);
  FClient.Port := FirstGamePort;
  FClient.ReadTimeout := 250;
end;

destructor TJoinTheDotsNetwork.Destroy;
begin
  Disconnect;
  FCriticalSection.Free;
  FStatusQueue.Free;
  FMessageQueue.Free;
  FPeers.Free;
  inherited;
end;

procedure TJoinTheDotsNetwork.BroadcastLoop;
begin
  while FIsHosting do
  begin
    try
      FUDPClient.Broadcast(Format('%s|%s|%s|%d',
        [DiscoveryPrefix, FInstanceId, FPlayerName, FHostPort]), DiscoveryPort);
    except
      EnqueueStatus('LAN discovery broadcast failed');
    end;
    TThread.Sleep(1000);
  end;
end;

procedure TJoinTheDotsNetwork.ConnectToPeer(const APeer: TNetworkPeer);
begin
  Disconnect;
  FIsHosting := False;
  StartDiscovery;
  FClient.Host := APeer.Host;
  FClient.Port := APeer.Port;
  FClient.ConnectTimeout := 1500;
  FClient.Connect;
  EnqueueStatus('Connected to ' + APeer.Name);
  TThread.CreateAnonymousThread(TCPClientReadLoop).Start;
end;

procedure TJoinTheDotsNetwork.Disconnect;
begin
  FIsHosting := False;

  if FClient.Connected then
    FClient.Disconnect;

  if FServer.Active then
    FServer.Active := False;

  if FUDPServer.Active then
    FUDPServer.Active := False;
end;

procedure TJoinTheDotsNetwork.EnqueueMessage(const AMessage: string);
begin
  FCriticalSection.Enter;
  try
    FMessageQueue.Enqueue(AMessage);
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TJoinTheDotsNetwork.EnqueueStatus(const AStatus: string);
begin
  FCriticalSection.Enter;
  try
    FStatusQueue.Enqueue(AStatus);
  finally
    FCriticalSection.Leave;
  end;
end;

function TJoinTheDotsNetwork.FirstPeer(out APeer: TNetworkPeer): Boolean;
begin
  FCriticalSection.Enter;
  try
    Result := FPeers.Count > 0;
    if Result then
      APeer := FPeers[0];
  finally
    FCriticalSection.Leave;
  end;
end;

function TJoinTheDotsNetwork.HasServerClient: Boolean;
var
  ContextList: System.Classes.TList;
begin
  Result := False;
  if not FServer.Active or (FServer.Contexts = nil) then
    Exit;

  ContextList := FServer.Contexts.LockList;
  try
    Result := ContextList.Count > 0;
  finally
    FServer.Contexts.UnlockList;
  end;
end;

function TJoinTheDotsNetwork.IsConnected: Boolean;
begin
  Result := FClient.Connected or HasServerClient;
end;

procedure TJoinTheDotsNetwork.PollEvents;
var
  MessageText: string;
  StatusText: string;
begin
  repeat
    FCriticalSection.Enter;
    try
      if FStatusQueue.Count = 0 then
        StatusText := ''
      else
        StatusText := FStatusQueue.Dequeue;
    finally
      FCriticalSection.Leave;
    end;

    if (StatusText <> '') and Assigned(FOnStatus) then
      FOnStatus(Self, StatusText);
  until StatusText = '';

  repeat
    FCriticalSection.Enter;
    try
      if FMessageQueue.Count = 0 then
        MessageText := ''
      else
        MessageText := FMessageQueue.Dequeue;
    finally
      FCriticalSection.Leave;
    end;

    if (MessageText <> '') and Assigned(FOnMessage) then
      FOnMessage(Self, MessageText);
  until MessageText = '';
end;

procedure TJoinTheDotsNetwork.SendMessage(const AMessage: string);
var
  Context: TIdContext;
  ContextList: System.Classes.TList;
begin
  if FClient.Connected then
  begin
    FClient.IOHandler.WriteLn(AMessage, IndyTextEncoding_UTF8);
    Exit;
  end;

  if FServer.Active and (FServer.Contexts <> nil) then
  begin
    ContextList := FServer.Contexts.LockList;
    try
      if ContextList.Count > 0 then
      begin
        Context := TIdContext(ContextList[0]);
        Context.Connection.IOHandler.WriteLn(AMessage, IndyTextEncoding_UTF8);
      end;
    finally
      FServer.Contexts.UnlockList;
    end;
  end;
end;

procedure TJoinTheDotsNetwork.StartDiscovery;
begin
  if FUDPServer.Active then
    Exit;

  try
    FUDPServer.Active := True;
  except
    on E: Exception do
      EnqueueStatus('LAN discovery listen failed: ' + E.Message);
  end;
end;

procedure TJoinTheDotsNetwork.StartHosting;
var
  Port: Integer;
begin
  StartDiscovery;
  if FServer.Active then
  begin
    FIsHosting := True;
    Exit;
  end;

  for Port := FirstGamePort to LastGamePort do
  begin
    try
      FServer.DefaultPort := Port;
      FServer.Active := True;
      FHostPort := Port;
      FIsHosting := True;
      TThread.CreateAnonymousThread(BroadcastLoop).Start;
      EnqueueStatus(Format('Hosting LAN game on port %d', [FHostPort]));
      Exit;
    except
      on E: EIdException do
        FServer.Active := False;
    end;
  end;

  EnqueueStatus('Could not host: no local game port is available');
end;

procedure TJoinTheDotsNetwork.TCPClientReadLoop;
var
  MessageText: string;
begin
  while FClient.Connected do
  begin
    try
      MessageText := FClient.IOHandler.ReadLn(IndyTextEncoding_UTF8);
      if MessageText <> '' then
        EnqueueMessage(MessageText);
    except
      Break;
    end;
  end;
  EnqueueStatus('Disconnected');
end;

procedure TJoinTheDotsNetwork.TCPConnect(AContext: TIdContext);
begin
  EnqueueStatus('Peer connected');
  EnqueueMessage('PEER_CONNECTED');
end;

procedure TJoinTheDotsNetwork.TCPExecute(AContext: TIdContext);
var
  MessageText: string;
begin
  try
    MessageText := AContext.Connection.IOHandler.ReadLn(IndyTextEncoding_UTF8);
    if MessageText <> '' then
      EnqueueMessage(MessageText);
  except
    EnqueueStatus('Peer disconnected');
  end;
end;

procedure TJoinTheDotsNetwork.UDPRead(AThread: TIdUDPListenerThread; const AData: TIdBytes;
  ABinding: TIdSocketHandle);
var
  Parts: TArray<string>;
  Peer: TNetworkPeer;
  I: Integer;
  MessageText: string;
begin
  MessageText := IndyTextEncoding_UTF8.GetString(AData);
  Parts := MessageText.Split(['|']);
  if (Length(Parts) <> 4) or (Parts[0] <> DiscoveryPrefix) or (Parts[1] = FInstanceId) then
    Exit;

  Peer.Id := Parts[1];
  Peer.Name := Parts[2];
  Peer.Host := ABinding.PeerIP;
  Peer.Port := StrToIntDef(Parts[3], FirstGamePort);

  FCriticalSection.Enter;
  try
    for I := 0 to FPeers.Count - 1 do
      if FPeers[I].Id = Peer.Id then
        Exit;

    FPeers.Add(Peer);
  finally
    FCriticalSection.Leave;
  end;

  EnqueueStatus('Found ' + Peer.Name + ' at ' + Peer.Host);
end;

end.
