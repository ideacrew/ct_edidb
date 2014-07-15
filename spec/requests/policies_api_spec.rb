require 'spec_helper'

def expect_policy_cv_xml(policy_xml, policy)
  broker_xml = policy_xml['broker']
  broker = policy.broker
  expect(broker_xml['npn_id']).to eq broker.npn
  expect(broker_xml['name']).to eq broker.name_full

  expect_address_xml(broker_xml['address'], broker.addresses.first)
  expect_phone_xml(broker_xml['phone'], broker.phones.first)
  expect_email_xml(broker_xml['email'], broker.emails.first)

  enrollees_xml = policy_xml['enrollees']['enrollee']
  policy.enrollees.each_with_index do |enrollee, index|
    enrollee_xml = enrollees_xml[index]
    expect(enrollee_xml['premium_amount']).to eq enrollee.pre_amt.to_s
    expect(enrollee_xml['disabled']).to eq enrollee.ds.to_s
    expect(enrollee_xml['benefit_status']).to eq enrollee.ben_stat
    expect(enrollee_xml['employment_status']).to eq enrollee.emp_stat
    expect(enrollee_xml['relationship']).to eq enrollee.rel_code
    expect(enrollee_xml['carrier_assigned_member_id']).to eq enrollee.c_id
    expect(enrollee_xml['carrier_assigned_policy_id']).to eq enrollee.cp_id
    expect(enrollee_xml['coverage_start_date']).to eq enrollee.coverage_start.strftime("%Y-%m-%d")
    expect(enrollee_xml['coverage_end_date']).to eq enrollee.coverage_end.strftime("%Y-%m-%d")
    expect(enrollee_xml['coverage_status']).to eq enrollee.coverage_status
    
    expect_member_xml(enrollee_xml['member'], enrollee.member)
  end

  expect(policy_xml['premium_amount_total']).to eq policy.pre_amt_tot.to_s
  # expect(policy_xml['hbx_uri']).to eq nil
  # expect(policy_xml['hbx_id']).to eq nil
  expect(policy_xml['total_responsible_amount']).to eq policy.tot_res_amt.to_s
  expect(policy_xml['total_employer_responsible_amount']).to eq policy.tot_emp_res_amt.to_s
  expect(policy_xml['carrier_to_bill']).to eq policy.carrier_to_bill.to_s  
  
  plan_xml = policy_xml['plan']
  plan = policy.plan
  expect(plan_xml['hios_plan_id']).to eq plan.hios_plan_id
  expect(plan_xml['coverage_type']).to eq plan.coverage_type
  # expect(plan_xml['hbx_uri']).to eq ''
  # expect(plan_xml['hbx_id']).to eq ''
  # expect(plan_xml['csr']).to eq ''
  expect(plan_xml['ehb']).to eq plan.ehb.to_s

  carrier_xml = plan_xml['carrier']
  carrier = plan.carrier
  expect(carrier_xml['carrier_name']).to eq carrier.name
  # expect(plan_xml['carrier']['hbx_uri']).to eq ''
  expect(carrier_xml['hbx_id']).to eq carrier.hbx_carrier_id

  expect(policy_xml['allocated_aptc']).to eq policy.allocated_aptc.to_s  
  expect(policy_xml['elected_aptc_percent']).to eq policy.elected_aptc.to_s 
  expect(policy_xml['applied_aptc']).to eq policy.applied_aptc.to_s  

end

describe 'Policy API' do
  before { sign_in_as_a_valid_user }

  describe 'retrieving a policy by primary key' do 
    let(:policy) { create :policy }

    before do
      # The following must be done because of the loose association between 
      #   Enrollee and Member using the hbx_member_id
      policy.enrollees.each do |e|
        person = create(:person)
        person.members.first.hbx_member_id = e.m_id
        person.save!
      end
    end
    before { get "/api/v1/policies/#{policy.id}" }

    it 'is successful (200)' do
      expect(response).to be_success
    end

    it 'responds with CV XML in body' do
      xml = Hash.from_xml(response.body)
      expect_policy_cv_xml(xml['policy'], policy)
    end
  end

  describe 'searching for policies by enrollment group id' do
    let(:policies) { create_list(:policy, 3) }

    before do 
      # The following must be done because of the loose association between 
      #   Enrollee and Member using the hbx_member_id
      policies.each do |policy|
        policy.enrollees.each do |e|
          person = create(:person)
          person.members.first.hbx_member_id = e.m_id
          person.save!
        end
      end
    end
    
    before { get "/api/v1/policies?enrollment_group_id=#{policies.first.eg_id}" }

    it 'is successful (200)' do
      expect(response).to be_success
    end

    it 'responds with CV XML in body' do
      xml = Hash.from_xml(response.body)
      policies_xml = xml['policies']
      expect_policy_cv_xml(policies_xml['policy'], policies.first)
    end
  end
end