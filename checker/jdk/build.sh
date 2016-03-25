#!/usr/bin/bash

# Builds jdk8.jar for Checker Framework, using multiple compilation
# phases to work around processor bugs.

# After an initial bootstrap build ("phase 0") with processors off,
# Phase 1 tries to process all annotated source files together.  Each
# subsequent phase processes only the subset of files for which
# processing has so far failed; if there are no such files left after
# a phase is completed, the finish function (see below) is called, and
# the script exits with status 0.  Phase 2 does the same as Phase 1 with
# the remaining files, in case the annotated class files from the
# previous phase somehow provide additional information that allows the
# processors to succeed.  Phase 3 processes each remaining file
# individually; Phase 4 does so as well, but running only one processor
# at a time, merging annotations at the end using Annotation File
# Utilities.  Finally, in finish(): ct.sym is exploded; annotations are
# extracted from each annotated classfile and inserted into the
# classfile's counterpart in the ct.sym class directory; and the
# resulting classfiles are repackaged as jdk8.jar.

PRESERVE=1  # option to preserve intermediate files
RET=0       # exit code initialization

# parameters derived from environment
# TOOLSJAR and CTSYM derived from JAVA_HOME, rest from CHECKERFRAMEWORK
JSR308="`cd $CHECKERFRAMEWORK/.. && pwd`"   # base directory
WORKDIR="${CHECKERFRAMEWORK}/checker/jdk"   # working directory
AJDK="${JSR308}/annotated-jdk8u-jdk"        # annotated JDK
SRCDIR="${AJDK}/src/share/classes"
BINDIR="${WORKDIR}/build"
BOOTDIR="${WORKDIR}/bootstrap"              # initial build w/o processors
TOOLSJAR="${JAVA_HOME}/lib/tools.jar"
LT_BIN="${JSR308}/jsr308-langtools/build/classes"
LT_JAVAC="${JSR308}/jsr308-langtools/dist/bin/javac"
CF_BIN="${CHECKERFRAMEWORK}/checker/build"
CF_DIST="${CHECKERFRAMEWORK}/checker/dist"
CF_JAR="${CF_DIST}/checker.jar"
CF_JAVAC="java -jar ${CF_JAR}"
CTSYM="${JAVA_HOME}/lib/ct.sym"
CP="${BINDIR}:${BOOTDIR}:${LT_BIN}:${TOOLSJAR}:${CF_BIN}:${CF_JAR}"
JFLAGS="-source 8 -target 8 -encoding ascii -cp ${CP} \
        -XDignore.symbol.file=true -Xmaxerrs 20000 -Xmaxwarns 20000"
PROCESSORS="interning,igj,javari,nullness,signature"
PFLAGS="-Aignorejdkastub -AuseDefaultsForUncheckedCode=source -AprintErrorStack -Awarns"

set -o pipefail

# if all source files successfully compiled, extract annotations from
# classfiles and insert them into ct.sym, repackaged as jdk8.jar
finish() {
    echo "building JAR"
    rm -rf ${WORKDIR}/sym
    mkdir -p ${WORKDIR}/sym
    cd ${WORKDIR}/sym
    # unjar ct.sym
    jar xf ${CTSYM}
    cd ${WORKDIR}/sym/META-INF/sym/rt.jar  # yes, it's a directory
    # annotate class files
    for f in `find * -name '*\.class' -print` ; do
        B=`basename $f .class`
        D=`dirname $f`
        if [ -r ${BINDIR}/$f ] ; then
            echo "extract-annotations ${BINDIR}/$f"
            CLASSPATH=${CP} extract-annotations ${BINDIR}/$f
            JAIFS=`echo ${BINDIR}/$D/*.jaif`
            for g in ${JAIFS} ; do
                CLS="$D/`basename $g .jaif`.class"
                if [ -r "${CLS}" ] ; then
                    echo "insert-annotations $CLS $g"
                    CLASSPATH=${CP} insert-annotations "$CLS" "$g"
                else
                    echo ${CLS}: not found
                fi
            done
            if [ ${PRESERVE} -ne 0 ] ; then
                # save JAIFs for analysis
                DEST=${WORKDIR}/jaifs/$D
                mkdir -p ${DEST}
                mv ${JAIFS} ${DEST}
            fi
        fi
    done
    # recreate jar
    jar cf ${WORKDIR}/jdk8.jar *
    cd ${WORKDIR}
    [ ${PRESERVE} -ne 0 ] || rm -rf sym
}

cd ${SRCDIR}
rm -rf ${BOOTDIR} ${BINDIR}
mkdir -p ${BOOTDIR} ${BINDIR}

SRC="`find com/sun/jarsigner com/sun/security com/sun/tools/attach \
           java javax/management jdk sun \
        \( -name dc -o -name jconsole -o -name snmp \) -prune \
        -o -name '*\.java' -print`"
# AGENDA keeps track of source files remaining to be processed
AGENDA=`grep -l -w checkerframework ${SRC}`

if [ -z "${AGENDA}" ] ; then
    echo "no annotated source files" | tee -a ${WORKDIR}/LOG0
    exit 1
fi

# warn of any files containing "checkerframework" but not "@AnnotatedFor"
NAF=`grep -L -w '@AnnotatedFor' ${AGENDA}`
if [ ! -z "${NAF}" ] ; then
    echo "Warning: missing @AnnotatedFor:"
    for f in ${NAF} ; do
        echo "    $f"
    done
fi

echo "phase 0: build bootstrap JDK" | tee ${WORKDIR}/LOG0
${LT_JAVAC} -g -d ${BOOTDIR} ${JFLAGS} ${SRC} | tee -a ${WORKDIR}/LOG0
[ $? -eq 0 ] || exit $?

echo "phase 1: process all source files together" | tee ${WORKDIR}/LOG1
[ ! -r ${CF_DIST} ] && echo making directory ${CF_DIST} && mkdir ${CF_DIST}
[ ! -r ${CF_DIST}/javac.jar ] && echo copying javac JAR && \
        cp ${JSR308}/jsr308-langtools/dist/lib/javac.jar ${CF_DIST}
[ ! -r ${CF_DIST}/jdk8.jar ] && echo creating bootstrap JDK 8 JAR && \
        cd ${BOOTDIR} && jar cf ${WORKDIR}/jdk8.jar * && \
        cp ${WORKDIR}/jdk8.jar ${CF_DIST}

${CF_JAVAC} -g -d ${BINDIR} ${JFLAGS} -processor ${PROCESSORS} ${PFLAGS} \
    ${AGENDA} 2>&1 | tee -a ${WORKDIR}/LOG1
[ $? -eq 0 ] && echo "success!" && exit 0

# hack: scrape log file to find which source files crashed
# TODO: check for corresponding class files instead
AGENDA=`grep 'Compilation unit: ' ${WORKDIR}/LOG1 | awk '{print$3}' | sort -u`
[ -z "${AGENDA}" ] && finish && echo "success!" && exit 0 | \
        tee -a ${WORKDIR}/LOG1

# retry failures with all phase 1 class files available in the classpath
echo "phase 2: retry failures" | tee ${WORKDIR}/LOG2
${CF_JAVAC} -g -d ${BINDIR} ${JFLAGS} -processor ${PROCESSORS} ${PFLAGS} \
         ${AGENDA} 2>&1 | tee -a ${WORKDIR}/LOG2

AGENDA=`grep 'Compilation unit: ' ${WORKDIR}/LOG2 | awk '{print$3}' | sort -u`
[ -z "${AGENDA}" ] && finish && echo "success!" && exit 0 | \
        tee -a ${WORKDIR}/LOG2

# retry remaining failures individually with all processors on
echo "phase 3: retry failures individually" | tee ${WORKDIR}/LOG3
for f in ${AGENDA} ; do
    ${CF_JAVAC} -g -d ${BINDIR} ${JFLAGS} -processor ${PROCESSORS} ${PFLAGS} \
            $f 2>&1 | tee -a ${WORKDIR}/LOG3
done

AGENDA=`grep 'Compilation unit: ' ${WORKDIR}/LOG3 | awk '{print$3}' | sort -u`
[ -z "${AGENDA}" ] && finish && echo "success!" && exit 0 | \
        tee -a ${WORKDIR}/LOG3

# retry remaining failures individually with each processor, one at a time;
# extract annotations from resulting class files;
# compile w/o processors and then re-insert all annotations
echo "phase 4: retry failures individually with one processor at a time" \
        | tee ${WORKDIR}/LOG4
mkdir -p jaifs
for f in ${AGENDA} ; do
    BASE="`dirname $f`/`basename $f .java`"
    CLS="${BASE}.class"

    # extract annotations
    for p in `echo ${PROCESSORS} | tr , '\012'` ; do
        ${CF_JAVAC} -g -d ${BINDIR} ${JFLAGS} -processor $p ${PFLAGS} \
                 $f 2>&1 | tee -a ${WORKDIR}/LOG4
        if [ $? -eq 0 -a -r ${CLS} ] ; then
            for c in "${BASE}.class ${BASE}\$*.class" ; do
                echo extracting from: $c
                CLASSPATH=${CP} extract-annotations "$c" 2>&1 | \
                        tee -a ${WORKDIR}/LOG4
                S=$?
                [ ${RET} -eq 0 ] && RET=$S
            done
            JAIFS="${BINDIR}/$D/*.jaif"
            if [ -z "${JAIFS}" ] ; then
                mkdir -p jaifs/$p
                mv ${JAIFS} jaifs/$p
            fi
        fi
    done
    [ ${RET} -ne 0 ] && echo "$f: extraction failed" && exit ${RET}

    # insert all annotations into unannotated class files
    ${CF_JAVAC} -g -d ${BINDIR} ${JFLAGS} $f 2>&1 | tee -a ${WORKDIR}/LOG4
    RET=$?
    if [ ${RET} -eq 0 -a -r ${CLS} ] ; then
        for g in jaifs/*/*.jaif ; do
            echo inserting into: $c
            CLASSPATH=${CP} insert-annotations "${CLS}" "$g" | \
                    tee -a ${WORKDIR}/LOG4
            RET=$?
            rm -f "$g"
        done
    fi
    [ ${RET} -ne 0 ] && echo "${CLS}: insertion failed" && exit ${RET}
done
[ ${PRESERVE} -eq 0 ] && rm -rf jaifs

finish && echo "success!" && exit 0

