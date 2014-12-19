# Behaviors that handle replicating creation and updates to copies of core objects (forms, questions, etc.) within and across missions.
module Replicable
  extend ActiveSupport::Concern

  DEPENDENT_CLASSES = %w(OptionNode Questioning Condition)

  # an initial list of attributes that we don't want to copy from the src_obj to the dest_obj
  ATTRIBS_NOT_TO_COPY = %w(id created_at updated_at mission_id mission is_standard standard_id standard)

  # whether to print verbose info to Rails log
  LOG_REPLICATION = true

  included do
    # create hooks to copy key params from parent and to children
    # this doesn't work with before_create for some reason
    before_validation(:copy_is_standard_and_mission_from_parent)
    before_validation(:copy_is_standard_and_mission_to_children)

    # dsl-style method for setting options from base class
    def self.replicable(options = {})
      options[:child_assocs] = Array.wrap(options[:child_assocs])
      options[:dont_copy] = Array.wrap(options[:dont_copy]).map(&:to_s)
      class_variable_set('@@replication_options', options)
    end

    # cleaner accessor for replication options
    def self.replication_options
      class_variable_defined?('@@replication_options') ? class_variable_get('@@replication_options') : nil
    end

    # only log replication if constant is set and env is dev or test
    def self.log_replication?
      LOG_REPLICATION && (Rails.env.test? || Rails.env.development?)
    end
  end

  # There are three replication modes passed via the :mode parameter:
  # * :clone      Make a copy of the object and its decendants in the same mission (or admin mode).
  # * :to_mission Copy/update a standard object and its decendants to a particular different mission.
  #               requires :dest_mission parameter
  # * :promote    Creates standard objects from a non-standard object. If :retain_link_on_promote parameter
  #               is true then the original objects immediately become standard copies and thus edits are restricted.
  #               Otherwise no link is maintained between the original and new standard.
  # Examples:
  # obj.replicate(:mode => :clone)
  # obj.replicate(:mode => :to_mission, :dest_mission => m)
  # obj.replicate(:mode => :promote, :retain_link_on_promote => false)
  def replicate(options = nil)
    # if mission or nil was passed in, we don't have a replication object, so we need to create one
    # a replication is an object to track replication parameters
    if options.is_a?(Replication)
      replication = options
    else
      raise ArgumentError, 'replication mode is required' unless options[:mode]
      raise ArgumentError, 'dest_mission must be given for to_mission mode' if options[:mode] == :to_mission && !options[:dest_mission]
      raise ArgumentError, 'dest_mission only required for to_mission mode' if options[:mode] != :to_mission && options[:dest_mission]
      replication = Replication.new(options.merge(:src_obj => self))
    end

    # Wrap in transaction and run assertions if this is the first call
    if !replication.in_transaction?

      transaction do
        replication.in_transaction = true
        result = replicate(replication)
        do_standard_assertions
        result
      end

    else

      # do logging after redo_in_transaction so we don't get duplication
      Rails.logger.debug(replication.to_s) if self.class.log_replication?

      dest_obj = setup_replication_destination_obj(replication)

      # If dest_obj is not a new record, we can just return it, no need to replicate further.
      unless dest_obj.new_record?
        add_replication_dest_obj_to_parents_assocation(replication, dest_obj)
        return dest_obj
      end

      # if we get this far we DO need to do recursive copying

      replication.dest_obj = dest_obj

      # set the proper mission ID if applicable
      dest_obj.mission_id = replication.dest_mission.try(:id)

      # copy attributes from src to parent
      replicate_attributes(replication)

      # if we are copying standard to standard, preserve the is_standard flag
      dest_obj.is_standard = true if replication.to_standard? && standardizable?

      # ensure uniqueness params are respected
      ensure_uniqueness_when_replicating(replication)

      # call a callback if requested
      self.send(replicable_opts(:after_copy_attribs), replication) if replicable_opts(:after_copy_attribs)

      # add dest_obj to its parent's assoc before recursive step so that children can access it
      add_replication_dest_obj_to_parents_assocation(replication)

      replicate_child_associations(replication)

      dest_obj.save!

      self.send(replicable_opts(:after_dest_obj_save), replication) if replicable_opts(:after_dest_obj_save)

      # if this is a standard-to-mission replication, add the newly replicated dest obj to the list of copies
      # unless it is there already
      add_copy(dest_obj) if replication.to_mission? && standardizable?

      link_object_to_standard(dest_obj) if replication.promote_and_retain_link? && standardizable?

      dest_obj
    end
  end

  # ensures the given name or other field would be unique, and generates a new name if it wouldnt be
  # (e.g. My Form 2, My Form 3, etc.) for the given name (e.g. My Form)
  # params[:mission] - the mission in which it should be unique
  # params[:dest_obj] - the object to which the name will be applied in the specified mission
  # params[:field] - the field to operate on
  # params[:style] - the style to adhere to in generating the unique value (:sep_words or :camel_case)
  def generate_unique_field_value(params)

    # extract any numeric suffix from existing value
    if params[:style] == :sep_words
      prefix = send(params[:field]).gsub(/( \d+)?$/, '')
    else
      prefix = send(params[:field]).gsub(/(\d+)?$/, '')
    end

    # keep track of whether we found the exact name
    found_exact = false

    # build a relation to get existing objs
    existing = self.class.for_mission(params[:mission])

    # if the dest_obj has an ID (is not a new record),
    # be sure to exclude that when looking for conflicting objects
    existing = existing.where('id != ?', params[:dest_obj]) unless params[:dest_obj].new_record?

    # get the number suffixes of all existing objects
    # e.g. if there are My Form, Other Form, My Form 4, My Form 3, TheForm return [1, 4, 3]
    existing_nums = existing.map do |obj|

      # for the current match, check if it's an exact match and take note
      if obj.send(params[:field]).downcase.strip == send(params[:field]).downcase.strip
        found_exact = true
      end

      # check if the current existing object's name matches the name we're looking for
      number_re = params[:style] == :sep_words ? /\s*( (\d+))?/ : /((\d+))?/
      m = obj.send(params[:field]).match(/^#{Regexp.escape(prefix)}#{number_re}\s*$/i)

      # if there was no match, return nil (this will be compacted out of the array at the end)
      if m.nil?
        nil

      # else if we got a match then we must examine what matched
      # if it was just the prefix, the number is 1
      elsif $2.nil?
        1

      # otherwise we matched a digit so use that
      else
        $2.to_i
      end
    end.compact

    # if we didn't find the exact match or any prefix matches, then no need to add any new suffix
    # just return the name as is
    return send(params[:field]) if existing_nums.empty? || !found_exact

    # copy num is max of existing plus 1
    copy_num = existing_nums.max + 1

    # suffix string depends on style
    if params[:style] == :sep_words
      suffix = " #{copy_num}"
    else
      suffix = copy_num.to_s
    end

    # now build the new value and return
    "#{prefix}#{suffix}"
  end

  # convenience method for replication options
  def replicable_opts(key)
    self.class.replication_options[key]
  end

  # returns a string representation used for debugging
  def to_s
    pieces = []
    pieces << self.class.name
    pieces << "id:##{id.inspect}"
    pieces << "standardized:" + (is_standard? ? 'standard' : (standard_id.nil? ? 'no' : "copy-of-#{standard_id}")) if standardizable?
    pieces << "mission:#{mission_id.inspect}"
    pieces.join(', ')
  end

  # Not all replicable objects are standardizable.
  def standardizable?
    respond_to?(:is_standard?)
  end

  # gets a value of the specified attribute before the last save call
  # uses the previous_changes hash
  # attrib - (symbol) the name of the attrib to get
  def attrib_before_save(attrib)
    attrib = attrib.to_s

    # if id just changed from nil then we know the last save was actually a create
    # in this case we just return the current value
    # if the value didn't change, we also just return the current value
    if previous_changes['id'] && previous_changes['id'].first.nil? || !previous_changes.has_key?(attrib)
      send(attrib)

    # otherwise, we return the old value
    else
      previous_changes[attrib].first
    end
  end

  # link the src object to the newly created standard object
  def link_object_to_standard(standard_object)
    if new_record?
      self.standard_id = standard_object.id
    else
      update_column(:standard_id, standard_object.id)
    end
  end

  private

    # gets the object to which the replication operation will copy attributes, etc.
    # may be a new object or an existing one depending on parameters
    def setup_replication_destination_obj(replication)

      # If we're on a recursive step and we're doing a shallow copy, THIS is the dest obj
      # UNLESS this is a dependent class, which always need to be replicated.
      if replication.recursed? && replication.shallow_copy? && !DEPENDENT_CLASSES.include?(self.class.name)
        self

      # If this is not the first step in the replication
      # AND is a standard object AND we're copying to a mission AND there exists a copy of this obj in the given mission,
      # then we don't need to create a new object, so return the existing copy
      elsif replication.recursed? && standardizable? && replication.has_dest_mission? && (copy = copy_for_mission(replication.dest_mission))
        copy

      # Else if trivial object and match, use that
      elsif respond_to?(:similar_for_mission) && (similar = similar_for_mission(replication.dest_mission))
        similar

      else
        # Otherwise, we init and return the new object
        self.class.new
      end
    end

    # replicates the appropriate attributes from the src to the dest
    def replicate_attributes(replication)
      # get the names of attribs NOT to copy
      skip = attribs_not_to_replicate(replication)

      # hashify the list to avoid n^2 runtime
      skip = Hash[*skip.map{|a| [a,1]}.flatten]

      # do the copy
      attributes.each{|k,v| replicate_attribute(k, v, replication, skip)}
    end

    # replicates a single attribute for the given replication op, respecting the given hashified skip list
    def replicate_attribute(name, value, replication, skip)
      # get ref to dest obj
      dest_obj = replication.dest_obj

      if !skip[name]
        Rails.logger.debug "Replicating attribute #{name}" if self.class.log_replication?
        dest_obj.send("#{name}=", value)
      end
    end

    # gets a list of attribute keys of this object that should NOT be copied to the dest obj
    # this might look like [foo, bar, alpha.bravo]
    # where alpha.bravo means "don't copy the 'bravo' key of the 'alpha' hash"
    def attribs_not_to_replicate(replication)
      # start with the initial, constant set
      dont_copy = ATTRIBS_NOT_TO_COPY

      # add the ones that are specified explicitly in the replicable options
      dont_copy += replicable_opts(:dont_copy)

      # don't copy foreign key field of belongs_to associations
      replicable_opts(:child_assocs).each do |assoc|
        refl = self.class.reflect_on_association(assoc)
        dont_copy << refl.foreign_key if refl.macro == :belongs_to
      end

      # don't copy foreign key field of parent's has_* association, if applicable
      if replicable_opts(:parent_assoc)
        dont_copy << replicable_opts(:parent_assoc).to_s + '_id'
      end

      Rails.logger.debug("Not copying #{dont_copy.to_s}") if self.class.log_replication?

      dont_copy
    end

    # ensures the uniqueness replicable option is respected
    def ensure_uniqueness_when_replicating(replication)
      # if uniqueness property is set, make sure the specified field is unique
      if params = replicable_opts(:uniqueness)
        # setup the params for the call to the generate_unique_field_value method
        params = params.merge(:mission => replication.dest_mission, :dest_obj => replication.dest_obj)

        # get a unique field value (e.g. name) for the dest_obj (may be the same as the source object's value)
        unique_field_val = generate_unique_field_value(params)

        # set the value on the dest_obj
        replication.dest_obj.send("#{params[:field]}=", unique_field_val)
      end
    end

    # adds the specified object to the applicable parent object's association
    # we do it this way so that links between parent and children objects
    # are established during recursion instead of all at the end
    # this is because some child objects (e.g. conditions) need access to their parents
    def add_replication_dest_obj_to_parents_assocation(replication, dest_obj = nil)
      # trivial case
      return unless replication.has_ancestors? # This has nothing to do with ancestry gem.

      dest_obj ||= replication.dest_obj

      # Associate object with parent using appropriate method depending on assoc type.
      if replication.parent_assoc_type == :singleton
        replication.parent.send("#{replication.current_assoc}=", dest_obj)
      else
        # only copy if not already there
        unless replication.parent.send(replication.current_assoc).include?(dest_obj)
          if replication.parent_assoc_type == :tree
            replication.parent.save! # Need to save here or setting parent may not work.
            dest_obj.parent = replication.parent
          else # :collection
            replication.parent.send(replication.current_assoc).send('<<', dest_obj)
          end
        end
      end
    end

    # replicates all child associations
    def replicate_child_associations(replication)
      # loop over each assoc and call appropriate method
      replicable_opts(:child_assocs).each do |assoc|
        if self.class.reflect_on_association(assoc).collection?
          replicate_collection_association(assoc, replication)
        else
          replicate_non_collection_association(assoc, replication)
        end
      end

      replicate_tree(replication) if replicable_opts(:replicate_tree)
    end

    # replicates a collection-type association
    # by replicating the existing children of the src obj to the dest obj
    def replicate_collection_association(assoc_name, replication)
      send(assoc_name).each{|o| replicate_associated(o, assoc_name, replication)}
    end

    # replicates a non-collection-type association (e.g. belongs_to)
    def replicate_non_collection_association(assoc_name, replication)
      replicate_associated(send(assoc_name), assoc_name, replication) unless send(assoc_name).nil?
    end

    # Replicates descendants of an object that has_ancestry.
    def replicate_tree(replication)
      children.each{|o| replicate_associated(o, 'children', replication)}
    end

    # calls replicate on an individual associated object, generating a new set of replication params
    # for this particular replicate call
    def replicate_associated(obj, assoc_name, replication)
      # build new replication param obj for obj
      new_replication = replication.clone_for_recursion(obj, assoc_name)
      obj.replicate(new_replication)
    end

    # Runs some assertions against the database and raises an error if they fail so that the cause
    # can be investigated.
    def do_standard_assertions
      return unless standardizable?
      tbl = self.class.table_name
      assert_no_results("select c.id from #{tbl} c inner join #{tbl} s on c.standard_id=s.id where s.mission_id is not null",
        'mission based objects should not be referenced as standards')
    end

    # Raises an error if the given sql returns any results.
    def assert_no_results(sql, msg)
      raise "Assertion failed: #{msg}" unless self.class.find_by_sql(sql).empty?
    end

    # copies the is_standard and mission properties from any parent association
    def copy_is_standard_and_mission_from_parent
      # reflect on parent association, if it exists
      parent_assoc = self.class.reflect_on_association(self.class.replication_options[:parent_assoc])

      # if the parent association exists and is a belongs_to association and parent exists
      # (e.g. questioning has parent = form, and a form association exists, and parent exists)
      if parent_assoc.try(:macro) == :belongs_to && parent = self.send(parent_assoc.name)
        # copy the params
        self.is_standard = parent.is_standard? if standardizable?
        self.mission = parent.mission
      end
      return true
    end

    # copies the is_standard and mission properties to any children associations
    def copy_is_standard_and_mission_to_children
      # iterate over children assocs
      self.class.replication_options[:child_assocs].each do |assoc|
        refl = self.class.reflect_on_association(assoc)

        # if is a collection association, copy to each, else copy to individual
        if refl.collection?
          send(assoc).each do |o|
            o.mission = mission
            o.is_standard = mission.nil? if o.standardizable?
          end
        else
          unless send(assoc).nil?
            send(assoc).mission = mission
            send(assoc).is_standard = mission.nil? if send(assoc).standardizable?
          end
        end
      end
      return true
    end
end
