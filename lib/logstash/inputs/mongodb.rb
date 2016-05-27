# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "logstash/timestamp"
require "stud/interval"
require "socket" # for Socket.gethostname
require "json"
require "mongo"

include Mongo

class LogStash::Inputs::MongoDB < LogStash::Inputs::Base
  config_name "mongodb"

  # If undefined, Logstash will complain, even if codec is unused.
  default :codec, "plain"

  # Example URI: mongodb://mydb.host:27017/mydbname?ssl=true
  config :uri, :validate => :string, :required => true

  # The directory that will contain the sqlite database file.
  config :placeholder_db_dir, :validate => :string, :required => true

  # The name of the sqlite databse file
  config :placeholder_db_name, :validate => :string, :default => "logstash_sqlite.db"

  config :mongo_cursor_limit, :avlidate => :number, :default => 125

  config :since_table, :validate => :string, :default => "logstash_since"

  # The collection to use. Is turned into a regex so 'events' will match 'events_20150227'
  # Example collection: events_20150227 or events_
  config :collection, :validate => :string, :required => true

  config :target_key, :validate => :string, :default => '_id'

  config :initial_place, :validate => :string, :default => ''

  # This allows you to select the method you would like to use to parse your data
  config :parse_method, :validate => :string, :default => 'simple'

  config :unpack_mongo_id, :validate => :boolean, :default => false

  # MongoDB polling interval in seconds
  config :interval, :validate => :number, :default => 1

  SINCE_TABLE = :since_table

  public
  def init_placeholder_table(sqlitedb)
    begin
      sqlitedb.create_table "#{SINCE_TABLE}" do
        String :table
        Int :place
        String :placeType
      end
    rescue
      @logger.debug("since table already exists")
    end
  end

  public
  def pluck_target(doc)
    target = doc[@target_key]
    @targetType = target.class.to_s
    # properly convert target into type that can be expressed as a SQL literal
    if target.is_a? BSON::ObjectId
      target = target.to_s
    elsif target.is_a? Time
      target = toISO8601(target)
    end
    return target
  end

  public
  def init_placeholder(sqlitedb, since_table, mongodb, mongo_collection_name)
    @logger.debug("init placeholder for #{since_table}_#{mongo_collection_name}, target key=#{target_key}")
    since = sqlitedb[SINCE_TABLE]
    mongo_collection = mongodb.collection(mongo_collection_name)
    first_entry = mongo_collection.find({}).sort(@target_key => 1).limit(1).first
    first_entry_id = pluck_target(first_entry)
    if !initial_place.empty?
      first_entry_id = initial_place
    end
    @logger.debug("collection: #{mongo_collection_name}, first_entry_id: #{first_entry_id}")
    since.insert(
      :table => "#{since_table}_#{mongo_collection_name}", 
      :place => first_entry_id,
      :placeType => @targetType)
    return first_entry_id
  end

  public
  def get_placeholder(sqlitedb, since_table, mongodb, mongo_collection_name)
    since = sqlitedb[SINCE_TABLE]
    x = since.where(:table => "#{since_table}_#{mongo_collection_name}")
    if x[:place].nil? || x[:place] == 0
      first_entry_id = init_placeholder(sqlitedb, since_table, mongodb, mongo_collection_name)
      @logger.debug("FIRST ENTRY ID for #{mongo_collection_name} is #{first_entry_id}")
      return first_entry_id
    else
      @logger.debug("placeholder already exists, it is #{x[:place]}")
      @targetType = x[:place][:placeType]
      return x[:place][:place]
    end
  end

  public
  def update_placeholder(sqlitedb, since_table, mongo_collection_name, place)
    #@logger.debug("updating placeholder for #{since_table}_#{mongo_collection_name} to #{place}")
    since = sqlitedb[SINCE_TABLE]
    since.where(:table => "#{since_table}_#{mongo_collection_name}").update(:place => place)
  end

  public
  def get_all_tables(mongodb)
    return @mongodb.collection_names
  end

  public
  def get_collection_names(mongodb, collection)
    collection_names = []
    @mongodb.collection_names.each do |coll|
      if /#{collection}/ =~ coll
        collection_names.push(coll)
        @logger.debug("Added #{coll} to the collection list as it matches our collection search")
      end
    end
    return collection_names
  end

  public
  def get_cursor_for_collection(mongodb, mongo_collection_name, last_id)
    collection = mongodb.collection(mongo_collection_name)
    last_id_object = last_id
    if @targetType == 'BSON::ObjectId'
      last_id_object = BSON::ObjectId(last_id)
    elsif @targetType == 'Time'
      last_id_object = Time.parse(last_id)
    end
    return collection.find({@target_key => {:$gt => last_id_object}}).sort(@target_key => 1).limit(@mongo_cursor_limit)
  end

  public
  def update_watched_collections(mongodb, collection, sqlitedb)
    collections = get_collection_names(mongodb, collection)
    collection_data = {}
    collections.each do |my_collection|
      init_placeholder_table(sqlitedb)
      last_id = get_placeholder(sqlitedb, since_table, mongodb, my_collection)
      if !collection_data[my_collection]
        collection_data[my_collection] = { :name => my_collection, :last_id => last_id }
      end
    end
    return collection_data
  end

  public
  def register
    require "jdbc/sqlite3"
    require "sequel"
    placeholder_db_path = File.join(@placeholder_db_dir, @placeholder_db_name)
    conn = Mongo::Client.new(@uri, :logger => @logger)

    @host = Socket.gethostname
    @logger.info("Registering MongoDB input")

    @mongodb = conn.database
    @sqlitedb = Sequel.connect("jdbc:sqlite:#{placeholder_db_path}")

    # Should check to see if there are new matching tables at a predefined interval or on some trigger
    @collection_data = update_watched_collections(@mongodb, @collection, @sqlitedb)
  end # def register

  class BSON::OrderedHash
    def to_h
      inject({}) { |acc, element| k,v = element; acc[k] = (if v.class == BSON::OrderedHash then v.to_h else v end); acc }
    end

    def to_json
      JSON.parse(self.to_h.to_json, :allow_nan => true)
    end
  end

  def run(queue)
    @logger.info("Tailing MongoDB")
    @logger.info("Collection data is: #{@collection_data}")

    while true && !stop?
      begin
        @logger.debug("collection_data is: #{@collection_data}")
        @collection_data.each do |index, collection|
          collection_name = collection[:name]
          last_id = @collection_data[index][:last_id]
          @logger.info("Polling mongo", :last_id => last_id, :index => index, :collection => collection_name)
          # get batch of events starting at the last_place
          cursor = get_cursor_for_collection(@mongodb, collection_name, last_id)
          cursor.each do |doc|
            logdate = Time.new
            if doc['_id'].is_a? BSON::ObjectId
              logdate = DateTime.parse(doc['_id'].generation_time.to_s)
            end
            event = LogStash::Event.new("host" => @host)
            decorate(event)
            event["logdate"] = logdate.iso8601
            log_entry = doc.to_h.to_s
            log_entry['_id'] = log_entry['_id'].to_s
            event["log_entry"] = log_entry
            event["mongo_id"] = doc['_id'].to_s
            @logger.debug("mongo_id: "+doc['_id'].to_s)
            #@logger.debug("EVENT looks like: "+event.to_s)
            #@logger.debug("Sent message: "+doc.to_h.to_s)
            #@logger.debug("EVENT looks like: "+event.to_s)
            # Extract the HOST_ID and PID from the MongoDB BSON::ObjectID
            if @unpack_mongo_id
              doc_hex_bytes = doc['_id'].to_s.each_char.each_slice(2).map {|b| b.join.to_i(16) }
              doc_obj_bin = doc_hex_bytes.pack("C*").unpack("a4 a3 a2 a3")
              host_id = doc_obj_bin[1].unpack("S")
              process_id = doc_obj_bin[2].unpack("S")
              event['host_id'] = host_id.first.to_i
              event['process_id'] = process_id.first.to_i
            end

            if @parse_method == 'simple'
              doc.each do |k, v|
                  event[k] = v
              end
            elsif @parse_method == 'json'
              doc.each do |k, v|
                  event[k] = bsonToJson(v)
              end
            end

            queue << event
            @collection_data[index][:last_id] = pluck_target(doc)
          end
          # Store the last-seen doc in the database
          update_placeholder(@sqlitedb, since_table, collection_name, @collection_data[index][:last_id])
        end
        @logger.debug("Updating watch collections")
        @collection_data = update_watched_collections(@mongodb, @collection, @sqlitedb)

        @logger.debug("Sleeping poll interval.", :time => @interval)
        sleep(@interval)
      rescue => e
        @logger.warn('MongoDB Input threw an exception, restarting', :exception => e)
      end
    end
  end # def run

  public
  def bsonToJson(inputVal)
    #@logger.info(inputVal.to_s + " is a: " + inputVal.class.to_s)
    if inputVal.is_a? Array
      array = []
      inputVal.each do |v|
        array.push(bsonToJson(v))
      end
      return array
    elsif inputVal.is_a? BSON::Document
      hash = {}
      inputVal.each do |k, v|
        hash[k] = bsonToJson(v)
      end
      return hash
    elsif inputVal.is_a? Time
      return toISO8601(inputVal)
    else
      return inputVal
    end
  end

  #Time.iso8601 drops milliseconds so using strftime instead
  public
  def toISO8601(time)
    time.utc
    return time.strftime('%Y-%m-%dT%H:%M:%S.%L') + 'Z'
  end

  def close
    # If needed, use this to tidy up on shutdown
    @logger.info("Shutting down...")
  end

end # class LogStash::Inputs::Example
