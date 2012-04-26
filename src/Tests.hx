class Tests {

	static function eq( f : String, out : String, ?pos : haxe.PosInfos ) {
		var fmt = new tid.Format().format(f);
		if( fmt != out )
			haxe.Log.trace(" ERROR\n  "+fmt+"\nshould be :\n  "+out+"\n",pos);
	}

	static function main() {
		eq('','');

		eq("a","<p>a</p>");
		eq("  a  ","<p>a</p>");
		eq("\na","<br/><p>a</p>");
		eq("\n\na","<p><br/><br/>a</p>");
		eq("\n\n\na","<p><br/><br/><br/>a</p>");
		eq("a\nb","<p>a<br/>b</p>");
		eq("  a\nb","<p>a<br/>b</p>");
		eq("a\n\nb","<p>a</p><p>b</p>");
		eq("a\n\nb\n\n\nc","<p>a</p><p>b</p><br/><p>c</p>");
		eq("a\n\nb\n\n\nc\n","<p>a</p><p>b</p><br/><p>c</p>");
		eq("a\n\nb\n\n\nc\n\n","<p>a</p><p>b</p><br/><p>c</p>");
		eq("a\n\nb\n\n\nc\n\n\n","<p>a</p><p>b</p><br/><p>c</p><br/>");
		eq("a\n\nb\n\n\nc\n\n\n\n","<p>a</p><p>b</p><br/><p>c</p><br/><br/>");
		eq("a\n\nb\n\n\n\nc\n\n","<p>a</p><p>b</p><br/><br/><p>c</p>");

		eq("[d]a[/d]",'<p><span class="d">a</span></p>');
		eq("[d]   a   [/d]",'<p><span class="d"> a </span></p>');
		eq("[d]a\n[/d]",'<p><span class="d">a<br/></span></p>');
		eq("[d]a\n\n[/d]",'<p><span class="d">a<br/><br/></span></p>');
		eq("[d]a\nb[/d]",'<p><span class="d">a<br/>b</span></p>');
		eq("[d]a[/d]\nb",'<p><span class="d">a</span><br/>b</p>');
		eq("[d]a[e]b[/d][/e]",'<p><span class="d">a[e]b</span>[/e]</p>');

		eq("[d]\na\n[/d]",'<div class="d">a</div>');
		eq("[d]\na[/d]",'<div class="d">a</div>');
		eq("[d]\n[k]a[/k]\n[/d]",'<div class="d"><span class="k">a</span></div>');

		eq("[d]\n\na\n\n[/d]",'<div class="d"><p>a</p></div>');
		eq("[d]\n\na\n[/d]",'<div class="d"><p>a</p></div>');
		eq("[d]\n\na[/d]",'<div class="d"><p>a</p></div>');

		eq("[d]\n\na\n\nb\n\n[/d]",'<div class="d"><p>a</p><p>b</p></div>');
		eq("[d]\n\na\n\nb\n[/d]",'<div class="d"><p>a</p><p>b</p></div>');
		eq("[d]\n\na\n\nb[/d]",'<div class="d"><p>a</p><p>b</p></div>');
		eq("[d]\n\na\n\n\n[/d]",'<div class="d"><p>a</p><br/></div>');

		eq("[d]\na\n[/d]\n\n[d]\na\n[/d]",'<div class="d">a</div><div class="d">a</div>');

		eq("====== T ======",'<h1>T</h1>');
		eq("====== T ======\n\n",'<h1>T</h1>');
		eq("====== T ======\n\n\n",'<h1>T</h1><br/>');
		eq("====== T ======\n\na",'<h1>T</h1><p>a</p>');
		eq("====== T ======\n\n\na",'<h1>T</h1><br/><p>a</p>');
		eq("====== T ======\n\n\n\na",'<h1>T</h1><br/><br/><p>a</p>');
		eq("====== T ====== ====== T ======",'<h1>T</h1><h1>T</h1>');

		eq("[d]\na\n[/d]\n",'<div class="d">a</div>');
		eq("[d]\na\n[/d]\n\n",'<div class="d">a</div>');
		eq("[d]\na\n[/d]\n\n\n",'<div class="d">a</div><br/>');
		eq("[d]\na\n[/d]\n[d]\nb\n[/d]",'<div class="d">a</div><div class="d">b</div>');
		eq("[d]\na\n[/d]\n\n[d]\nb\n[/d]",'<div class="d">a</div><div class="d">b</div>');
		eq("[d]\na\n[/d]\n\n\n[d]\nb\n[/d]",'<div class="d">a</div><br/><div class="d">b</div>');

		eq("<html>a\n</html>","a\n");
		eq("<html>a<>&</html>","a<>&");
		eq("<html>    a     </html>"," a "); // the lexer merge spaces

		eq(" * a","<ul><li>a</li></ul>");
		eq(" *   a  ","<ul><li>a</li></ul>");
		eq(" * a\n[d]b[/d]",'<ul><li>a<br/><span class="d">b</span></li></ul>');
		eq(" * a\n\n[d]b[/d]\n * c",'<ul><li>a</li></ul><p><span class="d">b</span></p><ul><li>c</li></ul>');

		eq(" * a\n * b","<ul><li>a</li><li>b</li></ul>");
		eq(" * a\n  * b\n * c","<ul><li>a<ul><li>b</li></ul></li><li>c</li></ul>");
	}

}
