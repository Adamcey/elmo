class Setting < ActiveRecord::Base
  include MissionBased

  # attribs to copy to configatron
  KEYS_TO_COPY = %w(timezone preferred_locales intellisms_username intellisms_password incoming_sms_numbers twilio_phone_number twilio_account_sid twilio_auth_token)

  # these are the keys that make sense in admin mode
  ADMIN_MODE_KEYS = %w(timezone preferred_locales)

  DEFAULTS = { timezone: "UTC", preferred_locales: [:en], incoming_sms_numbers: [] }

  scope(:by_mission, ->(m) { where(:mission_id => m ? m.id : nil) })

  scope(:default, -> { where(DEFAULTS) })

  before_validation(:normalize_locales)
  before_validation(:normalize_incoming_sms_numbers)
  before_validation(:nullify_fields_if_these_are_admin_mode_settings)
  before_validation(:normalize_twilio_phone_number)
  before_validation(:clear_sms_fields_if_requested)
  validate(:locales_are_valid)
  validate(:one_locale_must_have_translations)
  validate(:sms_adapter_is_valid)
  validate(:sms_credentials_are_valid)
  before_save(:save_sms_credentials)

  serialize :preferred_locales, JSON
  serialize :incoming_sms_numbers, JSON

  # accessors for password/password confirm/clear fields
  attr_accessor :intellisms_password1, :intellisms_password2, :twilio_auth_token1, :clear_intellisms, :clear_twilio

  # loads the settings for the given mission (or nil mission/admin mode) into the configatron store
  # if the settings can't be found, a default setting is created and saved before being loaded
  def self.load_for_mission(mission)
    setting = by_mission(mission).first

    if !setting
      setting = build_default(mission)
      setting.save!
    end

    setting.load
    return setting
  end

  # loads the default settings without saving
  def self.load_default
    setting = build_default
    setting.load
    return setting
  end

  # builds and returns (but doesn't save) a default Setting object
  # by using the defaults specified in this file and those specified in the local config
  # mission may be nil.
  def self.build_default(mission = nil)
    # initialize a new setting object with default values
    setting = by_mission(mission).default.new
    # preferred_locales from default scope is converted to string
    # bug in rails 4.2?
    setting.preferred_locales = [:en]

    setting.generate_incoming_sms_token if mission.present?

    # copy default_settings from configatron
    configatron.default_settings.configatron_keys.each do |k|
      setting.send("#{k}=", configatron.default_settings.send(k)) if setting.respond_to?("#{k}=")
    end

    setting
  end

  def generate_override_code!(size = 6)
    self.override_code = Random.alphanum_no_zero(size)
    self.save!
  end

  def generate_incoming_sms_token(replace=false)
    # Don't replace token unless replace==true
    unless incoming_sms_token.nil? or replace
      return
    end

    # Ensure that the new token is actually different
    begin
      new_token = SecureRandom.hex
    end while new_token == incoming_sms_token

    self.incoming_sms_token = new_token
  end

  def regenerate_incoming_sms_token!
    generate_incoming_sms_token(true)
    save!
  end

  # copies this setting to configatron
  def load
    # build hash
    hsh = Hash[*KEYS_TO_COPY.collect{|k| [k.to_sym, send(k)]}.flatten(1)]

    # get class based on sms adapter setting; default to nil if setting is invalid
    hsh[:outgoing_sms_adapter] = begin
      Sms::Adapters::Factory.new.create(default_outgoing_sms_adapter)
    rescue ArgumentError
      nil
    end

    #set the preferred locale for the mission
    hsh[:preferred_locale] = preferred_locales.first

    # set system timezone
    Time.zone = timezone

    # copy to configatron
    configatron.configure_from_hash(hsh)
  end

  # converts preferred_locales to a comma delimited string
  def preferred_locales_str
    (preferred_locales || []).join(',')
  end

  def preferred_locales_str=(codes)
    self.preferred_locales = (codes || '').split(',')
  end

  # converts preferred locales to symbols on read
  def preferred_locales
    read_attribute('preferred_locales').map(&:to_sym)
  end

  def incoming_sms_numbers_str
    incoming_sms_numbers.join(", ")
  end

  def incoming_sms_numbers_str=(nums)
    self.incoming_sms_numbers = (nums || "").split(",").map { |n| PhoneNormalizer.normalize(n) }.compact
  end

  # Determines if this setting is read only due to mission being locked.
  def read_only?
    mission.try(:locked?) # Mission may be nil if admin mode, in which case it's not read only.
  end

  private

    # gets rid of any junk chars in locales
    def normalize_locales
      self.preferred_locales = preferred_locales.map{|l| l.to_s.downcase.gsub(/[^a-z]/, "")[0,2]}
      return true
    end

    def normalize_twilio_phone_number
      # Allow for the use of a database that hasn't had the migration run
      return unless respond_to?(:twilio_phone_number)

      self.twilio_phone_number = PhoneNormalizer.normalize(twilio_phone_number)
    end

    def normalize_incoming_sms_numbers
      # Most normalization is performed in the assignment method.
      # Here we just ensure no nulls.
      self.incoming_sms_numbers = [] if incoming_sms_numbers.blank?
    end

    # makes sure all language codes are valid ISO639 codes
    def locales_are_valid
      preferred_locales.each do |l|
        errors.add(:preferred_locales_str, :invalid_code, :code => l) unless ISO_639.find(l.to_s)
      end
    end

    # makes sure at least one of the chosen locales is an available locale
    def one_locale_must_have_translations
      if (preferred_locales & configatron.full_locales).empty?
        errors.add(:preferred_locales_str, :one_must_have_translations, :locales => configatron.full_locales.join(","))
      end
    end

    # sms adapter can be blank or must be valid according to the Factory
    def sms_adapter_is_valid
      errors.add(:default_outgoing_sms_adapter, :is_invalid) unless default_outgoing_sms_adapter.blank? || Sms::Adapters::Factory.name_is_valid?(default_outgoing_sms_adapter)
    end

    # check if settings for a particular adapter should be validated
    def should_validate?(adapter)
      # settings for the default outgoing adapter should always be validated
      return true if default_outgoing_sms_adapter == adapter

      # settings for an adapter should be validated if any settings for that adapter are present
      case adapter
      when "IntelliSms"
        intellisms_username.present? || intellisms_password1.present? || intellisms_password2.present?
      when "Twilio"
        twilio_phone_number.present? || twilio_account_sid.present? || twilio_auth_token1.present?
      end
    end

    # checks that the provided credentials are valid
    def sms_credentials_are_valid
      if should_validate?("IntelliSms")
        errors.add(:intellisms_username, :blank) if intellisms_username.blank?
        errors.add(:intellisms_password1, :blank) if intellisms_password.blank? && intellisms_password1.blank? && intellisms_password2.blank?
        errors.add(:intellisms_password1, :did_not_match) unless intellisms_password1 == intellisms_password2
      end

      if should_validate?("Twilio")
        errors.add(:twilio_account_sid, :blank) if twilio_account_sid.blank?
        errors.add(:twilio_auth_token1, :blank) if twilio_auth_token.blank? && twilio_auth_token1.blank?
      end
    end

    # clear SMS fields if requested
    def clear_sms_fields_if_requested
      if clear_intellisms == "1"
        self.intellisms_username = nil
        self.intellisms_password = nil
        self.intellisms_password1 = nil
        self.intellisms_password2 = nil
      end
      if clear_twilio == "1"
        self.twilio_phone_number = nil
        self.twilio_account_sid = nil
        self.twilio_auth_token = nil
        self.twilio_auth_token1 = nil
      end
    end

    # if the sms credentials temp fields are set (and they match, which is checked above), copy the value to the real field
    def save_sms_credentials
      self.intellisms_password = intellisms_password1 unless intellisms_password1.blank?
      self.twilio_auth_token = twilio_auth_token1 unless twilio_auth_token1.blank?
      return true
    end

    # if we are in admin mode, then a bunch of fields don't make sense and should be null
    # make sure they are in fact null
    def nullify_fields_if_these_are_admin_mode_settings
      # if mission_id is nil, that means we're in admin mode
      if mission_id.nil?
        (attributes.keys - ADMIN_MODE_KEYS - %w(id created_at updated_at mission_id)).each{|a| self.send("#{a}=", nil)}
      end
    end
end
