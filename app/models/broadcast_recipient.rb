# Lightweight wrapper around a user or group, modeling useful properties in the context of broadcasts.
class BroadcastRecipient
  include ActiveModel::SerializerSupport

  attr_reader :object

  def initialize(object:)
    @object = object
  end

  def id
    "#{object.class.name.underscore}_#{object.id}"
  end

  def name
    "#{object.class.model_name.human}: #{object.name}"
  end
end
