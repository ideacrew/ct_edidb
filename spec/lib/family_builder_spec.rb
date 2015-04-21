require 'rails_helper'
require Rails.root.join('lib', 'import_families')

describe FamilyBuilder do

  let(:person_mapper) {
    double();
  }

  let(:member) {
    Member.new({:dob => "", :death_date => "", :ssn => "", :gender => "", :ethnicity => "", :race => "", :marital_status => ""})
  }

  let(:person) {
    Person.create({:id => "222", :members => [member]})
  }

  let(:family_member) {
    {is_primary_applicant: "true", family_member_id: "12333", person: person}
  }

  before(:each) {
    @params = {e_case_id: '12345', submitted_at: DateTime.now}

  }

  before(:all){
    @person = Person.create({:id => "222", name_first:"cool", :name_last  => "cool2", :members => [Member.new({:dob => "", :death_date => "", :ssn => "", :gender => "male", :ethnicity => "", :race => "", :marital_status => ""})]})
    @family_member_hash =   {is_primary_applicant: "true", family_member_id: "12333", person: @person}
    @person_mapper = ImportFamilies::PersonMapper.new
    @family_builder = FamilyBuilder.new(@params, @person_mapper)
    @family = @family_builder.family
    @policy = Policy.new()
  }

  context "initial state" do
    it "builds a valid family object" do
      expect(@family.class.name).to eq('Family')
      expect(@family.valid?).to be_true

    end

    it "should not have a irs_group" do
      expect(@family.irs_groups.length).to eq(0)
    end
  end

  it "adds a family_member" do
    @family_builder.add_family_member(@family_member_hash)
    expect(@family_builder.family.family_members.length).to eq(1)
  end

  it "saves successfully" do
    expect(@family.save!).to eq(true)
  end

end