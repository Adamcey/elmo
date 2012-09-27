require 'rubygems'
require 'mysql'

# assumes the main DB has already been db:schema:load'd and db:seedy'd


MISSION_DBS = [{
    :mission => "Oklahoma 2011",
    :database => "cceom_cc_ok",
    :username => "cceom_cc_ok",
    :password => "02870107"
  },{
    :mission => "Liberia 2011",
    :database => "cceom_cc_lr",
    :username => "cceom_cc_lr",
    :password => "t1ckleME"
  },{
    :mission => "Liberia 2011 Runoff",
    :database => "cceom_cc_lr2",
    :username => "cceom_cc_lr2",
    :password => "t1ckleME"
  },{
    :mission => "Egypt 2012",
    :database => "cceom_elmo_eg",
    :username => "cceom_elmo_eg",
    :password => "t1ckleME"
  },{
    :mission => "Libya 2012",
    :database => "cceom_elmo_ly",
    :username => "cceom_elmo_ly",
    :password => "nub87DE'"
  }
]

MAIN_DB = { :database => "cceom_elmo_main", :username => "cceom_elmo_main", :password => "telefunkuku" }
TEMP_DB = { :database => "cceom_temp1", :username => "cceom_temp1", :password => "temp" }

TABLES_NOT_TO_COPY = %w(question_types report_aggregations report_response_attributes roles search_searches sessions user_batches)

TABLES_TO_LOOKUP_IN_MAIN = {
  :question_types => ["questions.question_type_id", "report_fields.question_type_id"], 
  :report_aggregations => ["report_reports.aggregation_id"],
  :report_response_attributes => ["report_fields.attrib_id"],
  :roles => ["users.role_id"]
}

def connect(params)
  Mysql.connect('localhost', params[:username], params[:password], params[:database])
end

def clear_tables(dbname, con)
  res = con.query("show tables")
  while row = res.fetch_hash do
    unless TABLES_NOT_TO_COPY.include?(row[0])
      puts "Deleting from table #{dbname}.#{row[0]}"
      con.query("DELETE FROM #{row[0]}") 
    end
  end
end

# for each db
MISSION_DBS.each_with_index do |mission_db_params, mission_db_idx|

  # connect to mission, temp, and main dbs
  temp_db = connect(TEMP_DB)
  mission_db = connect(mission_db_params)
  main_db = connect(MAIN_DB)
  
  # delete all rows in appropriate tables from main db and temp db
  clear_tables(MAIN_DB[:database], main_db)
  clear_tables(TEMP_DB[:database], temp_db)

  # copy everything from old mission db to the temp db

  # rename the default mission to the correct name

  # first we offset everything in all tables
  # for each table except TABLES_NOT_TO_COPY

    # add offset to all ID's
  
    # for each col ending in _id, add offset
  

  # then we go through the TABLES_TO_LOOKUP_IN_MAIN and lookup their values and build translatioin keys by name
  # for each table in TABLES_TO_LOOKUP_IN_MAIN
    # for each row in old table
      # lookup value in new table and store
    
    # for each foreign key col
      # for each col in that row
        # update the value
      
  # copy all rows in appropriate tables to the main table -- everything should match by now
  
  # update auto increment counters in all appropriate tables to appropriate values
end