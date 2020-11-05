#!/bin/bsh

set -eo pipefail
VERIFY="true"
MARK_MAIN="true"
if [ "x$1" == "x" ] ; then
  ITW=javaws
  #ITW=/home/jvanek/git/icedtea-web-1.8/target/bin/javaws
else
  ITW="$1"
fi

#creates taht much jars.  1st depends on 2nd that on 3rd... up to last. Each can be launched separately, but if you launch the first one, each class will be triggered, and output will be from last
jars=2000
resSize=1000
pkg=my.app
subDir=`echo $pkg | sed "s;\.;/;g"`
stub=JavaApp
classIn="
package $pkg;

public class %NAME% {

  public static void main(String... args) {
    System.out.println(\"!Done %NAME%!\");
  }

  public static void depend(int x) {
    %DEP%.depend(++x);
  }  

}
"

function generateJavaFiles() {
  srcDir=`mktemp -d`
  for x in `seq 1 $jars` ; do
    className=$stub$x;
    echo $srcDir/$className.java
    if [ $x -eq $jars ] ; then
      echo "$classIn" | sed  "s|%NAME%|$stub$x|g" | sed "s|%DEP%.*|System.out.println(\"!traversed through \"+x+\" jars!\");|g" >  $srcDir/$className.java
    else
      let dep=$x+1
      dep=$stub$dep;
      if [ $x -eq 1 ] ; then
        echo "$classIn" | sed  "s|System.out.println.*%NAME%.*|depend(1);|"  | sed  "s|%NAME%|$stub$x|g" | sed "s|%DEP%|$dep|g" >  $srcDir/$className.java
      else
        echo "$classIn"                                                     | sed  "s|%NAME%|$stub$x|g" | sed "s|%DEP%|$dep|g" >  $srcDir/$className.java
      fi
    fi
  done
}

function generateClassFiles() {
  classesDir=`mktemp -d`
  javac -d $classesDir $srcDir/*.java
  dd if=/dev/random of=$classesDir/$subDir/$stub-1.res  bs=$resSize  count=1
  dd if=/dev/zero   of=$classesDir/$subDir/$stub-2.res  bs=$resSize  count=1 # will be packed a lot
  find $classesDir
}

function generatejars() {
  jarsDir=`mktemp -d`
  pushd $classesDir
    for x in `seq 1 $jars` ; do
      className=$stub$x;
      jar -cvf $jarsDir/$className.jar $subDir/$className.class $subDir/*.res
    done
  popd
  echo $jarsDir
  ls -l $jarsDir
}

function verifyClasses() {
  for x in `seq 1 $jars` ; do
    className=$stub$x;
    if [ $x -gt 1 ] ; then
      let dep=$x-1
      ds=-Naur
      set +e
        diff $ds  $srcDir/$stub$dep.java $srcDir/$className.java
        rd=$?
      set -e
      if [ ! $rd -eq 1 ] ; then
        echo "Error, no file can be same. $srcDir/$stub$dep.java $srcDir/$className.java were"
        exit 1
      fi
    fi
    java -cp $classesDir  $pkg.$className;
  done
}


function verifyJars() {
  for x in `seq $jars -1 1` ; do
    className=$stub$x;
    echo -n "$jarsDir/$className.jar: "
    if [ $x -eq 1 ] ; then
      set +e
        java -cp $jarsDir/$className.jar  $pkg.$className 
        rd=$?
      set -e
      if [ $rd -eq 0 ] ; then
        echo "$stub""1.jar must fail. Had not"
        exit 1
      else
        echo "$stub""1.jar correctly failed"
      fi
    else
      java -cp $jarsDir/$className.jar  $pkg.$className;
    fi
  done
}

function jarRuntime() {
  CP=""
  for x in `seq $jars -1 1` ; do
    className=$stub$x;
    jar="$jarsDir/$className.jar"
    CP="$CP:$jar"
  done
  java -cp "$CP" "$pkg.$stub""1";
}



function generateJnlp() {
  jnlpFile="$stub""1.jnlp"
  mainClass="$pkg.$stub""1"
  cat << End-of-message > /$jarsDir/$jnlpFile
<?xml version="1.0" encoding="utf-8"?>
<jnlp spec="1.0+" 
        codebase="."
        href="$jnlpFile">
    <information>
        <title>$jars jars</title>
        <vendor>jvanek</vendor>
    </information>
    <resources>
End-of-message
  for x in `seq $jars -1 1` ; do
    if [ $x -eq 1 ] ; then
      if [ "x$MARK_MAIN" = "xtrue" ] ; then
        echo "<jar href=\"$stub$x.jar\" main=\"true\" />" >> /$jarsDir/$jnlpFile
      else
        echo "<jar href=\"$stub$x.jar\" />" >> /$jarsDir/$jnlpFile
      fi
    else
      echo "<jar href=\"$stub$x.jar\" />" >> /$jarsDir/$jnlpFile
   fi
  done
  cat << End-of-message >> /$jarsDir/$jnlpFile
    </resources>
<!--SEC-->
    <application-desc
         name="$jars jars app"
         main-class="$mainClass">
    </application-desc>
</jnlp>
End-of-message
  echo "$jarsDir/$jnlpFile:"
  cat  "$jarsDir/$jnlpFile"
}



function stopServer() {
  kill $server
}

port=8000
function startServer()  {
  set -x
    python -m http.server $port --directory $jarsDir > server.log &
    server=$!
    trap stopServer EXIT
  set +x
}

function runItwHeadless() {
  $ITW -headless $1 $2 $3 $4 $5 $6 $7 $8 
}

function runItwHeadlessOnGeneratedJnlp() {
  # for headless dialogues
  echo "YES" | runItwHeadless $2 $3 $4 $5 $6 $7 $8 $9 "http://localhost:$port/$jnlpFile" | tee $1  | grep -v "\[.*\]"
}
function cleanCacheAndItwRun() {
  echo "Uncached$1:"
  set -x
    runItwHeadless -Xclearcache > xclear$1.log
    start=`date +%s`
      runItwHeadlessOnGeneratedJnlp uncached$1.log
    end=`date +%s`
  set +x
  let time=$end-$start
  echo "Uncached$1 took: $time""s" | tee -a $RESFILE
}

function runItwOnCachedContent() {
  echo "Cached$1:"
  set -x
    start=`date +%s`
      runItwHeadlessOnGeneratedJnlp cached$1.log
    end=`date +%s`
  set +x
  let time=$end-$start
  echo "Cached$1 took: $time""s" | tee -a $RESFILE
}

function runItwOnCachedContentOffline() {
  echo "Offline$1:"
  set -x
    start=`date +%s`
      runItwHeadlessOnGeneratedJnlp cachedOffline$1.log -Xoffline
    end=`date +%s`
  set +x
  let time=$end-$start
  echo "Offline$1 took: $time""s" | tee -a $RESFILE
}

function measureJre() {
  set +x
  echo "java -cp jars$1:"
  start=`date +%s`
  jarRuntime
  end=`date +%s`
  let time=$end-$start || true #can be 0, and the let returns nonzero
  echo "java jars$1 took: $time""s" | tee -a $RESFILE
}

function signJars() {
  keystore=local_keystore.ks
  tcaw=my_terrible_cert
  pass=super_secret
  rm -vf $keystore
  keytool -genkey -alias $tcaw -keystore $keystore -keypass $pass -storepass $pass -dname "cn=$tcaw, ou=$tcaw, o=$tcaw, c=$tcaw"
  for x in `seq 1 $jars` ; do
    jar="$jarsDir/$stub$x.jar"
    jarsigner -keystore $keystore -storepass $pass -keypass $pass  $jar  $tcaw
  done
  sed -s "s;<!--SEC-->;<security><all-permissions/></security>;g" -i "/$jarsDir/$jnlpFile"
  cat "/$jarsDir/$jnlpFile" | grep -e SEC -e sec
}


function verifySignatures() {
  keystore=local_keystore.ks
  for x in `seq 1 $jars` ; do
    jar="$jarsDir/$stub$x.jar"
    jarsigner -verify -verbose -keystore $keystore $jar
  done
}

######################## MAIN ########################
RESFILE=results-$jars.log
rm -vf $RESFILE
echo "jars: $jars" >> $RESFILE
echo "resources: $resSize" >> $RESFILE

generateJavaFiles
sleep 1 # wait for stdout to not mix stderr
generateClassFiles
generatejars
if [ "x$VERIFY" = "xtrue" ] ; then
  verifyClasses
  verifyJars
fi	
generateJnlp
startServer

cleanCacheAndItwRun
runItwOnCachedContent
runItwOnCachedContentOffline

measureJre


signJars
if [ "x$VERIFY" = "xtrue" ] ; then
  verifySignatures
fi

cleanCacheAndItwRun -signed
runItwOnCachedContent -signed
runItwOnCachedContentOffline -signed

measureJre -signed

cat $RESFILE
