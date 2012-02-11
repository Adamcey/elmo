class Report::Report < ActiveRecord::Base
  belongs_to(:pri_grouping, :class_name => "Report::Grouping", :autosave => true, :dependent => :destroy)
  belongs_to(:sec_grouping, :class_name => "Report::Grouping", :autosave => true, :dependent => :destroy)
  belongs_to(:aggregation)
  belongs_to(:calculation)
  belongs_to(:filter, :class_name => "Search::Search", :autosave => true, :dependent => :destroy)
  has_many(:fields, :class_name => "Report::Field", :foreign_key => "report_report_id")
  
  attr_reader(:headers, :data, :totals, :grand_total)
  scope(:by_viewed_at, order("viewed_at desc"))
  
  validates(:kind, :presence => true)
  validates(:name, :presence => true, :uniqueness => true)
  
  KINDS = ["Tally"]
  
  def self.type_select_options
    KINDS
  end
  
  def has_run?
    @has_run ||= !new_record?
  end
  
  def filter_attributes=(attribs)
    self.filter = attribs[:str].blank? ? nil : Search::Search.new(attribs)
  end
  
  def pri_grouping_attributes=(attribs)
    self.pri_grouping = Report::Grouping.construct(attribs)
  end

  def sec_grouping_attributes=(attribs)
    self.sec_grouping = Report::Grouping.construct(attribs)
  end
  
  def show_totals?(row_or_col)
    row_or_col == :row ? !sec_grouping.nil? : !pri_grouping.nil?
  end
  
  def run
    @has_run = true
    begin
      @rel = Response.unscoped
    
      # add groupings
      groupings.each{|g| @rel = g.apply(@rel)}
    
      # add count
      @rel = @rel.select("COUNT(responses.id) as `Count`")
    
      # apply filter
      @rel = filter.apply(@rel) unless filter.nil?
    
      # get data and headers
      results = @rel.all
    
      # get headers
      @headers = {
        :row => pri_grouping ? results.collect{|row| row[pri_grouping.col_name]}.uniq : ["# Responses"],
        :col => sec_grouping ? results.collect{|row| row[sec_grouping.col_name]}.uniq : ["# Responses"]
      }
    
      # initialize totals
      @totals = {:row => Array.new(@headers[:row].size, 0), :col => Array.new(@headers[:col].size, 0)}
      @grand_total = 0

      # create blank data table
      @data = @headers[:row].collect{|r| Array.new(@headers[:col].size)}

      # populate data table
      results.each do |row|
        # get row and column indices
        r = pri_grouping ? @headers[:row].index(row[pri_grouping.col_name]) : 0
        c = sec_grouping ? @headers[:col].index(row[sec_grouping.col_name]) : 0
      
        # set the cell value
        @data[r][c] = row["Count"].to_i

        # add to totals
        @totals[:row][r] += @data[r][c]
        @totals[:col][c] += @data[r][c]
        @grand_total += @data[r][c]
      end
    rescue Search::ParseError, Report::ReportError
      Rails.logger.debug("RUN ERROR!")
      errors.add(:base, "Couldn't run report: #{$!.to_s}")
    end
  end
  
  def record_viewing
    self.viewed_at = Time.now
    self.view_count += 1
    save(:validate => false)
  end
  
  def groupings
    [pri_grouping, sec_grouping].compact
  end
  
  def to_json
    {:headers => headers, :data => data, :totals => totals, :has_run => has_run?, :id => id, :name => name, :kind => kind,
      :grand_total => grand_total, :errors => errors.full_messages.join(", ")}.to_json
  end
end
