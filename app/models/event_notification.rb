class EventNotification < DocumentValidator
  validate :verify_is_event

  attr_reader :event_publisher

  def initialize(doc, s = Schemas::OpenHbx.get, e_pubber = EventPublisher.new)
    super(doc, s)
    @event_publisher = e_pubber
  end

  def save
    return false unless valid?
    event_publisher.publish(document)
    true
  end

  def verify_is_event
    unless document.xpath("//cv:event/cv:event_name", XML_NS).any?
      errors.add(:document, "is not an event")
    end
  end

end
