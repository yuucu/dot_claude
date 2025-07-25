# Snapshot file
# Unset all aliases to avoid conflicts with functions
unalias -a 2>/dev/null || true
# Functions
.zinit-add-fpath () {
	[[ $1 = (-f|--front) ]] && {
		shift
		integer front=1 
	}
	.zinit-any-to-user-plugin "$1" ""
	local id_as="$1" add_dir="$2" user="${reply[-2]}" plugin="${reply[-1]}" 
	if (( front ))
	then
		fpath[1,0]=${${${(M)user:#%}:+$plugin}:-${ZINIT[PLUGINS_DIR]}/${id_as//\//---}}${add_dir:+/$add_dir} 
	else
		fpath+=(${${${(M)user:#%}:+$plugin}:-${ZINIT[PLUGINS_DIR]}/${id_as//\//---}}${add_dir:+/$add_dir}) 
	fi
}
.zinit-add-report () {
	[[ -n $1 ]] && {
		(( ${+builtins[zpmod]} && 0 )) && zpmod report-append "$1" "$2"$'\n' || ZINIT_REPORTS[$1]+="$2"$'\n' 
	}
	[[ ${ZINIT[DTRACE]} = 1 ]] && {
		(( ${+builtins[zpmod]} )) && zpmod report-append _dtrace/_dtrace "$2"$'\n' || ZINIT_REPORTS[_dtrace/_dtrace]+="$2"$'\n' 
	}
	return 0
}
.zinit-any-to-pid () {
	builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
	builtin setopt extendedglob typesetsilent noshortloops rcquotes ${${${+REPLY}:#0}:+warncreateglobal}
	1=${~1} 2=${~2} 
	if [[ -n $2 ]]
	then
		if [[ $1 == (%|/)* || ( -z $1 && $2 == /* ) ]]
		then
			.zinit-util-shands-path $1${${(M)1#(%/?|%[^/]|/?)}:+/}$2
			REPLY=${${REPLY:#%*}:+%}$REPLY 
		else
			REPLY=$1${1:+/}$2 
		fi
		return 0
	fi
	if [[ $1 = (%|/|\~)* ]]
	then
		.zinit-util-shands-path $1
		REPLY=${${REPLY:#%*}:+%}$REPLY 
		return 0
	fi
	REPLY=${1//---//} 
	return 0
}
.zinit-any-to-user-plugin () {
	builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
	builtin setopt extendedglob typesetsilent noshortloops rcquotes ${${${+reply}:#0}:+warncreateglobal}
	if [[ -n $2 ]]
	then
		2=${~2} 
		reply=(${1:-${${(M)2#/}:+%}} ${${${(M)1#%}:+$2}:-${2//---//}}) 
		return 0
	fi
	if [[ $1 = /* ]]
	then
		reply=(% $1) 
		return 0
	fi
	if [[ $1 = %* ]]
	then
		local -A map
		map=(ZPFX "$ZPFX" HOME $HOME SNIPPETS $ZINIT[SNIPPETS_DIR] PLUGINS $ZINIT[PLUGINS_DIR]) 
		reply=(% ${${1/(#b)(#s)%(${(~j:|:)${(@k)map}}|)/$map[$match[1]]}}) 
		reply[2]=${~reply[2]} 
		return 0
	fi
	1=${1//---//} 
	if [[ $1 = */* ]]
	then
		reply=(${1%%/*} ${1#*/}) 
		return 0
	fi
	reply=("" "${1:-_unknown}") 
	return 0
}
.zinit-compdef-clear () {
	local quiet="$1" count="${#ZINIT_COMPDEF_REPLAY}" 
	ZINIT_COMPDEF_REPLAY=() 
	[[ $quiet = -q ]] || +zi-log "Compdef-replay cleared (it had {num}${count}{rst} entries)."
}
.zinit-compdef-replay () {
	local quiet="$1" 
	typeset -a pos
	if [[ ${+functions[compdef]} = 0 ]]
	then
		+zi-log "{u-warn}Error{b-warn}:{rst} The {func}compinit{rst}" "function hasn't been loaded, cannot do {it}{cmd}compdef replay{rst}."
		return 1
	fi
	local cdf
	for cdf in "${ZINIT_COMPDEF_REPLAY[@]}"
	do
		pos=("${(z)cdf}") 
		[[ ${#pos[@]} = 1 && -z ${pos[-1]} ]] && continue
		pos=("${(Q)pos[@]}") 
		[[ $quiet = -q ]] || +zi-log "Running compdef: {cmd}${pos[*]}{rst}"
		compdef "${pos[@]}"
	done
	return 0
}
.zinit-diff () {
	.zinit-diff-functions "$1" "$2"
	.zinit-diff-options "$1" "$2"
	.zinit-diff-env "$1" "$2"
	.zinit-diff-parameter "$1" "$2"
}
.zinit-diff-env () {
	typeset -a tmp
	local IFS=" " 
	[[ $2 = begin ]] && {
		{
			[[ -z ${ZINIT[PATH_BEFORE__$uspl2]} ]] && tmp=("${(q)path[@]}") 
			ZINIT[PATH_BEFORE__$1]="${tmp[*]}" 
		}
		{
			[[ -z ${ZINIT[FPATH_BEFORE__$uspl2]} ]] && tmp=("${(q)fpath[@]}") 
			ZINIT[FPATH_BEFORE__$1]="${tmp[*]}" 
		}
	} || {
		tmp=("${(q)path[@]}") 
		ZINIT[PATH_AFTER__$1]+=" ${tmp[*]}" 
		tmp=("${(q)fpath[@]}") 
		ZINIT[FPATH_AFTER__$1]+=" ${tmp[*]}" 
	}
}
.zinit-diff-functions () {
	local uspl2="$1" 
	local cmd="$2" 
	[[ $cmd = begin ]] && {
		[[ -z ${ZINIT[FUNCTIONS_BEFORE__$uspl2]} ]] && ZINIT[FUNCTIONS_BEFORE__$uspl2]="${(j: :)${(qk)functions[@]}}" 
	} || ZINIT[FUNCTIONS_AFTER__$uspl2]+=" ${(j: :)${(qk)functions[@]}}" 
}
.zinit-diff-options () {
	local IFS=" " 
	[[ $2 = begin ]] && {
		[[ -z ${ZINIT[OPTIONS_BEFORE__$uspl2]} ]] && ZINIT[OPTIONS_BEFORE__$1]="${(kv)options[@]}" 
	} || ZINIT[OPTIONS_AFTER__$1]+=" ${(kv)options[@]}" 
}
.zinit-diff-parameter () {
	typeset -a tmp
	[[ $2 = begin ]] && {
		{
			[[ -z ${ZINIT[PARAMETERS_BEFORE__$uspl2]} ]] && ZINIT[PARAMETERS_BEFORE__$1]="${(j: :)${(qkv)parameters[@]}}" 
		}
	} || {
		ZINIT[PARAMETERS_AFTER__$1]+=" ${(j: :)${(qkv)parameters[@]}}" 
	}
}
.zinit-find-other-matches () {
	local pdir_path="$1" pbase="$2" limit="$3" 
	if [[ $limit == 1 ]]
	then
		reply=("$pdir_path"/*.plugin.zsh(DN)) 
	elif [[ $limit == 0 ]]
	then
		reply=("$pdir_path"/*.service.zsh(DN)) 
	else
		if [[ -e $pdir_path/init.zsh ]]
		then
			reply=("$pdir_path"/init.zsh) 
		elif [[ -e $pdir_path/$pbase.zsh-theme ]]
		then
			reply=("$pdir_path/$pbase".zsh-theme) 
		elif [[ -e $pdir_path/$pbase.theme.zsh ]]
		then
			reply=("$pdir_path/$pbase".theme.zsh) 
		else
			reply=("$pdir_path"/*.plugin.zsh(DN) "$pdir_path"/*.zsh-theme(DN) "$pdir_path"/*.lib.zsh(DN) "$pdir_path"/*.zsh(DN) "$pdir_path"/*.sh(DN) "$pdir_path"/.zshrc(DN)) 
		fi
	fi
	reply=("${(u)reply[@]}") 
	return $(( ${#reply} > 0 ? 0 : 1 ))
}
.zinit-formatter-auto () {
	emulate -L zsh -o extendedglob -o warncreateglobal -o typesetsilent
	local out in=$1 i wrk match spaces rest 
	integer mbegin mend
	local -a ice_order ecmds
	ice_order=(${(As:|:)ZINIT[ice-list]} ${(@)${(A@kons:|:)${ZINIT_EXTS[ice-mods]//\'\'/}}/(#s)<->-/}) 
	ecmds=(${ZINIT_EXTS[(I)z-annex subcommand:*]#z-annex subcommand:}) 
	in=${(j: :)${${(Z+Cn+)in}//[$'\t ']/$'\u00a0'}} 
	wrk=$in 
	while [[ $in == (#b)([[:space:]]#)([^[:space:]]##)(*) ]]
	do
		spaces=$match[1] 
		rest=$match[3] 
		wrk=${match[2]//---//} 
		REPLY=$wrk 
		if [[ ( $wrk == ([[:space:]]##|(#s))[0-9.]##([[:space:]]##|(#e)) && $rest == ([[:space:]]#|(#s))[sm]([[:space:]]##*|(#e)) ) || $wrk == ([[:space:]]##|(#s))[0-9.]##[sm]([[:space:]]##|(#e)) ]]
		then
			REPLY=$ZINIT[col-time]$wrk$ZINIT[col-rst] 
			if [[ $wrk != *[sm]* ]]
			then
				rest=$ZINIT[col-time]${(M)rest##[[:space:]]#[sm]}$ZINIT[col-rst]${rest##[[:space:]]#[sm]} 
			fi
		elif [[ $wrk == ([[:space:]]##|(#s))[0-9.]##([[:space:]]##|(#e)) ]]
		then
			REPLY=$ZINIT[col-num]$wrk$ZINIT[col-rst] 
		elif [[ $wrk == (#b)(((http|ftp)(|s)|ssh|scp|ntp|file)://[[:alnum:].:+/]##) ]]
		then
			.zinit-formatter-url $wrk
		elif [[ $wrk == (--|)(${(~j:|:)ice_order})[:=\"\'\!a-zA-Z0-9-]* ]]
		then
			REPLY=$ZINIT[col-ice]$wrk$ZINIT[col-rst] 
		elif [[ $wrk == (OMZ([PLT]|)|PZT([MLT]|)):* || $wrk == [^/]##/[^/]## || -d $ZINIT[PLUGINS_DIR]/${wrk//\//---} ]]
		then
			.zinit-formatter-pid $wrk
		elif [[ $wrk == (${~ZINIT[cmds]}|${(~j:|:)ecmds}) ]]
		then
			REPLY=$ZINIT[col-cmd]$wrk$ZINIT[col-rst] 
		elif type $1 &> /dev/null
		then
			REPLY=$ZINIT[col-bcmd]$wrk$ZINIT[col-rst] 
		elif [[ $wrk == (#b)(*)('<->'|'<–>'|'<—>')(*) || $wrk == (#b)(*)(…|–|—|↔|...)(*) ]]
		then
			local -A map=(… … - dsh – ndsh — mdsh '<->' ↔ '<–>' ↔ '<—>' ↔ ↔ ↔ ... …) 
			REPLY=$match[1]$ZINIT[col-$map[$wrk]]$match[3] 
		elif [[ $wrk == (#b)(*)([\'\`\"])([^\'\`\"]##)([\'\`\"])(*) ]]
		then
			local -A map=(\` bapo \' apo \" quo x\` baps x\' aps x\" quos) 
			local openq=$match[2] str=$match[3] closeq=$match[4] RST=$ZINIT[col-rst] 
			REPLY=$match[1]$ZINIT[col-$map[$openq]]$openq$RST$ZINIT[col-$map[x$openq]]$str$RST$ZINIT[col-$map[$closeq]]$closeq$RST$match[5] 
		fi
		in=$rest 
		out+=${spaces//$'\n'/$'\013\015'}$REPLY 
	done
	REPLY=${out//$'\u00a0'/ } 
}
.zinit-formatter-bar () {
	.zinit-formatter-bar-util ─ bar
}
.zinit-formatter-bar-util () {
	if [[ $LANG == (#i)*utf-8* ]]
	then
		ch=$1 
	else
		ch=- 
	fi
	REPLY=$ZINIT[col-$2]${(pl:COLUMNS-1::$ch:):-}$ZINIT[col-rst] 
}
.zinit-formatter-dbg () {
	builtin emulate -L zsh -o extendedglob
	REPLY= 
	if (( ZINIT[DEBUG] ))
	then
		REPLY=$1 
	fi
}
.zinit-formatter-pid () {
	builtin emulate -L zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}
	local pbz=${(M)1##(#s)[[:space:]]##} 
	local kbz=${(M)1%%[[:space:]]##(#e)} 
	1=${1//((#s)[[:space:]]##|[[:space:]]##(#e))/} 
	((${+functions[.zinit-first]})) || source ${ZINIT[BIN_DIR]}/zinit-side.zsh
	.zinit-any-colorify-as-uspl2 "$1"
	pbz=${pbz/[[:blank:]]/ } 
	local kbz_rev="${(j::)${(@Oas::)kbz}}" 
	kbz="${(j::)${(@Oas::)${kbz_rev/[[:blank:]]/ }}}" 
	REPLY=$pbz$REPLY$kbz 
}
.zinit-formatter-th-bar () {
	.zinit-formatter-bar-util ━ th-bar
}
.zinit-formatter-url () {
	builtin emulate -LR zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}
	if [[ $1 = (#b)([^:]#)(://|::)((([[:alnum:]._+-]##).([[:alnum:]_+-]##))|([[:alnum:].+_-]##))(|/(*)) ]]
	then
		match[9]=${match[9]//\//"%F{227}%B"/"%F{81}%b"} 
		if [[ -n $match[4] ]]
		then
			REPLY="$(builtin print -Pr -- %F{220}$match[1]%F{227}$match[2]\
%B%F{82}$match[5]\
%B%F{227}.\
%B%F{183}$match[6]%f%b)" 
		else
			REPLY="$(builtin print -Pr -- %F{220}$match[1]%F{227}$match[2]\
%B%F{82}$match[7]%f%b)" 
		fi
		if [[ -n $match[9] ]]
		then
			REPLY+="$(print -Pr -- \
%F{227}%B/%F{81}%b$match[9]%f%b)" 
		fi
	else
		REPLY=$ZINIT[col-url]$1$ZINIT[col-rst] 
	fi
}
.zinit-get-mtime-into () {
	if (( ZINIT[HAVE_ZSTAT] ))
	then
		local -a arr
		{
			zstat +mtime -A arr "$1"
		} 2> /dev/null
		: ${(P)2::="${arr[1]}"}
	else
		{
			: ${(P)2::="$(stat -c %Y "$1")"}
		} 2> /dev/null
	fi
}
.zinit-get-object-path () {
	local type="$1" id_as="$2" local_dir dirname 
	integer exists
	id_as="${ICE[id-as]:-$id_as}" 
	id_as="${${id_as#"${id_as%%[! $'\t']*}"}%/}" 
	for type in ${=${${(M)type:#AUTO}:+snippet plugin}:-$type}
	do
		if [[ $type == snippet ]]
		then
			dirname="${${id_as%%\?*}:t}" 
			local_dir="${${${id_as%%\?*}/:\/\//--}:h}" 
			[[ $local_dir = . ]] && local_dir=  || local_dir="${${${${${local_dir#/}//\//--}//=/-EQ-}//\?/-QM-}//\&/-AMP-}" 
			local_dir="${ZINIT[SNIPPETS_DIR]}${local_dir:+/$local_dir}" 
		else
			.zinit-any-to-user-plugin "$id_as"
			local_dir=${${${(M)reply[-2]:#%}:+${reply[2]}}:-${ZINIT[PLUGINS_DIR]}/${id_as//\//---}} 
			[[ $id_as == _local/* && -d $local_dir && ! -d $local_dir/._zinit ]] && command mkdir -p "$local_dir"/._zinit
			dirname="" 
		fi
		[[ -e $local_dir/${dirname:+$dirname/}._zinit || -e $local_dir/${dirname:+$dirname/}._zplugin ]] && exists=1 
		(( exists )) && break
	done
	reply=("$local_dir" "$dirname" "$exists") 
	REPLY="$local_dir${dirname:+/$dirname}" 
	return $(( 1 - exists ))
}
.zinit-ice () {
	builtin setopt localoptions noksharrays extendedglob warncreateglobal typesetsilent noshortloops
	integer retval
	local bit exts="${(j:|:)${(@)${(@Akons:|:)${ZINIT_EXTS[ice-mods]//\'\'/}}/(#s)<->-/}}" 
	for bit
	do
		[[ $bit = (#b)(--|)(${~ZINIT[ice-list]}${~exts})(*) ]] && ZINIT_ICES[${match[2]}]+="${ZINIT_ICES[${match[2]}]:+;}${match[3]#(:|=)}"  || break
		retval+=1 
	done
	[[ ${ZINIT_ICES[as]} = program ]] && ZINIT_ICES[as]=command 
	[[ -n ${ZINIT_ICES[on-update-of]} ]] && ZINIT_ICES[subscribe]="${ZINIT_ICES[subscribe]:-${ZINIT_ICES[on-update-of]}}" 
	[[ -n ${ZINIT_ICES[pick]} ]] && ZINIT_ICES[pick]="${ZINIT_ICES[pick]//\$ZPFX/${ZPFX%/}}" 
	return retval
}
.zinit-load () {
	typeset -F 3 SECONDS=0 
	local ___mode="$3" ___limit="$4" ___rst=0 ___retval=0 ___key 
	.zinit-any-to-user-plugin "$1" "$2"
	local ___user="${reply[-2]}" ___plugin="${reply[-1]}" ___id_as="${ICE[id-as]:-${reply[-2]}${${reply[-2]:#(%|/)*}:+/}${reply[-1]}}" 
	local ___pdir_path="${${${(M)___user:#%}:+$___plugin}:-${ZINIT[PLUGINS_DIR]}/${___id_as//\//---}}" 
	local ___pdir_orig="$___pdir_path" 
	ZINIT[CUR_USR]="$___user" ZINIT[CUR_PLUGIN]="$___plugin" ZINIT[CUR_USPL2]="$___id_as" 
	if [[ -n ${ICE[teleid]} ]]
	then
		.zinit-any-to-user-plugin "${ICE[teleid]}"
		___user="${reply[-2]}" ___plugin="${reply[-1]}" 
	else
		ICE[teleid]="$___user${${___user:#%}:+/}$___plugin" 
	fi
	.zinit-set-m-func set
	local -a ___arr
	reply=(${(on)ZINIT_EXTS2[(I)zinit hook:preinit-pre <->]} ${(on)ZINIT_EXTS[(I)z-annex hook:preinit-<-> <->]} ${(on)ZINIT_EXTS2[(I)zinit hook:preinit-post <->]}) 
	for ___key in "${reply[@]}"
	do
		___arr=("${(Q)${(z@)ZINIT_EXTS[$___key]:-$ZINIT_EXTS2[$___key]}[@]}") 
		"${___arr[5]}" plugin "$___user" "$___plugin" "$___id_as" "$___pdir_orig" "${${___key##(zinit|z-annex) hook:}%% <->}" load || return $(( 10 - $? ))
	done
	if [[ $___user != % && ! -d ${ZINIT[PLUGINS_DIR]}/${___id_as//\//---} ]]
	then
		(( ${+functions[.zinit-setup-plugin-dir]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-install.zsh" || return 1
		reply=("$___user" "$___plugin") REPLY=github 
		if (( ${+ICE[pack]} ))
		then
			if ! .zinit-get-package "$___user" "$___plugin" "$___id_as" "${ZINIT[PLUGINS_DIR]}/${___id_as//\//---}" "${ICE[pack]:-default}"
			then
				zle && {
					builtin print
					zle .reset-prompt
				}
				return 1
			fi
			___id_as="${ICE[id-as]:-${___user}${${___user:#(%|/)*}:+/}$___plugin}" 
		fi
		___user="${reply[-2]}" ___plugin="${reply[-1]}" 
		ICE[teleid]="$___user${${___user:#(%|/)*}:+/}$___plugin" 
		[[ $REPLY = snippet ]] && {
			ICE[id-as]="${ICE[id-as]:-$___id_as}" 
			.zinit-load-snippet $___plugin "" $___limit && return
			zle && {
				builtin print
				zle .reset-prompt
			}
			return 1
		}
		.zinit-setup-plugin-dir "$___user" "$___plugin" "$___id_as" "$REPLY"
		local rc="$?" 
		if [[ "$rc" -ne 0 ]]
		then
			zle && {
				builtin print
				zle .reset-prompt
			}
			return "$rc"
		fi
		zle && ___rst=1 
	fi
	ZINIT_SICE[$___id_as]= 
	.zinit-pack-ice "$___id_as"
	(( ${+ICE[cloneonly]} )) && return 0
	.zinit-register-plugin "$___id_as" "$___mode" "${ICE[teleid]}"
	if [[ -n ${ICE[param]} ]]
	then
		.zinit-setup-params && local -x ${(Q)reply[@]}
	fi
	reply=(${(on)ZINIT_EXTS[(I)z-annex hook:\!atinit-<-> <->]}) 
	for ___key in "${reply[@]}"
	do
		___arr=("${(Q)${(z@)ZINIT_EXTS[$___key]}[@]}") 
		"${___arr[5]}" plugin "$___user" "$___plugin" "$___id_as" "${${${(M)___user:#%}:+$___plugin}:-${ZINIT[PLUGINS_DIR]}/${___id_as//\//---}}" \!atinit || return $(( 10 - $? ))
	done
	[[ ${+ICE[atinit]} = 1 && $ICE[atinit] != '!'* ]] && {
		local ___oldcd="$PWD" 
		(( ${+ICE[nocd]} == 0 )) && {
			() {
				setopt localoptions noautopushd
				builtin cd -q "${${${(M)___user:#%}:+$___plugin}:-${ZINIT[PLUGINS_DIR]}/${___id_as//\//---}}"
			} && eval "${ICE[atinit]}"
			((1))
		} || eval "${ICE[atinit]}"
		() {
			setopt localoptions noautopushd
			builtin cd -q "$___oldcd"
		}
	}
	reply=(${(on)ZINIT_EXTS[(I)z-annex hook:atinit-<-> <->]}) 
	for ___key in "${reply[@]}"
	do
		___arr=("${(Q)${(z@)ZINIT_EXTS[$___key]}[@]}") 
		"${___arr[5]}" plugin "$___user" "$___plugin" "$___id_as" "${${${(M)___user:#%}:+$___plugin}:-${ZINIT[PLUGINS_DIR]}/${___id_as//\//---}}" atinit || return $(( 10 - $? ))
	done
	.zinit-load-plugin "$___user" "$___plugin" "$___id_as" "$___mode" "$___rst" "$___limit"
	___retval=$? 
	(( ${+ICE[notify]} == 1 )) && {
		[[ $___retval -eq 0 || -n ${(M)ICE[notify]#\!} ]] && {
			local msg
			eval "msg=\"${ICE[notify]#\!}\""
			+zinit-deploy-message @msg "$msg"
		} || +zinit-deploy-message @msg "notify: Plugin not loaded / loaded with problem, the return code: $___retval"
	}
	(( ${+ICE[reset-prompt]} == 1 )) && +zinit-deploy-message @___rst
	.zinit-set-m-func unset
	ZINIT[CUR_USR]= ZINIT[CUR_PLUGIN]= ZINIT[CUR_USPL2]= 
	ZINIT[TIME_INDEX]=$(( ${ZINIT[TIME_INDEX]:-0} + 1 )) 
	ZINIT[TIME_${ZINIT[TIME_INDEX]}_${___id_as//\//---}]=$SECONDS 
	ZINIT[AT_TIME_${ZINIT[TIME_INDEX]}_${___id_as//\//---}]=$EPOCHREALTIME 
	return ___retval
}
.zinit-load-ices () {
	local id_as="$1" ___key ___path 
	local -a ice_order
	ice_order=(${(As:|:)ZINIT[ice-list]} ${(@)${(A@kons:|:)${ZINIT_EXTS[ice-mods]//\'\'/}}/(#s)<->-/}) 
	___path="${ZINIT[PLUGINS_DIR]}/${id_as//\//---}"/._zinit 
	if [[ ! -d $___path ]]
	then
		if ! .zinit-get-object-path snippet "${id_as//\//---}"
		then
			return 1
		fi
		___path="$REPLY"/._zinit 
	fi
	for ___key in "${ice_order[@]}"
	do
		(( ${+ICE[$___key]} )) && [[ ${ICE[$___key]} != +* ]] && continue
		[[ -e $___path/$___key ]] && ICE[$___key]="$(<$___path/$___key)" 
	done
	[[ -n ${ICE[on-update-of]} ]] && ICE[subscribe]="${ICE[subscribe]:-${ICE[on-update-of]}}" 
	[[ ${ICE[as]} = program ]] && ICE[as]=command 
	[[ -n ${ICE[pick]} ]] && ICE[pick]="${ICE[pick]//\$ZPFX/${ZPFX%/}}" 
	return 0
}
.zinit-load-object () {
	local ___type="$1" ___id=$2 
	local -a ___opt
	___opt=(${@[3,-1]}) 
	if [[ $___type == snippet ]]
	then
		.zinit-load-snippet $___opt "$___id"
	elif [[ $___type == plugin ]]
	then
		.zinit-load "$___id" "" $___opt
	fi
	___retval+=$? 
	return __retval
}
.zinit-load-plugin () {
	local ___user="$1" ___plugin="$2" ___id_as="$3" ___mode="$4" ___rst="$5" ___limit="$6" ___correct=0 ___retval=0 
	local ___pbase="${${___plugin:t}%(.plugin.zsh|.zsh|.git)}" ___key 
	builtin set --
	[[ -o ksharrays ]] && ___correct=1 
	[[ -n ${ICE[(i)(\!|)(sh|bash|ksh|csh)]}${ICE[opts]} ]] && {
		local -a ___precm
		___precm=(builtin emulate ${${(M)${ICE[(i)(\!|)(sh|bash|ksh|csh)]}#\!}:+-R} ${${${ICE[(i)(\!|)(sh|bash|ksh|csh)]}#\!}:-zsh} ${${ICE[(i)(\!|)bash]}:+-${(s: :):-o noshglob -o braceexpand -o kshglob}} ${(s: :):-${${:-${(@s: :):--o}" "${(s: :)^ICE[opts]}}:#-o }} -c) 
	}
	[[ -z ${ICE[subst]} ]] && local ___builtin=builtin 
	[[ ${ICE[as]} = null || ${+ICE[null]} -eq 1 || ${+ICE[binary]} -eq 1 ]] && ICE[pick]="${ICE[pick]:-/dev/null}" 
	if [[ -n ${ICE[autoload]} ]]
	then
		:zinit-tmp-subst-autoload -Uz ${(s: :)${${${(s.;.)ICE[autoload]#[\!\#]}#[\!\#]}//(#b)((*)(->|=>|→)(*)|(*))/${match[2]:+$match[2] -S $match[4]}${match[5]:+${match[5]} -S ${match[5]}}}} ${${(M)ICE[autoload]:#*(->|=>|→)*}:+-C} ${${(M)ICE[autoload]#(?\!|\!)}:+-C} ${${(M)ICE[autoload]#(?\#|\#)}:+-I}
	fi
	if [[ ${ICE[as]} = command ]]
	then
		[[ ${+ICE[pick]} = 1 && -z ${ICE[pick]} ]] && ICE[pick]="${___id_as:t}" 
		reply=() 
		if [[ -n ${ICE[pick]} && ${ICE[pick]} != /dev/null ]]
		then
			reply=(${(M)~ICE[pick]##/*}(DN) $___pdir_path/${~ICE[pick]}(DN)) 
			[[ -n ${reply[1-correct]} ]] && ___pdir_path="${reply[1-correct]:h}" 
		fi
		[[ -z ${path[(er)$___pdir_path]} ]] && {
			[[ $___mode != light ]] && .zinit-diff-env "${ZINIT[CUR_USPL2]}" begin
			path=("${___pdir_path%/}" ${path[@]}) 
			[[ $___mode != light ]] && .zinit-diff-env "${ZINIT[CUR_USPL2]}" end
			.zinit-add-report "${ZINIT[CUR_USPL2]}" "$ZINIT[col-info2]$___pdir_path$ZINIT[col-rst] added to \$PATH"
		}
		[[ -n ${reply[1-correct]} && ! -x ${reply[1-correct]} ]] && command chmod a+x ${reply[@]}
		[[ ${ICE[atinit]} = '!'* || -n ${ICE[src]} || -n ${ICE[multisrc]} || ${ICE[atload][1]} = "!" ]] && {
			if [[ ${ZINIT[TMP_SUBST]} = inactive ]]
			then
				(( ${+functions[compdef]} )) && ZINIT[bkp-compdef]="${functions[compdef]}"  || builtin unset "ZINIT[bkp-compdef]"
				functions[compdef]=':zinit-tmp-subst-compdef "$@";' 
				ZINIT[TMP_SUBST]=1 
			else
				(( ++ ZINIT[TMP_SUBST] ))
			fi
		}
		local ZERO
		[[ $ICE[atinit] = '!'* ]] && {
			local ___oldcd="$PWD" 
			(( ${+ICE[nocd]} == 0 )) && {
				() {
					setopt localoptions noautopushd
					builtin cd -q "${${${(M)___user:#%}:+$___plugin}:-${ZINIT[PLUGINS_DIR]}/${___id_as//\//---}}"
				} && eval "${ICE[atinit#!]}"
				((1))
			} || eval "${ICE[atinit]#!}"
			() {
				setopt localoptions noautopushd
				builtin cd -q "$___oldcd"
			}
		}
		[[ -n ${ICE[src]} ]] && {
			ZERO="${${(M)ICE[src]##/*}:-$___pdir_orig/${ICE[src]}}" 
			(( ${+ICE[silent]} )) && {
				{
					[[ -n $___precm ]] && {
						builtin ${___precm[@]} 'source "$ZERO"'
						((1))
					} || {
						((1))
						$___builtin source "$ZERO"
					}
				} 2> /dev/null >&2
				(( ___retval += $? ))
				((1))
			} || {
				((1))
				{
					[[ -n $___precm ]] && {
						builtin ${___precm[@]} 'source "$ZERO"'
						((1))
					} || {
						((1))
						$___builtin source "$ZERO"
					}
				}
				(( ___retval += $? ))
			}
		}
		[[ -n ${ICE[multisrc]} ]] && {
			local ___oldcd="$PWD" 
			() {
				setopt localoptions noautopushd
				builtin cd -q "$___pdir_orig"
			}
			eval "reply=(${ICE[multisrc]})"
			() {
				setopt localoptions noautopushd
				builtin cd -q "$___oldcd"
			}
			local ___fname
			for ___fname in "${reply[@]}"
			do
				ZERO="${${(M)___fname:#/*}:-$___pdir_orig/$___fname}" 
				(( ${+ICE[silent]} )) && {
					{
						[[ -n $___precm ]] && {
							builtin ${___precm[@]} 'source "$ZERO"'
							((1))
						} || {
							((1))
							$___builtin source "$ZERO"
						}
					} 2> /dev/null >&2
					(( ___retval += $? ))
					((1))
				} || {
					((1))
					{
						[[ -n $___precm ]] && {
							builtin ${___precm[@]} 'source "$ZERO"'
							((1))
						} || {
							((1))
							$___builtin source "$ZERO"
						}
					}
					(( ___retval += $? ))
				}
			done
		}
		reply=(${(on)ZINIT_EXTS[(I)z-annex hook:\!atload-<-> <->]}) 
		for ___key in "${reply[@]}"
		do
			___arr=("${(Q)${(z@)ZINIT_EXTS[$___key]}[@]}") 
			"${___arr[5]}" plugin "$___user" "$___plugin" "$___id_as" "$___pdir_orig" \!atload
		done
		if [[ -n ${ICE[wrap]} ]]
		then
			(( ${+functions[.zinit-service]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-additional.zsh"
			.zinit-wrap-functions "$___user" "$___plugin" "$___id_as"
		fi
		[[ ${ICE[atload][1]} = "!" ]] && {
			.zinit-add-report "$___id_as" "Note: Starting to track the atload'!…' ice…"
			ZERO="$___pdir_orig/-atload-" 
			local ___oldcd="$PWD" 
			(( ${+ICE[nocd]} == 0 )) && {
				() {
					setopt localoptions noautopushd
					builtin cd -q "$___pdir_orig"
				} && builtin eval "${ICE[atload]#\!}"
			} || eval "${ICE[atload]#\!}"
			() {
				setopt localoptions noautopushd
				builtin cd -q "$___oldcd"
			}
		}
		[[ -n ${ICE[src]} || -n ${ICE[multisrc]} || ${ICE[atload][1]} = "!" ]] && {
			(( -- ZINIT[TMP_SUBST] == 0 )) && {
				ZINIT[TMP_SUBST]=inactive 
				builtin setopt noaliases
				(( ${+ZINIT[bkp-compdef]} )) && functions[compdef]="${ZINIT[bkp-compdef]}"  || unfunction compdef
				(( ZINIT[ALIASES_OPT] )) && builtin setopt aliases
			}
		}
	elif [[ ${ICE[as]} = completion ]]
	then
		((1))
	else
		if [[ -n ${ICE[pick]} ]]
		then
			[[ ${ICE[pick]} = /dev/null ]] && reply=(/dev/null)  || reply=(${(M)~ICE[pick]##/*}(DN) $___pdir_path/${~ICE[pick]}(DN)) 
		elif [[ -e $___pdir_path/$___pbase.plugin.zsh && $___limit -ne 0 ]]
		then
			reply=("$___pdir_path/$___pbase".plugin.zsh) 
		else
			.zinit-find-other-matches "$___pdir_path" "$___pbase" "$___limit"
		fi
		local ___fname="${reply[1-correct]:t}" 
		___pdir_path="${reply[1-correct]:h}" 
		.zinit-add-report "${ZINIT[CUR_USPL2]}" "Source $___fname ${${${(M)___mode:#light}:+(no reporting)}:-$ZINIT[col-info2](reporting enabled)$ZINIT[col-rst]}"
		[[ $___mode != light(|-b) ]] && .zinit-diff "${ZINIT[CUR_USPL2]}" begin
		.zinit-tmp-subst-on "${___mode:-load}"
		(( ${+ICE[blockf]} )) && {
			local -a fpath_bkp
			fpath_bkp=("${fpath[@]}") 
		}
		local ZERO="$___pdir_path/$___fname" 
		(( ${+ICE[aliases]} )) || builtin setopt noaliases
		[[ $ICE[atinit] = '!'* ]] && {
			local ___oldcd="$PWD" 
			(( ${+ICE[nocd]} == 0 )) && {
				() {
					setopt localoptions noautopushd
					builtin cd -q "${${${(M)___user:#%}:+$___plugin}:-${ZINIT[PLUGINS_DIR]}/${___id_as//\//---}}"
				} && eval "${ICE[atinit]#!}"
				((1))
			} || eval "${ICE[atinit]#1}"
			() {
				setopt localoptions noautopushd
				builtin cd -q "$___oldcd"
			}
		}
		(( ${+ICE[silent]} )) && {
			{
				[[ -n $___precm ]] && {
					builtin ${___precm[@]} 'source "$ZERO"'
					((1))
				} || {
					((1))
					$___builtin source "$ZERO"
				}
			} 2> /dev/null >&2
			(( ___retval += $? ))
			((1))
		} || {
			((1))
			{
				[[ -n $___precm ]] && {
					builtin ${___precm[@]} 'source "$ZERO"'
					((1))
				} || {
					((1))
					$___builtin source "$ZERO"
				}
			}
			(( ___retval += $? ))
		}
		[[ -n ${ICE[src]} ]] && {
			ZERO="${${(M)ICE[src]##/*}:-$___pdir_orig/${ICE[src]}}" 
			(( ${+ICE[silent]} )) && {
				{
					[[ -n $___precm ]] && {
						builtin ${___precm[@]} 'source "$ZERO"'
						((1))
					} || {
						((1))
						$___builtin source "$ZERO"
					}
				} 2> /dev/null >&2
				(( ___retval += $? ))
				((1))
			} || {
				((1))
				{
					[[ -n $___precm ]] && {
						builtin ${___precm[@]} 'source "$ZERO"'
						((1))
					} || {
						((1))
						$___builtin source "$ZERO"
					}
				}
				(( ___retval += $? ))
			}
		}
		[[ -n ${ICE[multisrc]} ]] && {
			local ___oldcd="$PWD" 
			() {
				setopt localoptions noautopushd
				builtin cd -q "$___pdir_orig"
			}
			eval "reply=(${ICE[multisrc]})"
			() {
				setopt localoptions noautopushd
				builtin cd -q "$___oldcd"
			}
			for ___fname in "${reply[@]}"
			do
				ZERO="${${(M)___fname:#/*}:-$___pdir_orig/$___fname}" 
				(( ${+ICE[silent]} )) && {
					{
						[[ -n $___precm ]] && {
							builtin ${___precm[@]} 'source "$ZERO"'
							((1))
						} || {
							((1))
							$___builtin source "$ZERO"
						}
					} 2> /dev/null >&2
					(( ___retval += $? ))
					((1))
				} || {
					{
						[[ -n $___precm ]] && {
							builtin ${___precm[@]} 'source "$ZERO"'
							((1))
						} || {
							((1))
							$___builtin source "$ZERO"
						}
					}
					(( ___retval += $? ))
				}
			done
		}
		reply=(${(on)ZINIT_EXTS[(I)z-annex hook:\!atload-<-> <->]}) 
		for ___key in "${reply[@]}"
		do
			___arr=("${(Q)${(z@)ZINIT_EXTS[$___key]}[@]}") 
			"${___arr[5]}" plugin "$___user" "$___plugin" "$___id_as" "$___pdir_orig" \!atload
		done
		if [[ -n ${ICE[wrap]} ]]
		then
			(( ${+functions[.zinit-service]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-additional.zsh"
			.zinit-wrap-functions "$___user" "$___plugin" "$___id_as"
		fi
		[[ ${ICE[atload][1]} = "!" ]] && {
			.zinit-add-report "$___id_as" "Note: Starting to track the atload'!…' ice…"
			ZERO="$___pdir_orig/-atload-" 
			local ___oldcd="$PWD" 
			(( ${+ICE[nocd]} == 0 )) && {
				() {
					setopt localoptions noautopushd
					builtin cd -q "$___pdir_orig"
				} && builtin eval "${ICE[atload]#\!}"
				((1))
			} || eval "${ICE[atload]#\!}"
			() {
				setopt localoptions noautopushd
				builtin cd -q "$___oldcd"
			}
		}
		(( ZINIT[ALIASES_OPT] )) && builtin setopt aliases
		(( ${+ICE[blockf]} )) && {
			fpath=("${fpath_bkp[@]}") 
		}
		.zinit-tmp-subst-off "${___mode:-load}"
		[[ $___mode != light(|-b) ]] && .zinit-diff "${ZINIT[CUR_USPL2]}" end
	fi
	[[ ${+ICE[atload]} = 1 && ${ICE[atload][1]} != "!" ]] && {
		ZERO="$___pdir_orig/-atload-" 
		local ___oldcd="$PWD" 
		(( ${+ICE[nocd]} == 0 )) && {
			() {
				setopt localoptions noautopushd
				builtin cd -q "$___pdir_orig"
			} && builtin eval "${ICE[atload]}"
			((1))
		} || eval "${ICE[atload]}"
		() {
			setopt localoptions noautopushd
			builtin cd -q "$___oldcd"
		}
	}
	reply=(${(on)ZINIT_EXTS[(I)z-annex hook:atload-<-> <->]}) 
	for ___key in "${reply[@]}"
	do
		___arr=("${(Q)${(z@)ZINIT_EXTS[$___key]}[@]}") 
		"${___arr[5]}" plugin "$___user" "$___plugin" "$___id_as" "$___pdir_orig" atload
	done
	(( ___rst )) && {
		builtin print
		zle .reset-prompt
	}
	return ___retval
}
.zinit-load-snippet () {
	typeset -F 3 SECONDS=0 
	local -a opts
	zparseopts -E -D -a opts f -command || {
		+zi-log "{u-warn}Error{b-warn}:{rst} Incorrect options (accepted ones: {opt}-f{rst}, {opt}--command{rst})."
		return 1
	}
	local url="$1" limit="$3" 
	[[ -n ${ICE[teleid]} ]] && url="${ICE[teleid]}" 
	builtin set --
	integer correct retval exists
	[[ -o ksharrays ]] && correct=1 
	[[ -n ${ICE[(i)(\!|)(sh|bash|ksh|csh)]}${ICE[opts]} ]] && {
		local -a precm
		precm=(builtin emulate ${${(M)${ICE[(i)(\!|)(sh|bash|ksh|csh)]}#\!}:+-R} ${${${ICE[(i)(\!|)(sh|bash|ksh|csh)]}#\!}:-zsh} ${${ICE[(i)(\!|)bash]}:+-${(s: :):-o noshglob -o braceexpand -o kshglob}} ${(s: :):-${${:-${(@s: :):--o}" "${(s: :)^ICE[opts]}}:#-o }} -c) 
	}
	url="${${url#"${url%%[! $'\t']*}"}%/}" 
	ICE[teleid]="${ICE[teleid]:-$url}" 
	[[ ${ICE[as]} = null || ${+ICE[null]} -eq 1 || ${+ICE[binary]} -eq 1 ]] && ICE[pick]="${ICE[pick]:-/dev/null}" 
	local local_dir dirname filename save_url="$url" 
	eval "url=\"$url\""
	local id_as="${ICE[id-as]:-$url}" 
	.zinit-set-m-func set
	if [[ -n ${ICE[param]} ]]
	then
		.zinit-setup-params && local -x ${(Q)reply[@]}
	fi
	.zinit-pack-ice "$id_as" ""
	[[ $url = *(${(~kj.|.)${(Mk)ZINIT_1MAP:#OMZ*}}|robbyrussell*oh-my-zsh|ohmyzsh/ohmyzsh)* ]] && local ZSH="${ZINIT[SNIPPETS_DIR]}" 
	.zinit-get-object-path snippet "$id_as"
	filename="${reply[-2]}" dirname="${reply[-2]}" 
	local_dir="${reply[-3]}" exists=${reply[-1]} 
	local -a arr
	local key
	reply=(${(on)ZINIT_EXTS2[(I)zinit hook:preinit-pre <->]} ${(on)ZINIT_EXTS[(I)z-annex hook:preinit-<-> <->]} ${(on)ZINIT_EXTS2[(I)zinit hook:preinit-post <->]}) 
	for key in "${reply[@]}"
	do
		arr=("${(Q)${(z@)ZINIT_EXTS[$key]:-$ZINIT_EXTS2[$key]}[@]}") 
		"${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" "${${key##(zinit|z-annex) hook:}%% <->}" load || return $(( 10 - $? ))
	done
	if [[ -n ${opts[(r)-f]} || $exists -eq 0 ]]
	then
		(( ${+functions[.zinit-download-snippet]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-install.zsh" || return 1
		.zinit-download-snippet "$save_url" "$url" "$id_as" "$local_dir" "$dirname" "$filename"
		retval=$? 
	fi
	(( ${+ICE[cloneonly]} || retval )) && return 0
	ZINIT_SNIPPETS[$id_as]="$id_as <${${ICE[svn]+svn}:-single file}>" 
	ZINIT[CUR_USPL2]="$id_as" ZINIT_REPORTS[$id_as]= 
	reply=(${(on)ZINIT_EXTS[(I)z-annex hook:\!atinit-<-> <->]}) 
	for key in "${reply[@]}"
	do
		arr=("${(Q)${(z@)ZINIT_EXTS[$key]}[@]}") 
		"${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" \!atinit || return $(( 10 - $? ))
	done
	(( ${+ICE[atinit]} )) && {
		local ___oldcd="$PWD" 
		(( ${+ICE[nocd]} == 0 )) && {
			() {
				setopt localoptions noautopushd
				builtin cd -q "$local_dir/$dirname"
			} && eval "${ICE[atinit]}"
			((1))
		} || eval "${ICE[atinit]}"
		() {
			setopt localoptions noautopushd
			builtin cd -q "$___oldcd"
		}
	}
	reply=(${(on)ZINIT_EXTS[(I)z-annex hook:atinit-<-> <->]}) 
	for key in "${reply[@]}"
	do
		arr=("${(Q)${(z@)ZINIT_EXTS[$key]}[@]}") 
		"${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" atinit || return $(( 10 - $? ))
	done
	local -a list
	local ZERO
	if [[ -z ${opts[(r)--command]} && ( -z ${ICE[as]} || ${ICE[as]} = null || ${+ICE[null]} -eq 1 || ${+ICE[binary]} -eq 1 ) ]]
	then
		if [[ ${ZINIT[TMP_SUBST]} = inactive ]]
		then
			(( ${+functions[compdef]} )) && ZINIT[bkp-compdef]="${functions[compdef]}"  || builtin unset "ZINIT[bkp-compdef]"
			functions[compdef]=':zinit-tmp-subst-compdef "$@";' 
			ZINIT[TMP_SUBST]=1 
		else
			(( ++ ZINIT[TMP_SUBST] ))
		fi
		if [[ -d $local_dir/$dirname/functions ]]
		then
			[[ -z ${fpath[(r)$local_dir/$dirname/functions]} ]] && fpath+=("$local_dir/$dirname/functions") 
			() {
				builtin setopt localoptions extendedglob
				autoload $local_dir/$dirname/functions/^([_.]*|prompt_*_setup|README*)(D-.N:t)
			}
		fi
		if (( ${+ICE[svn]} == 0 ))
		then
			[[ ${+ICE[pick]} = 0 ]] && list=("$local_dir/$dirname/$filename") 
			[[ -n ${ICE[pick]} ]] && list=(${(M)~ICE[pick]##/*}(DN) $local_dir/$dirname/${~ICE[pick]}(DN)) 
		else
			if [[ -n ${ICE[pick]} ]]
			then
				list=(${(M)~ICE[pick]##/*}(DN) $local_dir/$dirname/${~ICE[pick]}(DN)) 
			elif (( ${+ICE[pick]} == 0 ))
			then
				.zinit-find-other-matches "$local_dir/$dirname" "$filename" "$limit"
				list=(${reply[@]}) 
			fi
		fi
		if [[ -f ${list[1-correct]} ]]
		then
			ZERO="${list[1-correct]}" 
			(( ${+ICE[silent]} )) && {
				{
					[[ -n $precm ]] && {
						builtin ${precm[@]} 'source "$ZERO"'
						((1))
					} || {
						((1))
						builtin source "$ZERO"
					}
				} 2> /dev/null >&2
				(( retval += $? ))
				((1))
			} || {
				((1))
				{
					[[ -n $precm ]] && {
						builtin ${precm[@]} 'source "$ZERO"'
						((1))
					} || {
						((1))
						builtin source "$ZERO"
					}
				}
				(( retval += $? ))
			}
			(( 0 == retval )) && [[ $url = PZT::* || $url = https://github.com/sorin-ionescu/prezto/* ]] && zstyle ":prezto:module:${${id_as%/init.zsh}:t}" loaded 'yes'
		else
			[[ ${+ICE[silent]} -eq 1 || ( ${+ICE[pick]} -eq 1 && -z ${ICE[pick]} ) || ${ICE[pick]} = /dev/null ]] || {
				+zi-log "Snippet not loaded ({url}${id_as}{rst})"
				retval=1 
			}
		fi
		[[ -n ${ICE[src]} ]] && {
			ZERO="${${(M)ICE[src]##/*}:-$local_dir/$dirname/${ICE[src]}}" 
			(( ${+ICE[silent]} )) && {
				{
					[[ -n $precm ]] && {
						builtin ${precm[@]} 'source "$ZERO"'
						((1))
					} || {
						((1))
						builtin source "$ZERO"
					}
				} 2> /dev/null >&2
				(( retval += $? ))
				((1))
			} || {
				((1))
				{
					[[ -n $precm ]] && {
						builtin ${precm[@]} 'source "$ZERO"'
						((1))
					} || {
						((1))
						builtin source "$ZERO"
					}
				}
				(( retval += $? ))
			}
		}
		[[ -n ${ICE[multisrc]} ]] && {
			local ___oldcd="$PWD" 
			() {
				setopt localoptions noautopushd
				builtin cd -q "$local_dir/$dirname"
			}
			eval "reply=(${ICE[multisrc]})"
			() {
				setopt localoptions noautopushd
				builtin cd -q "$___oldcd"
			}
			local fname
			for fname in "${reply[@]}"
			do
				ZERO="${${(M)fname:#/*}:-$local_dir/$dirname/$fname}" 
				(( ${+ICE[silent]} )) && {
					{
						[[ -n $precm ]] && {
							builtin ${precm[@]} 'source "$ZERO"'
							((1))
						} || {
							((1))
							builtin source "$ZERO"
						}
					} 2> /dev/null >&2
					(( retval += $? ))
					((1))
				} || {
					((1))
					{
						[[ -n $precm ]] && {
							builtin ${precm[@]} 'source "$ZERO"'
							((1))
						} || {
							((1))
							builtin source "$ZERO"
						}
					}
					(( retval += $? ))
				}
			done
		}
		reply=(${(on)ZINIT_EXTS[(I)z-annex hook:\!atload-<-> <->]}) 
		for key in "${reply[@]}"
		do
			arr=("${(Q)${(z@)ZINIT_EXTS[$key]}[@]}") 
			"${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" \!atload
		done
		if [[ -n ${ICE[wrap]} ]]
		then
			(( ${+functions[.zinit-service]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-additional.zsh"
			.zinit-wrap-functions "$save_url" "" "$id_as"
		fi
		[[ ${ICE[atload][1]} = "!" ]] && {
			.zinit-add-report "$id_as" "Note: Starting to track the atload'!…' ice…"
			ZERO="$local_dir/$dirname/-atload-" 
			local ___oldcd="$PWD" 
			(( ${+ICE[nocd]} == 0 )) && {
				() {
					setopt localoptions noautopushd
					builtin cd -q "$local_dir/$dirname"
				} && builtin eval "${ICE[atload]#\!}"
				((1))
			} || eval "${ICE[atload]#\!}"
			() {
				setopt localoptions noautopushd
				builtin cd -q "$___oldcd"
			}
		}
		(( -- ZINIT[TMP_SUBST] == 0 )) && {
			ZINIT[TMP_SUBST]=inactive 
			builtin setopt noaliases
			(( ${+ZINIT[bkp-compdef]} )) && functions[compdef]="${ZINIT[bkp-compdef]}"  || unfunction compdef
			(( ZINIT[ALIASES_OPT] )) && builtin setopt aliases
		}
	elif [[ -n ${opts[(r)--command]} || ${ICE[as]} = command ]]
	then
		[[ ${+ICE[pick]} = 1 && -z ${ICE[pick]} ]] && ICE[pick]="${id_as:t}" 
		if (( ${+ICE[svn]} ))
		then
			if [[ -n ${ICE[pick]} ]]
			then
				list=(${(M)~ICE[pick]##/*}(DN) $local_dir/$dirname/${~ICE[pick]}(DN)) 
				[[ -n ${list[1-correct]} ]] && local xpath="${list[1-correct]:h}" xfilepath="${list[1-correct]}" 
			else
				local xpath="$local_dir/$dirname" 
			fi
		else
			local xpath="$local_dir/$dirname" xfilepath="$local_dir/$dirname/$filename" 
			[[ -n ${ICE[pick]} ]] && {
				list=(${(M)~ICE[pick]##/*}(DN) $local_dir/$dirname/${~ICE[pick]}(DN)) 
				[[ -n ${list[1-correct]} ]] && xpath="${list[1-correct]:h}" xfilepath="${list[1-correct]}" 
			}
		fi
		[[ -n $xpath && -z ${path[(er)$xpath]} ]] && path=("${xpath%/}" ${path[@]}) 
		[[ -n $xfilepath && -f $xfilepath && ! -x "$xfilepath" ]] && command chmod a+x "$xfilepath" ${list[@]:#$xfilepath}
		[[ -n ${ICE[src]} || -n ${ICE[multisrc]} || ${ICE[atload][1]} = "!" ]] && {
			if [[ ${ZINIT[TMP_SUBST]} = inactive ]]
			then
				(( ${+functions[compdef]} )) && ZINIT[bkp-compdef]="${functions[compdef]}"  || builtin unset "ZINIT[bkp-compdef]"
				functions[compdef]=':zinit-tmp-subst-compdef "$@";' 
				ZINIT[TMP_SUBST]=1 
			else
				(( ++ ZINIT[TMP_SUBST] ))
			fi
		}
		if [[ -n ${ICE[src]} ]]
		then
			ZERO="${${(M)ICE[src]##/*}:-$local_dir/$dirname/${ICE[src]}}" 
			(( ${+ICE[silent]} )) && {
				{
					[[ -n $precm ]] && {
						builtin ${precm[@]} 'source "$ZERO"'
						((1))
					} || {
						((1))
						builtin source "$ZERO"
					}
				} 2> /dev/null >&2
				(( retval += $? ))
				((1))
			} || {
				((1))
				{
					[[ -n $precm ]] && {
						builtin ${precm[@]} 'source "$ZERO"'
						((1))
					} || {
						((1))
						builtin source "$ZERO"
					}
				}
				(( retval += $? ))
			}
		fi
		[[ -n ${ICE[multisrc]} ]] && {
			local ___oldcd="$PWD" 
			() {
				setopt localoptions noautopushd
				builtin cd -q "$local_dir/$dirname"
			}
			eval "reply=(${ICE[multisrc]})"
			() {
				setopt localoptions noautopushd
				builtin cd -q "$___oldcd"
			}
			local fname
			for fname in "${reply[@]}"
			do
				ZERO="${${(M)fname:#/*}:-$local_dir/$dirname/$fname}" 
				(( ${+ICE[silent]} )) && {
					{
						[[ -n $precm ]] && {
							builtin ${precm[@]} 'source "$ZERO"'
							((1))
						} || {
							((1))
							builtin source "$ZERO"
						}
					} 2> /dev/null >&2
					(( retval += $? ))
					((1))
				} || {
					((1))
					{
						[[ -n $precm ]] && {
							builtin ${precm[@]} 'source "$ZERO"'
							((1))
						} || {
							((1))
							builtin source "$ZERO"
						}
					}
					(( retval += $? ))
				}
			done
		}
		reply=(${(on)ZINIT_EXTS[(I)z-annex hook:\!atload-<-> <->]}) 
		for key in "${reply[@]}"
		do
			arr=("${(Q)${(z@)ZINIT_EXTS[$key]}[@]}") 
			"${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" \!atload
		done
		if [[ -n ${ICE[wrap]} ]]
		then
			(( ${+functions[.zinit-service]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-additional.zsh"
			.zinit-wrap-functions "$save_url" "" "$id_as"
		fi
		[[ ${ICE[atload][1]} = "!" ]] && {
			.zinit-add-report "$id_as" "Note: Starting to track the atload'!…' ice…"
			ZERO="$local_dir/$dirname/-atload-" 
			local ___oldcd="$PWD" 
			(( ${+ICE[nocd]} == 0 )) && {
				() {
					setopt localoptions noautopushd
					builtin cd -q "$local_dir/$dirname"
				} && builtin eval "${ICE[atload]#\!}"
				((1))
			} || eval "${ICE[atload]#\!}"
			() {
				setopt localoptions noautopushd
				builtin cd -q "$___oldcd"
			}
		}
		[[ -n ${ICE[src]} || -n ${ICE[multisrc]} || ${ICE[atload][1]} = "!" ]] && {
			(( -- ZINIT[TMP_SUBST] == 0 )) && {
				ZINIT[TMP_SUBST]=inactive 
				builtin setopt noaliases
				(( ${+ZINIT[bkp-compdef]} )) && functions[compdef]="${ZINIT[bkp-compdef]}"  || unfunction compdef
				(( ZINIT[ALIASES_OPT] )) && builtin setopt aliases
			}
		}
	elif [[ ${ICE[as]} = completion ]]
	then
		((1))
	fi
	(( ${+ICE[atload]} )) && [[ ${ICE[atload][1]} != "!" ]] && {
		ZERO="$local_dir/$dirname/-atload-" 
		local ___oldcd="$PWD" 
		(( ${+ICE[nocd]} == 0 )) && {
			() {
				setopt localoptions noautopushd
				builtin cd -q "$local_dir/$dirname"
			} && builtin eval "${ICE[atload]}"
			((1))
		} || eval "${ICE[atload]}"
		() {
			setopt localoptions noautopushd
			builtin cd -q "$___oldcd"
		}
	}
	reply=(${(on)ZINIT_EXTS[(I)z-annex hook:atload-<-> <->]}) 
	for key in "${reply[@]}"
	do
		arr=("${(Q)${(z@)ZINIT_EXTS[$key]}[@]}") 
		"${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" atload
	done
	(( ${+ICE[notify]} == 1 )) && {
		[[ $retval -eq 0 || -n ${(M)ICE[notify]#\!} ]] && {
			local msg
			eval "msg=\"${ICE[notify]#\!}\""
			+zinit-deploy-message @msg "$msg"
		} || +zinit-deploy-message @msg "notify: Plugin not loaded / loaded with problem, the return code: $retval"
	}
	(( ${+ICE[reset-prompt]} == 1 )) && +zinit-deploy-message @rst
	ZINIT[CUR_USPL2]= 
	ZINIT[TIME_INDEX]=$(( ${ZINIT[TIME_INDEX]:-0} + 1 )) 
	ZINIT[TIME_${ZINIT[TIME_INDEX]}_${id_as}]=$SECONDS 
	ZINIT[AT_TIME_${ZINIT[TIME_INDEX]}_${id_as}]=$EPOCHREALTIME 
	.zinit-set-m-func unset
	return retval
}
.zinit-main-message-formatter () {
	if [[ -z $1 && -z $2 && -z $3 ]]
	then
		REPLY="" 
		return
	fi
	local append influx in_prepend
	if [[ $2 == (b|u|it|st|nb|nu|nit|nst) ]]
	then
		append=$ZINIT[col-$2] 
	elif [[ $2 == (…|ndsh|mdsh|mmdsh|-…|lr|) || -z $2 || -z $ZINIT[col-$2] ]]
	then
		if [[ $ZINIT[__last-formatter-code] != (…|ndsh|mdsh|mmdsh|-…|lr|rst|nl|) ]]
		then
			in_prepend=$ZINIT[col-$ZINIT[__last-formatter-code]] 
			influx=$ZINIT[col-$ZINIT[__last-formatter-code]] 
		fi
	else
		append=$ZINIT[col-rst] 
	fi
	REPLY=$in_prepend${ZINIT[col-$2]:-$1}$influx$3$append 
	local nl=$'\n' vertical=$'\013' carriager=$'\015' 
	REPLY=${REPLY//$nl/$vertical$carriager} 
}
.zinit-pack-ice () {
	ZINIT_SICE[$1${1:+${2:+/}}$2]+="${(j: :)${(qkv)ICE[@]}} " 
	ZINIT_SICE[$1${1:+${2:+/}}$2]="${ZINIT_SICE[$1${1:+${2:+/}}$2]# }" 
	return 0
}
.zinit-parse-opts () {
	builtin emulate -LR zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}
	reply=("${(@)${@[2,-1]//([  $'\t']##|(#s))(#b)(${(~j.|.)${(@s.|.)___opt_map[$1]}})(#B)([  $'\t']##|(#e))/${OPTS[${___opt_map[${match[1]}]%%:*}]::=1}ß←↓→}:#1ß←↓→}") 
}
.zinit-prepare-home () {
	[[ -n ${ZINIT[HOME_READY]} ]] && return
	ZINIT[HOME_READY]=1 
	[[ ! -d ${ZINIT[HOME_DIR]} ]] && {
		command mkdir -p "${ZINIT[HOME_DIR]}"
		command chmod go-w "${ZINIT[HOME_DIR]}"
		command mkdir -p $ZPFX/bin 2> /dev/null
	}
	[[ ! -d ${ZINIT[PLUGINS_DIR]}/_local---zinit ]] && {
		command rm -rf "${ZINIT[PLUGINS_DIR]:-${TMPDIR:-/tmp}/132bcaCAB}/_local---zplugin"
		command mkdir -p "${ZINIT[PLUGINS_DIR]}/_local---zinit"
		command chmod go-w "${ZINIT[PLUGINS_DIR]}"
		command ln -s "${ZINIT[BIN_DIR]}/_zinit" "${ZINIT[PLUGINS_DIR]}/_local---zinit"
		command mkdir -p $ZPFX/bin 2> /dev/null
		(( ${+functions[.zinit-setup-plugin-dir]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-install.zsh" || return 1
		(( ${+functions[.zinit-confirm]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-autoload.zsh" || return 1
		.zinit-clear-completions &> /dev/null
		.zinit-compinit &> /dev/null
	}
	[[ ! -d ${ZINIT[COMPLETIONS_DIR]} ]] && {
		command mkdir "${ZINIT[COMPLETIONS_DIR]}"
		command chmod go-w "${ZINIT[COMPLETIONS_DIR]}"
		command ln -s "${ZINIT[PLUGINS_DIR]}/_local---zinit/_zinit" "${ZINIT[COMPLETIONS_DIR]}"
		command mkdir -p $ZPFX/bin 2> /dev/null
		(( ${+functions[.zinit-setup-plugin-dir]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-install.zsh" || return 1
		.zinit-compinit &> /dev/null
	}
	[[ ! -d ${ZINIT[SNIPPETS_DIR]} ]] && {
		command mkdir -p "${ZINIT[SNIPPETS_DIR]}/OMZ::plugins"
		command chmod go-w "${ZINIT[SNIPPETS_DIR]}"
		(
			builtin cd ${ZINIT[SNIPPETS_DIR]}
			command ln -s OMZ::plugins plugins
		)
		command mkdir -p "${ZINIT[SERVICES_DIR]}"
		command chmod go-w "${ZINIT[SERVICES_DIR]}"
		command mkdir -p $ZPFX/bin 2> /dev/null
	}
	[[ ! -d ${~ZINIT[MAN_DIR]}/man9 ]] && {
		command mkdir -p ${~ZINIT[MAN_DIR]}/man{1..9} 2> /dev/null
	}
	[[ ! -f $ZINIT[MAN_DIR]/man1/zinit.1 || $ZINIT[MAN_DIR]/man1/zinit.1 -ot $ZINIT[BIN_DIR]/doc/zinit.1 ]] && {
		command mkdir -p $ZINIT[MAN_DIR]/man1
		command cp -f $ZINIT[BIN_DIR]/doc/zinit.1 $ZINIT[MAN_DIR]/man1
	}
}
.zinit-register-plugin () {
	local uspl2="$1" mode="$2" teleid="$3" 
	integer ret=0 
	if [[ -z ${ZINIT_REGISTERED_PLUGINS[(r)$uspl2]} ]]
	then
		ZINIT_REGISTERED_PLUGINS+=("$uspl2") 
	else
		[[ -z ${ZINIT[TEST]}${${+ICE[wait]}:#0}${ICE[load]}${ICE[subscribe]} && ${ZINIT[MUTE_WARNINGS]} != (1|true|on|yes) ]] && +zi-log "{u-warn}Warning{b-warn}:{rst} plugin {apo}\`{pid}${uspl2}{apo}\`{rst} already registered, will overwrite-load."
		ret=1 
	fi
	zsh_loaded_plugins+=("$teleid") 
	[[ $mode == light ]] && ZINIT[STATES__$uspl2]=1  || ZINIT[STATES__$uspl2]=2 
	ZINIT_REPORTS[$uspl2]= ZINIT_CUR_BIND_MAP=(empty 1) 
	ZINIT[FUNCTIONS_BEFORE__$uspl2]= ZINIT[FUNCTIONS_AFTER__$uspl2]= 
	ZINIT[FUNCTIONS__$uspl2]= 
	ZINIT[ZSTYLES__$uspl2]= ZINIT[BINDKEYS__$uspl2]= 
	ZINIT[ALIASES__$uspl2]= 
	ZINIT[WIDGETS_SAVED__$uspl2]= ZINIT[WIDGETS_DELETE__$uspl2]= 
	ZINIT[OPTIONS__$uspl2]= ZINIT[PATH__$uspl2]= 
	ZINIT[OPTIONS_BEFORE__$uspl2]= ZINIT[OPTIONS_AFTER__$uspl2]= 
	ZINIT[FPATH__$uspl2]= 
	return ret
}
.zinit-run () {
	if [[ $1 = (-l|--last) ]]
	then
		{
			set -- "${ZINIT[last-run-plugin]:-$(<${ZINIT[BIN_DIR]}/last-run-object.txt)}" "${@[2-correct,-1]}"
		} &> /dev/null
		[[ -z $1 ]] && {
			+zi-log "{u-warn}Error{b-warn}:{rst} No recent plugin-ID saved on the disk yet, please specify" "it as the first argument, i.e.{ehi}: {cmd}zi run {pid}usr/plg{slight} {…}the code to run{…} "
			return 1
		}
	else
		integer ___nolast=1 
	fi
	.zinit-any-to-user-plugin "$1" ""
	local ___id_as="$1" ___user="${reply[-2]}" ___plugin="${reply[-1]}" ___oldpwd="$PWD" 
	() {
		builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
		builtin cd -q ${${${(M)___user:#%}:+$___plugin}:-${ZINIT[PLUGINS_DIR]}/${___id_as//\//---}} &> /dev/null || {
			.zinit-get-object-path snippet "$___id_as"
			builtin cd -q $REPLY &> /dev/null
		}
	}
	if (( $? == 0 ))
	then
		(( ___nolast )) && {
			builtin print -r "$1" >| ${ZINIT[BIN_DIR]}/last-run-object.txt
		}
		ZINIT[last-run-plugin]="$1" 
		eval "${@[2-correct,-1]}"
		() {
			setopt localoptions noautopushd
			builtin cd -q "$___oldpwd"
		}
	else
		+zi-log "{u-warn}Error{b-warn}:{rst} no such plugin or snippet."
	fi
}
.zinit-run-task () {
	local ___pass="$1" ___t="$2" ___tpe="$3" ___idx="$4" ___mode="$5" ___id="${(Q)6}" ___opt="${(Q)7}" ___action ___s=1 ___retval=0 
	local -A ICE ZINIT_ICE
	ICE=("${(@Q)${(z@)ZINIT[WAIT_ICE_${___idx}]}}") 
	ZINIT_ICE=("${(kv)ICE[@]}") 
	local ___id_as=${ICE[id-as]:-$___id} 
	if [[ $___pass = 1 && ${${ICE[wait]#\!}%%[^0-9]([^0-9]|)([^0-9]|)([^0-9]|)} = <-> ]]
	then
		___action="${(M)ICE[wait]#\!}load" 
	elif [[ $___pass = 1 && -n ${ICE[wait]#\!} ]] && {
			eval "${ICE[wait]#\!}" || [[ $(( ___s=0 )) = 1 ]]
		}
	then
		___action="${(M)ICE[wait]#\!}load" 
	elif [[ -n ${ICE[load]#\!} && -n $(( ___s=0 )) && $___pass = 3 && -z ${ZINIT_REGISTERED_PLUGINS[(r)$___id_as]} ]] && eval "${ICE[load]#\!}"
	then
		___action="${(M)ICE[load]#\!}load" 
	elif [[ -n ${ICE[unload]#\!} && -n $(( ___s=0 )) && $___pass = 2 && -n ${ZINIT_REGISTERED_PLUGINS[(r)$___id_as]} ]] && eval "${ICE[unload]#\!}"
	then
		___action="${(M)ICE[unload]#\!}remove" 
	elif [[ -n ${ICE[subscribe]#\!} && -n $(( ___s=0 )) && $___pass = 3 ]] && {
			local -a fts_arr
			eval "fts_arr=( ${ICE[subscribe]}(DNms-$(( EPOCHSECONDS -
                 ZINIT[fts-${ICE[subscribe]}] ))) ); (( \${#fts_arr} ))" && {
				ZINIT[fts-${ICE[subscribe]}]="$EPOCHSECONDS" 
				___s=${+ICE[once]} 
			} || (( 0 ))
		}
	then
		___action="${(M)ICE[subscribe]#\!}load" 
	fi
	if [[ $___action = *load ]]
	then
		if [[ $___tpe = p* ]]
		then
			.zinit-load "${(@)=___id}" "" "$___mode" ${___tpe#p}
			(( ___retval += $? ))
		elif [[ $___tpe = s* ]]
		then
			.zinit-load-snippet $___opt "$___id" "" ${___tpe#s}
			(( ___retval += $? ))
		fi
		if [[ $___tpe = p1 || $___tpe = s1 ]]
		then
			(( ${+functions[.zinit-service]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-additional.zsh"
			zpty -b "${___id//\//:} / ${ICE[service]}" '.zinit-service '"${(M)___tpe#?}"' "$___mode" "$___id"'
		fi
		(( ${+ICE[silent]} == 0 && ${+ICE[lucid]} == 0 && ___retval == 0 )) && zle && zle -M "Loaded $___id"
	elif [[ $___action = *remove ]]
	then
		(( ${+functions[.zinit-confirm]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-autoload.zsh" || return 1
		[[ $___tpe = p ]] && .zinit-unload "$___id_as" "" -q
		(( ${+ICE[silent]} == 0 && ${+ICE[lucid]} == 0 && ___retval == 0 )) && zle && zle -M "Unloaded $___id_as"
	fi
	[[ ${REPLY::=$___action} = \!* ]] && zle && zle .reset-prompt
	return ___s
}
.zinit-set-m-func () {
	if [[ $1 == set ]]
	then
		ZINIT[___m_bkp]="${functions[m]}" 
		setopt noaliases
		functions[m]="${functions[+zi-log]}" 
		setopt aliases
	elif [[ $1 == unset ]]
	then
		if [[ -n ${ZINIT[___m_bkp]} ]]
		then
			setopt noaliases
			functions[m]="${ZINIT[___m_bkp]}" 
			setopt aliases
		else
			noglob unset functions[m]
		fi
	else
		+zi-log "{error}ERROR #1"
		return 1
	fi
}
.zinit-setup-params () {
	builtin emulate -LR zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}
	reply=(${(@)${(@s.;.)ICE[param]}/(#m)*/${${MATCH%%(-\>|→|=\>)*}//((#s)[[:space:]]##|[[:space:]]##(#e))}${${(M)MATCH#*(-\>|→|=\>)}:+\=${${MATCH#*(-\>|→|=\>)}//((#s)[[:space:]]##|[[:space:]]##(#e))}}}) 
	(( ${#reply} )) && return 0 || return 1
}
.zinit-submit-turbo () {
	local tpe="$1" mode="$2" opt_uspl2="$3" opt_plugin="$4" 
	ICE[wait]="${ICE[wait]%%.[0-9]##}" 
	ZINIT[WAIT_IDX]=$(( ${ZINIT[WAIT_IDX]:-0} + 1 )) 
	ZINIT[WAIT_ICE_${ZINIT[WAIT_IDX]}]="${(j: :)${(qkv)ICE[@]}}" 
	ZINIT[fts-${ICE[subscribe]}]="${ICE[subscribe]:+$EPOCHSECONDS}" 
	[[ $tpe = s* ]] && local id="${${opt_plugin:+$opt_plugin}:-$opt_uspl2}"  || local id="${${opt_plugin:+$opt_uspl2${${opt_uspl2:#%*}:+/}$opt_plugin}:-$opt_uspl2}" 
	if [[ ${${ICE[wait]}%%[^0-9]([^0-9]|)([^0-9]|)([^0-9]|)} = (\!|.|)<-> ]]
	then
		ZINIT_TASKS+=("$EPOCHSECONDS+${${ICE[wait]#(\!|.)}%%[^0-9]([^0-9]|)([^0-9]|)([^0-9]|)}+${${${(M)ICE[wait]%a}:+1}:-${${${(M)ICE[wait]%b}:+2}:-${${${(M)ICE[wait]%c}:+3}:-1}}} $tpe ${ZINIT[WAIT_IDX]} ${mode:-_} ${(q)id} ${opt_plugin:+${(q)opt_uspl2}}") 
	elif [[ -n ${ICE[wait]}${ICE[load]}${ICE[unload]}${ICE[subscribe]} ]]
	then
		ZINIT_TASKS+=("${${ICE[wait]:+0}:-1}+0+1 $tpe ${ZINIT[WAIT_IDX]} ${mode:-_} ${(q)id} ${opt_plugin:+${(q)opt_uspl2}}") 
	fi
}
.zinit-tmp-subst-off () {
	builtin setopt localoptions noerrreturn noerrexit extendedglob warncreateglobal typesetsilent noshortloops unset noaliases
	local mode="$1" 
	[[ ${ZINIT[TMP_SUBST]} = inactive || ${ZINIT[TMP_SUBST]} != $mode ]] && return 0
	ZINIT[TMP_SUBST]=inactive 
	if [[ $mode != compdef ]]
	then
		(( ${+ZINIT[bkp-autoload]} )) && functions[autoload]="${ZINIT[bkp-autoload]}"  || unfunction autoload
	fi
	(( ${+ZINIT[bkp-compdef]} )) && functions[compdef]="${ZINIT[bkp-compdef]}"  || unfunction compdef
	(( ${+ZINIT[bkp-source]} )) && functions[source]="${ZINIT[bkp-source]}"  || unfunction source 2> /dev/null
	(( ${+ZINIT[bkp-.]} )) && functions[.]="${ZINIT[bkp-.]}"  || unfunction . 2> /dev/null
	[[ ( $mode = light && ${+ICE[trackbinds]} -eq 0 ) || $mode = compdef ]] && return 0
	(( ${+ZINIT[bkp-bindkey]} )) && functions[bindkey]="${ZINIT[bkp-bindkey]}"  || unfunction bindkey
	[[ $mode = light-b || ( $mode = light && ${+ICE[trackbinds]} -eq 1 ) ]] && return 0
	(( ${+ZINIT[bkp-zstyle]} )) && functions[zstyle]="${ZINIT[bkp-zstyle]}"  || unfunction zstyle
	(( ${+ZINIT[bkp-alias]} )) && functions[alias]="${ZINIT[bkp-alias]}"  || unfunction alias
	(( ${+ZINIT[bkp-zle]} )) && functions[zle]="${ZINIT[bkp-zle]}"  || unfunction zle
	return 0
}
.zinit-tmp-subst-on () {
	local mode="$1" 
	[[ ${ZINIT[TMP_SUBST]} != inactive ]] && builtin return 0
	ZINIT[TMP_SUBST]="$mode" 
	builtin unset "ZINIT[bkp-autoload]" "ZINIT[bkp-compdef]"
	if [[ $mode != compdef ]]
	then
		(( ${+functions[autoload]} )) && ZINIT[bkp-autoload]="${functions[autoload]}" 
		functions[autoload]=':zinit-tmp-subst-autoload "$@";' 
	fi
	(( ${+functions[compdef]} )) && ZINIT[bkp-compdef]="${functions[compdef]}" 
	functions[compdef]=':zinit-tmp-subst-compdef "$@";' 
	if [[ -n ${ICE[subst]} ]]
	then
		(( ${+functions[source]} )) && ZINIT[bkp-source]="${functions[source]}" 
		(( ${+functions[.]} )) && ZINIT[bkp-.]="${functions[.]}" 
		(( ${+functions[.zinit-service]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-additional.zsh"
		functions[source]=':zinit-tmp-subst-source "$@";' 
		functions[.]=':zinit-tmp-subst-source "$@";' 
	fi
	[[ ( $mode = light && ${+ICE[trackbinds]} -eq 0 ) || $mode = compdef ]] && return 0
	builtin unset "ZINIT[bkp-bindkey]" "ZINIT[bkp-zstyle]" "ZINIT[bkp-alias]" "ZINIT[bkp-zle]"
	(( ${+functions[bindkey]} )) && ZINIT[bkp-bindkey]="${functions[bindkey]}" 
	functions[bindkey]=':zinit-tmp-subst-bindkey "$@";' 
	[[ $mode = light-b || ( $mode = light && ${+ICE[trackbinds]} -eq 1 ) ]] && return 0
	(( ${+functions[zstyle]} )) && ZINIT[bkp-zstyle]="${functions[zstyle]}" 
	functions[zstyle]=':zinit-tmp-subst-zstyle "$@";' 
	(( ${+functions[alias]} )) && ZINIT[bkp-alias]="${functions[alias]}" 
	functions[alias]=':zinit-tmp-subst-alias "$@";' 
	(( ${+functions[zle]} )) && ZINIT[bkp-zle]="${functions[zle]}" 
	functions[zle]=':zinit-tmp-subst-zle "$@";' 
	builtin return 0
}
.zinit-util-shands-path () {
	builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
	builtin setopt extendedglob typesetsilent noshortloops rcquotes ${${${+REPLY}:#0}:+warncreateglobal}
	local -A map
	map=(\~ %HOME $HOME %HOME $ZINIT[SNIPPETS_DIR] %SNIPPETS $ZINIT[PLUGINS_DIR] %PLUGINS "$ZPFX" %ZPFX HOME %HOME SNIPPETS %SNIPPETS PLUGINS %PLUGINS "" "") 
	REPLY=${${1/(#b)(#s)(%|)(${(~j:|:)${(@k)map:#$HOME}}|$HOME|)/$map[$match[2]]}} 
	return 0
}
:zinit-reload-and-run () {
	local fpath_prefix="$1" autoload_opts="$2" func="$3" 
	shift 3
	unfunction -- "$func"
	local -a ___fpath
	___fpath=(${fpath[@]}) 
	local -a +h fpath
	[[ $FPATH != *${${(@0)fpath_prefix}[1]}* ]] && fpath=(${(@0)fpath_prefix} ${___fpath[@]}) 
	builtin autoload ${(s: :)autoload_opts} -- "$func"
	"$func" "$@"
}
:zinit-tmp-subst-alias () {
	builtin setopt localoptions noerrreturn noerrexit extendedglob warncreateglobal typesetsilent noshortloops unset
	.zinit-add-report "${ZINIT[CUR_USPL2]}" "Alias $*"
	typeset -a pos
	pos=("$@") 
	local -a opts
	zparseopts -a opts -D ${(s::):-gs}
	local a quoted tmp
	for a in "$@"
	do
		local aname="${a%%[=]*}" 
		local avalue="${a#*=}" 
		(( ${+aliases[$aname]} )) && .zinit-add-report "${ZINIT[CUR_USPL2]}" "Warning: redefining alias \`${aname}', previous value: ${aliases[$aname]}"
		local bname=${(q)aliases[$aname]} 
		aname="${(q)aname}" 
		if (( ${+opts[(r)-s]} ))
		then
			tmp=-s 
			tmp="${(q)tmp}" 
			quoted="$aname $bname $tmp" 
		elif (( ${+opts[(r)-g]} ))
		then
			tmp=-g 
			tmp="${(q)tmp}" 
			quoted="$aname $bname $tmp" 
		else
			quoted="$aname $bname" 
		fi
		quoted="${(q)quoted}" 
		[[ -n ${ZINIT[CUR_USPL2]} ]] && ZINIT[ALIASES__${ZINIT[CUR_USPL2]}]+="$quoted " 
		[[ ${ZINIT[DTRACE]} = 1 ]] && ZINIT[ALIASES___dtrace/_dtrace]+="$quoted " 
	done
	builtin alias "${pos[@]}"
	return $?
}
:zinit-tmp-subst-autoload () {
	builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
	builtin setopt extendedglob warncreateglobal typesetsilent rcquotes
	local -a opts opts2 custom reply
	local func
	zparseopts -D -E -M -a opts ${(s::):-RTUXdkmrtWzwC} I+=opts2 S+:=custom
	builtin set -- ${@:#--}
	.zinit-any-to-user-plugin $ZINIT[CUR_USPL2]
	[[ $reply[1] = % ]] && local PLUGIN_DIR="$reply[2]"  || local PLUGIN_DIR="$ZINIT[PLUGINS_DIR]/${reply[1]:+$reply[1]---}${reply[2]//\//---}" 
	local -a fpath_elements
	fpath_elements=(${fpath[(r)$PLUGIN_DIR/*]}) 
	[[ -d $PLUGIN_DIR/functions ]] && fpath_elements+=("$PLUGIN_DIR"/functions) 
	if (( ${+opts[(r)-X]} ))
	then
		.zinit-add-report "${ZINIT[CUR_USPL2]}" "Warning: Failed autoload ${(j: :)opts[@]} $*"
		+zi-log -u2 "{error}builtin autoload required for {obj}${(j: :)opts[@]}{error} option(s)"
		return 1
	fi
	if (( ${+opts[(r)-w]} ))
	then
		.zinit-add-report "${ZINIT[CUR_USPL2]}" "-w-Autoload ${(j: :)opts[@]} ${(j: :)@}"
		fpath+=($PLUGIN_DIR) 
		builtin autoload ${opts[@]} "$@"
		return $?
	fi
	if [[ -n ${(M)@:#+X} ]]
	then
		.zinit-add-report "${ZINIT[CUR_USPL2]}" "Autoload +X ${opts:+${(j: :)opts[@]} }${(j: :)${@:#+X}}"
		local +h FPATH=$PLUGINS_DIR${fpath_elements:+:${(j.:.)fpath_elements[@]}}:$FPATH 
		local +h -a fpath
		fpath=($PLUGIN_DIR $fpath_elements $fpath) 
		builtin autoload +X ${opts[@]} "${@:#+X}"
		return $?
	fi
	for func
	do
		.zinit-add-report "${ZINIT[CUR_USPL2]}" "Autoload $func${opts:+ with options ${(j: :)opts[@]}}"
	done
	integer count retval
	for func
	do
		if (( ${+functions[$func]} != 1 ))
		then
			builtin setopt noaliases
			if [[ $func == /* ]] && is-at-least 5.4
			then
				builtin autoload ${opts[@]} $func
				return $?
			elif [[ $func == /* ]]
			then
				if [[ $ZINIT[MUTE_WARNINGS] != (1|true|on|yes) && -z $ZINIT[WARN_SHOWN_FOR_$ZINIT[CUR_USPL2]] ]]
				then
					+zi-log "{u-warn}Warning{b-warn}: {rst}the plugin {pid}$ZINIT[CUR_USPL2]" "{rst}is using autoload functions specified by their absolute path," "which is not supported by this Zsh version ({↔} {version}$ZSH_VERSION{rst}," "required is Zsh >= {version}5.4{rst})." "{nl}A fallback mechanism has been applied, which works well only" "for functions in the plugin {u}{slight}main{rst} directory." "{nl}(To mute this message, set" "{var}\$ZINIT[MUTE_WARNINGS]{rst} to a truth value.)"
					ZINIT[WARN_SHOWN_FOR_$ZINIT[CUR_USPL2]]=1 
				fi
				func=$func:t 
			fi
			if [[ ${ZINIT[NEW_AUTOLOAD]} = 2 ]]
			then
				builtin autoload ${opts[@]} "$PLUGIN_DIR/$func"
				retval=$? 
			elif [[ ${ZINIT[NEW_AUTOLOAD]} = 1 ]]
			then
				if (( ${+opts[(r)-C]} ))
				then
					local pth nl=$'\n' sel="" 
					for pth in $PLUGIN_DIR $fpath_elements $fpath
					do
						[[ -f $pth/$func ]] && {
							sel=$pth 
							break
						}
					done
					if [[ -z $sel ]]
					then
						+zi-log '{u-warn}zinit{b-warn}:{error} Couldn''t find autoload function{ehi}:' "{apo}\`{file}${func}{apo}\`{error} anywhere in {var}\$fpath{error}."
						retval=1 
					else
						eval "function ${(q)${custom[++count*2]}:-$func} {
                            local body=\"\$(<${(qqq)sel}/${(qqq)func})\" body2
                            () { setopt localoptions extendedglob
                                 body2=\"\${body##[[:space:]]#${func}[[:blank:]]#\(\)[[:space:]]#\{}\"
                                 [[ \$body2 != \$body ]] &&                                     body2=\"\${body2%\}[[:space:]]#([$nl]#([[:blank:]]#\#[^$nl]#((#e)|[$nl]))#)#}\"
                            }

                            functions[${${(q)custom[count*2]}:-$func}]=\"\$body2\"
                            ${(q)${custom[count*2]}:-$func} \"\$@\"
                        }"
						retval=$? 
					fi
				else
					functions[$func]="
                        local -a fpath
                        fpath=( ${(qqq)PLUGIN_DIR} ${(qqq@)fpath_elements} ${(qqq@)fpath} )
                        builtin autoload -X ${(j: :)${(q-)opts[@]}}
                    " 
					retval=$? 
				fi
			else
				eval "function ${(q)func} {
                    :zinit-reload-and-run ${(qqq)PLUGIN_DIR}"$'\0'"${(pj,\0,)${(qqq)fpath_elements[@]}} ${(qq)opts[*]} ${(q)func} "'"$@"
                }'
				retval=$? 
			fi
			(( ZINIT[ALIASES_OPT] )) && builtin setopt aliases
		fi
		if (( ${+opts2[(r)-I]} ))
		then
			${custom[count*2]:-$func}
			retval=$? 
		fi
	done
	return $retval
}
:zinit-tmp-subst-bindkey () {
	builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
	builtin setopt extendedglob warncreateglobal typesetsilent noshortloops
	is-at-least 5.3 && .zinit-add-report "${ZINIT[CUR_USPL2]}" "Bindkey ${(j: :)${(q+)@}}" || .zinit-add-report "${ZINIT[CUR_USPL2]}" "Bindkey ${(j: :)${(q)@}}"
	typeset -a pos
	pos=("$@") 
	local -A opts
	zparseopts -A opts -D ${(s::):-lLdDAmrsevaR} M: N:
	if (( ${#opts} == 0 ||
        ( ${#opts} == 1 && ${+opts[-M]} ) ||
        ( ${#opts} == 1 && ${+opts[-R]} ) ||
        ( ${#opts} == 1 && ${+opts[-s]} ) ||
        ( ${#opts} <= 2 && ${+opts[-M]} && ${+opts[-s]} ) ||
        ( ${#opts} <= 2 && ${+opts[-M]} && ${+opts[-R]} )
    ))
	then
		local string="${(q)1}" widget="${(q)2}" 
		local quoted
		if [[ -n ${ICE[bindmap]} && ${ZINIT_CUR_BIND_MAP[empty]} -eq 1 ]]
		then
			local -a pairs
			pairs=("${(@s,;,)ICE[bindmap]}") 
			if [[ -n ${(M)pairs:#*\\(#e)} ]]
			then
				local prev
				pairs=(${pairs[@]//(#b)((*)\\(#e)|(*))/${match[3]:+${prev:+$prev\;}}${match[3]}${${prev::=${match[2]:+${prev:+$prev\;}}${match[2]}}:+}}) 
			fi
			pairs=("${(@)${(@)${(@s:->:)pairs}##[[:space:]]##}%%[[:space:]]##}") 
			ZINIT_CUR_BIND_MAP=(empty 0) 
			(( ${#pairs} > 1 && ${#pairs[@]} % 2 == 0 )) && ZINIT_CUR_BIND_MAP+=("${pairs[@]}") 
		fi
		local bmap_val="${ZINIT_CUR_BIND_MAP[${1}]}" 
		if (( !ZINIT_CUR_BIND_MAP[empty] ))
		then
			[[ -z $bmap_val ]] && bmap_val="${ZINIT_CUR_BIND_MAP[${(qqq)1}]}" 
			[[ -z $bmap_val ]] && bmap_val="${ZINIT_CUR_BIND_MAP[${(qqq)${(Q)1}}]}" 
			[[ -z $bmap_val ]] && {
				bmap_val="${ZINIT_CUR_BIND_MAP[!${(qqq)1}]}" 
				integer val=1 
			}
			[[ -z $bmap_val ]] && bmap_val="${ZINIT_CUR_BIND_MAP[!${(qqq)${(Q)1}}]}" 
		fi
		if [[ -n $bmap_val ]]
		then
			string="${(q)bmap_val}" 
			if (( val ))
			then
				[[ ${pos[1]} = "-M" ]] && pos[4]="$bmap_val"  || pos[2]="$bmap_val" 
			else
				[[ ${pos[1]} = "-M" ]] && pos[3]="${(Q)bmap_val}"  || pos[1]="${(Q)bmap_val}" 
			fi
			.zinit-add-report "${ZINIT[CUR_USPL2]}" ":::Bindkey: combination <$1> changed to <$bmap_val>${${(M)bmap_val:#hold}:+, i.e. ${ZINIT[col-error]}unmapped${ZINIT[col-rst]}}"
			((1))
		elif [[ ( -n ${bmap_val::=${ZINIT_CUR_BIND_MAP[UPAR]}} && -n ${${ZINIT[UPAR]}[(r);:${(q)1};:]} ) || ( -n ${bmap_val::=${ZINIT_CUR_BIND_MAP[DOWNAR]}} && -n ${${ZINIT[DOWNAR]}[(r);:${(q)1};:]} ) || ( -n ${bmap_val::=${ZINIT_CUR_BIND_MAP[RIGHTAR]}} && -n ${${ZINIT[RIGHTAR]}[(r);:${(q)1};:]} ) || ( -n ${bmap_val::=${ZINIT_CUR_BIND_MAP[LEFTAR]}} && -n ${${ZINIT[LEFTAR]}[(r);:${(q)1};:]} ) ]]
		then
			string="${(q)bmap_val}" 
			if (( val ))
			then
				[[ ${pos[1]} = "-M" ]] && pos[4]="$bmap_val"  || pos[2]="$bmap_val" 
			else
				[[ ${pos[1]} = "-M" ]] && pos[3]="${(Q)bmap_val}"  || pos[1]="${(Q)bmap_val}" 
			fi
			.zinit-add-report "${ZINIT[CUR_USPL2]}" ":::Bindkey: combination <$1> recognized as cursor-key and changed to <${bmap_val}>${${(M)bmap_val:#hold}:+, i.e. ${ZINIT[col-error]}unmapped${ZINIT[col-rst]}}"
		fi
		[[ $bmap_val = hold ]] && return 0
		local prev="${(q)${(s: :)$(builtin bindkey ${(Q)string})}[-1]#undefined-key}" 
		if (( ${+opts[-M]} ))
		then
			local Mopt=-M 
			local Marg="${opts[-M]}" 
			Mopt="${(q)Mopt}" 
			Marg="${(q)Marg}" 
			quoted="$string $widget $prev $Mopt $Marg" 
		else
			quoted="$string $widget $prev" 
		fi
		if (( ${+opts[-R]} ))
		then
			local Ropt=-R 
			Ropt="${(q)Ropt}" 
			if (( ${+opts[-M]} ))
			then
				quoted="$quoted $Ropt" 
			else
				local space=_ 
				space="${(q)space}" 
				quoted="$quoted $space $space $Ropt" 
			fi
		fi
		quoted="${(q)quoted}" 
		[[ -n ${ZINIT[CUR_USPL2]} ]] && ZINIT[BINDKEYS__${ZINIT[CUR_USPL2]}]+="$quoted " 
		[[ ${ZINIT[DTRACE]} = 1 ]] && ZINIT[BINDKEYS___dtrace/_dtrace]+="$quoted " 
	else
		if [[ ${#opts} -eq 1 && ${+opts[-A]} = 1 && ${#pos} = 3 && ${pos[-1]} = main && ${pos[-2]} != -A ]]
		then
			(( ZINIT[BINDKEY_MAIN_IDX] = ${ZINIT[BINDKEY_MAIN_IDX]:-0} + 1 ))
			local pname="${ZINIT[CUR_PLUGIN]:-_dtrace}" 
			local name="${(q)pname}-main-${ZINIT[BINDKEY_MAIN_IDX]}" 
			builtin bindkey -N "$name" main
			local keys=_ widget=_ prev= optA=-A mapname="${name}" optR=_ 
			local quoted="${(q)keys} ${(q)widget} ${(q)prev} ${(q)optA} ${(q)mapname} ${(q)optR}" 
			quoted="${(q)quoted}" 
			[[ -n ${ZINIT[CUR_USPL2]} ]] && ZINIT[BINDKEYS__${ZINIT[CUR_USPL2]}]+="$quoted " 
			[[ ${ZINIT[DTRACE]} = 1 ]] && ZINIT[BINDKEYS___dtrace/_dtrace]+="$quoted " 
			.zinit-add-report "${ZINIT[CUR_USPL2]}" "Warning: keymap \`main' copied to \`${name}' because of \`${pos[-2]}' substitution"
		elif [[ ${#opts} -eq 1 && ${+opts[-N]} = 1 ]]
		then
			local Nopt=-N 
			local Narg="${opts[-N]}" 
			local keys=_ widget=_ prev= optN=-N mapname="${Narg}" optR=_ 
			local quoted="${(q)keys} ${(q)widget} ${(q)prev} ${(q)optN} ${(q)mapname} ${(q)optR}" 
			quoted="${(q)quoted}" 
			[[ -n ${ZINIT[CUR_USPL2]} ]] && ZINIT[BINDKEYS__${ZINIT[CUR_USPL2]}]+="$quoted " 
			[[ ${ZINIT[DTRACE]} = 1 ]] && ZINIT[BINDKEYS___dtrace/_dtrace]+="$quoted " 
		else
			.zinit-add-report "${ZINIT[CUR_USPL2]}" "Warning: last bindkey used non-typical options: ${(kv)opts[*]}"
		fi
	fi
	builtin bindkey "${pos[@]}"
	return $?
}
:zinit-tmp-subst-compdef () {
	builtin setopt localoptions noerrreturn noerrexit extendedglob warncreateglobal typesetsilent noshortloops unset
	.zinit-add-report "${ZINIT[CUR_USPL2]}" "Saving \`compdef $*' for replay"
	ZINIT_COMPDEF_REPLAY+=("${(j: :)${(q)@}}") 
	return 0
}
:zinit-tmp-subst-zle () {
	builtin setopt localoptions noerrreturn noerrexit extendedglob warncreateglobal typesetsilent noshortloops unset
	.zinit-add-report "${ZINIT[CUR_USPL2]}" "Zle $*"
	typeset -a pos
	pos=("$@") 
	builtin set -- "${@:#--}"
	if [[ ( $1 = -N && ( $# = 2 || $# = 3 ) ) || ( $1 = -C && $# = 4 ) ]]
	then
		if [[ ${ZINIT_ZLE_HOOKS_LIST[$2]} = 1 ]]
		then
			local quoted="$2" 
			quoted="${(q)quoted}" 
			[[ -n ${ZINIT[CUR_USPL2]} ]] && ZINIT[WIDGETS_DELETE__${ZINIT[CUR_USPL2]}]+="$quoted " 
			[[ ${ZINIT[DTRACE]} = 1 ]] && ZINIT[WIDGETS_DELETE___dtrace/_dtrace]+="$quoted " 
		elif (( ${+widgets[$2]} ))
		then
			local widname="$2" targetfun="${${${(M)1:#-C}:+$4}:-$3}" 
			local completion_widget="${${(M)1:#-C}:+$3}" 
			local saved_widcontents="${widgets[$widname]}" 
			widname="${(q)widname}" 
			completion_widget="${(q)completion_widget}" 
			targetfun="${(q)targetfun}" 
			saved_widcontents="${(q)saved_widcontents}" 
			local quoted="$1 $widname $completion_widget $targetfun $saved_widcontents" 
			quoted="${(q)quoted}" 
			[[ -n ${ZINIT[CUR_USPL2]} ]] && ZINIT[WIDGETS_SAVED__${ZINIT[CUR_USPL2]}]+="$quoted " 
			[[ ${ZINIT[DTRACE]} = 1 ]] && ZINIT[WIDGETS_SAVED___dtrace/_dtrace]+="$quoted " 
		else
			.zinit-add-report "${ZINIT[CUR_USPL2]}" "Note: a new widget created via zle -N: \`$2'"
			local quoted="$2" 
			quoted="${(q)quoted}" 
			[[ -n ${ZINIT[CUR_USPL2]} ]] && ZINIT[WIDGETS_DELETE__${ZINIT[CUR_USPL2]}]+="$quoted " 
			[[ ${ZINIT[DTRACE]} = 1 ]] && ZINIT[WIDGETS_DELETE___dtrace/_dtrace]+="$quoted " 
		fi
	fi
	builtin zle "${pos[@]}"
	return $?
}
:zinit-tmp-subst-zstyle () {
	builtin setopt localoptions noerrreturn noerrexit extendedglob nowarncreateglobal typesetsilent noshortloops unset
	.zinit-add-report "${ZINIT[CUR_USPL2]}" "Zstyle $*"
	typeset -a pos
	pos=("$@") 
	local -a opts
	zparseopts -a opts -D ${(s::):-eLdgabsTtm}
	if [[ ${#opts} -eq 0 || ( ${#opts} -eq 1 && ${+opts[(r)-e]} = 1 ) ]]
	then
		local pattern="${(q)1}" style="${(q)2}" 
		local ps="$pattern $style" 
		ps="${(q)ps}" 
		[[ -n ${ZINIT[CUR_USPL2]} ]] && ZINIT[ZSTYLES__${ZINIT[CUR_USPL2]}]+="$ps " 
		[[ ${ZINIT[DTRACE]} = 1 ]] && ZINIT[ZSTYLES___dtrace/_dtrace]+=$ps 
	else
		if [[ ! ${#opts[@]} = 1 && ( ${+opts[(r)-s]} = 1 || ${+opts[(r)-b]} = 1 || ${+opts[(r)-a]} = 1 || ${+opts[(r)-t]} = 1 || ${+opts[(r)-T]} = 1 || ${+opts[(r)-m]} = 1 ) ]]
		then
			.zinit-add-report "${ZINIT[CUR_USPL2]}" "Warning: last zstyle used non-typical options: ${opts[*]}"
		fi
	fi
	builtin zstyle "${pos[@]}"
	return $?
}
@autoload () {
	:zinit-tmp-subst-autoload -Uz ${(s: :)${${(j: :)${@#\!}}//(#b)((*)(->|=>|→)(*)|(*))/${match[2]:+$match[2]       -S $match[4]}${match[5]:+${match[5]}       -S ${match[5]}}}} ${${${(@M)${@#\!}:#*(->|=>|→)*}}:+-C} ${${@#\!}:+-C}
}
@zinit-register-annex () {
	builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
	builtin setopt nobanghist
	local name="$1" type="$2" handler="$3" helphandler="$4" icemods="$5" key="z-annex ${(q)2}" 
	ZINIT_EXTS[seqno]=$(( ${ZINIT_EXTS[seqno]:-0} + 1 )) 
	ZINIT_EXTS[$key${${(M)type#hook:}:+ ${ZINIT_EXTS[seqno]}}]="${ZINIT_EXTS[seqno]} z-annex-data: ${(q)name} ${(q)type} ${(q)handler} ${(q)helphandler} ${(q)icemods}" 
	() {
		builtin emulate -LR zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}
		builtin setopt nobanghist
		integer index="${type##[%a-zA-Z:_!-]##}" 
		ZINIT_EXTS[ice-mods]="${ZINIT_EXTS[ice-mods]}${icemods:+|}${(j:|:)${(@)${(@s:|:)icemods}/(#b)(#s)(?)/$index-$match[1]}}" 
	}
}
@zinit-register-hook () {
	builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
	builtin setopt extendedglob nobanghist noshortloops typesetsilent warncreateglobal
	local name="$1" type="$2" handler="$3" icemods="$4" key="zinit ${(q)2}" 
	ZINIT_EXTS2[seqno]=$(( ${ZINIT_EXTS2[seqno]:-0} + 1 )) 
	ZINIT_EXTS2[$key${${(M)type#hook:}:+ ${ZINIT_EXTS2[seqno]}}]="${ZINIT_EXTS2[seqno]} z-annex-data: ${(q)name} ${(q)type} ${(q)handler} '' ${(q)icemods}" 
	ZINIT_EXTS2[ice-mods]="${ZINIT_EXTS2[ice-mods]}${icemods:+|}$icemods" 
}
@zinit-scheduler () {
	integer ___ret="${${ZINIT[lro-data]%:*}##*:}" 
	[[ $1 = following ]] && sched +1 'ZINIT[lro-data]="$_:$?:${options[printexitvalue]}"; @zinit-scheduler following "${ZINIT[lro-data]%:*:*}"'
	[[ -n $1 && $1 != (following*|burst) ]] && {
		local THEFD="$1" 
		zle -F "$THEFD"
		exec {THEFD}<&-
	}
	[[ $1 = burst ]] && local -h EPOCHSECONDS=$(( EPOCHSECONDS+10000 )) 
	ZINIT[START_TIME]="${ZINIT[START_TIME]:-$EPOCHREALTIME}" 
	integer ___t=EPOCHSECONDS ___i correct 
	local -a match mbegin mend reply
	local MATCH REPLY AFD
	integer MBEGIN MEND
	[[ -o ksharrays ]] && correct=1 
	if [[ -n $1 ]]
	then
		if [[ ${#ZINIT_RUN} -le 1 || $1 = following ]]
		then
			() {
				builtin emulate -L zsh ${=${options[xtrace]:#off}:+-o xtrace}
				builtin setopt extendedglob
				integer ___idx1 ___idx2
				local ___ar2 ___ar3 ___ar4 ___ar5
				for ((___idx1 = 0; ___idx1 <= 4; ___idx1 ++ )) do
					for ((___idx2 = 1; ___idx2 <= (___idx >= 4 ? 1 : 3); ___idx2 ++ )) do
						___i=2 
						ZINIT_TASKS=(${ZINIT_TASKS[@]/(#b)([0-9]##)+([0-9]##)+([1-3])(*)/${ZINIT_TASKS[
                        $(( (___ar2=${match[2]}+1) ? (
                            (___ar3=${(M)match[3]%[1-3]}) ? (
                            (___ar4=___idx1+1) ? (
                            (___ar5=___idx2) ? (
                (${match[1]}+${match[2]}) <= $___t ?
                zinit_scheduler_add(___i++) : ___i++ )
                            : 1 )
                            : 1 )
                            : 1 )
                            : 1  ))]}}) 
						ZINIT_TASKS=("<no-data>" ${ZINIT_TASKS[@]:#<no-data>}) 
					done
				done
			}
		fi
	else
		add-zsh-hook -d -- precmd @zinit-scheduler
		add-zsh-hook -- chpwd @zinit-scheduler
		() {
			builtin emulate -L zsh ${=${options[xtrace]:#off}:+-o xtrace}
			builtin setopt extendedglob
			ZINIT_TASKS=(${ZINIT_TASKS[@]/(#b)([0-9]##)(*)/$(( ${match[1]} <= 1 ? ${match[1]} : ___t ))${match[2]}}) 
		}
		sched +1 'ZINIT[lro-data]="$_:$?:${options[printexitvalue]}"; @zinit-scheduler following ${ZINIT[lro-data]%:*:*}'
		AFD=13371337 
		exec {AFD}< <(LANG=C command sleep 0.002; builtin print run;)
		command true
		zle -F "$AFD" @zinit-scheduler
	fi
	local ___task ___idx=0 ___count=0 ___idx2 
	for ___task in "${ZINIT_RUN[@]}"
	do
		.zinit-run-task 1 "${(@z)___task}" && ZINIT_TASKS+=("$___task") 
		if [[ $(( ++___idx, ___count += ${${REPLY:+1}:-0} )) -gt 0 && $1 != burst ]]
		then
			AFD=13371337 
			exec {AFD}< <(LANG=C command sleep 0.0002; builtin print run;)
			command true
			zle -F "$AFD" @zinit-scheduler
			break
		fi
	done
	for ((___idx2=1; ___idx2 <= ___idx; ++ ___idx2 )) do
		.zinit-run-task 2 "${(@z)ZINIT_RUN[___idx2-correct]}"
	done
	for ((___idx2=1; ___idx2 <= ___idx; ++ ___idx2 )) do
		.zinit-run-task 3 "${(@z)ZINIT_RUN[___idx2-correct]}"
	done
	ZINIT_RUN[1-correct,___idx-correct]=() 
	[[ ${ZINIT[lro-data]##*:} = on ]] && return 0 || return ___ret
}
@zinit-substitute () {
	builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
	builtin setopt extendedglob warncreateglobal typesetsilent noshortloops
	local -A ___subst_map
	___subst_map=("%ID%" "${id_as_clean:-$id_as}" "%USER%" "$user" "%PLUGIN%" "${plugin:-$save_url}" "%URL%" "${save_url:-${user:+$user/}$plugin}" "%DIR%" "${local_path:-$local_dir${dirname:+/$dirname}}" '$ZPFX' "$ZPFX" '${ZPFX}' "$ZPFX" '%OS%' "${OSTYPE%(-gnu|[0-9]##)}" '%MACH%' "$MACHTYPE" '%CPU%' "$CPUTYPE" '%VENDOR%' "$VENDOR" '%HOST%' "$HOST" '%UID%' "$UID" '%GID%' "$GID") 
	if [[ -n ${ICE[param]} && ${ZINIT[SUBST_DONE_FOR]} != ${ICE[param]} ]]
	then
		ZINIT[SUBST_DONE_FOR]=${ICE[param]} 
		ZINIT[PARAM_SUBST]= 
		local -a ___params
		___params=(${(s.;.)ICE[param]}) 
		local ___param ___from ___to
		for ___param in ${___params[@]}
		do
			local ___from=${${___param%%([[:space:]]|)(->|→)*}##[[:space:]]##} ___to=${${___param#*(->|→)([[:space:]]|)}%[[:space:]]} 
			___from=${___from//((#s)[[:space:]]##|[[:space:]]##(#e))/} 
			___to=${___to//((#s)[[:space:]]##|[[:space:]]##(#e))/} 
			ZINIT[PARAM_SUBST]+="%${(q)___from}% ${(q)___to} " 
		done
	fi
	local -a ___add
	___add=("${ICE[param]:+${(@Q)${(@z)ZINIT[PARAM_SUBST]}}}") 
	(( ${#___add} % 2 == 0 )) && ___subst_map+=("${___add[@]}") 
	local ___var_name
	for ___var_name
	do
		local ___value=${(P)___var_name} 
		___value=${___value//(#m)(%[a-zA-Z0-9]##%|\$ZPFX|\$\{ZPFX\})/${___subst_map[$MATCH]}} 
		: ${(P)___var_name::=$___value}
	done
}
@zsh-plugin-run-on-unload () {
	ICE[ps-on-unload]="${(j.; .)@}" 
	.zinit-pack-ice "$id_as" ""
}
@zsh-plugin-run-on-update () {
	ICE[ps-on-update]="${(j.; .)@}" 
	.zinit-pack-ice "$id_as" ""
}
add-zsh-hook () {
	emulate -L zsh
	local -a hooktypes
	hooktypes=(chpwd precmd preexec periodic zshaddhistory zshexit zsh_directory_name) 
	local usage="Usage: add-zsh-hook hook function\nValid hooks are:\n  $hooktypes" 
	local opt
	local -a autoopts
	integer del list help
	while getopts "dDhLUzk" opt
	do
		case $opt in
			(d) del=1  ;;
			(D) del=2  ;;
			(h) help=1  ;;
			(L) list=1  ;;
			([Uzk]) autoopts+=(-$opt)  ;;
			(*) return 1 ;;
		esac
	done
	shift $(( OPTIND - 1 ))
	if (( list ))
	then
		typeset -mp "(${1:-${(@j:|:)hooktypes}})_functions"
		return $?
	elif (( help || $# != 2 || ${hooktypes[(I)$1]} == 0 ))
	then
		print -u$(( 2 - help )) $usage
		return $(( 1 - help ))
	fi
	local hook="${1}_functions" 
	local fn="$2" 
	if (( del ))
	then
		if (( ${(P)+hook} ))
		then
			if (( del == 2 ))
			then
				set -A $hook ${(P)hook:#${~fn}}
			else
				set -A $hook ${(P)hook:#$fn}
			fi
			if (( ! ${(P)#hook} ))
			then
				unset $hook
			fi
		fi
	else
		if (( ${(P)+hook} ))
		then
			if (( ${${(P)hook}[(I)$fn]} == 0 ))
			then
				typeset -ga $hook
				set -A $hook ${(P)hook} $fn
			fi
		else
			typeset -ga $hook
			set -A $hook $fn
		fi
		autoload $autoopts -- $fn
	fi
}
cd_ghq_list () {
	local destination_dir="$(ghq list --full-path| fzf)" 
	if [ -n "$destination_dir" ]
	then
		cd $destination_dir
	fi
	echo $destination_dir
}
colors () {
	emulate -L zsh
	typeset -Ag color colour
	color=(00 none 01 bold 02 faint 22 normal 03 italic 23 no-italic 04 underline 24 no-underline 05 blink 25 no-blink 07 reverse 27 no-reverse 08 conceal 28 no-conceal 30 black 40 bg-black 31 red 41 bg-red 32 green 42 bg-green 33 yellow 43 bg-yellow 34 blue 44 bg-blue 35 magenta 45 bg-magenta 36 cyan 46 bg-cyan 37 white 47 bg-white 39 default 49 bg-default) 
	local k
	for k in ${(k)color}
	do
		color[${color[$k]}]=$k 
	done
	for k in ${color[(I)3?]}
	do
		color[fg-${color[$k]}]=$k 
	done
	for k in grey gray
	do
		color[$k]=${color[black]} 
		color[fg-$k]=${color[$k]} 
		color[bg-$k]=${color[bg-black]} 
	done
	colour=(${(kv)color}) 
	local lc=$'\e[' rc=m 
	typeset -Hg reset_color bold_color
	reset_color="$lc${color[none]}$rc" 
	bold_color="$lc${color[bold]}$rc" 
	typeset -AHg fg fg_bold fg_no_bold
	for k in ${(k)color[(I)fg-*]}
	do
		fg[${k#fg-}]="$lc${color[$k]}$rc" 
		fg_bold[${k#fg-}]="$lc${color[bold]};${color[$k]}$rc" 
		fg_no_bold[${k#fg-}]="$lc${color[normal]};${color[$k]}$rc" 
	done
	typeset -AHg bg bg_bold bg_no_bold
	for k in ${(k)color[(I)bg-*]}
	do
		bg[${k#bg-}]="$lc${color[$k]}$rc" 
		bg_bold[${k#bg-}]="$lc${color[bold]};${color[$k]}$rc" 
		bg_no_bold[${k#bg-}]="$lc${color[normal]};${color[$k]}$rc" 
	done
}
command_not_found_handler () {
	if [[ "$1" != "mise" && "$1" != "mise-"* ]] && /opt/homebrew/bin/mise hook-not-found -s zsh -- "$1"
	then
		_mise_hook
		"$@"
	elif [ -n "$(declare -f _command_not_found_handler)" ]
	then
		_command_not_found_handler "$@"
	else
		echo "zsh: command not found: $1" >&2
		return 127
	fi
}
compaudit () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
compdef () {
	local opt autol type func delete eval new i ret=0 cmd svc 
	local -a match mbegin mend
	emulate -L zsh
	setopt extendedglob
	if (( ! $# ))
	then
		print -u2 "$0: I need arguments"
		return 1
	fi
	while getopts "anpPkKde" opt
	do
		case "$opt" in
			(a) autol=yes  ;;
			(n) new=yes  ;;
			([pPkK]) if [[ -n "$type" ]]
				then
					print -u2 "$0: type already set to $type"
					return 1
				fi
				if [[ "$opt" = p ]]
				then
					type=pattern 
				elif [[ "$opt" = P ]]
				then
					type=postpattern 
				elif [[ "$opt" = K ]]
				then
					type=widgetkey 
				else
					type=key 
				fi ;;
			(d) delete=yes  ;;
			(e) eval=yes  ;;
		esac
	done
	shift OPTIND-1
	if (( ! $# ))
	then
		print -u2 "$0: I need arguments"
		return 1
	fi
	if [[ -z "$delete" ]]
	then
		if [[ -z "$eval" ]] && [[ "$1" = *\=* ]]
		then
			while (( $# ))
			do
				if [[ "$1" = *\=* ]]
				then
					cmd="${1%%\=*}" 
					svc="${1#*\=}" 
					func="$_comps[${_services[(r)$svc]:-$svc}]" 
					[[ -n ${_services[$svc]} ]] && svc=${_services[$svc]} 
					[[ -z "$func" ]] && func="${${_patcomps[(K)$svc][1]}:-${_postpatcomps[(K)$svc][1]}}" 
					if [[ -n "$func" ]]
					then
						_comps[$cmd]="$func" 
						_services[$cmd]="$svc" 
					else
						print -u2 "$0: unknown command or service: $svc"
						ret=1 
					fi
				else
					print -u2 "$0: invalid argument: $1"
					ret=1 
				fi
				shift
			done
			return ret
		fi
		func="$1" 
		[[ -n "$autol" ]] && autoload -rUz "$func"
		shift
		case "$type" in
			(widgetkey) while [[ -n $1 ]]
				do
					if [[ $# -lt 3 ]]
					then
						print -u2 "$0: compdef -K requires <widget> <comp-widget> <key>"
						return 1
					fi
					[[ $1 = _* ]] || 1="_$1" 
					[[ $2 = .* ]] || 2=".$2" 
					[[ $2 = .menu-select ]] && zmodload -i zsh/complist
					zle -C "$1" "$2" "$func"
					if [[ -n $new ]]
					then
						bindkey "$3" | IFS=$' \t' read -A opt
						[[ $opt[-1] = undefined-key ]] && bindkey "$3" "$1"
					else
						bindkey "$3" "$1"
					fi
					shift 3
				done ;;
			(key) if [[ $# -lt 2 ]]
				then
					print -u2 "$0: missing keys"
					return 1
				fi
				if [[ $1 = .* ]]
				then
					[[ $1 = .menu-select ]] && zmodload -i zsh/complist
					zle -C "$func" "$1" "$func"
				else
					[[ $1 = menu-select ]] && zmodload -i zsh/complist
					zle -C "$func" ".$1" "$func"
				fi
				shift
				for i
				do
					if [[ -n $new ]]
					then
						bindkey "$i" | IFS=$' \t' read -A opt
						[[ $opt[-1] = undefined-key ]] || continue
					fi
					bindkey "$i" "$func"
				done ;;
			(*) while (( $# ))
				do
					if [[ "$1" = -N ]]
					then
						type=normal 
					elif [[ "$1" = -p ]]
					then
						type=pattern 
					elif [[ "$1" = -P ]]
					then
						type=postpattern 
					else
						case "$type" in
							(pattern) if [[ $1 = (#b)(*)=(*) ]]
								then
									_patcomps[$match[1]]="=$match[2]=$func" 
								else
									_patcomps[$1]="$func" 
								fi ;;
							(postpattern) if [[ $1 = (#b)(*)=(*) ]]
								then
									_postpatcomps[$match[1]]="=$match[2]=$func" 
								else
									_postpatcomps[$1]="$func" 
								fi ;;
							(*) if [[ "$1" = *\=* ]]
								then
									cmd="${1%%\=*}" 
									svc=yes 
								else
									cmd="$1" 
									svc= 
								fi
								if [[ -z "$new" || -z "${_comps[$1]}" ]]
								then
									_comps[$cmd]="$func" 
									[[ -n "$svc" ]] && _services[$cmd]="${1#*\=}" 
								fi ;;
						esac
					fi
					shift
				done ;;
		esac
	else
		case "$type" in
			(pattern) unset "_patcomps[$^@]" ;;
			(postpattern) unset "_postpatcomps[$^@]" ;;
			(key) print -u2 "$0: cannot restore key bindings"
				return 1 ;;
			(*) unset "_comps[$^@]" ;;
		esac
	fi
}
compdump () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
compinit () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
compinstall () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
getent () {
	if [[ $1 = hosts ]]
	then
		sed 's/#.*//' /etc/$1 | grep -w $2
	elif [[ $2 = <-> ]]
	then
		grep ":$2:[^:]*$" /etc/$1
	else
		grep "^$2:" /etc/$1
	fi
}
gitmain () {
	git config --global user.name "higuchi-yuya-ab"
	git config --global user.email "higuchi_yuya@applibot.co.jp"
}
gitsub () {
	git config --global user.name "yuucu"
	git config --global user.email "yuucu.work@gmail.com"
}
is-at-least () {
	emulate -L zsh
	local IFS=".-" min_cnt=0 ver_cnt=0 part min_ver version order 
	min_ver=(${=1}) 
	version=(${=2:-$ZSH_VERSION} 0) 
	while (( $min_cnt <= ${#min_ver} ))
	do
		while [[ "$part" != <-> ]]
		do
			(( ++ver_cnt > ${#version} )) && return 0
			if [[ ${version[ver_cnt]} = *[0-9][^0-9]* ]]
			then
				order=(${version[ver_cnt]} ${min_ver[ver_cnt]}) 
				if [[ ${version[ver_cnt]} = <->* ]]
				then
					[[ $order != ${${(On)order}} ]] && return 1
				else
					[[ $order != ${${(O)order}} ]] && return 1
				fi
				[[ $order[1] != $order[2] ]] && return 0
			fi
			part=${version[ver_cnt]##*[^0-9]} 
		done
		while true
		do
			(( ++min_cnt > ${#min_ver} )) && return 0
			[[ ${min_ver[min_cnt]} = <-> ]] && break
		done
		(( part > min_ver[min_cnt] )) && return 0
		(( part < min_ver[min_cnt] )) && return 1
		part='' 
	done
}
mise () {
	local command
	command="${1:-}" 
	if [ "$#" = 0 ]
	then
		command /opt/homebrew/bin/mise
		return
	fi
	shift
	case "$command" in
		(deactivate | shell | sh) if [[ ! " $@ " =~ " --help " ]] && [[ ! " $@ " =~ " -h " ]]
			then
				eval "$(command /opt/homebrew/bin/mise "$command" "$@")"
				return $?
			fi ;;
	esac
	command /opt/homebrew/bin/mise "$command" "$@"
}
pmodload () {
	local -A ices
	(( ${+ICE} )) && ices=("${(kv)ICE[@]}" teleid '') 
	local -A ICE ZINIT_ICE
	ICE=("${(kv)ices[@]}") ZINIT_ICE=("${(kv)ices[@]}") 
	while (( $# ))
	do
		ICE[teleid]="PZT::modules/$1${ICE[svn]-/init.zsh}" 
		ZINIT_ICE[teleid]="PZT::modules/$1${ICE[svn]-/init.zsh}" 
		if zstyle -t ":prezto:module:$1" loaded 'yes' 'no'
		then
			shift
			continue
		else
			[[ -z ${ZINIT_SNIPPETS[PZT::modules/$1${ICE[svn]-/init.zsh}]} && -z ${ZINIT_SNIPPETS[https://github.com/sorin-ionescu/prezto/trunk/modules/$1${ICE[svn]-/init.zsh}]} ]] && .zinit-load-snippet PZT::modules/"$1${ICE[svn]-/init.zsh}"
			shift
		fi
	done
}
prompt_starship_precmd () {
	STARSHIP_CMD_STATUS=$? STARSHIP_PIPE_STATUS=(${pipestatus[@]}) 
	if (( ${+STARSHIP_START_TIME} ))
	then
		__starship_get_time && (( STARSHIP_DURATION = STARSHIP_CAPTURED_TIME - STARSHIP_START_TIME ))
		unset STARSHIP_START_TIME
	else
		unset STARSHIP_DURATION STARSHIP_CMD_STATUS STARSHIP_PIPE_STATUS
	fi
	STARSHIP_JOBS_COUNT=${#jobstates} 
}
prompt_starship_preexec () {
	__starship_get_time && STARSHIP_START_TIME=$STARSHIP_CAPTURED_TIME 
}
starship_zle-keymap-select () {
	zle reset-prompt
}
zi-browse-symbol () {
	local -a fpath
	fpath=("/Users/s09104/.local/share/zinit/zinit.git" "/Users/s09104/.local/share/zinit/completions" "/opt/homebrew/share/zsh/site-functions" "/usr/local/share/zsh/site-functions" "/usr/share/zsh/site-functions" "/usr/share/zsh/5.9/functions") 
	builtin autoload -X -U -z
}
zicdclear () {
	.zinit-compdef-clear -q
}
zicdreplay () {
	.zinit-compdef-replay -q
}
zicompdef () {
	ZINIT_COMPDEF_REPLAY+=("${(j: :)${(q)@}}") 
}
zicompinit () {
	autoload -Uz compinit
	compinit -d ${ZINIT[ZCOMPDUMP_PATH]:-${ZDOTDIR:-$HOME}/.zcompdump} "${(Q@)${(z@)ZINIT[COMPINIT_OPTS]}}"
}
zinit () {
	local -A ICE ZINIT_ICE
	ICE=("${(kv)ZINIT_ICES[@]}") 
	ZINIT_ICE=("${(kv)ICE[@]}") 
	ZINIT_ICES=() 
	integer ___retval ___retval2 ___correct
	local -a match mbegin mend
	local MATCH cmd ___q="\`" ___q2="'" IFS=$' \t\n\0' 
	integer MBEGIN MEND
	match=(${ZINIT_EXTS[(I)z-annex subcommand:$1]}) 
	if (( !${#match} ))
	then
		local -a reply
		local REPLY
	fi
	[[ -o ksharrays ]] && ___correct=1 
	local -A ___opt_map OPTS
	___opt_map=(-q opt_-q,--quiet:"update:[Turn off almost-all messages from the {cmd}update{rst} operation {b-lhi}FOR the objects{rst} which don't have any {b-lhi}new version{rst} available.] *:[Turn off any (or: almost-any) messages from the operation.]" --quiet opt_-q,--quiet -v opt_-v,--verbose:"Turn on more messages from the operation." --verbose opt_-v,--verbose -r opt_-r,--reset:"Reset the repository before updating (or remove the files for single-file snippets and gh-r plugins)." --reset opt_-r,--reset -a opt_-a,--all:"delete:[Delete {hi}all{rst} plugins and snippets.] update:[Update {b-lhi}all{rst} plugins and snippets.]" --all opt_-a,--all -c opt_-c,--clean:"Delete {b-lhi}only{rst} the {b-lhi}currently-not loaded{rst} plugins and snippets." --clean opt_-c,--clean -y opt_-y,--yes:"Automatically confirm any yes/no prompts." --yes opt_-y,--yes -f opt_-f,--force:"Force new download of the snippet file." --force opt_-f,--force -p opt_-p,--parallel:"Turn on concurrent, multi-thread update (of all objects)." --parallel opt_-p,--parallel -s opt_-s,--snippets:"snippets:[Update only snippets (i.e.: skip updating plugins).] times:[Show times in seconds instead of milliseconds.]" --snippets opt_-s,--snippets -L opt_-l,--plugins:"Update only plugins (i.e.: skip updating snippets)." --plugins opt_-l,--plugins -h opt_-h,--help:"Show this help message." --help opt_-h,--help -u opt_-u,--urge:"Cause all the hooks like{ehi}:{rst} {ice}atpull{apo}''{rst}, {ice}cp{apo}''{rst}, etc. to execute even when there aren't any new commits {b}/{rst} any new version of the {b}{meta}gh-r{rst} file {b}/{rst} etc.{…} available for download {ehi}{lr}{rst} simulate a non-empty update." --urge opt_-u,--urge -n opt_-n,--no-pager:"Disable the use of the pager." --no-pager opt_-n,--no-pager -m opt_-m,--moments:"Show the {apo}*{b-lhi}moments{apo}*{rst} of object (i.e.: a plugin or snippet) loading time." --moments opt_-m,--moments -b opt_-b,--bindkeys:"Load in light mode, however do still track {cmd}bindkey{rst} calls (to allow remapping the keys bound)." --bindkeys opt_-b,--bindkeys -x opt_-x,--command:"Load the snippet as a {cmd}command{rst}, i.e.: add it to {var}\$PATH{rst} and set {b-lhi}+x{rst} on it." --command opt_-x,--command cdclear "--help|--quiet|-h|-q" cdreplay "--help|--quiet|-h|-q" delete "--all|--clean|--help|--quiet|--yes|-a|-c|-h|-q|-y" env-whitelist "--help|--verbose|-h|-v" light "--help|-b|-h" snippet "--command|--force|--help|-f|-h|-x" times "--help|-h|-m|-s" unload "--help|--quiet|-h|-q" update "--all|--help|--no-pager|--parallel|--plugins|--quiet|--reset|--snippets|--urge|--verbose|-L|-a|-h|-n|-p|-q|-r|-s|-u|-v" version "") 
	cmd="$1" 
	if [[ $cmd == (times|unload|env-whitelist|update|snippet|load|light|cdreplay|cdclear) ]]
	then
		if (( $@[(I)-*] || OPTS[opt_-h,--help] ))
		then
			.zinit-parse-opts "$cmd" "$@"
			if (( OPTS[opt_-h,--help] ))
			then
				+zinit-prehelp-usage-message $cmd $___opt_map[$cmd] $@
				return 1
			fi
		fi
	fi
	reply=(${ZINIT_EXTS[(I)z-annex subcommand:*]}) 
	[[ ( -n $1 && $1 != (${~ZINIT[cmds]}|${(~j:|:)reply[@]#z-annex subcommand:}) ) || $1 = (load|light|snippet) ]] && {
		integer ___error
		if [[ $1 = (load|light|snippet) ]]
		then
			integer ___is_snippet
			() {
				builtin setopt localoptions extendedglob
				: ${@[@]//(#b)([ $'\t']##|(#s))(-b|--command|-f|--force)([ $'\t']##|(#e))/${OPTS[${match[2]}]::=1}}
			} "$@"
			builtin set -- "${@[@]:#(-b|--command|-f|--force)}"
			[[ $1 = light && -z ${OPTS[(I)-b]} ]] && ICE[light-mode]= 
			[[ $1 = snippet ]] && ICE[is-snippet]=  || ___is_snippet=-1 
			shift
			ZINIT_ICES=("${(kv)ICE[@]}") 
			ICE=() ZINIT_ICE=() 
			1="${1:+@}${1#@}${2:+/$2}" 
			(( $# > 1 )) && {
				shift -p $(( $# - 1 ))
			}
			[[ -z $1 ]] && {
				+zi-log "Argument needed, try: {cmd}help."
				return 1
			}
		else
			.zinit-ice "$@"
			___retval2=$? 
			local ___last_ice=${@[___retval2]} 
			shift ___retval2
			if [[ $# -gt 0 && $1 != for ]]
			then
				+zi-log -n "{b}{u-warn}ERROR{b-warn}:{rst} Unknown subcommand{ehi}:" "{apo}\`{cmd}$1{apo}\`{rst} "
				+zinit-prehelp-usage-message rst
				return 1
			elif (( $# == 0 ))
			then
				___error=1 
			else
				shift
			fi
		fi
		integer ___had_wait
		local ___id ___ehid ___etid ___key
		local -a ___arr
		ZINIT[annex-exposed-processed-IDs]= 
		if (( $# ))
		then
			local -a ___ices
			___ices=("${(kv)ZINIT_ICES[@]}") 
			ZINIT_ICES=() 
			while (( $# ))
			do
				.zinit-ice "$@"
				___retval2=$? 
				local ___last_ice=${@[___retval2]} 
				shift ___retval2
				if [[ -n $1 ]]
				then
					ICE=("${___ices[@]}" "${(kv)ZINIT_ICES[@]}") 
					ZINIT_ICE=("${(kv)ICE[@]}") ZINIT_ICES=() 
					integer ___msgs=${+ICE[debug]} 
					(( ___msgs )) && +zi-log "{pre}zinit-main:{faint} Processing {pname}$1{faint}{…}{rst}"
					ZINIT[annex-exposed-processed-IDs]+="${___id:+ $___id}" 
					___id="${${1#@}%%(///|//|/)}" 
					(( ___is_snippet == -1 )) && ___id="${___id#https://github.com/}" 
					___ehid="${ICE[id-as]:-$___id}" 
					___etid="${ICE[teleid]:-$___id}" 
					if (( ${+ICE[pack]} ))
					then
						___had_wait=${+ICE[wait]} 
						.zinit-load-ices "$___ehid"
						[[ $___had_wait -eq 0 ]] && unset 'ICE[wait]'
					fi
					[[ ${ICE[id-as]} = (auto|) && ${+ICE[id-as]} == 1 ]] && ICE[id-as]="${___etid:t}" 
					integer ___is_snippet=${${(M)___is_snippet:#-1}:-0} 
					() {
						builtin setopt localoptions extendedglob
						if [[ $___is_snippet -ge 0 && ( -n ${ICE[is-snippet]+1} || $___etid = ((#i)(http(s|)|ftp(s|)):/|(${(~kj.|.)ZINIT_1MAP}))* ) ]]
						then
							___is_snippet=1 
						fi
					} "$@"
					local ___type=${${${(M)___is_snippet:#1}:+snippet}:-plugin} 
					reply=(${(on)ZINIT_EXTS2[(I)zinit hook:before-load-pre <->]} ${(on)ZINIT_EXTS[(I)z-annex hook:before-load-<-> <->]} ${(on)ZINIT_EXTS2[(I)zinit hook:before-load-post <->]}) 
					for ___key in "${reply[@]}"
					do
						___arr=("${(Q)${(z@)ZINIT_EXTS[$___key]:-$ZINIT_EXTS2[$___key]}[@]}") 
						"${___arr[5]}" "$___type" "$___id" "${ICE[id_as]}" "${(j: :)${(q)@[2,-1]}}" "${(j: :)${(qkv)___ices[@]}}" "${${___key##(zinit|z-annex) hook:}%% <->}" load
						___retval2=$? 
						if (( ___retval2 ))
						then
							___retval+=$(( ___retval2 & 1 ? ___retval2 : 0 )) 
							(( ___retval2 & 1 && $# )) && shift
							if (( ___retval2 & 2 ))
							then
								local -a ___args
								___args=("${(@Q)${(@z)ZINIT[annex-before-load:new-@]}}") 
								builtin set -- "${___args[@]}"
							fi
							if (( ___retval2 & 4 ))
							then
								local -a ___new_ices
								___new_ices=("${(Q@)${(@z)ZINIT[annex-before-load:new-global-ices]}}") 
								(( 0 == ${#___new_ices} % 2 )) && ___ices=("${___new_ices[@]}")  || {
									[[ ${ZINIT[MUTE_WARNINGS]} != (1|true|on|yes) ]] && +zi-log "{u-warn}Warning{b-warn}:{msg} Bad new-ices returned" "from the annex{ehi}:{rst} {annex}${___arr[3]}{msg}," "please file an issue report at:{url}" "https://github.com/zdharma-continuum/${___arr[3]}/issues/new{msg}.{rst}"
									___ices=() ___retval+=7 
								}
							fi
							continue 2
						fi
					done
					integer ___action_load=0 ___turbo=0 
					if [[ -n ${(M)${+ICE[wait]}:#1}${ICE[load]}${ICE[unload]}${ICE[service]}${ICE[subscribe]} ]]
					then
						___turbo=1 
					fi
					if [[ -n ${ICE[trigger-load]} || ( ${+ICE[wait]} == 1 && ${ICE[wait]} = (\!|)(<->(a|b|c|)|) ) ]] && (( !ZINIT[OPTIMIZE_OUT_DISK_ACCESSES]
                    ))
					then
						if (( ___is_snippet > 0 ))
						then
							.zinit-get-object-path snippet $___ehid
						else
							.zinit-get-object-path plugin $___ehid
						fi
						(( $? )) && [[ ${zsh_eval_context[1]} = file ]] && {
							___action_load=1 
						}
						local ___object_path="$REPLY" 
					elif (( ! ___turbo ))
					then
						___action_load=1 
						reply=(1) 
					else
						reply=(1) 
					fi
					if [[ ${reply[-1]} -eq 1 && -n ${ICE[trigger-load]} ]]
					then
						() {
							builtin setopt localoptions extendedglob
							local ___mode
							(( ___is_snippet > 0 )) && ___mode=snippet  || ___mode="${${${ICE[light-mode]+light}}:-load}" 
							for MATCH in ${(s.;.)ICE[trigger-load]}
							do
								eval "${MATCH#!}() {
                                    ${${(M)MATCH#!}:+unset -f ${MATCH#!}}
                                    local a b; local -a ices
                                    # The wait'' ice is filtered-out.
                                    for a b ( ${(qqkv@)${(kv@)ICE[(I)^(trigger-load|wait|light-mode)]}} ) {
                                        ices+=( \"\$a\$b\" )
                                    }
                                    zinit ice \${ices[@]}; zinit $___mode ${(qqq)___id}
                                    ${${(M)MATCH#!}:+# Forward the call
                                    eval ${MATCH#!} \$@}
                                }"
							done
						} "$@"
						___retval+=$? 
						(( $# )) && shift
						continue
					fi
					if (( ${+ICE[if]} ))
					then
						eval "${ICE[if]}" || {
							(( $# )) && shift
							continue
						}
					fi
					for REPLY in ${(s.;.)ICE[has]}
					do
						(( ${+commands[$REPLY]} )) || {
							(( $# )) && shift
							continue 2
						}
					done
					integer ___had_cloneonly=0 
					ICE[wait]="${${(M)${+ICE[wait]}:#1}:+${(M)ICE[wait]#!}${${ICE[wait]#!}:-0}}" 
					if (( ___action_load || !ZINIT[HAVE_SCHEDULER] ))
					then
						if (( ___turbo && ZINIT[HAVE_SCHEDULER] ))
						then
							___had_cloneonly=${+ICE[cloneonly]} 
							ICE[cloneonly]="" 
						fi
						(( ___is_snippet )) && local ___opt="${(k)OPTS[*]}"  || local ___opt="${${ICE[light-mode]+light}:-${OPTS[(I)-b]:+light-b}}" 
						.zinit-load-object ${${${(M)___is_snippet:#1}:+snippet}:-plugin} $___id $___opt
						integer ___last_retval=$? 
						___retval+=___last_retval 
						if (( ___turbo && !___had_cloneonly && ZINIT[HAVE_SCHEDULER] ))
						then
							command rm -f $___object_path/._zinit/cloneonly
							unset 'ICE[cloneonly]'
						fi
					fi
					if (( ___turbo && ZINIT[HAVE_SCHEDULER] && 0 == ___last_retval ))
					then
						ICE[wait]="${ICE[wait]:-${ICE[service]:+0}}" 
						if (( ___is_snippet > 0 ))
						then
							ZINIT_SICE[$___ehid]= 
							.zinit-submit-turbo s${ICE[service]:+1} "" "$___id" "${(k)OPTS[*]}"
						else
							ZINIT_SICE[$___ehid]= 
							.zinit-submit-turbo p${ICE[service]:+1} "${${${ICE[light-mode]+light}}:-load}" "$___id" ""
						fi
						___retval+=$? 
					fi
				else
					___error=1 
				fi
				(( $# )) && shift
				___is_snippet=0 
			done
		else
			___error=1 
		fi
		if (( ___error ))
		then
			() {
				builtin emulate -LR zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}
				+zi-log -n "{u-warn}Error{b-warn}:{rst} No plugin or snippet ID given"
				if [[ -n $___last_ice ]]
				then
					+zi-log -n " (the last recognized ice was: {ice}""${___last_ice/(#m)(${~ZINIT[ice-list]})/"{data}$MATCH"}{apo}''{rst}).{error}
You can try to prepend {apo}${___q}{lhi}@{apo}'{error} to the ID if the last ice is in fact a plugin.{rst}
{note}Note:{rst} The {apo}\`{ice}ice{apo}\`{rst} subcommand is now again required if not using the for-syntax"
				fi
				+zi-log "."
			}
			return 2
		elif (( ! $# ))
		then
			return ___retval
		fi
	}
	case "$1" in
		(ice) shift
			.zinit-ice "$@" ;;
		(cdreplay) .zinit-compdef-replay "$2"
			___retval=$?  ;;
		(cdclear) .zinit-compdef-clear "$2" ;;
		(add-fpath|fpath) .zinit-add-fpath "${@[2-correct,-1]}" ;;
		(run) .zinit-run "${@[2-correct,-1]}" ;;
		(man) man "${ZINIT[BIN_DIR]}/doc/zinit.1" ;;
		(env-whitelist) shift
			.zinit-parse-opts env-whitelist "$@"
			builtin set -- "${reply[@]}"
			if (( $# == 0 ))
			then
				ZINIT[ENV-WHITELIST]= 
				(( OPTS[opt_-v,--verbose] )) && +zi-log "{msg2}Cleared the parameter whitelist.{rst}"
			else
				ZINIT[ENV-WHITELIST]+="${(j: :)${(q-kv)@}} " 
				local ___sep="$ZINIT[col-msg2], $ZINIT[col-data2]" 
				(( OPTS[opt_-v,--verbose] )) && +zi-log "{msg2}Extended the parameter whitelist with: {data2}${(pj:$___sep:)@}{msg2}.{rst}"
			fi ;;
		(*) reply=(${ZINIT_EXTS[z-annex subcommand:${(q)1}]}) 
			(( ${#reply} )) && {
				reply=("${(Q)${(z@)reply[1]}[@]}") 
				(( ${+functions[${reply[5]}]} )) && {
					"${reply[5]}" "$@"
					return $?
				} || {
					+zi-log "({error}Couldn't find the subcommand-handler \`{obj}${reply[5]}{error}' of the z-annex \`{file}${reply[3]}{error}')"
					return 1
				}
			}
			(( ${+functions[.zinit-confirm]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-autoload.zsh" || return 1
			case "$1" in
				(zstatus) .zinit-show-zstatus ;;
				(delete) shift
					.zinit-delete "$@" ;;
				(times) .zinit-show-times "${@[2-correct,-1]}" ;;
				(self-update) .zinit-self-update ;;
				(unload) (( ${+functions[.zinit-unload]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-autoload.zsh" || return 1
					if [[ -z $2 && -z $3 ]]
					then
						builtin print "Argument needed, try: help"
						___retval=1 
					else
						[[ $2 = -q ]] && {
							5=-q 
							shift
						}
						.zinit-unload "${2%%(///|//|/)}" "${${3:#-q}%%(///|//|/)}" "${${(M)4:#-q}:-${(M)3:#-q}}"
						___retval=$? 
					fi ;;
				(bindkeys) .zinit-list-bindkeys ;;
				(update) if (( ${+ICE[if]} ))
					then
						eval "${ICE[if]}" || return 1
					fi
					for REPLY in ${(s.;.)ICE[has]}
					do
						(( ${+commands[$REPLY]} )) || return 1
					done
					shift
					.zinit-parse-opts update "$@"
					builtin set -- "${reply[@]}"
					if [[ ${OPTS[opt_-a,--all]} -eq 1 || ${OPTS[opt_-p,--parallel]} -eq 1 || ${OPTS[opt_-s,--snippets]} -eq 1 || ${OPTS[opt_-l,--plugins]} -eq 1 || -z $1$2${ICE[teleid]}${ICE[id-as]} ]]
					then
						[[ -z $1$2 && $(( OPTS[opt_-a,--all] + OPTS[opt_-p,--parallel] + OPTS[opt_-s,--snippets] + OPTS[opt_-l,--plugins] )) -eq 0 ]] && {
							builtin print -r -- "Assuming --all is passed"
							sleep 3
						}
						(( OPTS[opt_-p,--parallel] )) && OPTS[value]=${1:-15} 
						.zinit-update-or-status-all update
						___retval=$? 
					else
						local ___key ___id="${1%%(///|//|/)}${2:+/}${2%%(///|//|/)}" 
						[[ -z ${___id//[[:space:]]/} ]] && ___id="${ICE[id-as]:-$ICE[teleid]}" 
						.zinit-update-or-status update "$___id" ""
						___retval=$? 
					fi ;;
				(status) if [[ $2 = --all || ( -z $2 && -z $3 ) ]]
					then
						[[ -z $2 ]] && {
							builtin print -r -- "Assuming --all is passed"
							sleep 3
						}
						.zinit-update-or-status-all status
						___retval=$? 
					else
						.zinit-update-or-status status "${2%%(///|//|/)}" "${3%%(///|//|/)}"
						___retval=$? 
					fi ;;
				(report) if [[ $2 = --all || ( -z $2 && -z $3 ) ]]
					then
						[[ -z $2 ]] && {
							builtin print -r -- "Assuming --all is passed"
							sleep 4
						}
						.zinit-show-all-reports
					else
						.zinit-show-report "${2%%(///|//|/)}" "${3%%(///|//|/)}"
						___retval=$? 
					fi ;;
				(plugins) .zinit-list-plugins "$2" ;;
				(snippets) .zinit-list-snippets "$2" ;;
				(completions) .zinit-show-completions "$2" ;;
				(cclear) .zinit-clear-completions ;;
				(cdisable) if [[ -z $2 ]]
					then
						builtin print "Argument needed, try: help"
						___retval=1 
					else
						local ___f="_${2#_}" 
						if .zinit-cdisable "$___f"
						then
							(( ${+functions[.zinit-forget-completion]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-install.zsh" || return 1
							.zinit-forget-completion "$___f"
							+zi-log "Initializing completion system ({func}compinit{rst}){…}"
							builtin autoload -Uz compinit
							compinit -d ${ZINIT[ZCOMPDUMP_PATH]:-${ZDOTDIR:-$HOME}/.zcompdump} "${(Q@)${(z@)ZINIT[COMPINIT_OPTS]}}"
						else
							___retval=1 
						fi
					fi ;;
				(cenable) if [[ -z $2 ]]
					then
						builtin print "Argument needed, try: help"
						___retval=1 
					else
						local ___f="_${2#_}" 
						if .zinit-cenable "$___f"
						then
							(( ${+functions[.zinit-forget-completion]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-install.zsh" || return 1
							.zinit-forget-completion "$___f"
							+zi-log "Initializing completion system ({func}compinit{rst}){…}"
							builtin autoload -Uz compinit
							compinit -d ${ZINIT[ZCOMPDUMP_PATH]:-${ZDOTDIR:-$HOME}/.zcompdump} "${(Q@)${(z@)ZINIT[COMPINIT_OPTS]}}"
						else
							___retval=1 
						fi
					fi ;;
				(creinstall) (( ${+functions[.zinit-install-completions]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-install.zsh" || return 1
					[[ $2 = -[qQ] ]] && {
						5=$2 
						shift
					}
					.zinit-install-completions "${2%%(///|//|/)}" "${3%%(///|//|/)}" 1 "${(M)4:#-[qQ]}"
					___retval=$? 
					[[ -z ${(M)4:#-[qQ]} ]] && +zi-log "Initializing completion ({func}compinit{rst}){…}"
					builtin autoload -Uz compinit
					compinit -d ${ZINIT[ZCOMPDUMP_PATH]:-${ZDOTDIR:-$HOME}/.zcompdump} "${(Q@)${(z@)ZINIT[COMPINIT_OPTS]}}" ;;
				(cuninstall) if [[ -z $2 && -z $3 ]]
					then
						builtin print "Argument needed, try: help"
						___retval=1 
					else
						(( ${+functions[.zinit-forget-completion]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-install.zsh" || return 1
						.zinit-uninstall-completions "${2%%(///|//|/)}" "${3%%(///|//|/)}"
						___retval=$? 
						+zi-log "Initializing completion ({func}compinit{rst}){…}"
						builtin autoload -Uz compinit
						compinit -d ${ZINIT[ZCOMPDUMP_PATH]:-${ZDOTDIR:-$HOME}/.zcompdump} "${(Q@)${(z@)ZINIT[COMPINIT_OPTS]}}"
					fi ;;
				(csearch) .zinit-search-completions ;;
				(compinit) (( ${+functions[.zinit-forget-completion]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-install.zsh" || return 1
					.zinit-compinit
					___retval=$?  ;;
				(compile) (( ${+functions[.zinit-compile-plugin]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-install.zsh" || return 1
					if [[ $2 = --all || ( -z $2 && -z $3 ) ]]
					then
						[[ -z $2 ]] && {
							builtin print -r -- "Assuming --all is passed"
							sleep 3
						}
						.zinit-compile-uncompile-all 1
						___retval=$? 
					else
						.zinit-compile-plugin "${2%%(///|//|/)}" "${3%%(///|//|/)}"
						___retval=$? 
					fi ;;
				(debug) shift
					(( ${+functions[+zinit-debug]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-additional.zsh"
					+zinit-debug $@ ;;
				(uncompile) if [[ $2 = --all || ( -z $2 && -z $3 ) ]]
					then
						[[ -z $2 ]] && {
							builtin print -r -- "Assuming --all is passed"
							sleep 3
						}
						.zinit-compile-uncompile-all 0
						___retval=$? 
					else
						.zinit-uncompile-plugin "${2%%(///|//|/)}" "${3%%(///|//|/)}"
						___retval=$? 
					fi ;;
				(compiled) .zinit-compiled ;;
				(cdlist) .zinit-list-compdef-replay ;;
				(cd|recall|edit|glance|changes|create|stress) .zinit-"$1" "${@[2-correct,-1]%%(///|//|/)}"
					___retval=$?  ;;
				(recently) shift
					.zinit-recently "$@"
					___retval=$?  ;;
				(-h|--help|help) .zinit-help ;;
				(version) zi::version ;;
				(srv) () {
						setopt localoptions extendedglob warncreateglobal
						[[ ! -e ${ZINIT[SERVICES_DIR]}/"$2".fifo ]] && {
							builtin print "No such service: $2"
						} || {
							[[ $3 = (#i)(next|stop|quit|restart) ]] && {
								builtin print "${(U)3}" >>| ${ZINIT[SERVICES_DIR]}/"$2".fifo || builtin print "Service $2 inactive"
								___retval=1 
							} || {
								[[ $3 = (#i)start ]] && rm -f ${ZINIT[SERVICES_DIR]}/"$2".stop || {
									builtin print "Unknown service-command: $3"
									___retval=1 
								}
							}
						}
					} "$@" ;;
				(module) .zinit-module "${@[2-correct,-1]}"
					___retval=$?  ;;
				(*) if [[ -z $1 ]]
					then
						+zi-log -n "{b}{u-warn}ERROR{b-warn}:{rst} Missing a {cmd}subcommand "
						+zinit-prehelp-usage-message rst
					else
						+zi-log -n "{b}{u-warn}ERROR{b-warn}:{rst} Unknown subcommand{ehi}:{rst}" "{apo}\`{error}$1{apo}\`{rst} "
						+zinit-prehelp-usage-message rst
					fi
					___retval=1  ;;
			esac ;;
	esac
	return ___retval
}
zpcdclear () {
	.zinit-compdef-clear -q
}
zpcdreplay () {
	.zinit-compdef-replay -q
}
zpcompdef () {
	ZINIT_COMPDEF_REPLAY+=("${(j: :)${(q)@}}") 
}
zpcompinit () {
	autoload -Uz compinit
	compinit -d ${ZINIT[ZCOMPDUMP_PATH]:-${ZDOTDIR:-$HOME}/.zcompdump} "${(Q@)${(z@)ZINIT[COMPINIT_OPTS]}}"
}
zplugin () {
	zinit "$@"
}
# Shell Options
setopt nohashdirs
setopt login
setopt promptsubst
# Aliases
alias -- atheme='npx alacritty-themes'
alias -- fgh=cd_ghq_list
alias -- gw='bunx ccmanager'
alias -- lg=lazygit
alias -- ls='ls -G'
alias -- memomv='cd ~/.memolist'
alias -- run-help=man
alias -- t=todotui
alias -- v=nvim
alias -- vi=nvim
alias -- vim=nvim
alias -- which-command=whence
alias -- zi=zinit
alias -- zini=zinit
alias -- zpl=zinit
alias -- zplg=zinit
# Check for rg availability
if ! command -v rg >/dev/null 2>&1; then
  alias rg='/opt/homebrew/Cellar/ripgrep/14.1.1/bin/rg'
fi
export PATH=/Users/s09104/.local/share/zinit/plugins/paulirish---git-open\:/opt/homebrew/opt/mysql-client\@8.0/bin\:/opt/homebrew/opt/openjdk\@17/bin\:/Users/s09104/.bun/bin\:/opt/homebrew/opt/mysql-client/bin\:/Users/s09104/go/bin\:/Users/s09104/.local/share/mise/installs/go/1.24.3/bin\:/Users/s09104/.local/share/mise/installs/node/24.1.0/bin\:/Users/s09104/.local/share/mise/installs/npm-anthropic-ai-claude-code/1.0.44/bin\:/Users/s09104/.local/share/mise/installs/npm-ccusage/15.3.1/bin\:/Users/s09104/.local/share/mise/installs/deno/2.3.3/bin\:/Users/s09104/.local/share/mise/installs/deno/2.3.3/.deno/bin\:/Users/s09104/.local/share/mise/installs/yarn/4.7.0/bin\:/opt/homebrew/bin\:/opt/homebrew/sbin\:/usr/local/bin\:/System/Cryptexes/App/usr/bin\:/usr/bin\:/bin\:/usr/sbin\:/sbin\:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin\:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin\:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin\:/usr/local/share/dotnet\:~/.dotnet/tools\:/Library/Frameworks/Mono.framework/Versions/Current/Commands\:/Users/s09104/.local/share/zinit/plugins/paulirish---git-open\:/Users/s09104/.local/bin\:/opt/homebrew/opt/mysql-client\@8.0/bin\:/opt/homebrew/opt/openjdk\@17/bin\:/Users/s09104/Library/pnpm\:/Users/s09104/.bun/bin\:/opt/homebrew/opt/mysql-client/bin\:/Users/s09104/go/bin\:/Users/s09104/.local/share/zinit/polaris/bin\:/Users/s09104/.cargo/bin
