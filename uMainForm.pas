unit uMainForm;

{
  网卡管理器 - 基于 uNetworkConnection.pas 单元（Network Connections COM 接口）
  功能：
    1. 自动枚举电脑上所有网络连接（物理网卡 + 虚拟网卡，如 TAP/VPN/环回等）
    2. 周期性（2 秒）自动监测每个连接的实时状态
    3. 可随时对选中的连接执行“禁用 / 启用”（即断网/恢复上网）
    4. 双击列表项 = 启用/禁用切换
  注意：禁用/启用操作需要管理员权限，程序启动时会提示提权重启。
}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.StrUtils,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls, Winapi.ActiveX, Winapi.ShellAPI,
  uNetworkConnection;

type
  TMainForm = class(TForm)
    pnlTop: TPanel;
    btnRefresh: TButton;
    btnEnable: TButton;
    btnDisable: TButton;
    chkAutoRefresh: TCheckBox;
    Timer1: TTimer;
    lvAdapters: TListView;
    sbMain: TStatusBar;
    Button1: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnRefreshClick(Sender: TObject);
    procedure btnEnableClick(Sender: TObject);
    procedure btnDisableClick(Sender: TObject);
    procedure lvAdaptersDblClick(Sender: TObject);
    procedure lvAdaptersSelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure Timer1Timer(Sender: TObject);
    procedure Button1Click(Sender: TObject);

  private
    FIPMap: TStringList;   // GUID -> IP 地址列表
    FTypeMap: TStringList; // GUID -> 网卡接口类型描述
    function GetSelectedGuid: string;
    procedure LoadIPMap;
    procedure RefreshList;
    procedure UpdateButtonState;
    procedure DoEnableDisable(AEnable: Boolean);
    function IsElevated: Boolean;
  end;

var
  MainForm: TMainForm;

implementation
uses uGetAdapterInfo;

{$R *.dfm}





{ ---------- iphlpapi：获取各网卡当前 IP 地址 ---------- }

type
  PIP_ADDR_STRING = ^IP_ADDR_STRING;
  IP_ADDR_STRING = record
    Next: PIP_ADDR_STRING;
    IpAddress: array [0..15] of AnsiChar;
    IpMask: array [0..15] of AnsiChar;
    Context: array [0..15] of AnsiChar;
  end;

  PIP_ADAPTER_INFO = ^IP_ADAPTER_INFO;
  IP_ADAPTER_INFO = record
    Next: PIP_ADAPTER_INFO;
    ComboIndex: DWORD;
    AdapterName: array [0..255] of AnsiChar; // 接口 GUID 字符串
    Description: array [0..255] of AnsiChar;
    AddressLength: UINT;
    Address: array [0..7] of Byte;
    Index: DWORD;
    _Type: UINT;
    DhcpEnabled: UINT;
    CurrentIpAddress: PIP_ADDR_STRING;
    IpAddressList: IP_ADDR_STRING;
    GatewayList: IP_ADDR_STRING;
    DhcpServer: IP_ADDR_STRING;
    HaveWins: BOOL;
    PrimaryWinsServer: IP_ADDR_STRING;
    SecondaryWinsServer: IP_ADDR_STRING;
    LeaseObtained: Int64;
    LeaseExpires: Int64;
  end;

function GetAdaptersInfo(pAdapterInfo: PIP_ADAPTER_INFO;
  var OutBufLen: ULONG): ULONG; stdcall;
  external 'iphlpapi.dll' name 'GetAdaptersInfo';

function _IsUserAnAdmin: BOOL; stdcall;
  external 'shell32.dll' name 'IsUserAnAdmin';

{ ---------- 工具函数 ---------- }

function StatusToStr(AStatus: NETCON_STATUS): string;
begin
  case AStatus of
    NCS_CONNECTED:                Result := '已连接';
    NCS_DISCONNECTED:             Result := '已断开';
    NCS_CONNECTING:               Result := '正在连接';
    NCS_DISCONNECTING:            Result := '正在断开';
    NCS_HARDWARE_NOT_PRESENT:     Result := '硬件不存在';
    NCS_HARDWARE_DISABLED:        Result := '已禁用';
    NCS_HARDWARE_MALFUNCTION:     Result := '硬件故障';
    NCS_MEDIA_DISCONNECTED:       Result := '网线未插';
    NCS_AUTHENTICATING:           Result := '正在验证';
    NCS_AUTHENTICATION_SUCCEEDED: Result := '验证成功';
    NCS_AUTHENTICATION_FAILED:    Result := '验证失败';
    NCS_INVALID_ADDRESS:          Result := '地址无效';
    NCS_CREDENTIALS_REQUIRED:     Result := '需要凭据';
  else
    Result := '未知';
  end;
end;

function MediaTypeToStr(AMediaType: NETCON_MEDIATYPE): string;
begin
  case AMediaType of
    NCM_DIRECT:               Result := '直连';
    NCM_ISDN:                 Result := 'ISDN';
    NCM_LAN:                  Result := '局域网';
    NCM_PHONE:                Result := '拨号';
    NCM_TUNNEL:               Result := 'VPN隧道';
    NCM_PPPOE:                Result := 'PPPoE';
    NCM_BRIDGE:               Result := '网桥';
    NCM_SHAREDACCESSHOST_LAN: Result := '共享(LAN)';
    NCM_SHAREDACCESSHOST_RAS: Result := '共享(RAS)';
  else
    Result := '其他';
  end;
end;

// 将 IFTYPE（GetAdaptersInfo 的 Type 字段，IANA ifType 编号）转为可读文本
function IfTypeToStr(AType: DWORD): string;
begin
  case AType of
    1:    Result := '其他';
    6:    Result := '以太网';
    7:    Result := 'IEEE802.3';
    9:    Result := '令牌环';
    23:   Result := 'PPP拨号';
    24:   Result := '环回(Loopback)';
    28:   Result := 'SLIP';
    37:   Result := 'ATM';
    53:   Result := '虚拟接口(PropVirtual)';
    71:   Result := '无线局域网(Wi-Fi)';
    94:   Result := 'ADSL';
    117:  Result := '千兆以太网';
    131:  Result := '隧道(Tunnel)';
    144:  Result := 'IEEE1394';
    243:  Result := '蜂窝网络(WWAN)';
    244:  Result := '蜂窝网络(WWAN2)';
    257:  Result := '无线P2P(Wi-Fi Direct)';
  else
    Result := Format('类型%d', [AType]);
  end;
end;

// 依据驱动描述关键字判断是否为虚拟网卡
function IsVirtualAdapterDesc(const ADesc: string): Boolean;
const
  KEYS: array [0..11] of string = (
    'TAP', 'TUN', 'Virtual', 'VMware', 'VirtualBox', 'Hyper-V',
    'VPN', 'Wintun', 'WireGuard', 'Teredo', 'ISATAP', 'Wi-Fi Direct');
var
  K: string;
begin
  Result := False;
  for K in KEYS do
    if ContainsText(ADesc, K) then
      Exit(True);
end;

{ ---------- 窗体事件 ---------- }

procedure TMainForm.FormCreate(Sender: TObject);
begin
  CoInitializeEx(nil, COINIT_APARTMENTTHREADED);
  FIPMap := TStringList.Create;
  FTypeMap := TStringList.Create;
  lvAdapters.DoubleBuffered := True;

  RefreshList;

  // 禁用/启用网卡需要管理员权限
  if not IsElevated then
  begin
    if MessageBox(Handle,
      '程序当前未以管理员身份运行，将无法禁用/启用网卡。' + #13#10 +
      '是否以管理员身份重新启动？', '权限提示',
      MB_YESNO or MB_ICONQUESTION) = IDYES then
    begin
      ShellExecute(Handle, 'runas', PChar(ParamStr(0)), nil, nil, SW_SHOW);
      Application.Terminate;
    end;
  end;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FIPMap.Free;
  FTypeMap.Free;
end;

procedure TMainForm.Timer1Timer(Sender: TObject);
begin
  if chkAutoRefresh.Checked then
    RefreshList;
end;

procedure TMainForm.btnRefreshClick(Sender: TObject);
begin
  RefreshList;
end;



procedure TMainForm.Button1Click(Sender: TObject);
begin

 ShowMessage(GetPrimaryIPv4);

  var infoList:=GetAdapterInfo;
  var AdapterInfo: TAdapterInfo;
  for var i := 0 to infoList.Count-1 do
  begin
     AdapterInfo:=TAdapterInfo( infoList.Items[i]);
     ShowMessage(AdapterInfo.AdapterName+sLineBreak+AdapterInfo.AdapterType
     +sLineBreak+AdapterInfo.IPAddress
     +sLineBreak+AdapterInfo.MacAddress
     +sLineBreak+AdapterInfo.DHCPServer
     +sLineBreak+AdapterInfo.Gateway
     +sLineBreak+AdapterInfo.Subnetmask
     );
  end;

end;

procedure TMainForm.btnEnableClick(Sender: TObject);
begin
  DoEnableDisable(True);
end;

procedure TMainForm.btnDisableClick(Sender: TObject);
begin
  DoEnableDisable(False);
end;

procedure TMainForm.lvAdaptersSelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
begin
  UpdateButtonState;
end;

procedure TMainForm.lvAdaptersDblClick(Sender: TObject);
begin
  if lvAdapters.Selected = nil then
    Exit;
  // 双击切换：已禁用 -> 启用；其他状态 -> 禁用
  DoEnableDisable(Pos('断开', lvAdapters.Selected.SubItems[1]) > 0);
end;

{ ---------- 核心逻辑 ---------- }

function TMainForm.IsElevated: Boolean;
begin
  // Win10/11 下可直接用 shell32 的 IsUserAnAdmin 判断当前进程是否具有管理员权限
  Result := _IsUserAnAdmin;
end;

function TMainForm.GetSelectedGuid: string;
begin
  Result := '';
  if (lvAdapters.Selected <> nil) and
     (lvAdapters.Selected.SubItems.Count >= 6) then
    Result := lvAdapters.Selected.SubItems[5];
end;

// 通过 iphlpapi 取每个接口的 IPv4 地址与接口类型，建立 GUID -> IP / 类型 映射
procedure TMainForm.LoadIPMap;
const
  INIT_BUF = 16 * 1024; // 初始缓冲区 16KB，不够时按返回的实际大小重试
var
  Buf: PIP_ADAPTER_INFO;
  BufLen: ULONG;
  Ret: DWORD;
  pAdapter: PIP_ADAPTER_INFO;
  pAddr: PIP_ADDR_STRING;
  s, IPs, Name, Desc, TypeStr: string;
begin
  FIPMap.Clear;
  FTypeMap.Clear;

  (*
  // 注意：不能给 GetAdaptersInfo 传 nil 缓冲区探测大小（部分系统会返回
  // ERROR_INVALID_PARAMETER 且不设置 BufLen），必须先给一块初始缓冲区，
  // 若返回 ERROR_BUFFER_OVERFLOW 再按实际大小分配重试。
  BufLen := INIT_BUF;
  GetMem(Buf, BufLen);
  try
    Ret := GetAdaptersInfo(Buf, BufLen);
    if Ret = ERROR_BUFFER_OVERFLOW then
    begin
      FreeMem(Buf);
      GetMem(Buf, BufLen);
      Ret := GetAdaptersInfo(Buf, BufLen);
    end;
    if Ret = ERROR_SUCCESS then
    begin
      pAdapter := Buf;
      while pAdapter <> nil do
      begin
        IPs := '';

        pAddr := @pAdapter.IpAddressList;
        while pAddr <> nil do
        begin
          s := Trim(string(AnsiString(PAnsiChar(@pAddr.IpAddress[0]))));

          if (s <> '') and (s <> '0.0.0.0') then
          begin
            if IPs <> '' then
              IPs := IPs + ', ';
            IPs := IPs + s;
          end;
          pAddr := pAddr.Next;
        end;
        // AdapterName 即该接口的 GUID 字符串（形如 {4D36E972-...}），
        // 与 NETCON_PROPERTIES.guidId 对应，大小写不敏感地存入映射表
        Name := AnsiUpperCase(
          Trim(string(AnsiString(PAnsiChar(@pAdapter.AdapterName[0])))));
        FIPMap.Values[Name] := IPs;


        // 接口实际类型：IFTYPE 编号 + 驱动描述中的虚拟网卡关键字识别
      {  Desc := Trim(string(AnsiString(PAnsiChar(@pAdapter.Description[0]))));
       // ShowMessage(Desc);
        TypeStr := IfTypeToStr(pAdapter._Type);

        if (pAdapter._Type = 24) or (pAdapter._Type = 53) or
           (pAdapter._Type = 131) or (pAdapter._Type = 257) or
           IsVirtualAdapterDesc(Desc) then
          TypeStr := TypeStr + ' · 虚拟';
        FTypeMap.Values[Name] := TypeStr;
        }

        if uGetAdapterInfo.IsPhysicalAdapter(Name) then
        begin
           FTypeMap.Values[Name] := '物理';
        end
        else
        begin
           FTypeMap.Values[Name] := '虚拟';
        end;


        pAdapter := pAdapter.Next;
      end;
    end;
  finally
    FreeMem(Buf);
  end;
 *)

  var infoList:=GetAdapterInfo;
  var AdapterInfo: TAdapterInfo;
  for var i := 0 to infoList.Count-1 do
  begin
     AdapterInfo:=TAdapterInfo( infoList.Items[i]);

    // ShowMessage(AdapterInfo.AdapterName+sLineBreak+AdapterInfo.AdapterType +sLineBreak+AdapterInfo.IPAddress +sLineBreak+AdapterInfo.MacAddress);
     IPs:=AdapterInfo.IPAddress;
     FIPMap.Values[AdapterInfo.AdapterGUID] := IPs;
     FTypeMap.Values[AdapterInfo.AdapterGUID] := AdapterInfo.AdapterType;

     if uGetAdapterInfo.IsPhysicalAdapter(AdapterInfo.AdapterGUID) then
     begin
           FTypeMap.Values[AdapterInfo.AdapterGUID] := '物理';
     end
     else
     begin
           FTypeMap.Values[AdapterInfo.AdapterGUID] := '虚拟';
     end;

  end;


end;

// 枚举所有网络连接（物理 + 虚拟），刷新 ListView，并保持当前选中项
procedure TMainForm.RefreshList;
var
  pManager: INetConnectionManager;
  pEnum: IEnumNetConnection;
  pCon: INetConnection;
  pProps: PNETCON_PROPERTIES;
  Fetched: DWORD;
  hmod: HMODULE;
  NcFreeProps: procedure(pProps: PNETCON_PROPERTIES); stdcall;
  SavedGuid: string;
  Item: TListItem;
  Guid, IP, AdapterType: string;
  I: Integer;
begin
  hmod := LoadLibrary('netshell.dll');
  NcFreeProps := nil;
  if hmod <> 0 then
    @NcFreeProps := GetProcAddress(hmod, 'NcFreeNetconProperties');

  SavedGuid := GetSelectedGuid;
  LoadIPMap;

  lvAdapters.Items.BeginUpdate;
  try
    lvAdapters.Items.Clear;

    pManager := nil;
    if SUCCEEDED(CoCreateInstance(CLSID_ConnectionManager, nil, CLSCTX_SERVER,
      IID_INetConnectionManager, pManager)) then
    begin
      if SUCCEEDED(pManager.EnumConnections(NCME_DEFAULT, pEnum)) then
      begin
        while (pEnum.Next(1, pCon, @Fetched) = S_OK) do
        begin
          if SUCCEEDED(pCon.GetProperties(pProps)) then
          begin
            Guid := GUIDToString(pProps^.guidId);
            IP := FIPMap.Values[AnsiUpperCase(Guid)];
            if IP = '' then
              IP := '—（无 IP，未连接或已禁用）';

            // 网卡接口实际类型；已禁用等取不到的连接退回媒体类型推断
            AdapterType := FTypeMap.Values[AnsiUpperCase(Guid)];
            if AdapterType = '' then
              case pProps^.MediaType of
                NCM_TUNNEL: AdapterType := '隧道(Tunnel)';
                NCM_PPPOE:  AdapterType := 'PPPoE 拨号';
                NCM_ISDN:   AdapterType := 'ISDN';
                NCM_PHONE:  AdapterType := '拨号';
              else
                AdapterType := '—（未启用，无法获取）';
              end;

            Item := lvAdapters.Items.Add;
            Item.Caption := pProps^.pszwName;           //名称
            Item.SubItems.Add(pProps^.pszwDeviceName);   //设备名
            Item.SubItems.Add(StatusToStr(pProps^.Status));   //状态
            Item.SubItems.Add(MediaTypeToStr(pProps^.MediaType));  //类型
            Item.SubItems.Add(AdapterType);   //网卡类型
            Item.SubItems.Add(IP);
            Item.SubItems.Add(Guid);

            if Assigned(NcFreeProps) then
              NcFreeProps(pProps);
          end;
        end;
      end;
    end;

    // 恢复刷新前的选中项（GUID 位于 SubItems[5]）
    if SavedGuid <> '' then
      for I := 0 to lvAdapters.Items.Count - 1 do
        if (lvAdapters.Items[I].SubItems.Count >= 6) and
           SameText(lvAdapters.Items[I].SubItems[5], SavedGuid) then
        begin
          lvAdapters.Items[I].Selected := True;
          lvAdapters.Items[I].Focused := True;
          Break;
        end;
  finally
    lvAdapters.Items.EndUpdate;
  end;

  if hmod <> 0 then
    FreeLibrary(hmod);

  UpdateButtonState;
  sbMain.SimpleText := Format(
    '共 %d 个网络连接（物理 + 虚拟）   |   权限: %s   |   %s',
    [lvAdapters.Items.Count,
     IfThen(IsElevated, '管理员', '普通用户'),
     IfThen(chkAutoRefresh.Checked, '自动监测: 开 (2秒)', '自动监测: 关')]);
end;

procedure TMainForm.UpdateButtonState;
var
  HasSel, Disabled: Boolean;
begin
  HasSel := (lvAdapters.Selected <> nil) and
            (lvAdapters.Selected.SubItems.Count >= 2);
  Disabled := HasSel and ( (Pos('禁用', lvAdapters.Selected.SubItems[1]) > 0) or (Pos('断开', lvAdapters.Selected.SubItems[1]) > 0) );
  btnEnable.Enabled := HasSel and Disabled;
  btnDisable.Enabled := HasSel and not Disabled;
end;

// 调用 uNetworkConnection.EnableConnection 对指定连接启用/禁用
procedure TMainForm.DoEnableDisable(AEnable: Boolean);
var
  Guid: string;
  Ret: Integer;
begin
  Guid := GetSelectedGuid;
  if Guid = '' then
    Exit;

  if not IsElevated then
  begin
    MessageBox(Handle,
      '禁用/启用网卡需要管理员权限。' + #13#10 +
      '请右键本程序，选择“以管理员身份运行”。',
      '权限不足', MB_OK or MB_ICONWARNING);
    Exit;
  end;

  Ret := EnableConnection(Guid, AEnable);
  if SUCCEEDED(Ret) then
    sbMain.SimpleText := Format('操作已提交: %s -> %s（状态刷新约需 1~2 秒）',
      [Guid, IfThen(AEnable, '启用', '禁用')])
  else
    MessageBox(Handle,
      PChar(Format('操作失败，返回码: %d (0x%.8x)', [Ret, Ret])),
      '错误', MB_OK or MB_ICONERROR);

  RefreshList; // 周期定时器也会自动跟进后续状态变化
end;

end.
