\# DToon – Delphi TOON Parser



`DToon` is a small Delphi unit that parses \[TOON](https://toonformat.dev/guide/format-overview) documents into an in-memory tree structure.



It is intended as a simple, self-contained helper for projects that want a human-friendly, JSON-like configuration or data format in Delphi.



---



\## TOON Data Model (short version)



TOON models data in a way that is very close to JSON:



\- \*\*Primitives\*\*  

&nbsp; - strings  

&nbsp; - numbers  

&nbsp; - booleans  

&nbsp; - `null`



\- \*\*Objects\*\*  

&nbsp; - mappings from string keys to values



\- \*\*Arrays\*\*  

&nbsp; - ordered sequences of values



\### Root Forms



A TOON document can represent different \*root\* forms:



\- \*\*Root object\*\* (most common)  

&nbsp; Fields appear at depth `0` with no parent key.



\- \*\*Root array\*\*  

&nbsp; Begins with:



&nbsp; - `\[N]:` \*\*or\*\*

&nbsp; - `\[N]{fields}:`



&nbsp; at depth `0`, where `N` is the array length.



\- \*\*Root primitive\*\*  

&nbsp; A single primitive value (string, number, boolean, or `null`).



---



\## What this unit provides



The `DToon` unit exposes two main types:



\### `TToonNode`



Represents a node in the parsed TOON tree.



```pascal

type

&nbsp; TToonNodeType = (tntObject, tntArray, tntString, tntNumber, tntBoolean, tntNull);



&nbsp; TToonNode = class

&nbsp; private

&nbsp;   FNodeType: TToonNodeType;

&nbsp;   FValue: string;

&nbsp;   FChildren: TObjectList<TToonNode>;

&nbsp;   FKey: string;

&nbsp;   function GetItem(Index: Integer): TToonNode;

&nbsp;   function GetCount: Integer;

&nbsp;   function GetPair(const KeyName: string): TToonNode;

&nbsp; public

&nbsp;   constructor Create(ANodeType: TToonNodeType; const AKey: string = '');

&nbsp;   destructor Destroy; override;



&nbsp;   property NodeType: TToonNodeType read FNodeType;

&nbsp;   property Key: string read FKey;

&nbsp;   property Value: string read FValue write FValue;



&nbsp;   /// Children for object/array nodes

&nbsp;   property Children\[Index: Integer]: TToonNode read GetItem; default;

&nbsp;   property Count: Integer read GetCount;



&nbsp;   /// Access child node by key (for objects)

&nbsp;   property Pair\[const KeyName: string]: TToonNode read GetPair;



&nbsp;   // Helpers

&nbsp;   function AddChild(AType: TToonNodeType; AKey: string = ''): TToonNode;

&nbsp;   function AsString: string;

&nbsp;   function AsInteger: Integer;

&nbsp;   function AsBoolean: Boolean;



&nbsp;   // Debug helper – prints the subtree as text

&nbsp;   function ToString: string; override;

&nbsp; end;



