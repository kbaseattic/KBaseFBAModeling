#! /bin/bash
set_script_dir () {
	pushd . > /dev/null
	SCRIPT_DIR="${BASH_SOURCE[0]}";
	if ([ -h "${SCRIPT_DIR}" ]) then
		while([ -h "${SCRIPT_DIR}" ]) do cd `dirname "$SCRIPT_DIR"`; SCRIPT_PATH=`readlink "${SCRIPT_DIR}"`; done
	fi
	cd `dirname ${SCRIPT_DIR}` > /dev/null
	SCRIPT_DIR=`pwd`;
	popd  > /dev/null
}
set_script_dir
echo $$ >> $1/pid
perl ${SCRIPT_DIR}/RunFBAJob.pl $1
