# DToon - Delphi Support Lib for Toon (Token-Oriented Object Notation) 

`DToon` is a small Delphi unit that parses [TOON](https://toonformat.dev/guide/format-overview) documents into an in-memory tree structure.

It is based on the official TOON format overview and models data in a JSON-like way, but with a more human-friendly, indentation-based syntax.

---

## TOON Data Model

TOON models data the same way as JSON:

- **Primitives**
  - strings  
  - numbers  
  - booleans  
  - `null`

- **Objects**
  - mappings from string keys to values

- **Arrays**
  - ordered sequences of values

---

## Root Forms

A TOON document can represent different root forms:

- **Root object (most common)**  
  Fields appear at depth `0` with no parent key.

- **Root array**  
  Begins with:

  - `[N]:`  
  - or `[N]{fields}:`  

  at depth `0`, where `N` is the array length.

- **Root primitive**  
  A single primitive value (string, number, boolean, or `null`).

---

## Main Types

The unit exposes two core classes:

### `TToonNode`

Represents a node in the TOON tree:

- `NodeType: TToonNodeType` – kind of node:
  - `tntObject`, `tntArray`, `tntString`, `tntNumber`, `tntBoolean`, `tntNull`
- `Key: string` – field name (for object children)
- `Value: string` – raw string value for primitive nodes
- `Items[Index: Integer]: TToonNode` – indexed access to children
- `Pair[const KeyName: string]: TToonNode` – access by key (for objects)
- `Count: Integer` – number of children

Helper methods:

- `AddChild(AType: TToonNodeType; AKey: string = ''): TToonNode`
- `AsString: string`
- `AsInteger: Integer`
- `AsBoolean: Boolean`
- `ToString: string` – debug: prints the subtree as text

---

### `TToonParser`

Parses a TOON document from a string into a `TToonNode` tree:

- `function Parse(const AToonContent: string): TToonNode;`

Internally it:

- splits content into lines,
- calculates indentation depth,
- builds a stack of parent nodes,
- creates object/array/primitive nodes according to TOON rules.

---

## Basic Usage

```pascal
uses
  DToon;

procedure DemoToon;
const
  CToonSample =
    'name: "Example"' + sLineBreak +
    'version: 1'       + sLineBreak +
    'enabled: true'    + sLineBreak +
    'items[2]:'        + sLineBreak +
    '  0: "foo"'       + sLineBreak +
    '  1: "bar"';
var
  Parser: TToonParser;
  Root: TToonNode;
begin
  Parser := TToonParser.Create;
  try
    Root := Parser.Parse(CToonSample);

    // Object fields
    Writeln('Name: ',    Root.Pair['name'].AsString);
    Writeln('Version: ', Root.Pair['version'].AsInteger);
    Writeln('Enabled: ', BoolToStr(Root.Pair['enabled'].AsBoolean, True));

    // Array items
    Writeln('First item: ', Root.Pair['items'][0].AsString);

    // Debug print
    Writeln(Root.ToString);
  finally
    Parser.Free;
  end;
end;
```

## Requirements

- Delphi (any modern version with:
  - System.SysUtils
  - System.Classes
  - System.Generics.Collections
  - System.RegularExpressions
  - System.StrUtils
- No external dependencies beyond the RTL.

## License
This project is licensed under the Apache License 2.0 - see the [Apache License](LICENSE). file for details.

