MONGO_HOME="../../mongo/mongodb-osx-x86_64-3.0.11"

if [ -z "$1" ]
  then
    echo "Please specify script filename"
    exit 1
fi

$MONGO_HOME/bin/mongo localhost:27017/test $1
