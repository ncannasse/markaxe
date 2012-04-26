markaxe
=======

Customizable markup-to-Html parser/formater library

It support the following formats :


	- split the code into paragraphs (when there is an empty line)
	- add linebreaks otherwise	
	- `[tag]....[/tag]` : will call `formatTag` so you can build any HTML you want from it
	- `[tag=attrib]...[/tab]` : same but with an attribute (can be anything not including ] or newlines)
	- ` * ....` : lines items are a star prefixed by one or many spaces, which will give the identation for sublists
	- each plain text element goes through `formatPlainText` which can do the additional tricks (htmlEscape, but also autolinks, etc.)
	- `====== title ======` : h1 title, (use less = for h2,h3,...)
	- `<node>...</node>` : similar to tags but the content is not parsed, will call `formatNode` which can return null to keep it as-it

