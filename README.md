metarw-tumblr
=============

metarw scheme for Tumblr.


Dependencies
------------

* webapi-vim <https://github.com/mattn/webapi-vim>
* vim-metarw <https://github.com/kana/vim-metarw>


Install
-----------

	NeoBundle 'mattn/webapi-vim'
	NeoBundle 'kana/vim-metarw'
	NeoBundle 'hara/vim-metarw-tumblr'


Usage
-----

Authentication is required at first run.

	:TumblrSetup

Retrieving publised text posts or draft.

	:Edit tumblr:hostname
	:Edit tumblr:hostname@draft

Creating a published text posts or draft.

	:w tumblr:hostname
	:w tumblr:hostname@draft

You can omit the `hostname` part with `g:metarw#tumblr#default_hostname`.


Configuration
-------------

hostname of default blog

	let g:metarw#tumblr#default_hostname = '<short name of your blog>.tumblr.com'


License
-------

### The MIT License

	Copyright (c) 2013 https://github.com/hara/vim-metarw-tumblr
	
	Permission is hereby granted, free of charge, to any person
	obtaining a copy of this software and associated documentation
	files (the "Software"), to deal in the Software without
	restriction, including without limitation the rights to use, copy,
	modify, merge, publish, distribute, sublicense, and/or sell copies
	of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:
	
	The above copyright notice and this permission notice shall be
	included in all copies or substantial portions of the Software.
	
	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
	EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
	NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
	HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
	WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
	DEALINGS IN THE SOFTWARE.

