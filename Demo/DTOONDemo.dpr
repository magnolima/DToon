program DTOONDemo;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  DToon in '..\DToon.pas';

const
	// This TOON content tests:
	// 1. Flattened keys (server.config.ip)
	// 2. Standard indentation mixing
	// 3. Tabular arrays with commas inside quotes ("New York, NY")
	cTestContent =
		'# 1. Flattened Dot Notation' + sLineBreak +
		'server.config.ip: 192.168.1.1' + sLineBreak +
		'server.config.port: 8080' + sLineBreak +
		'' + sLineBreak +
		'# 2. Standard Indentation' + sLineBreak +
		'meta:' + sLineBreak +
		'  author: "Magno"' + sLineBreak +
		'  version: 1.5' + sLineBreak +
		'' + sLineBreak +
		'# 3. Tabular Array with Quoted CSV (Commas inside)' + sLineBreak +
		'users[2]{id, name, location}' + sLineBreak +
		'1, "Alice", "New York, NY"' + sLineBreak +
		'2, "Bob", "Washington, DC"';

procedure RunTest;
var
	Parser: TToonParser;
  Root, ServerNode, UserNode: TToonNode;
begin
  Parser := TToonParser.Create;
	try
    WriteLn('--- Parsing TOON Content ---');
    Root := Parser.Parse(cTestContent);
		try
			// Accessing flat data
			// Although defined as "server.config.ip", the parser will build the tree
			// Root -> server -> config -> ip
			WriteLn('1. Checking Flattened Data:');
			if Root.FindChild('server') <> nil then
			begin
				ServerNode := Root.Pair['server'].Pair['config'];
				WriteLn('   Server IP: ' + ServerNode.Pair['ip'].Value);
				WriteLn('   Server Port: ' + ServerNode.Pair['port'].Value);
			end;

			// Accessing array with commas
			WriteLn(sLineBreak + '2. Checking Smart CSV (Commas in quotes):');
			if Root.FindChild('users') <> nil then
			begin
				// Get the first user (Index 0)
				UserNode := Root.Pair['users'].Items[0];

        WriteLn('   User Name: ' + UserNode.Pair['name'].Value);

        // This verifies the splitter didn't break on "New York, NY"
        WriteLn('   User Location: ' + UserNode.Pair['location'].Value);
      end;

      WriteLn(sLineBreak + '--- Full Tree Dump ---');
      WriteLn(Root.ToString);

    finally
      Root.Free; // Root owns all children
    end;

  finally
    Parser.Free;
  end;
end;

begin
  try
    RunTest;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

  WriteLn(sLineBreak + 'Press Enter to exit...');
  ReadLn;
end.
