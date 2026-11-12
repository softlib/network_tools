unit uNetworkConnection;

interface

uses Windows, Messages, SysUtils, Variants, Classes, Graphics, ActiveX,
  ComObj, Contnrs;

const
  CLSID_ConnectionManager: TGUID = '{BA126AD1-2166-11D1-B1D0-00805FC1270E}';
  IID_INetConnectionManager: TGUID = '{C08956A2-1CD3-11D1-B1C5-00805FC1270E}';

type
  NETCONMGR_ENUM_FLAGS = (NCME_DEFAULT);

  NETCON_STATUS = (
    NCS_DISCONNECTED{连接已断开连接},
    NCS_CONNECTING{连接正在进行连接},
    NCS_CONNECTED{连接处于连接状态},
    NCS_DISCONNECTING{连接正在断开连接},
    NCS_HARDWARE_NOT_PRESENT{连接的硬件（例如网络接口卡 (NIC) ）不存在},
    NCS_HARDWARE_DISABLED{连接的硬件存在，但未启用},
    NCS_HARDWARE_MALFUNCTION{连接的硬件中发生了故障},
    NCS_MEDIA_DISCONNECTED{媒体（例如网络电缆）断开连接},
    NCS_AUTHENTICATING{连接正在等待身份验证发生},
    NCS_AUTHENTICATION_SUCCEEDED{身份验证在此连接上成功},
    NCS_AUTHENTICATION_FAILED{此连接上身份验证失败},
    NCS_INVALID_ADDRESS{地址无效},
    NCS_CREDENTIALS_REQUIRED {需要安全凭据}
     );

  NETCON_MEDIATYPE = (NCM_NONE, NCM_DIRECT, NCM_ISDN, NCM_LAN, NCM_PHONE,
    NCM_TUNNEL, NCM_PPPOE, NCM_BRIDGE, NCM_SHAREDACCESSHOST_LAN,
    NCM_SHAREDACCESSHOST_RAS);

  PNETCON_PROPERTIES = ^NETCON_PROPERTIES;

  NETCON_PROPERTIES = record
    guidId: TGUID;
    pszwName: LPWSTR; // array [0..255] of WCHAR;
    pszwDeviceName: LPWSTR;
    Status: NETCON_STATUS;
    MediaType: NETCON_MEDIATYPE;
    dwCharacter: DWORD;
    clsidThisObject: TGUID;
    clsidUiObject: TGUID;
  end;

  INetConnectionManager = interface;
  INetConnection = interface;
  IEnumNetConnection = interface;

  INetConnectionManager = interface(IUnknown)
    ['{C08956A2-1CD3-11D1-B1C5-00805FC1270E}']
    function EnumConnections(flag: NETCONMGR_ENUM_FLAGS;
      out ppv: IEnumNetConnection): HRESULT; stdcall;
  end;

  IEnumNetConnection = interface(IUnknown)
    ['{C08956A0-1CD3-11D1-B1C5-00805FC1270E}']
    function Next(celt: DWORD; out rgelt: INetConnection; pceltFetched: PULONG)
      : HRESULT; stdcall;
    function Skip(celt: ULONG): HRESULT; stdcall;
    function Reset(): HRESULT; stdcall;
    function Clone(out ppenum: IEnumNetConnection): HRESULT; stdcall;
  end;

  INetConnection = interface(IUnknown)
    ['{C08956A1-1CD3-11D1-B1C5-00805FC1270E}']
    function Connect(): HRESULT; stdcall;
    function Disconnect(): HRESULT; stdcall;
    function Delete(): HRESULT; stdcall;
    function Duplicate(pszwDuplicateName: LPCWSTR; out ppCon: INetConnection)
      : HRESULT; stdcall;
    function GetProperties(out ppProps: PNETCON_PROPERTIES): HRESULT; stdcall;
    function GetUiObjectClassId(out pclsid: TGUID): HRESULT; stdcall;
    function Rename(pszwNewName: LPCWSTR): HRESULT; stdcall;
  end; // Global functions


 //核心方法1 获取网络连接
procedure GetConnectionList(pList: TStrings);

  //核心方法2 启用或禁用网络连接
function EnableConnection(Guid: String; bEnable: Boolean): Integer;

implementation

procedure GetConnectionList(pList: TStrings);
var
  pManager: INetConnectionManager;
  pEnum: IEnumNetConnection;
  pConnection: INetConnection;
  celtFetched: DWORD;
  pProperties: PNETCON_PROPERTIES;
  Status: String;
begin
  CoCreateInstance(CLSID_ConnectionManager, nil, CLSCTX_SERVER,IID_INetConnectionManager, pManager);

  if SUCCEEDED(pManager.EnumConnections(NCME_DEFAULT, pEnum)) then
  begin
    while (pEnum.Next(1, pConnection, @celtFetched) = S_OK) do
    begin
      pConnection.GetProperties(pProperties);

      case pProperties.Status of
        NCS_CONNECTED:
        begin
           Status := '已连通';  //CONNECTED
        end;
        NCS_DISCONNECTED:
          Status := '已断开'; //DISCONNECTED
        NCS_CONNECTING:
          Status := '正在连接';   //CONNECTING
        NCS_HARDWARE_DISABLED:
          Status := '已禁用';   //DISABLED
        NCS_AUTHENTICATING:
          Status := '正在尝试身份验证';
        NCS_AUTHENTICATION_SUCCEEDED:
          Status := '身份验证成功';
        NCS_AUTHENTICATION_FAILED:
          Status := '身份验证失败';
        NCS_DISCONNECTING:
         Status := '正在断开连接';
        NCS_HARDWARE_MALFUNCTION:
          Status := '硬件故障';
        NCS_HARDWARE_NOT_PRESENT:
          Status := '硬件不存在';
        NCS_MEDIA_DISCONNECTED:
           Status := '网线已拔出';
        NCS_INVALID_ADDRESS:
           Status := '地址无效';
        NCS_CREDENTIALS_REQUIRED:
           Status := '需要安全凭据';

      else
        Status := '其他';  //Others
      end;
      pList.Add(Format('%s|%s|%s|%s', [GUIDToString(pProperties.guidId),
        pProperties.pszwName, pProperties.pszwDeviceName, Status]));
    end;
  end;
end;

// This method will enable/disable the network connection similar to  the GUI code.
// EnableConnection(L"Local Area Connection", true);
//
function EnableConnection(Guid: String; bEnable: Boolean): Integer;
var
  LPNcFreeNetconProperties: procedure(pProps: PNETCON_PROPERTIES)stdcall;
  // LPIEnumNetConnection_EnumConnections : procedure(myob : IEnumNetConnectionj, NETCONMGR_ENUM_FLAGS flags, IEnumNetConnection * * ppEnum);
  hres: HRESULT;
  pMan: INetConnectionManager;
  pEnum: IEnumNetConnection;
  pCon: INetConnection;
  count: DWORD;
  done: Integer;
  hmod: HMODULE;
  pProps: PNETCON_PROPERTIES;
begin
  result := 0;
  hmod := LoadLibrary('netshell.dll');
  if (hmod = 0) then
    exit;
  @LPNcFreeNetconProperties := GetProcAddress(hmod, 'NcFreeNetconProperties');
  if (@LPNcFreeNetconProperties = nil) then
  begin
    FreeLibrary(hmod);
    exit;
  end;
  pMan := nil;
  hres := CoCreateInstance(CLSID_ConnectionManager, nil, CLSCTX_ALL,
    IID_INetConnectionManager, pMan);
  if (SUCCEEDED(hres)) then
  begin
    hres := pMan.EnumConnections(NCME_DEFAULT, pEnum);
    if (SUCCEEDED(hres)) then
    begin
      done := 0;
      Guid := LowerCase(Guid);
      while ((pEnum.Next(1, pCon, @count) = S_OK) and (done = 0)) do
      begin
        pCon.GetProperties(pProps);
        if (SUCCEEDED(hres)) then
        begin

          if (LowerCase(GUIDToString(pProps.guidId)) = Guid) then
          begin
            // messagebox(0,pchar(GuidToString(pProps.guidId)),'guid',1);
            if (bEnable) then
            begin
              result := pCon.Connect(); // 启用(恢复)连接
            end
            else
            begin
              result := pCon.Disconnect(); // 断开连接
            end;
            done := 1;
          end; // END if (wcsstr(pProps->...
          LPNcFreeNetconProperties(pProps);
          // pCon._Release();
        end;
      end; // END while
      // pEnum._Release();
    end;
    // pMan._Release();
  end;
  FreeLibrary(hmod);
end;

end.
