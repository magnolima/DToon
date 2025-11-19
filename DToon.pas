(***

DTonn 1.0 - Delphi Support Lib for Toon (Token-Oriented Object Notation)

While JSON is the standard for web APIs, it is "token-heavy" 
due to excessive punctuation (braces, quotes, commas). 
TOON solves this by using a clean, indentation-based syntax similar to YAML, 
but with the strict structural model of JSON.

Overview: https://toonformat.dev/guide/format-overview 

TOON models data the same way as JSON:
    - Primitives: strings, numbers, booleans, and null
    - Objects: mappings from string keys to values
    - Arrays: ordered sequences of values

Root Forms
  A TOON document can represent different root forms:
    - Root object (most common):
      Fields appear at depth 0 with no parent key
    - Root array:
      Begins with [N]: or [N]{fields}: at depth 0
    - Root primitive:
      A single primitive value (string, number, boolean, or null)

Author: Magno Lima
Version: 1.0
Compatible: Delphi 12+

License: MIT License (see LICENSE file)
***)
unit DToon;

interface

uses
  System.SysUtils, 
  System.Classes, 
  System.Generics.Collections, 
  System.RegularExpressions,
  System.StrUtils,
  System.Rtti;

type
  TToonNodeType = (tntObject, tntArray, tntString, tntNumber, tntBoolean, tntNull);

  TToonNode = class
  private
    FNodeType: TToonNodeType;
    FValue: string;
    FChildren: TObjectList<TToonNode>;
    FKey: string;
    FOwnsChildren: Boolean;
    function GetItem(Index: Integer): TToonNode;
    function GetCount: Integer;
    function GetPair(const KeyName: string): TToonNode;
  public
    constructor Create(AType: TToonNodeType; AKey: string = '');
    destructor Destroy; override;
	
	// Main properties
    property NodeType: TToonNodeType read FNodeType;
    property Value: string read FValue write FValue;
    property Key: string read FKey write FKey;
    property Items[Index: Integer]: TToonNode read GetItem; default;
    property Pair[const KeyName: string]: TToonNode read GetPair;
    property Count: Integer read GetCount;
    
	// Helpers
    function AddChild(AType: TToonNodeType; AKey: string = ''): TToonNode;
	function AsString: string;
    function AsInteger: Integer;
    function AsBoolean: Boolean;    
    
    // Debug: Print the tree as text.
    function ToString: string; override;
  end;

  TToonParser = class
  private
    FLines: TStringList;
    FRoot: TToonNode;
    
    function CalculateIndent(const Line: string): Integer;
    function ParseValue(const ValueStr: string): TToonNode;
    procedure ProcessLines;
  public
    constructor Create;
    destructor Destroy; override;
    
    function Parse(const AToonContent: string): TToonNode;
  end;

implementation

{ TToonNode }

constructor TToonNode.Create(AType: TToonNodeType; AKey: string);
begin
  FNodeType := AType;
  FKey := AKey;
  FChildren := TObjectList<TToonNode>.Create(True);
  FOwnsChildren := True;
end;

destructor TToonNode.Destroy;
begin
  FChildren.Free;
  inherited;
end;

function TToonNode.AddChild(AType: TToonNodeType; AKey: string): TToonNode;
begin
  Result := TToonNode.Create(AType, AKey);
  FChildren.Add(Result);
end;

function TToonNode.GetItem(Index: Integer): TToonNode;
begin
  Result := FChildren[Index];
end;

function TToonNode.GetCount: Integer;
begin
  Result := FChildren.Count;
end;

function TToonNode.GetPair(const KeyName: string): TToonNode;
var
  Node: TToonNode;
begin
  Result := nil;
  for Node in FChildren do
    if SameText(Node.Key, KeyName) then
      Exit(Node);
end;

function TToonNode.AsString: string;
begin
  Result := FValue;
end;

function TToonNode.AsInteger: Integer;
begin
  Result := StrToIntDef(FValue, 0);
end;

function TToonNode.AsBoolean: Boolean;
begin
  Result := SameText(FValue, 'true');
end;

function TToonNode.ToString: string;
var
  I: Integer;
begin
  Result := Format('%s (%s): %s', [FKey, TRttiEnumerationType.GetName(FNodeType), FValue]);
  if FChildren.Count > 0 then
  begin
    Result := Result + sLineBreak + '[';
    for I := 0 to FChildren.Count - 1 do
      Result := Result + sLineBreak + '  ' + FChildren[I].ToString;
    Result := Result + sLineBreak + ']';
  end;
end;

{ TToonParser }

constructor TToonParser.Create;
begin
  FLines := TStringList.Create;
end;

destructor TToonParser.Destroy;
begin
  FLines.Free;
  inherited;
end;

function TToonParser.CalculateIndent(const Line: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to Length(Line) do
  begin
    if Line[I] = ' ' then
      Inc(Result)
    else
      Break;
  end;
end;

function TToonParser.ParseValue(const ValueStr: string): TToonNode;
var
  LowerVal: string;
  iVal: Integer;
  dVal: Double;
begin
  LowerVal := LowerCase(Trim(ValueStr));
  
  if LowerVal = 'null' then
    Result := TToonNode.Create(tntNull)
  else if (LowerVal = 'true') or (LowerVal = 'false') then
  begin
    Result := TToonNode.Create(tntBoolean);
    Result.Value := LowerVal;
  end
  else if TryStrToInt(Trim(ValueStr), iVal) or TryStrToFloat(Trim(ValueStr), dVal) then
  begin
    Result := TToonNode.Create(tntNumber);
    Result.Value := Trim(ValueStr);
  end
  else
  begin
    Result := TToonNode.Create(tntString);
    Result.Value := Trim(ValueStr); // Remove quotes
  end;
end;

function TToonParser.Parse(const AToonContent: string): TToonNode;
begin
  FLines.Text := AToonContent;
  FRoot := TToonNode.Create(tntObject, 'root');
  try
    ProcessLines;
    Result := FRoot;
  except
    FRoot.Free;
    raise;
  end;
end;

procedure TToonParser.ProcessLines;
var
  I, J, CurrIndent, LevelIndent, ArrayCount: Integer;
  Line, TrimmedLine, KeyPart, HeadersPart, ValPart: string;
  Stack: TList<TPair<Integer, TToonNode>>; // Stack (Indent, Node)
  CurrentParent: TToonNode;
  Headers: TArray<string>;
  RowValues: TArray<string>;
  ChildNode, ArrayNode, ObjNode: TToonNode;
  RegexTabular: TRegEx;
  Match: TMatch;
begin
  Stack := TList<TPair<Integer, TToonNode>>.Create;
  try
    Stack.Add(TPair<Integer, TToonNode>.Create(-1, FRoot));

	// Regex to capture tabular format: key[3]{col1,col2}:
	// Group 1: Key, Group 2: Count, Group 3: Headers (optional)
    RegexTabular := TRegEx.Create('^([\w\d_]+)\[(\d+)\](?:\{([^}]+)\})?:?');

    I := 0;
    while I < FLines.Count do
    begin
      Line := FLines[I];
      TrimmedLine := Trim(Line);
      
      // Ignore empty lines or comments (#)
      if (TrimmedLine = '') or (TrimmedLine.StartsWith('#')) then
      begin
        Inc(I);
        Continue;
      end;

      CurrIndent := CalculateIndent(Line);

      // Find the correct parent based on the indentation.
      while (Stack.Count > 1) and (Stack.Last.Key >= CurrIndent) do
        Stack.Delete(Stack.Count - 1);
      
      CurrentParent := Stack.Last.Value;

      // Checks if it is a Tabular/Structured Array (Ex: users[2]{id,name}:)
      Match := RegexTabular.Match(TrimmedLine);
      if Match.Success then
      begin
        KeyPart := Match.Groups[1].Value;
        ArrayCount := StrToIntDef(Match.Groups[2].Value, 0);
        HeadersPart := Match.Groups[3].Value; // Pode ser vazio

        // Creates array node
        ArrayNode := CurrentParent.AddChild(tntArray, KeyPart);
        
        // If there are headers, we read the next N lines as CSV.
        if HeadersPart <> '' then
        begin
           Headers := HeadersPart.Split([',']);
           // Consume the next 'ArrayCount' rows.
           for J := 1 to ArrayCount do
           begin
             Inc(I);
             if I >= FLines.Count then Break;
             
             RowValues := Trim(FLines[I]).Split([','], Length(Headers)); // Split simples
             
             // One object per line
             ObjNode := ArrayNode.AddChild(tntObject);
             
             // Map headers to values
             var K: Integer;
             for K := 0 to High(Headers) do
             begin
               if K <= High(RowValues) then
               begin
                 ChildNode := ParseValue(RowValues[K]);
                 ChildNode.Key := Headers[K];
                 // Add a manual so you don't have to create another wrapper.
                 ObjNode.FChildren.Add(ChildNode); 
               end;
             end;
           end;
        end;
        // If there are no headers, it would be a simple list (not fully implemented here).
      end
      else if TrimmedLine.Contains(':') then
      begin
		// Standard Format: Key: Value
		// Note: full implementation needs to handle ':' within strings
        var SeparatorPos := Pos(':', TrimmedLine);
        KeyPart := Copy(TrimmedLine, 1, SeparatorPos - 1);
        ValPart := Copy(TrimmedLine, SeparatorPos + 1, MaxInt);

        if Trim(ValPart) = '' then
        begin
          // It's a nested object (the value is in the next indented lines)
          ChildNode := CurrentParent.AddChild(tntObject, Trim(KeyPart));
          Stack.Add(TPair<Integer, TToonNode>.Create(CurrIndent, ChildNode));
        end
        else
        begin
          // Scalar value (String, Number, etc)
          ChildNode := ParseValue(ValPart);
          ChildNode.Key := Trim(KeyPart);
          CurrentParent.FChildren.Add(ChildNode);
        end;
      end;

      Inc(I);
    end;
  finally
    Stack.Free;
  end;
end;

end.