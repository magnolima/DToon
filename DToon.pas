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
    property NodeType: TToonNodeType read FNodeType write FNodeType;
    property Value: string read FValue write FValue;
    property Key: string read FKey write FKey;
    property Items[Index: Integer]: TToonNode read GetItem; default;
    property Pair[const KeyName: string]: TToonNode read GetPair;
    property Count: Integer read GetCount;

    // Helpers
		function AddChild(AType: TToonNodeType; AKey: string = ''): TToonNode;
    function FindChild(const AKey: string): TToonNode; // Helper for Dot Notation
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
    function SmartSplitCSV(const Line: string; ExpectedCount: Integer): TArray<string>;
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

function TToonNode.FindChild(const AKey: string): TToonNode;
var
	Node: TToonNode;
begin
  Result := nil;
	for Node in FChildren do
		//Use SameText for lookup robustness, but keys are stored case-sensitive
    if SameText(Node.Key, AKey) then
      Exit(Node);
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
begin
  Result := FindChild(KeyName);
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

// Robust CSV splitting (handles commas inside quotes)
function TToonParser.SmartSplitCSV(const Line: string; ExpectedCount: Integer): TArray<string>;
var
  I, Len: Integer;
  InQuote: Boolean;
  CurrentToken: string;
  Tokens: TList<string>;
  C: Char;
begin
  Tokens := TList<string>.Create;
  try
    InQuote := False;
    CurrentToken := '';
    Len := Length(Line);

    for I := 1 to Len do
    begin
      C := Line[I];
      if C = '"' then
        InQuote := not InQuote // Toggle quote state
      else if (C = ',') and (not InQuote) then
      begin
				Tokens.Add(Trim(CurrentToken));
        CurrentToken := '';
      end
      else
        CurrentToken := CurrentToken + C;
    end;
    Tokens.Add(Trim(CurrentToken)); // Add last token

    Result := Tokens.ToArray;
  finally
    Tokens.Free;
  end;
end;

function TToonParser.ParseValue(const ValueStr: string): TToonNode;
var
  LowerVal: string;
  iVal: Integer;
  dVal: Double;
  CleanVal: string;
begin
	// Remove surrounding quotes if they exist
	CleanVal := ValueStr;
  if (Length(CleanVal) >= 2) and (CleanVal.StartsWith('"')) and (CleanVal.EndsWith('"')) then
    CleanVal := Copy(CleanVal, 2, Length(CleanVal) - 2);

  LowerVal := LowerCase(CleanVal);

  if LowerVal = 'null' then
    Result := TToonNode.Create(tntNull)
  else if (LowerVal = 'true') or (LowerVal = 'false') then
  begin
    Result := TToonNode.Create(tntBoolean);
    Result.Value := LowerVal;
  end
  else if TryStrToInt(CleanVal, iVal) or TryStrToFloat(CleanVal, dVal) then
  begin
    Result := TToonNode.Create(tntNumber);
    Result.Value := CleanVal;
  end
  else
  begin
    Result := TToonNode.Create(tntString);
    Result.Value := CleanVal;
  end;
end;

function TToonParser.Parse(const AToonContent: string): TToonNode;
begin
  FLines.Text := AToonContent;
  // Default to object, but ProcessLines might morph it into an Array for Root Arrays
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
	I, J, K, CurrIndent, ArrayCount: Integer;
  Line, TrimmedLine, KeyPart, HeadersPart, ValPart: string;
  Stack: TList<TPair<Integer, TToonNode>>;
  CurrentParent, ChildNode, ArrayNode, ObjNode, PathNode: TToonNode;
  Headers, RowValues, KeyPath: TArray<string>;
  RegexTabular: TRegEx;
  Match: TMatch;
  SeparatorPos: Integer;
begin
  Stack := TList<TPair<Integer, TToonNode>>.Create;
  try
    Stack.Add(TPair<Integer, TToonNode>.Create(-1, FRoot));
		//
		// 1. Key is now optional/wildcard ([\w\d_\.]*) to support Root Arrays [N]
    // 2. Key supports dots for flattening logic
    RegexTabular := TRegEx.Create('^([\w\d_\.]*)\[(\d+)\](?:\{([^}]+)\})?:?');

    I := 0;
    while I < FLines.Count do
    begin
      Line := FLines[I];
      TrimmedLine := Trim(Line);

      if (TrimmedLine = '') or (TrimmedLine.StartsWith('#')) then
      begin
        Inc(I);
        Continue;
      end;

      CurrIndent := CalculateIndent(Line);

      // Context Management
      while (Stack.Count > 1) and (Stack.Last.Key >= CurrIndent) do
        Stack.Delete(Stack.Count - 1);
      CurrentParent := Stack.Last.Value;

      // ---------------------------------------------------------
			// Tabular Array (e.g., users[2]... OR [2]...)
			// ---------------------------------------------------------
			Match := RegexTabular.Match(TrimmedLine);
			if Match.Success then
			begin
				KeyPart := Match.Groups[1].Value;
				ArrayCount := StrToIntDef(Match.Groups[2].Value, 0);
				HeadersPart := Match.Groups[3].Value;

				// Handle Root Array (Empty Key)
				if KeyPart = '' then
				begin
					 // Convert the Root Object to an Array type conceptually
					 // (Or just append to it if we treat Root as the container)
					 FRoot.NodeType := tntArray;
					 ArrayNode := FRoot;
				end
				else
				begin
					// Handle Dot Notation for Array Keys (e.g., data.users[2])
					KeyPath := KeyPart.Split(['.']);
					for K := 0 to High(KeyPath) - 1 do
					begin
						 PathNode := CurrentParent.FindChild(KeyPath[K]);
						 if PathNode = nil then
							 PathNode := CurrentParent.AddChild(tntObject, KeyPath[K]);
						 CurrentParent := PathNode;
					end;
					// Create the actual array
					ArrayNode := CurrentParent.AddChild(tntArray, KeyPath[High(KeyPath)]);
				end;

				if HeadersPart <> '' then
				begin
					 Headers := HeadersPart.Split([',']);

					 for K := 0 to High(Headers) do
						 Headers[K] := Trim(Headers[K]);

					 for J := 1 to ArrayCount do
					 begin
						 Inc(I);
						 if I >= FLines.Count then Break;

						 // Use SmartSplitCSV instead of simple Split
						 RowValues := SmartSplitCSV(Trim(FLines[I]), Length(Headers));

						 ObjNode := ArrayNode.AddChild(tntObject);
						 for K := 0 to High(Headers) do
						 begin
							 if K <= High(RowValues) then
							 begin
								 ChildNode := ParseValue(RowValues[K]);
								 // Preserve Header Case
								 ChildNode.Key := Headers[K];
								 ObjNode.FChildren.Add(ChildNode);
							 end;
						 end;
					 end;
				end;
			end
			// ---------------------------------------------------------
			// Standard Key: Value (with Path Compression)
			// ---------------------------------------------------------
			else if TrimmedLine.Contains(':') then
			begin
				SeparatorPos := Pos(':', TrimmedLine);
				KeyPart := Trim(Copy(TrimmedLine, 1, SeparatorPos - 1));
				ValPart := Trim(Copy(TrimmedLine, SeparatorPos + 1, MaxInt));

				// Dot Notation Flattening
				KeyPath := KeyPart.Split(['.']);

				for K := 0 to High(KeyPath) - 1 do
				begin
					PathNode := CurrentParent.FindChild(KeyPath[K]);
					if PathNode = nil then
						PathNode := CurrentParent.AddChild(tntObject, KeyPath[K]);
					CurrentParent := PathNode;
				end;

				KeyPart := KeyPath[High(KeyPath)];

				if ValPart = '' then
				begin
					// Nested Object Start
					ChildNode := CurrentParent.AddChild(tntObject, KeyPart);
					Stack.Add(TPair<Integer, TToonNode>.Create(CurrIndent, ChildNode));
				end
				else
				begin
					// Scalar Value
					ChildNode := ParseValue(ValPart);
					ChildNode.Key := KeyPart; // Preserves Key Case
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
