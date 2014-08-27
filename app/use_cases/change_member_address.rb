class ChangeMemberAddress
  def initialize(transmitter, listener, person_repo = Person)
    @listener = listener
    @person_repo = person_repo
    @transmitter = transmitter
  end

  def execute(req)
    request = req.to_hash
    person = @person_repo.find_for_member_id(request[:member_id])
    failed = false
    if(person.nil?)
      @listener.no_such_member({:member_id => request[:member_id]})
      @listener.fail
      return
    end

    active_policies = person.active_policies
    if(active_policies.empty?)
      @listener.no_active_policies
      failed = true
    end

    if (count_policies_by_coverage_type(active_policies, 'health') > 1)
      @listener.too_many_health_policies
      failed = true
    end

    if (count_policies_by_coverage_type(active_policies, 'dental') > 1)
      @listener.too_many_dental_policies
      failed = true
    end

    if failed
      @listener.fail
      return
    end

    active_policies.each do |policy|
      # people = people_with_members_address(policy, person)
      active_enrollees = policy.active_enrollees
      affected_enrollees = active_enrollees.select do |enrollee|
        person.addresses_match?(enrollee.person)
      end

      people = affected_enrollees.map { |e| e.person }

      people.each do |person|
        person.update_address(Address.new(
          address_type: 'home', 
          address_1: request[:line_one], 
          address_2: request[:line_two], 
          city: request[:city], 
          state: request[:state], 
          zip: request[:zip]
        ))
      end

      # TODO: Operation/Reason constant cleanup
      transmit_request = {
        policy_id: policy.id,
        operation: 'change',
        reason: 'change_of_location',
        affected_enrollee_ids: affected_enrollees.map(&:m_id),#enrollees.map(&:m_id),
        include_enrollee_ids: active_enrollees.map(&:m_id), #active and term...no canceled,
        current_user: 'me@example.com' 
      }

      @transmitter.execute(transmit_request)
    end
    @listener.success
  end

  def count_policies_by_coverage_type(policies, type)
    count = 0
    policies.count do |policy|
      policy.plan.coverage_type == type
    end
  end

  def people_with_members_address(policy, member_person)
    enrollees = policy.enrollees.select do |enrollee|
      member_person.addresses_match?(enrollee.person)
    end

    enrollees.map { |e| e.person }
    # policy.enrollees.inject([]) do |accum, enrollee|
    #   member_person.addresses_match?(enrollee.person) ? accum+[enrollee] : accum
    # end
  end

end
