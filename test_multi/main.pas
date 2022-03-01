unit main;

(*
  testmulti a small Free Pascal/Lazarus GUI program to test

    1. changes to mqttclas.pas with respect to client_id in mosquitto-p
    2. dynamic loading of the mosquitto library
    3. graceful exit if the mosquitto library is not installed on the system
    4. multiple MQTT client connections to multiple MQTT brokers or
       multiple MQTT client connections to a single MQTT broker.
    5. a common logging facility that is OS independant
    6. usage of the PostMessage/SendMessage method to update the GUI as
       suggested in the *Multithreaded Application Turorial* in the Lazarus Wiki
       @https://wiki.lazarus.freepascal.org/Multithreaded_Application_Tutorial


  Requirements:
    1. The cthreads unit must be loaded first in Linux systems. On the Amiga
       the athreads unit must be loaded first (not tested). Here is the
       uses clause in the project source testmulti.lpr
          uses
            {$IFDEF UNIX}
            cthreads,
            {$ENDIF}
            {$IFDEF HASAMIGA}
            athreads,
            {$ENDIF}

    2. The sigmdel fork of mosquitto-p @https://github.com/sigmdel/mosquitto-p.
       (mosquitto-p is a Free Pascal conversions of the mosquitto library
       header file and a Pascal wrapper by Károly Balogh (chainq)
       @https://github.com/chainq/mosquitto-p)

    3. Enable dynamic loading of the mosquitto library by add -dDYNAMIC_MOSQLIB
       as a custom compiler option. Menu choices:
       Project / Project Options / Compiler Options / Custom Options

    4. The Eclipse mosquitto libraries should be installed on the system. If not
       the program should terminate with a meaningful error message.

    5. Define the hostname (or IP address) of the first two MQTT brokers,
       (and if required the username and password or the CA certificate) in
       the TForm1.ConfigClients procedure.

  Copyright (c) 2022 by Michel Deslierres
  License: BSD Zero Clause see https://spdx.org/licenses/0BSD.html
*)

// SPDX-License-Identifier: 0BSD

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LMessages, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ComCtrls, mqttclass, mosquitto;


const
  CLIENT_COUNT = 3;
  UM_WRITE_MSG = LM_USER + 2004;
  UM_WRITE_LOG = UM_WRITE_MSG + 1;

type
  TMqttClient = class(TMQTTConnection)
    FIndex: integer;
    procedure MyOnMessage(const payload: Pmosquitto_message);
  end;
  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    Button5: TButton;
    Edit1: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    MessageMemo: TMemo;
    LogMemo: TMemo;
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FClient: array of TMQTTClient;
    Fconfig: array of TMQTTConfig;
    procedure ConfigClients;
    procedure Connect(index: integer);
    procedure Disconnect(index: integer);
    procedure updateIdLabels;
    procedure writemsg(var msg: TLMessage); message UM_WRITE_MSG;
    procedure writelog(var msg: TLMessage); message UM_WRITE_LOG;
  public
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

uses
  LCLIntf;

procedure TMqttClient.MyOnMessage(const payload: Pmosquitto_message);
var
  msg: ansistring;
  PMsg: PChar;
begin
  msg:='';
  with payload^ do begin
      { Note that MQTT messages could be binary,
        which is why the log only showns the size of the payload }
      SetLength(msg,payloadlen);
      Move(payload^,msg[1],payloadlen);
      writestr(msg, 'Client[',Findex,']: ', FConfig.client_id, ' - Topic: [',topic,'] - Message: [',msg,']');
  end;
  PMsg := StrAlloc(Length(msg)+1);
  StrCopy(PMsg, PChar(Msg));
  {$IFDEF WINDOWS}
  SendMessage(Form1.Handle, UM_WRITE_MSG, PtrUInt(PMsg), 0);
  {$ELSE}
  PostMessage(Form1.Handle, UM_WRITE_MSG, PtrUInt(PMsg), 0);
  {$ENDIF}
end;

{ TForm1 }

procedure TForm1.writemsg(var msg: TLMessage);
var
  MsgStr: PChar;
  MsgPasStr: string;
begin
  MsgStr := PChar(Msg.wparam);
  MsgPasStr := StrPas(MsgStr);
  MessageMemo.Lines.add(MsgPasStr);
  StrDispose(MsgStr);
end;

procedure TForm1.writelog(var msg: TLMessage);
var
  MsgStr: PChar;
  MsgPasStr: string;
begin
  MsgStr := PChar(Msg.wparam);
  MsgPasStr := StrPas(MsgStr);
  LogMemo.Lines.add(MsgPasStr);
  StrDispose(MsgStr);
end;


procedure TForm1.ConfigClients;
var
  i: integer;
begin
  setlength(FClient, CLIENT_COUNT);
  setlength(Fconfig, CLIENT_COUNT);

  for i := 0 to CLIENT_COUNT-1 do
    FillChar(FConfig[i], sizeof(TMqttConfig), 0);
  with FConfig[0] do begin
     port := 1883;
     keepalives := 60;
     hostname := 'localhost';
     client_id := 'client_1';
     username := '';
     password := '';
   end;

  with FConfig[1] do begin
     port := 1883;
     keepalives := 60;
     hostname := '127.0.0.1';
     client_id := 'client_2';
     username := '';
     password := '';
  end;

  with FConfig[2] do begin
     port := 1883;
     keepalives := 60;
     hostname := 'test.mosquitto.org';
     client_id := 'mosquitto.org';
     username := 'wildcard';
     password := '';
  end;
end;

procedure TForm1.Connect(index: integer);
begin
  if (index < 0) or (index >= CLIENT_COUNT) then
    Raise Exception.CreateFmt('%d is an invalid client index which must be 1, 2 or 3', [index]);
  if FConfig[index].hostname = '' then
    Raise Exception.CreateFmt('No hostname for MQTT client %d', [index]);
  FClient[index] := TMqttClient.Create(FConfig[index].client_id, FConfig[index], MOSQ_LOG_ALL);
  try
    FClient[index].FIndex := index;
    FClient[index].OnMessage:=@FClient[index].MyOnMessage;
    FClient[index].Connect;
    FClient[index].Subscribe('#',0); { Subscribe to all topics }
    MessageMemo.Lines.add('');
    MessageMemo.Lines.add(Format('Client[%d]: client_id: %s. Connecting to %s', [index, FConfig[index].client_id, FConfig[index].hostname]));
  except
    MessageMemo.Lines.add('');
    MessageMemo.Lines.add(Format('Client[%d]: unable to Connect to %s', [index, FConfig[index].hostname]));
  end;
end;

procedure TForm1.disconnect(index: integer);
begin
  if (index < 0) or (index >= CLIENT_COUNT) then
    Raise Exception.CreateFmt('%d is an invalid client index which must be 1, 2 or 3', [index]);
  if assigned(FClient[index]) then
    freeandnil(FClient[index]);
  MessageMemo.Lines.add('');
  MessageMemo.Lines.add(Format('Client id: %s. Disconnected from %s', [FConfig[index].client_id, FConfig[index].hostname]));
end;

procedure TForm1.updateIdLabels;
begin
  Label1.Caption := Format('"%s"', [FConfig[0].client_id]);
  Label2.Caption := Format('"%s"', [FConfig[1].client_id]);
  Label3.Caption := Format('"%s"', [FConfig[2].client_id]);
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  if button1.tag = 0 then begin
    Connect(0);
    button1.tag := 1;
    button1.caption := 'stop';
  end
  else begin
    disconnect(0);
    button1.tag := 0;
    button1.caption := 'start';
  end;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  if button2.tag = 0 then begin
    Connect(1);
    button2.tag := 1;
    button2.caption := 'stop';
  end
  else begin
    disconnect(1);
    button2.tag := 0;
    button2.caption := 'start';
  end;
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
  if button3.tag = 0 then begin
    Connect(2);
    button3.tag := 1;
    button3.caption := 'stop';
  end
  else begin
    disconnect(2);
    button3.tag := 0;
    button3.caption := 'start';
  end;
end;

procedure TForm1.Button4Click(Sender: TObject);
begin
  close;
end;

procedure TForm1.Button5Click(Sender: TObject);
var
  common: string;
  i: integer;
begin
  common := trim(Edit1.text);
  for i := 0 to CLIENT_COUNT-1 do
    if FConfig[i].client_id <> common then begin
      FConfig[i].client_id := common;
      if assigned(FClient[i]) then begin
        disconnect(i);
        Connect(i);
      end;
    end;
  updateIdLabels;
end;

procedure TForm1.FormActivate(Sender: TObject);
var
  msg: string;
begin
  if not mqtt_init(false) then begin
    try
      if mosquitto_lib_loaded then
        msg := 'Could not initialize mosquitto library'
      else
        msg := 'The required mosquitto library is not installed';
      MessageDlgPos(msg, mtError, [mbAbort], 0, left+50, top+150);
    finally
      halt;
    end;
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  ConfigClients;
  updateIdLabels;
  Label4.Caption := FConfig[0].hostname;
  Label5.Caption := FConfig[1].hostname;
  Label6.Caption := FConfig[2].hostname;
end;

procedure TForm1.FormDestroy(Sender: TObject);
var
  i: integer;
begin
  for i := 0 to CLIENT_COUNT-1 do
    freeandnil(FClient[i]);
end;

// logger file that will replace the default mqtt_log(const msg: ansistring);
// which writes msg to stdout
procedure mqttlog(const msg: ansistring);
var
  PMsg: PChar;
begin
  PMsg := StrAlloc(Length(msg)+1);
  StrCopy(PMsg, PChar(Msg));
  {$IFDEF WINDOWS}
  SendMessage(Form1.Handle, UM_WRITE_LOG, PtrUInt(PMsg), 0);
  {$ELSE}
  PostMessage(Form1.Handle, UM_WRITE_LOG, PtrUInt(PMsg), 0);
  {$ENDIF}
end;

initialization
  mqtt_setlogfunc(@mqttlog);
end.

