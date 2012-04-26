
private enum Token {
	TData( str : String );
	TSpace;
	TNewLine;
	TBlockEnd;
	TEof;
	THead( count : Int );
	TTagOpen( name : String, attrib : String );
	TTagClose( name : String );
	TNodeOpen( name : String, attrib : String );
	TNodeClose( name : String );
	TList( count : Int );
	TDouble( c : Int );
}

private enum FlowItem {
	Paragraph( f : Flow );
	Heading( k : Int, f : Flow );
	Span( t : String, attrib : String, f : Flow );
	Div( t : String, attrib : String, f : Flow );
	Node( t : String, attrib : String, f : Flow );
	Li( items : Array<FlowItem> );
	Text( s : String );
	LineBreak;
	Space;
}

private typedef Flow = Array<FlowItem>;

class Format {

	static var SPECIAL_CHARS = "\r\n \t=[*/<'-";
	static var STABLE = {
		var t = [];
		for( i in 0...SPECIAL_CHARS.length )
			t[SPECIAL_CHARS.charCodeAt(i)] = true;
		t;
	}

	var pos : Int;
	var buf : String;
	var openedTags : Array<String>;
	var inSpan : Int;
	var inList : Int;
	var newLine : Bool;
	var cachedTokens : haxe.FastList<Token>;
	var outBuf : StringBuf;

	public function new() {
	}

	public dynamic function formatTag( t : String, attrib : Null<String>, span : Bool ) : Array<String> {
		return switch( t ) {
		case "g", "b", "strong", "star": ["<strong>","</strong>"];
		case "i", "em", "slash": ["<em>","</em>"];
		case "h1", "h2", "h3": ["<"+t+">","</"+t+">"];
		case "quote": ["<code>","</code>"];
		case "link", "lien":
			var rlink = ~/^(https?:\/\/[a-zA-Z0-9\/?;&%_.#=|-]+)/;
			var url = if( attrib == null || !rlink.match(attrib) ) '#' else rlink.matched(1);
			['<a href="' + url + '" target="_blank">','</a>'];
		default:
			if( span )
				['<span class="' + t + '">','</span>'];
			else
				['<div class="' + t + '">','</div>'];
		}
	}

	public dynamic function formatPlainText( t : String ) {
		t = StringTools.htmlEscape(t);
		// insec
		t = t.split(" !").join("&nbsp;!").split(" :").join("&nbsp;:").split(" ?").join("&nbsp;?");
		// autolinks
		t = ~/(https?:\/\/[a-zA-Z0-9\/?;&%_.#=|-]+)/.customReplace(t, function(r) {
			var url = r.matched(1);
			return '<a href="'+url+'" target="_blank">'+(url.length > 40 ? url.substr(0,37)+"..." : url)+'</a>';
		});
		// image
		t = ~/@([A-Za-z0-9_\/.]+)@/g.replace(t, '<img src="$1"/>');
		return t;
	}

	public dynamic function formatNode( node : String, attrib : Null<String>, content : String ) {
		if( node == "html" )
			return content;
		return null;
	}

	public function format( s : String ) {
		this.buf = s;
		this.pos = 0;
		inSpan = 0;
		inList = 0;
		newLine = true;
		openedTags = new Array();
		cachedTokens = new haxe.FastList<Token>();
		var flow = [];
		while( true ) {
			var t = token();
			if( t == TEof ) break;
			push(t);
			flow.push(parseBlock(false));
		}
		openedTags = [];
		outBuf = new StringBuf();
		printFlow(flow);
		flow = null;
		return outBuf.toString();
	}

	function outTag(?a:Array<String>) {
		if( a == null ) {
			outBuf.add(openedTags.pop());
			return;
		}
		openedTags.push(a[1]);
		outBuf.add(a[0]);
	}

	function printFlow( f : Flow ) {
		var text = null;
		for( i in f )
			switch( i ) {
			case Text(str): if( text == null ) text = str else text += str;
			default:
				if( text != null ) {
					outBuf.add(formatPlainText(text));
					text = null;
				}
				printItem(i);
			}
		if( text != null ) {
			outBuf.add(formatPlainText(text));
			text = null;
		}
	}

	function printItem(f) {
		switch( f ) {
		case Paragraph(f):
			outTag(["<p>","</p>"]);
			printFlow(f);
			outTag();
		case Li(item):
			outTag(["<ul>","</ul>"]);
			for( i in item ) {
				outTag(["<li>","</li>"]);
				switch( i ) {
				case Paragraph(f): printFlow(f);
				default: printItem(i);
				}
				outTag();
			}
			outTag();
		case Heading(k, f):
			var tt = formatTag("h" + (k + 1), null, false);
			if( tt == null ) {
				var f = f.copy();
				f.unshift(Text(tokenStr(THead(k))));
				f.push(Text(tokenStr(THead(k))));
				printFlow(f);
			} else {
				outTag(tt);
				printFlow(f);
				outTag();
			}
		case Text(str):
			outBuf.add(formatPlainText(str));
		case Span(t, a, f):
			var tt = formatTag(t, a, true);
			if( tt == null ) {
				var f = f.copy();
				f.unshift(Text(tokenStr(TTagOpen(t, a))));
				f.push(Text(tokenStr(TTagClose(t))));
				printFlow(f);
			} else {
				outTag(tt);
				printFlow(f);
				outTag();
			}
		case Div(t, a, f):
			var tt = formatTag(t, a, false);
			if( tt == null ) {
				var f = f.copy();
				f.unshift(Text(tokenStr(TTagOpen(t, a))));
				f.push(Text(tokenStr(TTagClose(t))));
				printFlow(f);
			} else {
				outTag(tt);
				printFlow(f);
				outTag();
			}
		case Node(t, a, f):
			var old = outBuf;
			outBuf = new StringBuf();
			for( f in f )
				switch( f ) {
				case Text(s): outBuf.add(s);
				default: printItem(f);
				}
			var str = outBuf.toString();
			outBuf = old;
			var r = formatNode(t, a, str);
			if( r == null )
				printFlow([Text(tokenStr(TNodeOpen(t, a)) + str + tokenStr(TNodeClose(t)))]);
			else
				outBuf.add(r);
		case Space:
			outBuf.add(" ");
		case LineBreak:
			outBuf.add("<br/>");
		}
	}

	inline function push(t) {
		cachedTokens.add(t);
	}

	function tokenStr(t) {
		return switch(t) {
		case TData(str): str;
		case TSpace: " ";
		case TNewLine: "\n";
		case TEof: "<eof>";
		case THead(count): "======".substr(0, 6 - count);
		case TTagOpen(name,attrib): "[" + name + (attrib == null ? "" : "="+attrib) + "]";
		case TTagClose(name): "[/" + name + "]";
		case TList(count): " *";
		case TBlockEnd: "\n\n";
		case TNodeOpen(name, attrib): "<" + name + (attrib == null ? "" : " " + attrib) + ">";
		case TNodeClose(name): "</" + name + ">";
		case TDouble(c): var c = String.fromCharCode(c); c + c;
		};
	}

	function ignoreEnd() {
		if( inList > 0 ) return;
		var t = token();
		if( t != TBlockEnd && t != TNewLine )
			push(t);
	}

	function parseBlock(limited) {
		var t = token();
		switch( t ) {
		case TEof:
			if( limited )
				return null;
		case THead(count):
			var f = parseFlow();
			var t2 = token();
			if( !Type.enumEq(t2, t) ) {
				push(t2);
				f.unshift(Text(tokenStr(t)));
				return Paragraph(f);
			}
			ignoreEnd();
			return Heading(count, f);
		case TBlockEnd:
			if( limited ) {
				push(t);
				return null;
			}
		case TSpace:
			return parseBlock(limited);
		case TNewLine:
			return inSpan == 0 ? LineBreak : parseBlock(limited);
		case TList(count):
			var items = [];
			inList++;
			while( true ) {
				var b = parseBlock(true);
				if( b == null ) break;
				items.push(b);
				do {
					t = token();
					switch( t ) {
					case TEof:
						return Li(items);
					case TList(c2):
						if( c2 == count )
							break;
						push(t);
						if( c2 < count )
							return Li(items);
						switch( b ) {
						case Paragraph(flow):
							var b = parseBlock(true);
							if( b == null ) break;
							flow.push(b);
						default:
						}
					default:
						push(t);
						break;
					}
				} while( true );
			}
			inList--;
			ignoreEnd();
			return Li(items);
		case TTagOpen(name,attrib):
			var t2 = token();
			var hasP = false;
			if( t2 == TBlockEnd ) {
				hasP = true;
				t2 = TNewLine;
			}
			if( t2 != TNewLine )
				push(t2);
			else {
				var flow = [];
				var old = inList;
				inList = 0;
				openedTags.push(name);
				while( true ) {
					t = token();
					switch( t ) {
					case TEof:
						break;
					case TTagClose(name2):
						if( name == name2 )
							break;
						for( n in openedTags )
							if( n == name2 ) {
								push(t);
								t = null;
								break;
							}
						if( t == null )
							break;
					default:
					}
					push(t);
					var b = parseBlock(false);
					// remove <p> around spans in divs
					switch( b ) {
					case Paragraph(f):
						if( f.length == 1 )
							switch(f[0]) {
							case Span(_):
								b = f[0];
							default:
							}
					default:
					}
					flow.push(b);
				}
				openedTags.pop();
				if( flow.length == 1 && !hasP )
					switch( flow[0] ) {
					case Paragraph(f): flow = f;
					default:
					}
				inList = old;
				ignoreEnd();
				return Div(name, attrib, flow);
			}
		case TNodeOpen(name, attrib):
			var flow = new Array();
			var buf = new StringBuf();
			openedTags.push("code:"+name);
			while( true ) {
				t = token();
				switch( t ) {
				case TNodeOpen(_):
					push(t);
					flow.push(parseBlock(false));
					continue;
				case TEof:
					break;
				case TNodeClose(n2):
					if( n2 == name )
						break;
					if( Lambda.has(openedTags, "code:" + n2) ) {
						push(t);
						break;
					}
				default:
				}
				flow.push(Text(tokenStr(t)));
			}
			openedTags.pop();
			ignoreEnd();
			return Node(name, attrib, flow);
		case TTagClose(_):
			if( limited ) {
				push(t);
				return null;
			}
		case TNodeClose(_):
			if( limited ) {
				push(t);
				return null;
			}
			t = TData(tokenStr(t));
		case TData(_), TDouble(_):
		}
		push(t);
		return Paragraph(parseFlow());
	}

	function parseFlow() : Flow {
		var flow = [];
		while( true ) {
			var t = token();
			switch( t ) {
			case TData(str):
				flow.push(Text(str));
			case TBlockEnd:
				if( inSpan == 0 && flow.length > 0 ) {
					if( inList > 0 )
						push(t);
					break;
				}
				flow.push(LineBreak);
				flow.push(LineBreak);
			case TNewLine:
				flow.push(LineBreak);
			case TSpace:
				if( flow.length > 0 || inSpan > 0 )
					flow.push(Space);
			case TDouble(char):
				var k = ":" + switch( char ) {
				case "'".code: "quote";
				case '*'.code: "star";
				case '/'.code: "slash";
				case '-'.code: "dash";
				default: "unk";
				};
				for( tag in openedTags )
					if( tag == k ) {
						push(t);
						t = null;
						break;
					}
				if( t == null ) break;
				openedTags.push(k);
				inSpan++;
				var f = parseFlow();
				inSpan--;
				openedTags.pop();
				var t2 = token();
				if( !Type.enumEq(t2,t) ) {
					push(t2);
					flow.push(Text(tokenStr(t)));
					for( i in f )
						flow.push(i);
					break;
				}
				flow.push(Span(k.substr(1), null, f));
			case TTagOpen(name,attrib):
				openedTags.push(name);
				inSpan++;
				var f = parseFlow();
				inSpan--;
				openedTags.pop();
				var t2 = token();
				if( !Type.enumEq(t2, TTagClose(name)) ) {
					push(t2);
					flow.push(Text(tokenStr(t)));
					for( i in f )
						flow.push(i);
					break;
				}
				flow.push(Span(name, attrib, f));
			case TTagClose(name):
				for( tag in openedTags )
					if( tag == name ) {
						push(t);
						t = null;
						break;
					}
				if( t == null ) break;
				flow.push(Text(tokenStr(t)));
			case TEof, THead(_), TList(_), TNodeOpen(_), TNodeClose(_):
				push(t);
				break;
			}
		}
		if( inSpan == 0 )
			while( flow.length > 0 )
				switch( flow[flow.length - 1] ) {
				case Space, LineBreak:
					flow.pop();
				default:
					break;
				}
		return flow;
	}

	function _token() {
		var t = cachedTokens.pop();
		if( t != null )
			return t;
		var t = _token();
		//trace(t);
		return t;
	}

	inline function isAlphaNum(c) {
		return (c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code) || (c >= '0'.code && c <= '9'.code);
	}

	function token() {
		var t = cachedTokens.pop();
		if( t != null )
			return t;
		var pos = pos;
		var c = StringTools.fastCodeAt(buf, pos++);
		if( StringTools.isEOF(c) )
			return TEof;
		switch( c ) {
		case '\r'.code:
			if( StringTools.fastCodeAt(buf, pos) == '\n'.code )
				pos++;
			while( StringTools.fastCodeAt(buf, pos) == '\r'.code) {
				pos++;
				if( StringTools.fastCodeAt(buf, pos) == '\n'.code )
					pos++;
				cachedTokens.add(TNewLine);
			}
			newLine = true;
			this.pos = pos;
			if( cachedTokens.pop() != null )
				return TBlockEnd;
			return TNewLine;
		case '\n'.code:
			while( StringTools.fastCodeAt(buf, pos) == '\n'.code ) {
				pos++;
				cachedTokens.add(TNewLine);
			}
			newLine = true;
			this.pos = pos;
			if( cachedTokens.pop() != null )
				return TBlockEnd;
			return TNewLine;
		case ' '.code, '\t'.code:
			while( true ) {
				var c = StringTools.fastCodeAt(buf, pos);
				if( c != ' '.code && c != '\t'.code ) {
					if( newLine && c == '*'.code ) {
						newLine = false;
						var count = pos - this.pos;
						this.pos = pos + 1;
						return TList(count);
					}
					break;
				}
				pos++;
			}
			this.pos = pos;
			return TSpace;
		case '['.code:
			var close = false;
			if( StringTools.fastCodeAt(buf, pos) == '/'.code ) {
				pos++;
				close = true;
			}
			var start = pos;
			var name = null, attrib = null;
			while( true ) {
				var c = StringTools.fastCodeAt(buf, pos);
				if( !isAlphaNum(c) ) {
					if( !close && c == '='.code && name == null && pos > start ) {
						name = buf.substr(start, pos - start);
						pos++;
						var old = start;
						start = pos;
						while( true ) {
							var c = StringTools.fastCodeAt(buf, pos);
							if( StringTools.isEOF(c) || c == '\r'.code || c == '\n'.code ) {
								this.pos = old;
								return TData('[');
							}
							if( c == ']'.code ) break;
							pos++;
						}
						attrib = buf.substr(start, pos - start);
						pos++;
						break;
					}
					if( c != ']'.code || start == pos ) {
						this.pos = start;
						return TData(close ? '[/' : '[');
					}
					name = buf.substr(start, pos - start);
					pos++;
					break;
				}
				pos++;
			}
			this.pos = pos;
			return close ? TTagClose(name) : TTagOpen(name,attrib);
		case '='.code:
			var count = 1;
			while( count < 6 ) {
				if( StringTools.fastCodeAt(buf, pos++) == '='.code )
					count++;
				else {
					pos--;
					break;
				}
			}
			this.pos = pos;
			return count >= 4 ? THead(6 - count) : TData("====".substr(0, count));
		case '<'.code:
			var close = false;
			if( StringTools.fastCodeAt(buf, pos) == '/'.code ) {
				pos++;
				close = true;
			}
			var start = pos;
			var name = null, attrib = null;
			while( true ) {
				var c = StringTools.fastCodeAt(buf, pos);
				if( !isAlphaNum(c) ) {
					if( !close && c == ' '.code && name == null && pos > start ) {
						name = buf.substr(start, pos - start);
						pos++;
						var old = start;
						start = pos;
						while( true ) {
							var c = StringTools.fastCodeAt(buf, pos);
							if( StringTools.isEOF(c) || c == '\r'.code || c == '\n'.code ) {
								this.pos = old;
								return TData('<');
							}
							if( c == '>'.code ) break;
							pos++;
						}
						attrib = buf.substr(start, pos - start);
						start = old;
						pos++;
						break;
					}
					if( c != '>'.code || start == pos ) {
						this.pos = start;
						return TData(close ? '</' : '<');
					}
					name = buf.substr(start, pos - start);
					pos++;
					break;
				}
				pos++;
			}
			if( !close && formatNode(name, attrib, "") == null ) {
				this.pos = start;
				return TData('<');
			}
			this.pos = pos;
			return close ? TNodeClose(name) : TNodeOpen(name, attrib);
		case "'".code, '*'.code, '/'.code, '-'.code:
			// Protect urls
			if( (pos < 2 || c != '/'.code || StringTools.fastCodeAt(buf, pos-2) != ':'.code) && StringTools.fastCodeAt(buf, pos) == c ) {
				this.pos = pos + 1;
				return TDouble(c);
			}
			this.pos = pos;
			return TData(String.fromCharCode(c));
		default:
		}
		var t = STABLE;
		var start = this.pos;
		do {
			c = StringTools.fastCodeAt(buf, pos++);
			if( StringTools.isEOF(c) ) break;
		} while( !t[c] );
		this.pos = pos - 1;
		newLine = false;
		return TData(buf.substr(start, pos - start - 1));
	}

}

