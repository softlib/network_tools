unit uGetAdapterInfo;

interface

uses

  Windows, SysUtils, Classes, dialogs;

const
  NCF_VIRTUAL = $01; // 说明组件是个虚拟适配器
  NCF_SOFTWARE_ENUMERATED = $02; // 说明组件是一个软件模拟的适配器
  NCF_PHYSICAL = $04; // 说明组件是一个物理适配器
  NCF_HIDDEN = $08; // 说明组件不显示用户接口
  NCF_NO_SERVICE = $10; // 说明组件没有相关的服务(设备驱动程序)
  NCF_NOT_USER_REMOVABLE = $20; // 说明不能被用户删除(例如，通过控制面板或设备管理器)
  NCF_MULTIPORT_INSTANCED_ADAPTER = $40; // 说明组件有多个端口，每个端 口作为单独的设备安装。
  // 每个 端口有自己的hw_id(组件ID) 并可被单独安装，
  // 这只适合于 EISA适配器
  NCF_HAS_UI = $80; // 说明组件支持用户接口(例如，Advanced Page或Customer  Properties Sheet)
  NCF_FILTER = $400; // 说明组件是一个过滤器

const
  MAX_INTERFACE_NAME_LEN = 256;
  MAXLEN_PHYSADDR = 8;
  MAXLEN_IFDESCR = 256;
  MIB_IF_TYPE_OTHER = 1;
  MIB_IF_TYPE_ETHERNET = 6;
  MIB_IF_TYPE_TOKENRING = 9;
  MIB_IF_TYPE_FDDI = 15;
  MIB_IF_TYPE_PPP = 23;
  MIB_IF_TYPE_LOOPBACK = 24;
  MIB_IF_TYPE_SLIP = 28;
  MIB_IF_ADMIN_STATUS_UP = 1;
  MIB_IF_ADMIN_STATUS_DOWN = 2;
  MIB_IF_ADMIN_STATUS_TESTING = 3;
  MIB_IF_OPER_STATUS_NON_OPERATIONAL = 0;
  MIB_IF_OPER_STATUS_UNREACHABLE = 1;
  MIB_IF_OPER_STATUS_DISCONNECTED = 2;
  MIB_IF_OPER_STATUS_CONNECTING = 3;
  MIB_IF_OPER_STATUS_CONNECTED = 4;
  MIB_IF_OPER_STATUS_OPERATIONAL = 5;

const

  MAX_HOSTNAME_LEN = 128; { from IPTYPES.H }

  MAX_DOMAIN_NAME_LEN = 128;

  MAX_SCOPE_ID_LEN = 256;

  MAX_ADAPTER_NAME_LENGTH = 256;

  MAX_ADAPTER_DESCRIPTION_LENGTH = 128;

  MAX_ADAPTER_ADDRESS_LENGTH = 8;

type

  TIPAddressString = array [0 .. 4 * 4 - 1] of AnsiChar;

  PIPAddrString = ^TIPAddrString;

  TIPAddrString = record

    Next: PIPAddrString;

    IPAddress: TIPAddressString;

    IPMask: TIPAddressString;

    Context: Integer;

  end;

  PFixedInfo = ^TFixedInfo;

  TFixedInfo = record { FIXED_INFO }

    HostName: array [0 .. MAX_HOSTNAME_LEN + 3] of AnsiChar;

    DomainName: array [0 .. MAX_DOMAIN_NAME_LEN + 3] of AnsiChar;

    CurrentDNSServer: PIPAddrString;

    DNSServerList: TIPAddrString;

    NodeType: Integer;

    ScopeId: array [0 .. MAX_SCOPE_ID_LEN + 3] of AnsiChar;

    EnableRouting: Integer;

    EnableProxy: Integer;

    EnableDNS: Integer;

  end;

  PIPAdapterInfo = ^TIPAdapterInfo;

  TIPAdapterInfo = record { IP_ADAPTER_INFO }

    Next: PIPAdapterInfo;

    ComboIndex: Integer;

    AdapterName: array [0 .. MAX_ADAPTER_NAME_LENGTH + 3] of AnsiChar;

    Description: array [0 .. MAX_ADAPTER_DESCRIPTION_LENGTH + 3] of AnsiChar;

    AddressLength: Integer;

    Address: array [1 .. MAX_ADAPTER_ADDRESS_LENGTH] of Byte;

    Index: Integer;

    _Type: Integer; // 网卡类型

    DHCPEnabled: Integer;

    CurrentIPAddress: PIPAddrString;

    IPAddressList: TIPAddrString;

    GatewayList: TIPAddrString;

    DHCPServer: TIPAddrString;

    HaveWINS: Bool;

    PrimaryWINSServer: TIPAddrString;

    SecondaryWINSServer: TIPAddrString;

    LeaseObtained: Integer;

    LeaseExpires: Integer;

  end;

  TAdapterInfo = class(TObject)

    Index: Integer; // 序号(即该网卡接口的索引值，多网卡时有用）

    AdapterType: string; // 网卡接口的类型

    AdapterName: string; // 网卡名

    AdapterGUID: string; // 网卡GUID

    IPAddress: string; // IP地址

    Subnetmask: string; // 子网掩码

    Gateway: string; // 网关

    MacAddress: string; // MAC地址

    DHCP: Boolean; // 是否是自动分配

    DHCPServer: string; // DHCP服务器地址

  end;

  // 发送一个arp请求，获得一个物理地址所对应的IP地址
function SendARP(ipaddr: ulong; temp: dword; ulmacaddr: pointer;
  ulmacaddrleng: pointer): dword; StdCall;

// 核心方法
function GetAdapterInfo: TList;

function GetAdapterTypeString(const dwType: dword): string;

// 判断当前网卡是物理网卡（有线网卡，无线网卡）还是虚拟网卡
{
  MAC地址作为硬件唯一标识，在很多时候会被使用，如在软件授权方面，很多软件在产生机器码时会采用CPUID或MAC地址，或使用MAC地址来做一对一绑定。
  相信很多人会碰到以下问题：
  1）获取的是VMWare的网卡MAC地址
  2）获取的是VPN的网卡MAC地址

  VMWare或VPN软件的安装卸载都会导致获取的MAC地址变化，所以我们需要正确获取当前物理网卡的MAC地址。
}
function IsPhysicalAdapter(sAdapterGUID: string;
  bOnlyPCI: Boolean = False): Boolean;

function GetMacAddress(): string;

function GetLocalIP: string;

function GetPrimaryIPv4: string;

var

  AI, Work: PIPAdapterInfo;

  Size: Integer;

  Res: Integer;

  I: Integer;

implementation

uses Registry, winsock

 {$IFDEF MSWINDOWS}
//, Winapi.Windows
, Winapi.Winsock2
, Winapi.IpHlpApi
, Winapi.IpTypes
  {$ENDIF};

function SendARP; external 'Iphlpapi.dll' Name 'SendARP';
function GetAdaptersInfo(AI: PIPAdapterInfo; var BufLen: Integer): Integer; stdcall; external 'iphlpapi.dll' Name 'GetAdaptersInfo';
function GetAdaptersAddresses():Integer; stdcall; external 'iphlpapi.dll' Name 'GetAdaptersAddresses';

function GetAdapterTypeString(const dwType: dword): string;
begin
  case dwType of
    MIB_IF_TYPE_OTHER:
      Result := '其他';
    MIB_IF_TYPE_ETHERNET:
      Result := '以太网';
    MIB_IF_TYPE_TOKENRING:
      Result := '令牌环';
    MIB_IF_TYPE_FDDI:
      Result := 'FDDI';
    MIB_IF_TYPE_PPP:
      Result := 'PPP';
    MIB_IF_TYPE_LOOPBACK:
      Result := '回路';
    MIB_IF_TYPE_SLIP:
      Result := 'SLIP';
  end;

end;

function IsPhysicalAdapter(sAdapterGUID: string;
  bOnlyPCI: Boolean = False): Boolean;
const
  NET_CARD_KEY_PATH =
    'SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}';
var
  Reg: TRegistry;
  sList: TStrings;
  vCharacteristics: dword;
  I: Integer;
begin
  Result := False;
  sList := TStringList.Create;
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    if not Reg.OpenKey(NET_CARD_KEY_PATH, False) then
      Exit;
    Reg.GetKeyNames(sList);
    Reg.CloseKey;
    if sList.Count > 0 then
      for I := 0 to Pred(sList.Count) do
        if Reg.OpenKey(NET_CARD_KEY_PATH + '\' + sList.Strings[I], False) then
        begin
          try
            // showmessage('NetCfgInstanceId='+Reg.ReadString('NetCfgInstanceId'));
            // if sAdapterGUID.ToUpper.Trim.Equals(Reg.ReadString('NetCfgInstanceId').ToUpper.Trim) then
            if sAdapterGUID = Reg.ReadString('NetCfgInstanceId') then

            begin
              vCharacteristics := dword(Reg.ReadInteger('Characteristics'));
              Result := (NCF_PHYSICAL and vCharacteristics) = NCF_PHYSICAL;
              Break;
            end;
          finally
            Reg.CloseKey;
          end;
        end;
  finally
    Reg.Free;
    sList.Free;
  end;
end;

function GetMacAddress(): string;
var
  dwRet: Integer;
  AI, Work: PIPAdapterInfo;
  sGUID, sTmp, sLastMAC, sFirstMAC: string;
  I: Integer;
  uSize: Integer;
begin
  Result := '';
  sLastMAC := '';
  sFirstMAC := '';
  uSize := SizeOf(TIPAdapterInfo);
  GetMem(AI, uSize);
  dwRet := GetAdaptersInfo(AI, uSize);
  if (dwRet = ERROR_BUFFER_OVERFLOW) then
  begin
    FreeMem(AI);
    GetMem(AI, uSize);
    dwRet := GetAdaptersInfo(AI, uSize);
  end;

  try
    if (dwRet <> ERROR_SUCCESS) then
      Exit;
    Work := AI;
    while Work <> nil do
    begin
      try
        sGUID := string(AnsiString(Work.AdapterName));
        sTmp := string(AnsiString(Work.Description));
        // 名称描述出现VMWare，直接忽略
        if Pos('VMWare', sTmp) > 0 then
          Continue;

        if Pos('usb', lowercase(sTmp)) > 0 then
          Continue;

        // 配置的ID地址不正常，忽略
        if Work.AddressLength = 0 then
          Continue;

        // 将网卡MAC地址转成字符串
        sLastMAC := '';
        for I := 0 to Work.AddressLength - 1 do
        begin
          sLastMAC := sLastMAC + Format('%.2x', [Work.Address[I]]);
        end;

        if sFirstMAC = '' then
          sFirstMAC := sLastMAC;

        // 不是物理网卡，忽略
        if not IsPhysicalAdapter(sGUID) then
          Continue;

        Result := sLastMAC;

        // 找到第一个物理网卡后退出
        Break;
      finally
        Work := Work.Next;
      end;
    end;
    // 找不到物理网卡MAC，返回第一个即可
    if Result = '' then
      Result := sFirstMAC;
  finally
    FreeMem(AI);
  end;
end;

function GetLocalIP: string;
type
  TaPInAddr = array [0 .. 10] of PInAddr;
  PaPInAddr = ^TaPInAddr;
var
  phe: PHostEnt;
  pptr: PaPInAddr;
  Buffer: array [0 .. 63] of Ansichar;
  I: Integer;
  GInitData: TWSADATA;
begin // winsock
  // 取得了 360无线上网的网卡IP（172.27.35.1）

  WSAStartup($101, GInitData);
  Result := '';
  GetHostName(Buffer, SizeOf(Buffer));
  phe := GetHostByName(Buffer);
  if phe = nil then
    Exit;
  pptr := PaPInAddr(phe^.h_addr_list);
  I := 0;
  while pptr^[I] <> nil do
  begin
    Result := StrPas(inet_ntoa(pptr^[I]^));
    Inc(I);
  end;
  WSACleanup;
end;

function MACToStr(ByteArr: PByte; Len: Integer): string;

begin

  Result := '';

  while (Len > 0) do

  begin

    Result := Result + IntToHex(ByteArr^, 2) + '-';

    ByteArr := pointer(Integer(ByteArr) + SizeOf(Byte));

    Dec(Len);

  end;

  SetLength(Result, Length(Result) - 1); { remove last dash }

end;

function GetAddrString(Addr: PIPAddrString): string;

begin

  Result := '';

  while (Addr <> nil) do

  begin

    Result := Result + 'A: ' + Addr^.IPAddress + ' M: ' + Addr^.IPMask + #13;

    Addr := Addr^.Next;

  end;

end;

function TimeTToDateTimeStr(TimeT: Integer): string;

const

  UnixDateDelta = 25569; { days between12/31/1899and 1/1/1970 }

var

  DT: TDateTime;

  TZ: TTimeZoneInformation;

  Res: dword;

begin

  if (TimeT = 0) then

    Result := ''

  else

  begin

    { Unix TIME_T is secs since1/1/1970 }

    DT := UnixDateDelta + (TimeT / (24 * 60 * 60)); { in UTC }

    { calculate bias }

    Res := GetTimeZoneInformation(TZ);

    if (Res = TIME_ZONE_ID_INVALID) then

      RaiseLastWin32Error;

    if (Res = TIME_ZONE_ID_STANDARD) then

    begin

      DT := DT - ((TZ.Bias + TZ.StandardBias) / (24 * 60));

      Result := DateTimeToStr(DT) + ' ' + WideCharToString(TZ.StandardName);

    end

    else

    begin { daylight saving time }

      DT := DT - ((TZ.Bias + TZ.DaylightBias) / (24 * 60));

      Result := DateTimeToStr(DT) + ' ' + WideCharToString(TZ.DaylightName);

    end;
  end;
end;

function ParseSubnetMask(const AText: string): string;
var
  lst: TStrings;
  I: Integer;
  sline: string;
begin
  lst := TStringList.Create;
  Result := '';
  try
    lst.Text := Trim(AText);
    for I := 0 to lst.Count - 1 do
    begin
      sline := lst[I];
      // if pos('A: 19',sline)>0 then //这里假定 19开头的IP为本机内网网卡地址（注意！！）

      begin
        Exit(Copy(sline, Pos(' M: ', sline) + 4, Length(sline)));
      end;
    end; // for i end
  finally
    FreeAndNil(lst);
  end;
end;

function GetAdapterInfo: TList;
var
  AAdapterInfo: TAdapterInfo;
  AAdapterInfos: TList;
begin
  Size := 5120;
  GetMem(AI, Size);
  Res := GetAdaptersInfo(AI, Size);
  if (Res <> ERROR_SUCCESS) then
  begin
    SetLastError(Res);
    RaiseLastWin32Error;
  end;

  Work := AI;

  I := 1;

  AAdapterInfos := TList.Create;

  repeat

    AAdapterInfo := TAdapterInfo.Create;

    AAdapterInfo.Index := I;

    AAdapterInfo.AdapterName := Work^.Description;
    AAdapterInfo.AdapterGUID := string(Ansistring( Work^.AdapterName));

   // ShowMessage(AAdapterInfo.AdapterGUID);

    AAdapterInfo.AdapterType := GetAdapterTypeString(Work^._Type);

   // ShowMessage(GetAddrString(@Work^.IPAddressList));

    AAdapterInfo.IPAddress := Copy(GetAddrString(@Work^.IPAddressList),
      Pos('A: ', GetAddrString(@Work^.IPAddressList)) + 3, Pos(' M: ',
      GetAddrString(@Work^.IPAddressList)) - Pos('A: ',
      GetAddrString(@Work^.IPAddressList)) - 3);

   //  ShowMessage(GetAddrString(@Work^.IPAddressList));

    //ShowMessage('GatewayList='+GetAddrString(@Work^.GatewayList));

    AAdapterInfo.Subnetmask :=
      ParseSubnetMask(GetAddrString(@Work^.IPAddressList));


    AAdapterInfo.Gateway := Copy(GetAddrString(@Work^.GatewayList), Pos('A: ',

      GetAddrString(@Work^.GatewayList)) + 3, Pos(' M: ',

      GetAddrString(@Work^.GatewayList)) - Pos('A: ',

      GetAddrString(@Work^.GatewayList)) - 3);

    AAdapterInfo.MacAddress := MACToStr(@Work^.Address, Work^.AddressLength);

    AAdapterInfo.DHCP := Work^.DHCPEnabled > 0;

   { if Not AAdapterInfo.DHCP then
    ShowMessage('DHCPServer='+GetAddrString(@Work^.DHCPServer));
   }

    AAdapterInfo.DHCPServer := Copy(GetAddrString(@Work^.DHCPServer), Pos('A: ',

      GetAddrString(@Work^.DHCPServer)) + 3, Pos(' M: ',

      GetAddrString(@Work^.DHCPServer)) - Pos('A: ',

      GetAddrString(@Work^.DHCPServer)) - 3);

    AAdapterInfos.Add(AAdapterInfo);



    Inc(I);

    Work := Work^.Next;

  until (Work = nil);

  Result := AAdapterInfos;

  FreeMem(AI);

end;

{}

function GetPrimaryIPv4: string;
{$IFDEF MSWINDOWS}
var
  LDestAddr: ULONG;
  LBestIfIndex: DWORD;
  LAdapterInfo, LpAdapter: PIP_ADAPTER_ADDRESSES;
  LOutBufLen: ULONG;
  LRetVal: ULONG;
  LpUnicast: PIP_ADAPTER_UNICAST_ADDRESS;
  LPSockAddrIn: PSockAddrIn;
 {$ENDIF}
{$IFDEF ANDROID}
var
  NetworkInterfaces: JEnumeration;
  NetIf: JNetworkInterface;
  AddrEnum: JEnumeration;
  InetAddr: JInetAddress;
{$ENDIF}
begin
  Result := '127.0.0.1'; // fallback

{$IFDEF MSWINDOWS}

  // remote target to determine the best interface
  LDestAddr := inet_addr(PAnsiChar(AnsiString('8.8.8.8')));

  if GetBestInterface(LDestAddr, LBestIfIndex) <> NO_ERROR then
    Exit;

  // first call to learn required buffer size
  LOutBufLen := 0;
  LRetVal := Winapi.IpHlpApi.GetAdaptersAddresses(AF_INET, 0, nil, nil, @LOutBufLen);
  if (LRetVal <> ERROR_BUFFER_OVERFLOW) and (LOutBufLen = 0) then
    Exit;

  GetMem(LAdapterInfo, LOutBufLen);
  try
    LRetVal := Winapi.IpHlpApi.GetAdaptersAddresses(AF_INET, 0, nil, LAdapterInfo, @LOutBufLen);
    if LRetVal = NO_ERROR then
    begin
      LpAdapter := LAdapterInfo;
      while LpAdapter <> nil do
      begin
        // NOTE: IfIndex is inside the Union field in this Delphi declaration
        if LpAdapter^.Union.IfIndex = LBestIfIndex then
        begin
          LpUnicast := LpAdapter^.FirstUnicastAddress;
          while LpUnicast <> nil do
          begin
            if (LpUnicast^.Address.lpSockaddr.sa_family = AF_INET) then
            begin
              LPSockAddrIn := PSockAddrIn(LpUnicast^.Address.lpSockaddr);
              Result := string(inet_ntoa(LPSockAddrIn^.sin_addr));
              Exit;
            end;
            LpUnicast := LpUnicast^.Next; // <-- you were missing this
          end;
        end;
        LpAdapter := LpAdapter^.Next;
      end;
    end;
  finally
    FreeMem(LAdapterInfo);
  end;
 {$ENDIF}
end;


end.
