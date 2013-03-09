" metarw-tumblr - a tumblr plugin for metarw

" Constants"{{{
let s:FALSE = 0
let s:TRUE  = !s:FALSE

let s:REQUEST_TOKEN_URL = 'http://www.tumblr.com/oauth/request_token'
let s:AUTHORIZE_URL     = 'http://www.tumblr.com/oauth/authorize'
let s:ACCESS_TOKEN_URL  = 'http://www.tumblr.com/oauth/access_token'

let s:POSTS_URL     = 'http://api.tumblr.com/v2/blog/%s/posts%s'
let s:CREATE_URL    = 'http://api.tumblr.com/v2/blog/%s/post'
let s:EDIT_URL      = 'http://api.tumblr.com/v2/blog/%s/post/edit'
let s:USER_INFO_URL = 'http://api.tumblr.com/v2/user/info'

let s:PUBLISHED = 'published'
let s:DRAFT     = 'draft'

let s:HTML     = 'html'
let s:MARKDONW = 'markdown'

let s:TEXT = 'text'

let s:ITEMS_PER_PAGE= 20
let s:MAX_ITEMS_PER_PAGE= 20

let s:default_hostname = get(g:, 'metarw#tumblr#default_hostname', '')
let s:default_hostname_given_p = s:default_hostname == '' ? s:FALSE : s:TRUE
"}}}

" Interfaces"{{{

" Authenticate with OAuth.
function! metarw#tumblr#authenticate()"{{{
  let ctx = {}
  let ctx.consumer_key = input('consumer_key:')
  let ctx.consumer_secret = input('consumer_secret:')
  let ctx = webapi#oauth#request_token(s:REQUEST_TOKEN_URL, ctx)
  if has('win32') || has('win64')
    exe '!start rundll32 url.dll,FileProtocolHandler '.s:AUTHORIZE_URL.'?oauth_token='.ctx.request_token
    let pin = input('PIN:')
  elseif has('mac')
    call system('open "'.s:AUTHORIZE_URL.'?oauth_token='.ctx.request_token.'"')
    let pin = input('PIN:')
  else
    let pin = input('open '.s:AUTHORIZE_URL.'?oauth_token='.ctx.request_token.' and input PIN:')
  endif
  let ctx = webapi#oauth#access_token(s:ACCESS_TOKEN_URL, ctx, {'oauth_verifier': pin})
  silent! unlet s:settings
  silent! unlet s:token
  let s:settings = {}
  let s:settings.consumer_key = ctx.consumer_key
  let s:settings.consumer_secret = ctx.consumer_secret
  let s:settings.access_token = ctx.access_token
  let s:settings.access_token_secret = ctx.access_token_secret
  call s:save_settings()
endfunction"}}}

"}}}

" metarw Interfaces"{{{

function! metarw#tumblr#complete(arglead, cmdline, cursorpos)"{{{
  try
    call s:load_settings()
    call s:load_user_info()
    let _ = s:parse_fakepath(a:arglead)
    let blogs = s:get_blogs(_)
  catch
    return [[], '', '']
  endtry

  let candidates = []
  for blog in s:user.blogs
    call add(candidates,
          \ printf('%s:%s', _.scheme, s:get_hostname(blog.url)))
  endfor

  let head = printf('%s:', _.scheme)
  let tail = _.hostname

  return [candidates, head, tail]
endfunction"}}}


function! metarw#tumblr#read(fakepath)"{{{
  try
    call s:load_settings()
    call s:load_user_info()

    let _ = s:parse_fakepath(a:fakepath)
  catch
    return ['error', v:exception]
  endtry

  if !_.hostname_given_p
    return s:get_blogs(_)
  end

  if !_.id_given_p
    return s:get_posts(_)
  endif

  return s:get_post(_)
endfunction"}}}


function! metarw#tumblr#write(fakepath, line1, line2, append_p)"{{{
  try
    call s:load_settings()
    call s:load_user_info()

    let _ = s:parse_fakepath(a:fakepath)
  catch
    return ['error', v:exception]
  endtry

  if !_.hostname_given_p
    return ['error', 'hostname is required']
  end

  let content = {}
  let lines = getline(a:line1, a:line2)
  if len(lines) > 2 && lines[1] == ''
    let content.title = lines[0]
    let content.body = join(lines[2:], "\n")
  else
    let content.body = join(lines, "\n")
  endif

  if _.id_given_p
    return s:edit_post(_, content)
  else
    return s:create_post(_, content)
  endif
endfunction"}}}

"}}}

" Misc"{{{

" Get blogs
function! s:get_blogs(_) "{{{
  call s:load_user_info()

  let result = []
  for blog in s:user.blogs
    let hostname = s:get_hostname(blog.url)
    let label = blog.title
    let fakepath = printf('%s:%s@%s', a:_.scheme, hostname, a:_.state)
    call add(result, {
    \    'label': label,
    \    'fakepath': fakepath
    \ })
  endfor

  return ['browse', result]
endfunction"}}}

" Get a hostname from URL
function! s:get_hostname(url) "{{{
  let pattern = '^\%(https\=://\)\zs[^/]\+\ze'
  return matchstr(a:url, pattern)
endfunction"}}}

" Parse the fakepath.
function! s:parse_fakepath(fakepath) "{{{
  let _ = {}

  " scheme:hostname/id.format@state?offset=num&limit=num
  let pattern = '^\(\l\+\):\([a-z.]\+\)\=\%(/\%(\([0-9]\+\)\.\([a-z]\+\)\)\=\)\=\%(@\([a-z]\+\)\)\=\%(?\%(&\=offset=\([0-9]\+\)\)\=\%(&\=limit=\([0-9]\+\)\)\=\)\=$'

  let [fakepath, scheme, hostname, id, format, state, offset, limit] = matchlist(a:fakepath, pattern)[0:7]

  if (fakepath == '')
    throw 'Unexpected a:fakepath:'.string(a:fakepath)
  endif

  let _.fakepath = fakepath
  let _.scheme = scheme

  let _.hostname = hostname
  if s:default_hostname_given_p
    let _.hostname = s:default_hostname
  end
  let _.hostname_given_p = _.hostname == '' ? s:FALSE : s:TRUE

  let _.id = id
  let _.id_given_p = _.id == '' ? s:FALSE : s:TRUE

  let _.format = format
  if format == ''
    call s:load_user_info()
    let _.format = s:user.default_post_format
  endif

  let _.state = state == '' ? s:PUBLISHED : state

  let _.offset = offset == '' ? 0 : str2nr(offset)
  let _.limit = limit == '' ? s:ITEMS_PER_PAGE : str2nr(limit)
  if _.limit > s:MAX_ITEMS_PER_PAGE
    throw 'limit parameter is too large'
  end

  return _
endfunction"}}}

" Get url to retrieve posts
function! s:posts_url(_) "{{{
  let state = a:_.state == s:PUBLISHED ? '' : '/'.a:_.state
  return printf(s:POSTS_URL, a:_.hostname, state)
endfunction"}}}

" Get parameters to retrieve posts
function! s:posts_params(_) "{{{
  let params = {}
  if a:_.state == s:PUBLISHED
    let params.api_key = s:settings['consumer_key']
    if a:_.id_given_p
      let params.id = a:_.id
    else
      let params.offset = a:_.offset
      let params.limit = a:_.limit
    endif
  endif
  let params.filter = 'raw'
  return params
endfunction"}}}

" Retrieve post collection
function! s:get_posts(_) "{{{
  let url = s:posts_url(a:_)
  let data = s:posts_params(a:_)

  let res = webapi#json#decode(s:normalize_json(webapi#oauth#get(url, s:token, {}, data).content))

  if res.meta.status != 200
    return ['error', res.meta.msg]
  endif

  let result = []

  if a:_.state == s:PUBLISHED && a:_.offset != 0
    let previous_offset = max([0, a:_.offset - a:_.limit])
    call add(result, {
          \ 'label': '<< previous',
          \ 'fakepath': printf('%s:%s@%s?offset=%d&limit=%d', a:_.scheme, a:_.hostname, a:_.state, previous_offset, a:_.limit)
          \ })
  endif

  for post in res.response.posts
    if post.type != s:TEXT
      continue
    endif

    let label = post.title == '' ? '[No Title]' : post.title
    let fakepath = printf('%s:%s/%s.%s@%s', a:_.scheme, a:_.hostname, post.id, post.format, post.state)
    call add(result, {
    \    'label': label,
    \    'fakepath': fakepath
    \ })
  endfor

  let next_offset = a:_.offset + a:_.limit
  if a:_.state == s:PUBLISHED && res.response.total_posts > next_offset
    call add(result, {
          \ 'label': '>> next',
          \ 'fakepath': printf('%s:%s@%s?offset=%d&limit=%d', a:_.scheme, a:_.hostname, a:_.state, next_offset, a:_.limit)
          \ })
  endif

  return ['browse', result]
endfunction"}}}

" Retrieve a single post
function! s:get_post(_) "{{{
  let url = s:posts_url(a:_)
  let data = s:posts_params(a:_)
  let res = webapi#json#decode(s:normalize_json(webapi#oauth#get(url, s:token, {}, data).content))

  if res.meta.status != 200
    return ['error', res.meta.msg]
  endif

  for post in res.response.posts
    if post.id != a:_.id
      continue
    endif

    if post.type != s:TEXT
      continue
    endif

    let format = post.format
    let title = post.title
    let content = post.body
    if title != ''
      let content = title."\n\n".content
    endif
    call setline(2, split(iconv(content, 'utf-8', &encoding), "\n"))
    let &filetype = format
    return ['done', '']
  endfor
endfunction"}}}

" Get url for editing
function! s:edit_url(_) "{{{
  return printf(s:EDIT_URL, a:_.hostname)
endfunction"}}}

" Get parameters for editing
function! s:edit_params(_) "{{{
  let params = {}
  let params.type = s:TEXT
  let params.id = a:_.id
  let params.state = a:_.state
  let params.format = a:_.format
  return params
endfunction"}}}

" Edit a post
function! s:edit_post(_, content) "{{{
  let url = s:edit_url(a:_)
  let data = s:edit_params(a:_)
  if has_key(a:content, 'title')
    let data.title = a:content.title
  endif
  let data.body = a:content.body

  let res = webapi#json#decode(s:normalize_json(webapi#oauth#post(url, s:token, {}, data).content))

  if res.meta.status != 200
    return ['error', res.meta.msg]
  endif

  return ['done', '']
endfunction"}}}

" Get url for creating
function! s:create_url(_) "{{{
  return printf(s:CREATE_URL, a:_.hostname)
endfunction"}}}

" Get parameters for creating
function! s:create_params(_) "{{{
  let params = {}
  let params.type = s:TEXT
  let params.state = a:_.state
  let params.format = a:_.format
  return params
endfunction"}}}

" Create a new post
function! s:create_post(_, content) "{{{
  let url = s:create_url(a:_)
  let data = s:create_params(a:_)
  if has_key(a:content, 'title')
    let data.title = a:content.title
  endif
  let data.body = a:content.body
  let res = webapi#json#decode(s:normalize_json(webapi#oauth#post(url, s:token, {}, data).content))

  if res.meta.status != 201
    return ['error', res.meta.msg]
  endif

  exe 'noautocmd file' printf('tumblr:%s/%s.%s@%s', a:_.hostname, res.response.id, a:_.format, a:_.state)

  return ['done', '']
endfunction"}}}

" Convert post id of json to string because vim cannot eval 64bit integer.
function! s:normalize_json(json) "{{{
  let pattern = '"id"\s*:\s*\zs\([0-9]\+\)\ze\s*'
  return substitute(a:json, pattern, '"\1"', 'g')
endfunction"}}}

let s:configfile = expand('~/.vim-metarw-tumblr-vim')

" Load config file.
function! s:load_settings() "{{{
  if !exists('s:settings')
    let s:settings = {}
    if filereadable(s:configfile)
      silent! sandbox let s:settings = eval(join(readfile(s:configfile), ''))
    else
      throw "[Please setup with :TumblrSetup]"
    endif
  endif

  if !exists('s:token')
    let s:token = {}
    let s:token.consumer_key = s:settings.consumer_key
    let s:token.consumer_secret = s:settings.consumer_secret
    let s:token.access_token = s:settings.access_token
    let s:token.access_token_secret = s:settings.access_token_secret
  endif
endfunction"}}}

" Save settings to config file.
function! s:save_settings() "{{{
  call writefile([string(s:settings)], s:configfile)
endfunction"}}}

" Load a user's information.
function! s:load_user_info() "{{{
  if exists('s:user')
    return
  endif

  let res = webapi#json#decode(webapi#oauth#get(s:USER_INFO_URL, s:token).content)
  if (res.meta.status != 200)
    throw res.meta.msg
  endif

  let s:user = res.response.user
endfunction"}}}

"}}}

" vim: set foldmethod=marker :

