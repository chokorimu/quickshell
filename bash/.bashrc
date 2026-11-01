#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]]  && return

echo '                   __  
  ____ ___________╱ ╱_ 
 ╱ __ `╱ ___╱ ___╱ __ ╲
╱ ╱_╱ ╱ ╱  ╱ ╱__╱ ╱ ╱ ╱
╲__,_╱_╱   ╲___╱_╱ ╱_╱ 
                       '

alias ls='ls --color=auto'
alias grep='grep --color=auto'
# PS1='[\u@\h \W]\$ '
PS1='╭─ \w\n╰─❯ '

clear() {
	command clear
	echo '                   __  
  ____ ___________╱ ╱_ 
 ╱ __ `╱ ___╱ ___╱ __ ╲
╱ ╱_╱ ╱ ╱  ╱ ╱__╱ ╱ ╱ ╱
╲__,_╱_╱   ╲___╱_╱ ╱_╱ 
                       '
}

export PATH="$HOME/.local/bin:$PATH"
