LOGSTASH_HOME="../../logstash-2.2.2"

echo "## Uninstalling existing logstash-input-mongodb plugin"
$LOGSTASH_HOME/bin/plugin uninstall logstash-input-mongodb

echo "## Building logstash-input-mongodb"
rm logstash-input-mongodb-*.gem
gem build ../logstash-input-mongodb.gemspec

echo "## Deploying logstash-input-mongodb"
$LOGSTASH_HOME/bin/plugin install logstash-input-mongodb-0.1.0.gem

echo "## Listing existing logstash plugins containing tag 'mongo'"
$LOGSTASH_HOME/bin/plugin list | grep "mongo"

echo "## Starting logstash with test configuration"
#cat test.conf
#$LOGSTASH_HOME/bin/logstash -f test.conf
