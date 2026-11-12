unit uGetAdapterInfo_V2;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes,
   //my_iphlpapi, my_ifdef,my_IPTypes,
   Winsock, Winapi.IpHlpApi, Winapi.IpRtrMib,
  Vcl.Menus, Vcl.ExtCtrls, Generics.Collections, Winapi.IpTypes,
   ShellAPI, Registry;

//========================================================
const
  GAA_FLAG_SKIP_UNICAST                = $0001;
  GAA_FLAG_SKIP_ANYCAST                = $0002;
  GAA_FLAG_SKIP_MULTICAST              = $0004;
  GAA_FLAG_SKIP_DNS_SERVER             = $0008;
  GAA_FLAG_INCLUDE_PREFIX              = $0010;
  GAA_FLAG_SKIP_FRIENDLY_NAME          = $0020;
  GAA_FLAG_INCLUDE_WINS_INFO           = $0040;
  GAA_FLAG_INCLUDE_GATEWAYS            = $0080;
  GAA_FLAG_INCLUDE_ALL_INTERFACES      = $0100;
  GAA_FLAG_INCLUDE_ALL_COMPARTMENTS    = $0200;
  GAA_FLAG_INCLUDE_TUNNEL_BINDINGORDER = $0400;


type
  NET_IFINDEX = ULONG;
  NET_LUID = record
    case Integer of
      0: (
          Value: ULONG64);
      1: (
          Info: ULONG64);
  end;

type
  NL_ROUTER_DISCOVERY_BEHAVIOR = (
    RouterDiscoveryDisabled = 0,
    RouterDiscoveryEnabled,
    RouterDiscoveryDhcp,
    RouterDiscoveryUnchanged = -1
  );

  NL_LINK_LOCAL_ADDRESS_BEHAVIOR = (
    LinkLocalAlwaysOff = 0,
    LinkLocalDelayed,
    LinkLocalAlwaysOn,
    LinkLocalUnchanged = -1
  );


type
  MIB_NOTIFICATION_TYPE = (
    MibParameterNotification,
    MibAddInstance,
    MibDeleteInstance,
    MibInitialNotification
  );

  MIB_IPINTERFACE_ROW = record
    Family:ADDRESS_FAMILY;
    InterfaceLuid:NET_LUID;
    InterfaceIndex:NET_IFINDEX;
    MaxReassemblySize:ULONG;
    InterfaceIdentifier:ULONG64;
    MinRouterAdvertisementInterval:ULONG;
    MaxRouterAdvertisementInterval:ULONG;
    AdvertisingEnabled:BOOLEAN;
    ForwardingEnabled:BOOLEAN;
    WeakHostSend:BOOLEAN;
    WeakHostReceive:BOOLEAN;
    UseAutomaticMetric:BOOLEAN;
    UseNeighborUnreachabilityDetection:BOOLEAN;
    ManagedAddressConfigurationSupported:BOOLEAN;
    OtherStatefulConfigurationSupported:BOOLEAN;
    AdvertiseDefaultRoute:BOOLEAN;
    RouterDiscoveryBehavior:NL_ROUTER_DISCOVERY_BEHAVIOR;
    DadTransmits:ULONG;
    BaseReachableTime:ULONG;
    RetransmitTime:ULONG;
    PathMtuDiscoveryTimeout:ULONG;
    LinkLocalAddressBehavior:NL_LINK_LOCAL_ADDRESS_BEHAVIOR;
    LinkLocalAddressTimeout:ULONG;
    ZoneIndices:Array[0..15] Of ULONG;
    SitePrefixLength:ULONG;
    Metric:ULONG;
    NlMtu:ULONG;
    Connected:BOOLEAN;
    SupportsWakeUpPatterns:BOOLEAN;
    SupportsNeighborDiscovery:BOOLEAN;
    SupportsRouterDiscovery:BOOLEAN;
    ReachableTime:ULONG;
    TransmitOffload:Byte;           //TransmitOffload:NL_INTERFACE_OFFLOAD_ROD;
    ReceiveOffload:Byte;            //ReceiveOffload:NL_INTERFACE_OFFLOAD_ROD;
    DisableDefaultRoutes:BOOLEAN;
  end;
  PMIB_IPINTERFACE_ROW = ^MIB_IPINTERFACE_ROW;

  PIPINTERFACE_CHANGE_CALLBACK = Pointer;

function ConvertIpv4MaskToLength(Mask:ULONG; var MaskLength:UINT8):Integer; stdcall; external 'Iphlpapi.dll';
function GetIpInterfaceEntry(var Row:MIB_IPINTERFACE_ROW):Integer; stdcall; external 'Iphlpapi.dll';
function NotifyIpInterfaceChange(
  Family:ADDRESS_FAMILY;
  Callback:PIPINTERFACE_CHANGE_CALLBACK;
  CallerContext:PVOID;
  InitialNotification:Boolean;
  var NotificationHandle:THandle
):Integer; stdcall; external 'Iphlpapi.dll';



//==========================================================
type TIPMaskInfo=record
   IPAddress:string;
   Mask:string;
end;

type TIPAddress=record
    IP:string;
end;

type TNetworkInfo=record
     FriendlyName:string;
     Description:string;
     MACAddress:string;
     NetworkGuid:string;
     DHCPEnabled:boolean;
     DefaultGateway:string;
     DHCPServer:string;
     InterfaceType:string;
     OperStatus:string;
     DNS_Suffix:String;
     IP_Mask_List:TArray<TIPMaskInfo>;
     DnsServers:TArray<TIPAddress>;
end;


function GetNetworkInfo():TArray<TNetworkInfo>;

implementation


function BytesToMAC(b:Array Of Byte):string;
var
  I:Integer;
begin
  Result := '';
  for I := 0 to 5 do begin
    Result := Result + IntToHex(b[I], 2);
    if (I <> 5) then Result := Result + ':';
  end;
end;

function InterfaceTypeToStr(IfType:Cardinal):string;
begin
  case IfType of
    1: begin
      Result := 'IF_TYPE_OTHER (';
    end;
    6: begin
      Result := 'IF_TYPE_ETHERNET_CSMACD (';
    end;
    9: begin
      Result := 'IF_TYPE_ISO88025_TOKENRING (';
    end;
    23: begin
      Result := 'IF_TYPE_PPP (';
    end;
    24: begin
      Result := 'IF_TYPE_SOFTWARE_LOOPBACK (';
    end;
    37: begin
      Result := 'IF_TYPE_ATM (';
    end;
    71: begin
      Result := 'IF_TYPE_IEEE80211 (WLAN) (';
    end;
    131: begin
      Result := 'IF_TYPE_TUNNEL (';
    end;
    144: begin
      Result := 'IF_TYPE_IEEE1394 (Firewire) (';
    end else begin
      Result := 'Unknown, check MSDN! ('
    end;
  end;

  Result := Result + IntToStr(IfType) + ')';
end;

function OperStatusToStr(OperStatus:IF_OPER_STATUS):string;
begin
  case OperStatus of
    IfOperStatusUp: begin
      Result := 'IfOperStatusUp (1)';
    end;
    IfOperStatusDown: begin
      Result := 'IfOperStatusDown (2)';
    end;
    IfOperStatusTesting: begin
      Result := 'IfOperStatusTesting (3)';
    end;
    IfOperStatusUnknown: begin
      Result := 'IfOperStatusUnknown (4)';
    end;
    IfOperStatusDormant: begin
      Result := 'IfOperStatusDormant (5)';
    end;
    IfOperStatusNotPresent: begin
      Result := 'IfOperStatusNotPresent (6)';
    end;
    IfOperStatusLowerLayerDown: begin
      Result := 'IfOperStatusLowerLayerDown (7)';
    end else begin
      Result := 'Unknown status (' + IntToStr(Integer(OperStatus)) + '), check MSDN!';
    end;
  end;
end;

function GetNetworkInfo():TArray<TNetworkInfo>;
var
  c, count:Cardinal;
  AddrBuffer, IfBuffer:Array Of Byte;
  I:Integer;
  Addresses:PIP_ADAPTER_ADDRESSES;
  dns:PIP_ADAPTER_DNS_SERVER_ADDRESS;
  masklen:Byte;
  NWI:TNetworkInfo;
const
  flags =
    GAA_FLAG_INCLUDE_GATEWAYS or
    GAA_FLAG_SKIP_UNICAST or
    GAA_FLAG_SKIP_ANYCAST or
    GAA_FLAG_SKIP_MULTICAST
  ;
begin
  NWI.NetworkGuid:='';

  // Get IP Address Table, iterated later
  count := 0;
  c := GetIpAddrTable(@AddrBuffer[0], count, False);
  if (c <> ERROR_INSUFFICIENT_BUFFER) then Exit;

  SetLength(AddrBuffer, count);
  c := GetIpAddrTable(@AddrBuffer[0], count, False);
  if (c <> NO_ERROR) then Exit;

  // Get Adapters
  count := 0;
  c := GetAdaptersAddresses(AF_INET, flags, nil, @IfBuffer[0], @count);
  if (c <> ERROR_BUFFER_OVERFLOW) then Exit;

  SetLength(IfBuffer, count);
  c := GetAdaptersAddresses(AF_INET, flags, nil, @IfBuffer[0], @count);
  if (c <> ERROR_SUCCESS) then Exit;

  Addresses := @IfBuffer[0];

  SetLength(Result,0);

  while (Addresses <> nil) do
  begin

    SetLength(Result,length(Result)+1);

    NWI.FriendlyName:=Addresses.FriendlyName;
    NWI.Description:=Addresses.Description;
    NWI.MACAddress:=BytesToMAC(Addresses.PhysicalAddress);
    NWI.DHCPEnabled:=(Addresses.Flags OR IP_ADAPTER_DHCP_ENABLED) = Addresses.Flags;

    NWI.NetworkGuid:=string( Addresses.AdapterName);

    // IPs
    setlength(NWI.IP_Mask_List,0);
    for I := 0 to PMIB_IPADDRTABLE(@AddrBuffer[0]).dwNumEntries-1 do
    begin
      if PMIB_IPADDRROW(@AddrBuffer[4+SizeOf(MIB_IPADDRROW)*i]).dwIndex = Addresses.Union.IfIndex then
      begin
        ConvertIpv4MaskToLength(PMIB_IPADDRROW(@AddrBuffer[4+SizeOf(MIB_IPADDRROW)*i]).dwMask, masklen);
        setlength(NWI.IP_Mask_List,length(NWI.IP_Mask_List)+1);
        NWI.IP_Mask_List[high(NWI.IP_Mask_List)].IPAddress:=string(inet_ntoa(in_addr(PMIB_IPADDRROW(@AddrBuffer[4+SizeOf(MIB_IPADDRROW)*i]).dwAddr)));
        NWI.IP_Mask_List[high(NWI.IP_Mask_List)].Mask:=string(inet_ntoa(in_addr(PMIB_IPADDRROW(@AddrBuffer[4+SizeOf(MIB_IPADDRROW)*i]).dwMask)));
      end;
    end;

    //Default Gateway
    NWI.DefaultGateway:='0.0.0.0';
    if (Addresses.FirstGatewayAddress <> nil) then
    begin
      NWI.DefaultGateway:=string(inet_ntoa(in_addr(Addresses.FirstGatewayAddress.Address.lpSockaddr.sin_addr)));
    end;

    // DNS servers
    SetLength(NWI.DnsServers,0);
    if (Addresses.FirstDnsServerAddress <> nil) then
    begin
      dns := Addresses.FirstDnsServerAddress;
      while (dns <> nil) do
      begin
        SetLength(NWI.DnsServers,length(NWI.DnsServers)+1);
        NWI.DnsServers[high(NWI.DnsServers)].IP:=string(inet_ntoa(dns.Address.lpSockaddr.sin_addr));
        dns := dns.Next;
      end;
    end;

    NWI.DHCPServer:='0.0.0.0';
    if (Addresses.Dhcpv4Server.lpSockaddr <> nil) then
      NWI.DHCPServer:=string(inet_ntoa(Addresses.Dhcpv4Server.lpSockaddr.sin_addr));

    NWI.InterfaceType:=InterfaceTypeToStr(Addresses.IfType);
    NWI.OperStatus:=OperStatusToStr(Addresses.OperStatus);  //Operational status
    NWI.DNS_Suffix:=Addresses.DnsSuffix; //DNS suffix


    Result[high(Result)]:=NWI;

    Addresses := Addresses.Next;
  end; //while end

end;

end.
