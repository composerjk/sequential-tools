#!/bin/bash
#
# quick hack to renumber a Sequential Pro 3 wavetable SysEx file.
# --Jeff Kellem, @composerjk
#	2 August 2020
#

# NOTE: possible that a valid wavetable might have different hex values
#	in bytes 3-6 (counting from zero).
#	f0	SysEx
#	01	Sequential
#	31	Pro 3
#	6a	Wavetable data
#	6c	Wavetable data/param?
#	01	?File Version?
#	6b	Wavetable data/param?
EXPECTED_HEADER='f001316a6c016b'
EXPECTED_END='0001b6ef: f7'


XXD=xxd

usage() {
	echo "Usage: $0 wavetable-number filename.syx newfilename.syx"
	echo "    wavetable-number should be a number from 33 to 64."
	echo "    NOTE: newfilename.syx must not already exist."
	echo "    Example use:"
	echo "        $0 64 filename.syx newfilename.syx"
}

check_lastbyte_size() {
	endbyte=$(xxd -s -1 $1 | cut -c 1-12 )
	if [ "$endbyte" != "$EXPECTED_END" ]; then
		return 1
	else
		return 0
	fi
}

if [ $# != 3 ]; then
	usage
	exit 1
fi

num=$1
filename="$2"
newfilename="$3"

if [ -n "${num//[0-9]}" -o -z "$num" ]; then
	echo "$0: wavetable-number argument was NOT a number; must be a number from 33 to 64."
	echo ""
	usage
	exit 2
fi

if [ "$num" -lt "33" -o "$num" -gt "64" ]; then
	echo "$0: wavetable-number argument out of range; must be a number from 33 to 64."
	echo ""
	usage
	exit 2
fi

if [ ! -f $filename ]; then
	echo "$0: Input file $filename does not exist or is not a regular file."
	echo ""
	usage
	exit 3
fi

if [ -e $newfilename ]; then
	echo "$0: Output file $newfilename already exists. Use a different name."
	echo ""
	usage
	exit 4
fi

syxnum=$(($num - 1))
slot=$(printf '%x' $syxnum)

filetype=$($XXD -p -s 0 -l 7 $filename)
if [ "$filetype" != "$EXPECTED_HEADER" ]; then
	echo "ERROR: $filename does not seem to be a Pro 3 wavetable SysEx file."
	echo "    Expected: $EXPECTED_HEADER"
	echo "         Got: $filetype"
	exit 5
fi
check_lastbyte_size $filename
if [ $? -ne 0 ]; then
	echo "ERROR: $filename may not be a proper/complete Pro 3 wavetable SysEx file."
	echo "	Either last byte OR file size was unexpected."
	exit 9
fi

oldsyxnum=0x$($XXD -p -s 7 -l 1 $filename)
oldnum=$((oldsyxnum + 1))

if [ $oldnum -eq $num ]; then
	echo "$0: Wavetable in $filename already at slot $num."
	exit 6
fi

# -i not really needed except for race condition of newfilename
#	being created between exist check and copy.
cp -i "$filename" "$newfilename"

echo "Renumbering from slot $oldnum ($filename) to $num ($newfilename)."

echo "7: $slot" | $XXD -r - "$newfilename"

# double check
newsyxnum=$($XXD -p -s 7 -l 1 $newfilename)
if [ "$slot" != "$newsyxnum" ]; then
	echo "FAILED. Something went wrong."
	echo "Expected hex: $syxnum"
	echo "         Got: $newsyxnum"
	exit 7
fi
check_lastbyte_size $newfilename
if [ $? -ne 0 ]; then
	echo "FAILED. Something went wrong."
	echo "Last byte OR file size unexpected for $newfilename file."
	exit 9
fi
