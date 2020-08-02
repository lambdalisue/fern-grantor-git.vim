if exists('g:loaded_fern_grantor_git')
  finish
endif
let g:loaded_fern_grantor_git = 1

call extend(g:fern#grantors, {
      \ 'git': function('fern#grantor#git#new'),
      \})
