let s:Process = vital#fern#import('Async.Promise.Process')
let s:Promise = vital#fern#import('Async.Promise')
let s:Lambda = vital#fern#import('Lambda')
let s:AsyncLambda = vital#fern#import('Async.Lambda')
let s:CancellationToken = vital#fern#import('Async.CancellationToken')
let s:CancellationTokenSource = vital#fern#import('Async.CancellationTokenSource')

let s:PATTERN = '^$~.*[]\'


function! fern#grantor#git#new() abort
  return {
        \ 'grant': funcref('s:grant'),
        \ 'syntax': funcref('s:syntax'),
        \ 'highlight': funcref('s:highlight'),
        \}
endfunction

function! s:grant(helper) abort
  if a:helper.fern.scheme !=# 'file'
    return s:Promise.reject()
  endif

  if exists('s:source')
    call s:source.cancel()
  endif
  let s:source = s:CancellationTokenSource.new()

  return s:build_badge_map(a:helper.fern.root._path, s:source.token)
        \.then({ m -> s:remap(a:helper, m) })
        \.catch({ e -> s:on_catch(e) })
endfunction

function! s:syntax() abort
  for [k, v] in items(g:fern#grantor#git#status_map)
    if !empty(v)
      execute printf(
            \ 'syntax match FernGrantorGit%s /%s/ contained containedin=FernBadge',
            \ k, escape(v, s:PATTERN),
            \)
    endif
  endfor
endfunction

function! s:highlight() abort
  highlight default link FernGrantorGitStained   WarningMsg
  highlight default link FernGrantorGitCleaned   Special
  highlight default link FernGrantorGitStaged    Special
  highlight default link FernGrantorGitRenamed   Title
  highlight default link FernGrantorGitDeleted   Title
  highlight default link FernGrantorGitModified  WarningMsg
  highlight default link FernGrantorGitUnmerged  WarningMsg
  highlight default link FernGrantorGitUntracked Comment
  highlight default link FernGrantorGitIgnored   Comment
  highlight default link FernGrantorGitUnknown   Comment
endfunction

function! s:build_badge_map(root, token) abort
  let t = s:Process.start(
        \ ['git', '-C', a:root, 'rev-parse', '--show-toplevel'],
        \ { 'token': a:token },
        \)
        \.then({ v -> v.exitval ? s:Promise.reject(join(v.stderr, "\n")) : v.stdout })
        \.then({ v -> join(v, '') })
  let args = [
        \ g:fern#grantor#git#disable_untracked ? '' : '-uall',
        \ g:fern#grantor#git#disable_ignored ? '' : '--ignored',
        \]
  let s = s:Process.start(
        \ ['git', '-C', a:root, 'status', '--porcelain'] + filter(args, { -> !empty(v:val) }),
        \ { 'token': a:token },
        \)
        \.then({ v -> v.exitval ? s:Promise.reject(join(v.stderr, "\n")) : v.stdout })
  return s:Promise.all([t, s])
        \.then({ v -> v + [!g:fern#grantor#git#disable_stained] })
        \.then({ v -> call('fern#grantor#git#parser#parse', v) })
        \.then({ v -> map(v, { -> g:fern#grantor#git#status_map[v:val] }) })
endfunction

function! s:remap(helper, m) abort
  let m = {}
  return s:Promise.resolve(a:helper.fern.nodes)
        \.then(s:AsyncLambda.map_f({ n -> [join(n.__key, '/'), get(a:m, n._path, '')] }))
        \.then(s:AsyncLambda.filter_f({ v -> !empty(v[1]) }))
        \.then(s:AsyncLambda.map_f({ v -> s:Lambda.let(m, v[0], v[1]) }))
        \.then({ -> m })
endfunction

function! s:on_catch(error) abort
  if a:error ==# s:CancellationToken.CancelledError
    return s:Promise.resolve()
  elseif a:error =~# '^fatal: not a git repository'
    return s:Promise.resolve()
  endif
  return a:error
endfunction

let g:fern#grantor#git#disable_untracked = get(g:, 'fern#grantor#git#disable_untracked', 0)
let g:fern#grantor#git#disable_ignored = get(g:, 'fern#grantor#git#disable_ignored', 0)
let g:fern#grantor#git#disable_stained = get(g:, 'fern#grantor#git#disable_stained', 0)
let g:fern#grantor#git#status_map = get(g:, 'fern#grantor#git#status_map', {
      \ 'Stained': '"',
      \ 'Cleaned': "'",
      \ 'Staged': '+',
      \ 'Renamed': 'r',
      \ 'Deleted': 'x',
      \ 'Modified': '*',
      \ 'Unmerged': 'u',
      \ 'Untracked': '?',
      \ 'Ignored': '!',
      \ 'Unknown': 'U',
      \})
