unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, DBGrids, DBCtrls,
  StdCtrls, ExtCtrls, Spin, XMLPropStorage, DividerBevel, ACBrMail, ACBrSedex,
  DB, BufDataset;

type

  { TForm1 }

  TForm1 = class(TForm)
    ACBrMail1: TACBrMail;
    ACBrSedex1: TACBrSedex;
    BufDataset1: TBufDataset;
    BufDataset1CODIGO: TStringField;
    BufDataset1EVENTOS: TLongintField;
    BufDataset1ULTIMO_EVENTO: TMemoField;
    ckbSSL: TCheckBox;
    ckbTLS: TCheckBox;
    DataSource1: TDataSource;
    DBGrid1: TDBGrid;
    DBNavigator1: TDBNavigator;
    DividerBevel2: TDividerBevel;
    edtSMTP: TEdit;
    edtUsuario: TEdit;
    edtSenha: TEdit;
    edtDestinatario: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    edtPorta: TSpinEdit;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    mmoLog: TMemo;
    Timer1: TTimer;
    ToggleBox1: TToggleBox;
    XMLPropStorage1: TXMLPropStorage;
    procedure ACBrMail1MailException(const AMail: TACBrMail;
      const E: Exception; var ThrowIt: Boolean);
    procedure BufDataset1NewRecord(DataSet: TDataSet);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure ToggleBox1Change(Sender: TObject);
  private
    procedure ApplicationException(Sender: TObject; E: Exception);
    procedure EnviarEmail;
    procedure Form1Activate(Sender: TObject);
    procedure Log(Mensagem: string);
  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.FormShow(Sender: TObject);
begin
  if FileExists('dados.bin') then
    BufDataset1.LoadFromFile('dados.bin')
  else
    BufDataset1.CreateDataset;

  BufDataset1.Open;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
var
  I: Integer;
begin
  BufDataset1.DisableControls;
  Timer1.Enabled := False;
  try
    BufDataset1.First;
    while not BufDataset1.EOF do
    begin
      if not ToggleBox1.Checked then Exit;

      ACBrSedex1.Rastrear(BufDataset1CODIGO.AsString);

      I := ACBrSedex1.retRastreio.Count;
      if (I > 0) and
         (I > BufDataset1EVENTOS.AsInteger) then
      begin
        Log('Há novidades para o código ' + BufDataset1CODIGO.AsString);

        BufDataset1.Edit;
        BufDataset1EVENTOS.AsInteger      := I;
        BufDataset1ULTIMO_EVENTO.AsString := Format(
          '%s - %s',
            [ACBrSedex1.retRastreio[Pred(I)].Local,
             ACBrSedex1.retRastreio[Pred(I)].Situacao]);
        BufDataset1.Post;

        EnviarEmail;
      end;
      BufDataset1.Next;
    end;
  finally
    BufDataset1.EnableControls;
    Timer1.Enabled := True;
  end;
end;

procedure TForm1.ToggleBox1Change(Sender: TObject);
begin
  Timer1.Interval      := 30 * 60 * 1000;
  Timer1.Enabled       := ToggleBox1.Checked;
  DBGrid1.Enabled      := not ToggleBox1.Checked;
  DBNavigator1.Enabled := DBGrid1.Enabled;
  Timer1Timer(Sender);
end;

procedure TForm1.ApplicationException(Sender: TObject; E: Exception);
begin
  Log('Ocorreu um erro.');
  Log('Mensagem do sistema');
  Log(E.Message);
end;

procedure TForm1.EnviarEmail;
var
  I: Integer;
begin
  ACBrMail1.Port     := edtPorta.Text;
  ACBrMail1.HOST     := edtSMTP.Text;
  ACBrMail1.Username := edtUsuario.Text;
  ACBrMail1.From     := edtUsuario.Text;
  ACBrMail1.Password := edtSenha.Text;
  ACBrMail1.FromName := 'Lazarus Streaming Day';
  ACBrMail1.Subject  := 'Atualização no status da entrega';
  ACBrMail1.IsHTML   := False;
  ACBrMail1.SetSSL   := ckbSSL.Checked;
  ACBrMail1.SetTLS   := ckbTLS.Checked;
  ACBrMail1.AddAddress(edtDestinatario.Text);

  I := Pred(ACBrSedex1.retRastreio.Count);

  ACBrMail1.AltBody.Clear;

  ACBrMail1.AltBody.Add(
    'Informações sobre sua entrega ' + BufDataset1CODIGO.AsString);

  ACBrMail1.AltBody.Add(sLineBreak);

  ACBrMail1.AltBody.Add(
    'Local: ' + ACBrSedex1.retRastreio[I].Local);

  ACBrMail1.AltBody.Add(sLineBreak);

  ACBrMail1.AltBody.Add(
    'DataHora: ' + FormatDateTime('dd/mm/yyyy', ACBrSedex1.retRastreio[I].DataHora));

  ACBrMail1.AltBody.Add(sLineBreak);

  ACBrMail1.AltBody.Add(
    'Situação: ' + ACBrSedex1.retRastreio[I].Situacao);

  ACBrMail1.AltBody.Add(sLineBreak);

  ACBrMail1.AltBody.Add(
    'Observacao: ' + ACBrSedex1.retRastreio[I].Observacao);

  ACBrMail1.Send(False);

  Log('E-mail enviado com sucesso!');
end;

procedure TForm1.Form1Activate(Sender: TObject);
begin

end;

procedure TForm1.Log(Mensagem: string);
begin
  mmoLog.Lines.Add(Mensagem);
end;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  BufDataset1.SaveToFile('dados.bin');
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Application.OnException := @ApplicationException;
  //Form1.OnActivate:=@Form1Activate;

  with FormatSettings do
  begin
    CurrencyString      := 'R$';
    CurrencyFormat      := 2;
    DecimalSeparator    := ',';
    ThousandSeparator   := '.';
    DateSeparator       := '/';
    ShortDateFormat     := 'dd/mm/yyy';
    LongDateFormat      := 'dddd, dd "de" mmmm "de" yyy';
    LongMonthNames[1]   := 'Janeiro';
    LongMonthNames[2]   := 'Fevereiro';
    LongMonthNames[3]   := 'Março';
    LongMonthNames[4]   := 'Abril';
    LongMonthNames[5]   := 'Maio';
    LongMonthNames[6]   := 'Junho';
    LongMonthNames[7]   := 'Julho';
    LongMonthNames[8]   := 'Agosto';
    LongMonthNames[9]   := 'Setembro';
    LongMonthNames[10]  := 'Outubro';
    LongMonthNames[11]  := 'Novembro';
    LongMonthNames[12]  := 'Dezembro';
    ShortMonthNames[1]  := 'Jan';
    ShortMonthNames[2]  := 'Fev';
    ShortMonthNames[3]  := 'Mar';
    ShortMonthNames[4]  := 'Abr';
    ShortMonthNames[5]  := 'Mai';
    ShortMonthNames[6]  := 'Jun';
    ShortMonthNames[7]  := 'Jul';
    ShortMonthNames[8]  := 'Ago';
    ShortMonthNames[9]  := 'Set';
    ShortMonthNames[10] := 'Out';
    ShortMonthNames[11] := 'Nov';
    ShortMonthNames[12] := 'Dez';
    LongDayNames[1]     := 'Domingo';
    LongDayNames[2]     := 'Segunda';
    LongDayNames[3]     := 'Terça';
    LongDayNames[4]     := 'Quarta';
    LongDayNames[5]     := 'Quinta';
    LongDayNames[6]     := 'Sexta';
    LongDayNames[7]     := 'Sábado';
    ShortDayNames[1]    := 'Dom';
    ShortDayNames[2]    := 'Seg';
    ShortDayNames[3]    := 'Ter';
    ShortDayNames[4]    := 'Qua';
    ShortDayNames[5]    := 'Qui';
    ShortDayNames[6]    := 'Sex';
    ShortDayNames[7]    := 'Sáb';
  end;
end;

procedure TForm1.BufDataset1NewRecord(DataSet: TDataSet);
begin
  BufDataset1EVENTOS.AsInteger := 0;
end;

procedure TForm1.ACBrMail1MailException(const AMail: TACBrMail;
  const E: Exception; var ThrowIt: Boolean);
begin
  Log('Ocorreu um erro ao enviar o email.');
  Log('Mensagem do sistema');
  Log(E.Message);
end;

end.

