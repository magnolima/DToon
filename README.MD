# DToon - Delphi Support Lib for Toon (Token-Oriented Object Notation) 

**DToon** is a lightweight Delphi library for parsing **TOON (Token-Oriented Object Notation)**, a modern data serialization format designed specifically for the AI era.

It is based on the official TOON format overview [TOON](https://toonformat.dev/guide/format-overview) and models data in a JSON-like way, but with a more human-friendly, indentation-based syntax.

### What is TOON?
While JSON is the standard for web APIs, it is "token-heavy" due to excessive punctuation (braces, quotes, commas). TOON solves this by using a clean, indentation-based syntax similar to YAML, but with the strict structural model of JSON.

**Key Benefits:**
* **Token Efficiency:** Reduces token usage by removing syntactic noise, saving costs and context window space in LLM interactions.
* **High Density:** Supports "Table Arrays" (e.g., `users[N]{fields}`), allowing lists of objects to be represented as dense CSV-like rows.
* **Human Readable:** Easier to read and edit manually than minified JSON.

DToon brings this efficiency to the Delphi ecosystem, allowing you to easily integrate token-optimized data streams into your applications.

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

##
Standard TOON (like YAML) excels at readability but suffers with arrays of objects. Repeating keys and indentation for every item wastes tokens.
Uniform arrays are converted into a tabular format supported TToonParser. This separates schema from data, drastically reducing overhead.

Json:
```json
{
  "meta": {
    "version": "1.0",
    "generated": "2023-10-27"
  },
  "users": [
    {
      "id": 101,
      "name": "Alice Johnson",
      "role": "Admin",
      "active": true,
      "login_count": 42
    },
    {
      "id": 102,
      "name": "Bob Smith",
      "role": "Editor",
      "active": true,
      "login_count": 15
    },
    {
      "id": 103,
      "name": "Charlie Brown",
      "role": "Viewer",
      "active": false,
      "login_count": 3
    },
    {
      "id": 104,
      "name": "Diana Prince",
      "role": "Admin",
      "active": true,
      "login_count": 128
    },
    {
      "id": 105,
      "name": "Evan Wright",
      "role": "Viewer",
      "active": true,
      "login_count": 0
    }
  ],
  "inventory": [
    {
      "sku": "WID-001",
      "desc": "Widget A",
      "stock": 500,
      "price": 19.99
    },
    {
      "sku": "WID-002",
      "desc": "Widget B",
      "stock": 0,
      "price": 25.5
    },
    {
      "sku": "GAD-001",
      "desc": "Gadget X",
      "stock": 120,
      "price": 99
    }
  ]
}
```

Standard TOON (Nested)
```
meta:
  version: 1.0
  generated: 2023-10-27
users:
  item_0:
    id: 101
    name: Alice Johnson
    role: Admin
    active: true
    login_count: 42
  item_1:
    id: 102
    name: Bob Smith
    role: Editor
    active: true
    login_count: 15
  item_2:
    id: 103
    name: Charlie Brown
    role: Viewer
    active: false
    login_count: 3
  item_3:
    id: 104
    name: Diana Prince
    role: Admin
    active: true
    login_count: 128
  item_4:
    id: 105
    name: Evan Wright
    role: Viewer
    active: true
    login_count: 0
inventory:
  item_0:
    sku: WID-001
    desc: Widget A
    stock: 500
    price: 19.99
  item_1:
    sku: WID-002
    desc: Widget B
    stock: 0
    price: 25.5
  item_2:
    sku: GAD-001
    desc: Gadget X
    stock: 120
    price: 99
```

Optimized TOON (Flat)
```
meta:
  version: 1.0
  generated: 2023-10-27
users[5]{id,name,role,active,login_count}:
  101,Alice Johnson,Admin,true,42
  102,Bob Smith,Editor,true,15
  103,Charlie Brown,Viewer,false,3
  104,Diana Prince,Admin,true,128
  105,Evan Wright,Viewer,true,0
inventory[3]{sku,desc,stock,price}:
  WID-001,Widget A,500,19.99
  WID-002,Widget B,0,25.5
  GAD-001,Gadget X,120,99
```

| Token Usage Analysis   |  Usage                |
|------------------------|----------------------:|
| JSON                   | 100%  ██████████████  |
| Standard TOON (Nested) |  74%  ██████████░░░░  |
| Optimized TOON (Flat)  |  35%  █████░░░░░░░░░  |
* Based on character count approximation (1 token ≈ 4 chars). Actual LLM tokenization may vary slightly.

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
This project is licensed under the MIT License - see the [LICENSE](LICENSE). file for details.

