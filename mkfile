< /$objtype/mkfile

# Build Ziran's generated native Plan 9 application with current Kryon Libdraw.
# Run `make plan9-c` on the host after changing the maintained .zi source.
TARG=t9
BIN=/$objtype/bin
GEN=build/plan9/generated
LIST=build/plan9/generated-c-files.txt
HEADERS=`{ls $GEN/*.h}
OFILES=`{cat $LIST | sed -e 's@\.c$@.'$O'@' -e 's@^@'$GEN'/@'}
OUT=$O.out
CFLAGS=-FTVw

all:V: check-generated $OUT

check-generated:V:
	if(! test -f $GEN/app_main.c || ! test -f $LIST) {
		echo 'Missing Terminal native sources; run make plan9-c on the host' >[1=2]
		exit missing
	}
	exit 0

$GEN/%.$O: $GEN/%.c $HEADERS
	$CC $CFLAGS -I$GEN -o $target -c $GEN/$stem^.c

$OUT: $OFILES
	$LD -o $target $prereq -ldraw -lmemdraw -lthread -lflate

install:V: all
	cp $OUT $BIN/$TARG

clean:V:
	rm -f $GEN/*.[$OS] [$OS].out $TARG
