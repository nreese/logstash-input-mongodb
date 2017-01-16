# logstash-input-mongodb

This is a logstash plugin for pulling data out of mongodb and processing with logstash. It will connect to the database specified in `uri`, use the `collection` attribute to find collections to pull documents from, start at the first collection it finds and pull the number of documents specified in `mongo_cursor_limit`, save it's progress in an sqlite database who's location is specified by `placeholder_db_dir` and `placeholder_db_name` and repeat. It will continue this until it no longer finds documents newer than ones that it has processed, sleep for a moment, then continue to loop over the collections.

This plugin tracks its position in the mongo collection by storing the last value of the field specified by the parameter `target_key` in a sqlite database. When looking for new or modified documents, the plugin queries mongo for any documents with a value greater than the last stored value. The field identified by `target_key` must have several important properties; it must be unique, it must be mutable,  and when mutated - the value must be greater than the largest value in the collection. A good value is a ISO_8601 date string identifing the update timestamp concatinated with the document id. For example, the value `2016-05-18T20:29:57.036Z_507f1f77bcf86cd799439011` meets these properties. When the document gets updated, the updated value `2016-10-19T09:37:57.036Z_507f1f77bcf86cd79943901` also meets these properties.

## Changes from phutchins logstash-input-mongodb
This plugin is a fork from [phutchins](https://github.com/phutchins/logstash-input-mongodb).

The original plugin lacked support for mutable Mongodb collections.
This version adds support for updating documents in MongoDB and having those updates migrated to Elasticsearch.

The original plugin had logic to transform the documents pulled from mongo. 
While convenient, this breaks the logstash design pattern. The Logstash paradigm is to use filters to modify events.
The following configuration parameters were remove as a result - `dig_fields` and `dig_dig_fields`. Support for the configuration parameter `parse_method` values dig and flattern were removed.

The original plugin had some configuration options that were not used; `exclude_tables`, `retry_delay`, and `generateId`. These have been removed.

The original plugin used the configuration parameter `batch_size` to specify the mongo cursor limit. The parameter name confuses two very different Mongo cursor concepts, limit and batch_size. Limit specifies the total number of results to fetch. These results may be returned in multiple batches. Batch_size specifies the number of results that should be returned in each batch. The `batch_size` parameter has been renamed to `mongo_cursor_limit`. A new parameter `mongo_cursor_batch_size` has been created, allowing one to configure the mongo cursor batch_size.

## Example Configuration
```
input {
  mongodb {
    uri => 'mongodb://localhost:27017/test'
    placeholder_db_dir => 'directory_that_holds_sqlite_files/'
    placeholder_db_name => 'file_holding_place_of_last_modified_document_for_this_collection.db'
    interval => 10
    parse_method => 'json'
    target_key => 'lastModified'
    initial_place => '2016-05-03T22'
    collection => 'items'
    mongo_cursor_limit => 3
  }
}
```

### Set up env
* Set up [development envirnoment](https://github.com/EagerELK/logstash-development-environment)
* clone code base `git clone git@github.com:nreese/logstash-input-mongodb.git`
* `cd logstash-input-mongodb`
* `bundle install`
 
### Run tests
* `bundle exec rspec`

### Build plugin
* `gem build logstash-input-mongodb.gemspec`

### Install plugin
* `$LOGSTASH_HOME/bin/plugin install logstash-input-mongodb-0.4.0.gem`

## Debugging

### view contents of sqlite file
`sqlite3 -header -csv <filename> "select * from since_table"`
