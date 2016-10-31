module HandlePolicyNotification
  class VerifyRequiredDetailsPresent
    # Context Requires:
    # - policy_details (Openhbx::Cv2::Policy)
    # - plan_details (HandlePolicyNotification::PlanDetails)
    # - member_detail_collection (array of HandlePolicyNotification::MemberDetails)
    # -  (HandlePolicyNotification::BrokerDetails may be nil)
    # - empbroker_detailsloyer_details (HandlePolicyNotification::EmployerDetails may be nil)
    # - processing_errors (HandlePolicyNotification::ProcessingErrors)
    #
    # Call "fail!" if validation does not pass.
    def call
      if policy_details.market.blank?
        context.processing_errors.errors.add(:policy_details, "No market found")
      end
      if policy_details.enrollment_group_id.blank?
        context.processing_errors.errors.add(:policy_details, "No Enrollment Group ID was submitted.")
      end
      if policy_details.pre_amt_tot.blank? || policy_details.tot_res_amt.blank? || policy_details.tot_emp_res_amt.blank?
        context.processing_errors.errors.add(:policy_details, "One ore more pieces of premium data was not included."
      end
      
      if plan_details.found_plan.nil?
        context.processing_errors.errors.add(
           :plan_details,
           "No plan found with HIOS ID #{plan_details.hios_id} and active year #{plan_details.active_year}"
        )
      end

      if processing_errors.has_errors?
        fail!
      end
    end
  end
end
