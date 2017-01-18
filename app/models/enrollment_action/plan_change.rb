module EnrollmentAction
  class PlanChange < Base
    extend PlanComparisonHelper
    extend DependentComparisonHelper
    def self.qualifies?(chunk)
      return false if chunk.length < 2
      return false if same_plan?(chunk)
      (!carriers_are_different?(chunk)) && !dependents_changed?(chunk)
    end

    # TODO: Create new policy
    def persist
      policy_to_term = termination.existing_policy
      policy_to_term.terminate_as_of(termination.subscriber_end)
    end

    def publish
      action_helper = EnrollmentAction::ActionPublishHandler.new(action.event_xml)
      action_helper.set_event_action("urn:openhbx:terms:v1:enrollment#change_product")
      publish_edi(amqp_connection, action_helper.to_xml, action.hbx_enrollment_id, action.employer_hbx_id)
    end
  end
end
